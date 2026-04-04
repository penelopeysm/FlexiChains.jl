module FCTuringExtTests

using AbstractMCMC: AbstractMCMC
using DimensionalData: DimensionalData as DD
using DynamicPPL: DynamicPPL
using FlexiChains: FlexiChains, FlexiChain, VNChain, Parameter, Extra
using MCMCChains: MCMCChains
using OffsetArrays: OffsetArray
using Random: Random, Xoshiro
using Serialization: serialize, deserialize
using StableRNGs: StableRNG
using Test
using Turing

Turing.setprogress!(false)

# This sampler does nothing (it just stays at the existing state)
struct StaticSampler <: AbstractMCMC.AbstractSampler end
function Turing.Inference.initialstep(rng, model, ::StaticSampler, vi; kwargs...)
    return DynamicPPL.ParamsWithStats(vi, model), vi
end
function AbstractMCMC.step(
        rng, model, ::StaticSampler, vi::DynamicPPL.AbstractVarInfo; kwargs...
    )
    return DynamicPPL.ParamsWithStats(vi, model), vi
end

@testset verbose = true "FlexiChainTuringExt" begin
    @info "Testing ext/turing.jl"

    @testset "sampling" begin
        @model function demomodel(x)
            m ~ Normal(0, 1.0)
            x ~ Normal(m, 1.0)
            return nothing
        end
        model = demomodel(1.5)

        @testset "single-chain sampling" begin
            chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
            @test chn isa VNChain
            @test size(chn) == (100, 1)
        end

        @testset "multi-chain sampling" begin
            chn = sample(
                model, NUTS(), MCMCSerial(), 100, 3; chain_type = VNChain, verbose = false
            )
            @test chn isa VNChain
            @test size(chn) == (100, 3)
        end

        @testset "serialisation" begin
            chn = sample(
                model, NUTS(), MCMCSerial(), 100, 3; chain_type = VNChain, verbose = false
            )
            fname = Base.Filesystem.tempname()
            serialize(fname, chn)
            chn2 = deserialize(fname)
            @test isequal(chn, chn2)
            # also test ordering of keys, since isequal doesn't check that
            @test collect(keys(chn)) == collect(keys(chn2))
            # note that we can't test isequal(chn1, chn2) with save_state=true because the
            # states don't compare equal :( that would need to be fixed upstream in Turing
        end

        @testset "rng is respected" begin
            @testset "single-chain" begin
                chn1 = sample(
                    Xoshiro(468), model, NUTS(), 100; chain_type = VNChain, verbose = false
                )
                chn2 = sample(
                    Xoshiro(468), model, NUTS(), 100; chain_type = VNChain, verbose = false
                )
                @test FlexiChains.has_same_data(chn1, chn2)
                chn3 = sample(
                    Xoshiro(469), model, NUTS(), 100; chain_type = VNChain, verbose = false
                )
                @test !FlexiChains.has_same_data(chn1, chn3)
            end

            @testset "single-chain with seed!" begin
                Random.seed!(468)
                chn1 = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
                Random.seed!(468)
                chn2 = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
                @test FlexiChains.has_same_data(chn1, chn2)
            end

            @testset "multi-chain" begin
                chn1 = sample(
                    Xoshiro(468),
                    model,
                    NUTS(),
                    MCMCSerial(),
                    100,
                    3;
                    chain_type = VNChain,
                    verbose = false,
                )
                chn2 = sample(
                    Xoshiro(468),
                    model,
                    NUTS(),
                    MCMCSerial(),
                    100,
                    3;
                    chain_type = VNChain,
                    verbose = false,
                )
                @test FlexiChains.has_same_data(chn1, chn2)
                chn3 = sample(
                    Xoshiro(469),
                    model,
                    NUTS(),
                    MCMCSerial(),
                    100,
                    3;
                    chain_type = VNChain,
                    verbose = false,
                )
                @test !FlexiChains.has_same_data(chn1, chn3)
            end
        end

        @testset "ordering of parameters follows that of model" begin
            @model function f()
                a ~ Normal()
                x = zeros(2)
                x .~ Normal()
                return b ~ Normal()
            end
            chn = sample(f(), NUTS(), 10; chain_type = VNChain, verbose = false)
            @test FlexiChains.parameters(chn) == [@varname(a), @varname(x), @varname(b)]
        end

        @testset "underlying data is same as MCMCChains" begin
            chn_flexi = sample(
                Xoshiro(468), model, NUTS(), 100; chain_type = VNChain, verbose = false
            )
            chn_mcmc = sample(
                Xoshiro(468),
                model,
                NUTS(),
                100;
                chain_type = MCMCChains.Chains,
                verbose = false,
            )
            @test vec(chn_flexi[@varname(m)]) == vec(chn_mcmc[:m])
            for lp_type in [:logprior, :loglikelihood, :logjoint]
                @test vec(chn_flexi[Extra(lp_type)]) == vec(chn_mcmc[lp_type])
            end
        end

        @testset "with another sampler: $spl_name" for (spl_name, spl) in
            [("MH", MH()), ("HMC", HMC(0.1, 10))]
            chn = sample(model, spl, 20; chain_type = VNChain)
            @test chn isa VNChain
            @test size(chn) == (20, 1)
        end

        @testset "with a custom sampler" begin
            # Set up the sampler itself.
            struct S <: AbstractMCMC.AbstractSampler end
            struct Tn end
            AbstractMCMC.step(
                rng::Random.AbstractRNG,
                model::DynamicPPL.Model,
                ::S,
                state = nothing;
                kwargs...,
            ) = (Tn(), nothing)
            # Get it to work with FlexiChains
            FlexiChains.to_vnt_and_stats(::Tn) = (VarNamedTuple(; x = 1), (; b = "hi"))
            # Then we should be able to sample
            chn = sample(model, S(), 20; chain_type = VNChain)
            @test chn isa VNChain
            @test size(chn) == (20, 1)
            @test all(x -> x == 1, vec(chn[@varname(x)]))
            @test all(x -> x == "hi", vec(chn[Extra(:b)]))
        end
    end

    @testset "chain metadata" begin
        @testset "sampling time exists" begin
            @model f() = x ~ Normal()
            model = f()

            @testset "single chain" begin
                chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
                @test only(FlexiChains.sampling_time(chn)) isa AbstractFloat
            end
            @testset "multiple chain" begin
                chn = sample(
                    model, NUTS(), MCMCThreads(), 100, 3; chain_type = VNChain, verbose = false
                )
                @test FlexiChains.sampling_time(chn) isa AbstractVector{<:AbstractFloat}
                @test length(FlexiChains.sampling_time(chn)) == 3
            end
        end

        @testset "save_state and initial_state" begin
            @model f() = x ~ Normal()
            model = f()

            @testset "single chain" begin
                chn1 = sample(
                    model,
                    StaticSampler(),
                    10;
                    chain_type = VNChain,
                    verbose = false,
                    save_state = true,
                )
                # check that the sampler state is stored
                @test only(FlexiChains.last_sampler_state(chn1)) isa DynamicPPL.VarInfo
                # check that it can be resumed from
                chn2 = sample(
                    model,
                    StaticSampler(),
                    10;
                    chain_type = VNChain,
                    verbose = false,
                    initial_state = only(FlexiChains.last_sampler_state(chn1)),
                )
                # check that it did reuse the previous state
                xval = chn1[@varname(x)][end]
                @test all(x -> x == xval, chn2[@varname(x)])
            end

            @testset "multiple chain" begin
                chn1 = sample(
                    model,
                    StaticSampler(),
                    MCMCThreads(),
                    10,
                    3;
                    chain_type = VNChain,
                    verbose = false,
                    save_state = true,
                )
                # check that the sampler state is stored
                @test FlexiChains.last_sampler_state(chn1) isa
                    AbstractVector{<:DynamicPPL.VarInfo}
                @test length(FlexiChains.last_sampler_state(chn1)) == 3
                # check that it can be resumed from
                chn2 = sample(
                    model,
                    StaticSampler(),
                    MCMCThreads(),
                    10,
                    3;
                    chain_type = VNChain,
                    verbose = false,
                    initial_state = FlexiChains.last_sampler_state(chn1),
                )
                # check that it did reuse the previous state
                xval = chn1[@varname(x)][end, :]
                @test all(i -> chn2[@varname(x)][i, :] == xval, 1:10)
            end
        end
    end

    @testset "InitFromParams(chain, i, j)" begin
        @model function f()
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f()
        chn = sample(model, NUTS(), 100; chain_type = VNChain)
        chn2 = sample(
            model,
            StaticSampler(),
            10;
            chain_type = VNChain,
            initial_params = InitFromParams(chn, 10, 1),
        )
        @test all(x -> x == chn[@varname(x), iter = 10, chain = 1], chn2[@varname(x)])
        @test all(y -> y == chn[@varname(y), iter = 10, chain = 1], chn2[@varname(y)])
    end

    @testset "summaries on chains from Turing" begin
        @model function f()
            x ~ Normal()
            y ~ Poisson()
            return z ~ MvNormal(zeros(2), I)
        end
        model = f()
        chn = sample(model, MH(), 100; chain_type = VNChain)
        ss = FlexiChains.summarystats(chn)
        @test ss isa FlexiChains.FlexiSummary
        @test Set(FlexiChains.parameters(ss)) ==
            Set([@varname(x), @varname(y), @varname(z[1]), @varname(z[2])])
        display(ss)
    end

    @testset "AbstractMCMC.from_samples" begin
        @model function f(z)
            x ~ Normal()
            y := x + 1
            return z ~ Normal(y)
        end

        z = 1.0
        model = f(z)

        ps = [
            DynamicPPL.ParamsWithStats(DynamicPPL.VarInfo(model), model) for _ in 1:50,
                _ in 1:3
        ]
        c = AbstractMCMC.from_samples(VNChain, ps)
        @test c isa VNChain
        @test size(c) == (50, 3)
        @test FlexiChains.parameters(c) == [@varname(x), @varname(y)]
        @test c[@varname(x)] == map(p -> p.params[@varname(x)], ps)
        @test c[@varname(y)] == c[@varname(x)] .+ 1
        @test logpdf.(Normal(), c[@varname(x)]) ≈ c[Extra(:logprior)]
    end

    @testset "parameters_at and values_at" begin
        @model function f()
            x ~ Normal()
            y = zeros(3)
            y[2] ~ Normal()
            z = (; a = nothing)
            return z.a ~ Normal()
        end
        Ni, Nc = 10, 2
        # These should give the same results, but chn is just the ParamsWithStats
        # bundled into a VNChain. (For chain_type=Any, default bundle_samples gives
        # a vector of vectors, so we use stack to get it into an Ni * Nc matrix.)
        chn = sample(Xoshiro(468), f(), Prior(), MCMCSerial(), Ni, Nc; chain_type = VNChain)
        pwss = stack(
            sample(Xoshiro(468), f(), Prior(), MCMCSerial(), Ni, Nc; chain_type = Any)
        )

        for i in 1:Ni, c in 1:Nc
            prms = FlexiChains.parameters_at(chn; iter = i, chain = c)
            @test prms isa VarNamedTuple
            @test prms == pwss[i, c].params
            vals = FlexiChains.values_at(chn; iter = i, chain = c)
            @test vals isa DynamicPPL.ParamsWithStats
            @test vals == pwss[i, c]
        end
    end

    @testset "return type of rand" begin
        @model function f()
            x ~ Normal()
            y ~ Normal()
            return nothing
        end
        chn = sample(f(), Prior(), 10; chain_type = VNChain)
        @test rand(chn) isa DynamicPPL.ParamsWithStats
        @test rand(chn; parameters_only = true) isa DynamicPPL.VarNamedTuple
        @test rand(chn, 5) isa Vector{<:DynamicPPL.ParamsWithStats}
        @test rand(chn, 5; parameters_only = true) isa Vector{<:DynamicPPL.VarNamedTuple}
    end

    @testset "AbstractMCMC.to_samples" begin
        @model function f(z)
            x ~ Normal()
            y := x + 1
            return z ~ Normal(y)
        end
        # Make the chain first
        z = 1.0
        model = f(z)
        ps = hcat(
            [
                DynamicPPL.ParamsWithStats(DynamicPPL.VarInfo(model), model) for _ in 1:50
            ]
        )
        c = AbstractMCMC.from_samples(VNChain, ps)

        # Then convert back to ParamsWithStats
        @model function newmodel()
            error(
                "This model should never be run, because there is structure info" *
                    " in the chain.",
            )
            x ~ Normal()
            return nothing
        end

        @testset "with model" begin
            # Make sure that the model isn't actually ever used, by passing one that
            # errors when run.
            arr_pss = AbstractMCMC.to_samples(DynamicPPL.ParamsWithStats, c, newmodel())
            @test arr_pss == ps
        end
        @testset "without model" begin
            arr_pss = AbstractMCMC.to_samples(DynamicPPL.ParamsWithStats, c)
            @test arr_pss == ps
        end
    end

    @testset "logp(model, chain)" begin
        @model function f()
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f() | (; y = 1.0)
        chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
        xs = chn[@varname(x)]
        expected_logprior = logpdf.(Normal(), xs)
        expected_loglike = logpdf.(Normal.(xs), 1.0)

        @testset "logprior" begin
            lprior = logprior(model, chn)
            @test isapprox(lprior, expected_logprior)
            @test parent(parent(DD.dims(lprior, :iter))) == FlexiChains.iter_indices(chn)
            @test parent(parent(DD.dims(lprior, :chain))) == FlexiChains.chain_indices(chn)
        end
        @testset "loglikelihood" begin
            llike = loglikelihood(model, chn)
            @test isapprox(llike, expected_loglike)
            @test parent(parent(DD.dims(llike, :iter))) == FlexiChains.iter_indices(chn)
            @test parent(parent(DD.dims(llike, :chain))) == FlexiChains.chain_indices(chn)
        end
        @testset "logjoint" begin
            ljoint = logjoint(model, chn)
            @test isapprox(ljoint, expected_logprior .+ expected_loglike)
            @test parent(parent(DD.dims(ljoint, :iter))) == FlexiChains.iter_indices(chn)
            @test parent(parent(DD.dims(ljoint, :chain))) == FlexiChains.chain_indices(chn)
        end

        @testset "errors on missing variables" begin
            @model function xonly()
                return x ~ Normal()
            end
            @model function xy()
                x ~ Normal()
                return y ~ Normal()
            end
            chn = sample(xonly(), NUTS(), 100; chain_type = VNChain, verbose = false)
            @test_throws "not found in chain" logprior(xy(), chn)
            @test_throws "not found in chain" loglikelihood(xy(), chn)
            @test_throws "not found in chain" logjoint(xy(), chn)
        end

        @testset "with non-standard Array variables" begin
            @model function offset_lp(y)
                x = OffsetArray(zeros(2), -2:-1)
                x[-2] ~ Normal()
                y ~ Normal(x[-2])
                return nothing
            end
            model = offset_lp(2.0)
            chn = sample(model, NUTS(), 50; chain_type = VNChain, verbose = false)
            lprior = logprior(model, chn)
            @test logprior(model, chn) ≈ logpdf.(Normal(), chn[@varname(x[-2])])
            @test loglikelihood(model, chn) ≈ logpdf.(Normal.(chn[@varname(x[-2])]), 2.0)
        end
    end

    @testset "pointwise logprobs" begin
        @model function f(y)
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f(1.0)

        chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
        xs = chn[@varname(x)]

        @testset "logdensities" begin
            pld = DynamicPPL.pointwise_logdensities(model, chn)
            @test pld isa VNChain
            @test FlexiChains.iter_indices(pld) == FlexiChains.iter_indices(chn)
            @test FlexiChains.chain_indices(pld) == FlexiChains.chain_indices(chn)
            @test length(keys(pld)) == 2
            @test isapprox(pld[@varname(x)], logpdf.(Normal(), xs))
            @test isapprox(pld[@varname(y)], logpdf.(Normal.(xs), 1.0))
        end

        @testset "loglikelihoods" begin
            pld = DynamicPPL.pointwise_loglikelihoods(model, chn)
            @test pld isa VNChain
            @test FlexiChains.iter_indices(pld) == FlexiChains.iter_indices(chn)
            @test FlexiChains.chain_indices(pld) == FlexiChains.chain_indices(chn)
            @test length(keys(pld)) == 1
            @test isapprox(pld[@varname(y)], logpdf.(Normal.(xs), 1.0))
        end

        @testset "logpriors" begin
            pld = DynamicPPL.pointwise_prior_logdensities(model, chn)
            @test pld isa VNChain
            @test FlexiChains.iter_indices(pld) == FlexiChains.iter_indices(chn)
            @test FlexiChains.chain_indices(pld) == FlexiChains.chain_indices(chn)
            @test length(keys(pld)) == 1
            @test isapprox(pld[@varname(x)], logpdf.(Normal(), xs))
        end

        @testset "errors on missing variables" begin
            @model function xonly()
                return x ~ Normal()
            end
            @model function xy()
                x ~ Normal()
                return y ~ Normal()
            end
            chn = sample(xonly(), NUTS(), 100; chain_type = VNChain, verbose = false)
            @test_throws "not found in chain" DynamicPPL.pointwise_logdensities(xy(), chn)
            @test_throws "not found in chain" DynamicPPL.pointwise_loglikelihoods(xy(), chn)
            @test_throws "not found in chain" DynamicPPL.pointwise_prior_logdensities(
                xy(), chn
            )
        end

        @testset "with non-standard Array variables" begin
            @model function offset_pld(y)
                x = OffsetArray(zeros(2), -2:-1)
                x[-2] ~ Normal()
                y ~ Normal(x[-2])
                return nothing
            end
            model = offset_pld(2.0)
            chn = sample(model, NUTS(), 50; chain_type = VNChain, verbose = false)
            plds = DynamicPPL.pointwise_logdensities(model, chn)
            @test plds[@varname(x[-2])] == logpdf.(Normal(), chn[@varname(x[-2])])
            @test plds[@varname(y)] == logpdf.(Normal.(chn[@varname(x[-2])]), 2.0)
        end
    end

    @testset "returned" begin
        @model function f()
            x ~ Normal()
            y ~ MvNormal(zeros(2), I)
            return x + y[1] + y[2]
        end
        model = f()
        chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
        expected_rtnd = chn[@varname(x)] .+ chn[@varname(y[1])] .+ chn[@varname(y[2])]

        rtnd = returned(model, chn)
        @test isapprox(rtnd, expected_rtnd)
        @test rtnd isa DD.DimMatrix
        @test parent(parent(DD.dims(rtnd, :iter))) == FlexiChains.iter_indices(chn)
        @test parent(parent(DD.dims(rtnd, :chain))) == FlexiChains.chain_indices(chn)

        @testset "works even for dists that hasvalue isn't implemented for" begin
            @model function f_product()
                return x ~ product_distribution((; a = Normal()))
            end
            model = f_product()
            chn = sample(model, NUTS(), 100; chain_type = VNChain, verbose = false)
            rets = returned(f_product(), chn)
            @test chn[@varname(x)] == rets
        end

        @testset "errors on missing variables" begin
            @model function xonly()
                return x ~ Normal()
            end
            @model function xy()
                x ~ Normal()
                return y ~ Normal()
            end
            chn = sample(xonly(), NUTS(), 100; chain_type = VNChain, verbose = false)
            @test_throws "not found in chain" returned(xy(), chn)
        end

        @testset "stacks DimArray return values" begin
            @model function return_dimarray()
                x ~ Normal()
                return DD.DimArray(randn(2, 3), (:a, :b))
            end
            chn = sample(return_dimarray(), NUTS(), 50; chain_type = VNChain, verbose = false)
            rets = returned(return_dimarray(), chn)
            @test rets isa DD.DimArray{T, 4} where {T}
            @test size(rets) == (50, 1, 2, 3)
            @test DD.name.(DD.dims(rets)) == (:iter, :chain, :a, :b)
        end

        @testset "with non-standard Array variables" begin
            # This essentially tests that templates are correctly used when calling
            # returned()
            @model function offset()
                x = OffsetArray(zeros(2), -2:-1)
                # Don't sample all elements of `x` to prevent it from being densified,
                # thus bypassing the code that we want to check.
                x[-2] ~ Normal()
                return first(x)
            end
            model = offset()
            chn = sample(model, NUTS(), 50; chain_type = VNChain, verbose = false)
            rets = returned(model, chn)
            @test rets == chn[@varname(x[-2])]
        end
    end

    @testset "predict" begin
        @model function f()
            # By default, FlexiChains will store `m` as a single variable. However, this
            # also lets us check behaviour after splitting up VarNames (i.e., if the chain
            # has m[1] and m[2] but the model has m).
            m ~ MvNormal(zeros(2), I)
            # Same but with dot tilde; on DPPL v0.40 onwards, the model will have p[1] and
            # p[2] but since the VNT is densified before chain construction, the chain will
            # have p.
            p = zeros(2)
            p .~ Normal()
            # Then some normal parameters.
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f() | (; y = 4.0)
        # Sample larger numbers so that we have some confidence that the results weren't
        # obtained by sheer luck.
        chn = sample(
            StableRNG(468),
            model,
            NUTS(),
            1000;
            chain_type = VNChain,
            discard_initial = 1000,
            verbose = false,
        )
        # Sanity check
        @test isapprox(mean(chn[@varname(x)]), 2.0; atol = 0.1)
        @test isapprox(mean(chn[@varname(m[1])]), 0.0; atol = 0.1)
        @test isapprox(mean(chn[@varname(m[2])]), 0.0; atol = 0.1)
        @test isapprox(mean(chn[@varname(p[1])]), 0.0; atol = 0.1)
        @test isapprox(mean(chn[@varname(p[2])]), 0.0; atol = 0.1)

        @testset "chain values are actually used" begin
            pdns = predict(StableRNG(468), f(), chn)
            # Sanity check.
            @test pdns[@varname(x)] == chn[@varname(x)]
            @test pdns[@varname(m)] == chn[@varname(m)]
            @test pdns[@varname(p)] == chn[@varname(p)]
            # Since the model was conditioned with y = 4.0, we should
            # expect that the chain's mean of x is approx 2.0.
            # So the posterior predictions for y should be centred on
            # 2.0 (ish).
            @test isapprox(mean(pdns[@varname(y)]), 2.0; atol = 0.1)
        end

        @testset "logp" begin
            pdns = predict(f(), chn)
            # Since we deconditioned `y`, there are no likelihood terms.
            @test all(iszero, pdns[FlexiChains._LOGLIKELIHOOD_KEY])
            # The logprior should be the same as that of the original chain, but
            # with an extra term for y ~ Normal(x)
            chn_logprior = chn[FlexiChains._LOGPRIOR_KEY]
            pdns_logprior = pdns[FlexiChains._LOGPRIOR_KEY]
            expected_diff = logpdf.(Normal.(chn[@varname(x)]), pdns[@varname(y)])
            @test isapprox(pdns_logprior, chn_logprior .+ expected_diff)
            # Logjoint should be the same as logprior
            @test pdns[FlexiChains._LOGJOINT_KEY] == pdns[FlexiChains._LOGPRIOR_KEY]
        end

        @testset "non-parameter keys are preserved" begin
            pdns = predict(f(), chn)
            display(chn)
            display(pdns)
            # Check that the only new thing added was the prediction for y.
            @test only(setdiff(Set(keys(pdns)), Set(keys(chn)))) == Parameter(@varname(y))
            # Check that no other keys originally in `chn` were removed.
            @test isempty(setdiff(Set(keys(chn)), Set(keys(pdns))))
        end

        @testset "include_all=false" begin
            pdns = predict(f(), chn; include_all = false)
            # Check that the only parameter in the chain is the prediction for y.
            @test only(Set(FlexiChains.parameters(pdns))) == @varname(y)
        end

        @testset "indices are preserved" begin
            pdns = predict(f(), chn)
            @test FlexiChains.iter_indices(pdns) == FlexiChains.iter_indices(chn)
            @test FlexiChains.chain_indices(pdns) == FlexiChains.chain_indices(chn)
        end

        @testset "no sampling time and sampler state" begin
            # it just doesn't really make sense for the predictions to carry those
            # information
            pdns = predict(f(), chn)
            @test all(ismissing, FlexiChains.sampling_time(pdns))
            @test all(ismissing, FlexiChains.last_sampler_state(pdns))
        end

        @testset "rng is respected" begin
            pdns1 = predict(Xoshiro(468), f(), chn)
            pdns2 = predict(Xoshiro(468), f(), chn)
            @test FlexiChains.has_same_data(pdns1, pdns2)
            pdns3 = predict(Xoshiro(469), f(), chn)
            @test !FlexiChains.has_same_data(pdns1, pdns3)
        end

        @testset "with non-standard Array variables" begin
            # This essentially tests that templates are correctly used when calling
            # predict().
            @model function offset2()
                x = OffsetArray(zeros(2), -2:-1)
                # Don't sample all elements of `x` to prevent it from being densified,
                # thus bypassing the code that we want to check.
                x[-2] ~ Normal()
                return y ~ Normal(x[-2])
            end
            cond_model = offset2() | (; y = 2.0)
            chn = sample(
                StableRNG(468), cond_model, NUTS(), 1000; chain_type = VNChain, verbose = false
            )
            @test mean(chn[@varname(x[-2])]) ≈ 1.0 atol = 0.05
            pdns = predict(StableRNG(468), offset2(), chn)
            @test pdns[@varname(x[-2])] == chn[@varname(x[-2])]
            @test mean(pdns[@varname(y)]) ≈ 1.0 atol = 0.05
        end
    end

    @testset "FlexiChain -> MCMCChains" begin
        @model function f()
            x ~ Normal()
            y ~ MvNormal(zeros(3), I)
            return z ~ LKJCholesky(3, 2.0)
        end
        mcmcc = sample(
            Xoshiro(468), f(), NUTS(), 20; chain_type = MCMCChains.Chains, verbose = false
        )
        flexic = sample(Xoshiro(468), f(), NUTS(), 20; chain_type = VNChain, verbose = false)
        new_mcmcc = MCMCChains.Chains(flexic)

        @testset "the data itself" begin
            @test Set(keys(new_mcmcc)) == Set(keys(mcmcc))
            for k in keys(new_mcmcc)
                @test new_mcmcc[k] == mcmcc[k]
            end
        end

        @testset "iteration indices" begin
            @test FlexiChains.iter_indices(flexic) == range(new_mcmcc)
            @test range(new_mcmcc) == range(mcmcc)
        end

        @testset "grouping of data into sections" begin
            @test Set(keys(new_mcmcc.name_map)) == Set(keys(mcmcc.name_map))
            for k in keys(new_mcmcc.name_map)
                # each of these is a vector which may be in a different order
                @test Set(new_mcmcc.name_map[k]) == Set(mcmcc.name_map[k])
            end
        end

        @testset "sampling time is preserved" begin
            @test hasproperty(new_mcmcc.info, :start_time)
            @test hasproperty(new_mcmcc.info, :stop_time)
            durations = new_mcmcc.info.stop_time .- new_mcmcc.info.start_time
            @test durations ≈ FlexiChains.sampling_time(flexic)
        end

        @testset "sampler state is preserved with save_state=true" begin
            flexic_with_state = sample(
                Xoshiro(468), f(), NUTS(), 20;
                chain_type = VNChain, verbose = false, save_state = true,
            )
            mc_with_state = MCMCChains.Chains(flexic_with_state)
            @test hasproperty(mc_with_state.info, :samplerstate)
            @test mc_with_state.info.samplerstate ==
                FlexiChains.last_sampler_state(flexic_with_state)
        end
    end

    @testset "MCMCChains -> FlexiChain{Symbol}" begin
        @model function g()
            m ~ Normal(0, 1.0)
            s ~ InverseGamma(2, 3)
            return 1.5 ~ Normal(m, sqrt(s))
        end

        @testset "single chain" begin
            chn = sample(g(), MH(), 100; verbose = false)
            fc = FlexiChain{Symbol}(chn)

            @test fc isa FlexiChain{Symbol}
            @test size(fc) == (size(chn, 1), size(chn, 3))

            # Key names & grouping
            @test Set(FlexiChains.parameters(fc)) == Set(names(chn, :parameters))
            for name in names(chn, :internals)
                @test Extra(name) in FlexiChains.extras(fc)
            end
            # Data
            for name in names(chn)
                k = name in names(chn, :parameters) ? Parameter(name) : Extra(name)
                @test fc[k] == chn[:, name, :].data
            end
            # Iteration indices
            @test collect(FlexiChains.iter_indices(fc)) == collect(range(chn))
            # Sampling time
            @test !any(ismissing, FlexiChains.sampling_time(fc))
            @test only(FlexiChains.sampling_time(fc)) > 0
        end

        @testset "multiple chains" begin
            ni, nc = 100, 3
            chn = sample(g(), MH(), MCMCSerial(), ni, nc; verbose = false)
            fc = FlexiChain{Symbol}(chn)
            @test size(fc) == (ni, nc)
            for name in names(chn, :parameters)
                @test fc[Parameter(name)] == chn[:, name, :].data
            end
            st = FlexiChains.sampling_time(fc)
            @test length(st) == nc
            # Sometimes the sampling time is exactly 0 -- unsure why, so test for >= rather
            # than >.
            @test all(t -> t >= 0, st)
        end

        @testset "sampler state is preserved" begin
            chn = sample(g(), MH(), 50; verbose = false, save_state = true)
            @test hasproperty(chn.info, :samplerstate)
            fc = FlexiChain{Symbol}(chn)
            lss = FlexiChains.last_sampler_state(fc)
            @test !all(ismissing, lss)
        end
    end

    @testset "Models with variable-length parameters" begin
        # These tests are mainly to check the interaction of VarNamedTuple with chains.
        @testset "single variable" begin
            @model function varlen_single()
                n ~ DiscreteUniform(2, 5)
                x ~ MvNormal(zeros(n), I)
                y ~ Normal(sum(x))
                return prod(x)
            end
            cond_model = varlen_single() | (; y = 1.0)
            chn = sample(cond_model, MH(), 100; chain_type = VNChain, verbose = false)
            # Sanity check
            @test chn[@varname(n)] == length.(chn[@varname(x)])
            # Check that returned and predict both work. For returned we can also
            # check correctness, but for predict we just check that it runs.
            @test isapprox(returned(cond_model, chn), prod.(chn[@varname(x)]))
            pdns = predict(varlen_single(), chn)
            @test pdns isa VNChain
            for vn in FlexiChains.parameters(chn)
                @test pdns[vn] == chn[vn]
            end
            @test @varname(y) in FlexiChains.parameters(pdns)
        end

        @testset "dense vector" begin
            # For this model, `x` should still be represented in the chain as a single
            # variable, since the PartialArray will get densified.
            @model function varlen_dense()
                n ~ DiscreteUniform(2, 5)
                x = zeros(n)
                x .~ Normal()
                y ~ Normal(sum(x))
                return prod(x)
            end
            cond_model = varlen_dense() | (; y = 1.0)
            chn = sample(cond_model, MH(), 100; chain_type = VNChain, verbose = false)
            # Sanity check
            @test chn[@varname(n)] == length.(chn[@varname(x)])
            # Check that returned and predict both work. For returned we can also
            # check correctness, but for predict we just check that it runs.
            @test isapprox(returned(cond_model, chn), prod.(chn[@varname(x)]))
            pdns = predict(varlen_dense(), chn)
            @test pdns isa VNChain
            for vn in FlexiChains.parameters(chn)
                @test pdns[vn] == chn[vn]
            end
            @test @varname(y) in FlexiChains.parameters(pdns)
        end

        @testset "nondense (sparse?) vector" begin
            # For this model, `x` will be broken up in the chain, because not
            # all entries in the PartialArray are filled
            @model function varlen_nondense()
                n ~ DiscreteUniform(2, 5)
                x = zeros(n + 2)
                for i in 1:n
                    x[i] ~ Normal()
                end
                y ~ Normal(sum(x[1:n]))
                return prod(x[1:n])
            end
            cond_model = varlen_nondense() | (; y = 1.0)
            chn = sample(cond_model, MH(), 100; chain_type = VNChain, verbose = false)
            # Check that returned and predict both work.
            @test returned(cond_model, chn) isa DD.DimArray
            pdns = predict(varlen_nondense(), chn)
            @test pdns isa VNChain
            for vn in FlexiChains.parameters(chn)
                @test isequal(pdns[vn], chn[vn]) # might have missing so need isequal
            end
            @test @varname(y) in FlexiChains.parameters(pdns)
        end
    end
end

end # module
