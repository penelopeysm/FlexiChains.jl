module FCTuringExtTests

using AbstractMCMC: AbstractMCMC
using DimensionalData: DimensionalData as DD
using DynamicPPL: DynamicPPL
using FlexiChains: FlexiChains, VNChain, Parameter, Extra
using MCMCChains: MCMCChains
using Random: Random, Xoshiro
using Serialization: serialize, deserialize
using StableRNGs: StableRNG
using Test
using Turing

Turing.setprogress!(false)

@testset verbose = true "FlexiChainTuringExt" begin
    @info "Testing ext/turing.jl"

    @testset "sampling" begin
        @model function gdemo(x, y)
            s2 ~ InverseGamma(2, 3)
            m ~ Normal(0, sqrt(s2))
            x ~ Normal(m, sqrt(s2))
            return y ~ Normal(m, sqrt(s2))
        end
        model = gdemo(1.5, 2)

        @testset "single-chain sampling" begin
            chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
            @test chn isa VNChain
            @test size(chn) == (100, 1)
        end

        @testset "multi-chain sampling" begin
            chn = sample(
                model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false
            )
            @test chn isa VNChain
            @test size(chn) == (100, 3)
        end

        @testset "serialisation" begin
            chn = sample(
                model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false
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
                    Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                chn2 = sample(
                    Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                @test FlexiChains.has_same_data(chn1, chn2)
                chn3 = sample(
                    Xoshiro(469), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                @test !FlexiChains.has_same_data(chn1, chn3)
            end

            @testset "single-chain with seed!" begin
                Random.seed!(468)
                chn1 = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
                Random.seed!(468)
                chn2 = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
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
                    chain_type=VNChain,
                    verbose=false,
                )
                chn2 = sample(
                    Xoshiro(468),
                    model,
                    NUTS(),
                    MCMCSerial(),
                    100,
                    3;
                    chain_type=VNChain,
                    verbose=false,
                )
                @test FlexiChains.has_same_data(chn1, chn2)
                chn3 = sample(
                    Xoshiro(469),
                    model,
                    NUTS(),
                    MCMCSerial(),
                    100,
                    3;
                    chain_type=VNChain,
                    verbose=false,
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
            chn = sample(f(), NUTS(), 10; chain_type=VNChain, verbose=false)
            @test FlexiChains.parameters(chn) ==
                [@varname(a), @varname(x[1]), @varname(x[2]), @varname(b)]
        end

        @testset "underlying data is same as MCMCChains" begin
            chn_flexi = sample(
                Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false
            )
            chn_mcmc = sample(
                Xoshiro(468),
                model,
                NUTS(),
                100;
                chain_type=MCMCChains.Chains,
                verbose=false,
            )
            @test vec(chn_flexi[@varname(s2)]) == vec(chn_mcmc[:s2])
            @test vec(chn_flexi[@varname(m)]) == vec(chn_mcmc[:m])
            for lp_type in [:logprior, :loglikelihood]
                @test vec(chn_flexi[Extra(lp_type)]) == vec(chn_mcmc[lp_type])
            end
            # logjoint is stored as different names
            @test vec(chn_flexi[Extra(:logjoint)]) == vec(chn_mcmc[:lp])
        end

        @testset "with another sampler: $spl_name" for (spl_name, spl) in
                                                       [("MH", MH()), ("HMC", HMC(0.1, 10))]
            chn = sample(model, spl, 20; chain_type=VNChain)
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
                state=nothing;
                kwargs...,
            ) = (Tn(), nothing)
            # Get it to work with FlexiChains
            FlexiChains.to_varname_dict(::Tn) =
                Dict(Parameter(@varname(x)) => 1, Extra(:b) => "hi")
            # Then we should be able to sample
            chn = sample(model, S(), 20; chain_type=VNChain)
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
                chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
                @test only(FlexiChains.sampling_time(chn)) isa AbstractFloat
            end
            @testset "multiple chain" begin
                chn = sample(
                    model, NUTS(), MCMCThreads(), 100, 3; chain_type=VNChain, verbose=false
                )
                @test FlexiChains.sampling_time(chn) isa AbstractVector{<:AbstractFloat}
                @test length(FlexiChains.sampling_time(chn)) == 3
            end
        end

        @testset "save_state and initial_state" begin
            @model f() = x ~ Normal()
            model = f()

            # This sampler does nothing (it just stays at the existing state)
            struct StaticSampler <: AbstractMCMC.AbstractSampler end
            function Turing.Inference.initialstep(
                rng, model, ::StaticSampler, vi; kwargs...
            )
                return Turing.Inference.Transition(model, vi, nothing), vi
            end
            function AbstractMCMC.step(
                rng, model, ::StaticSampler, vi::DynamicPPL.AbstractVarInfo; kwargs...
            )
                return Turing.Inference.Transition(model, vi, nothing), vi
            end

            @testset "single chain" begin
                chn1 = sample(
                    model,
                    StaticSampler(),
                    10;
                    chain_type=VNChain,
                    verbose=false,
                    save_state=true,
                )
                # check that the sampler state is stored
                @test only(FlexiChains.last_sampler_state(chn1)) isa DynamicPPL.VarInfo
                # check that it can be resumed from
                chn2 = sample(
                    model,
                    StaticSampler(),
                    10;
                    chain_type=VNChain,
                    verbose=false,
                    initial_state=only(FlexiChains.last_sampler_state(chn1)),
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
                    chain_type=VNChain,
                    verbose=false,
                    save_state=true,
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
                    chain_type=VNChain,
                    verbose=false,
                    initial_state=FlexiChains.last_sampler_state(chn1),
                )
                # check that it did reuse the previous state
                xval = chn1[@varname(x)][end, :]
                @test all(i -> chn2[@varname(x)][i, :] == xval, 1:10)
            end
        end
    end

    @testset "summaries on chains from Turing" begin
        @model function f()
            x ~ Normal()
            y ~ Poisson()
            return z ~ MvNormal(zeros(2), I)
        end
        model = f()
        chn = sample(model, MH(), 100; chain_type=VNChain)
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

        ps = [ParamsWithStats(VarInfo(model), model) for _ in 1:50, _ in 1:3]
        c = AbstractMCMC.from_samples(VNChain, ps)
        @test c isa VNChain
        @test size(c) == (50, 3)
        @test FlexiChains.parameters(c) == [@varname(x), @varname(y)]
        @test c[@varname(x)] == map(p -> p.params[@varname(x)], ps)
        @test c[@varname(y)] == c[@varname(x)] .+ 1
        @test logpdf.(Normal(), c[@varname(x)]) ≈ c[Extra(:logprior)]
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
        ps = hcat([ParamsWithStats(VarInfo(model), model) for _ in 1:50])
        c = AbstractMCMC.from_samples(VNChain, ps)

        # Then convert back to ParamsWithStats
        arr_pss = AbstractMCMC.to_samples(ParamsWithStats, c)
        @test size(arr_pss) == (50, 1)
        for i in 1:50
            new_p = arr_pss[i, 1]
            p = ps[i]
            @test new_p.params == p.params
            @test new_p.stats == p.stats
        end
    end

    @testset "logp(model, chain)" begin
        @model function f()
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f() | (; y=1.0)
        chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
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
    end

    @testset "pointwise logprobs" begin
        @model function f(y)
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f(1.0)

        chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
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
    end

    @testset "returned" begin
        @model function f()
            x ~ Normal()
            y ~ MvNormal(zeros(2), I)
            return x + y[1] + y[2]
        end
        model = f()
        chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
        expected_rtnd = chn[@varname(x)] .+ chn[@varname(y[1])] .+ chn[@varname(y[2])]

        rtnd = returned(model, chn)
        @test isapprox(rtnd, expected_rtnd)
        @test rtnd isa DD.DimMatrix
        @test parent(parent(DD.dims(rtnd, :iter))) == FlexiChains.iter_indices(chn)
        @test parent(parent(DD.dims(rtnd, :chain))) == FlexiChains.chain_indices(chn)

        split_chn = FlexiChains.split_varnames(chn)
        split_rtnd = returned(model, split_chn)
        @test split_rtnd == rtnd
    end

    @testset "predict" begin
        @model function f()
            # Inserting a vector-valued parameter lets us check behaviour when splitting up
            # VarNames.
            m ~ MvNormal(zeros(2), I)
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f() | (; y=4.0)
        # Sample larger numbers so that we have some confidence that the results weren't
        # obtained by sheer luck.
        chn = sample(
            StableRNG(468),
            model,
            NUTS(),
            1000;
            chain_type=VNChain,
            discard_initial=1000,
            verbose=false,
        )
        # Sanity check
        @test isapprox(mean(chn[@varname(x)]), 2.0; atol=0.1)
        @test isapprox(mean(chn[@varname(m[1])]), 0.0; atol=0.1)
        @test isapprox(mean(chn[@varname(m[2])]), 0.0; atol=0.1)

        @testset "chain values are actually used" begin
            pdns = predict(StableRNG(468), f(), chn)
            # Sanity check.
            @test pdns[@varname(x)] == chn[@varname(x)]
            @test pdns[@varname(m)] == chn[@varname(m)]
            # Since the model was conditioned with y = 4.0, we should
            # expect that the chain's mean of x is approx 2.0.
            # So the posterior predictions for y should be centred on
            # 2.0 (ish).
            @test isapprox(mean(pdns[@varname(y)]), 2.0; atol=0.1)
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
            pdns = predict(f(), chn; include_all=false)
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

        @testset "still works after chain has been split up" begin
            # I mean, just in case people want to do it......
            split_chn = FlexiChains.split_varnames(chn)
            pdns_split = predict(Xoshiro(468), f(), split_chn)
            pdns_orig = predict(Xoshiro(468), f(), chn)
            for k in FlexiChains.parameters(pdns_split)
                @test pdns_split[k] == pdns_orig[k]
            end
        end

        @testset "rng is respected" begin
            pdns1 = predict(Xoshiro(468), f(), chn)
            pdns2 = predict(Xoshiro(468), f(), chn)
            @test FlexiChains.has_same_data(pdns1, pdns2)
            pdns3 = predict(Xoshiro(469), f(), chn)
            @test !FlexiChains.has_same_data(pdns1, pdns3)

            @testset "and also with split chain" begin
                split_chn = FlexiChains.split_varnames(chn)
                pdns1 = predict(Xoshiro(468), f(), split_chn)
                pdns2 = predict(Xoshiro(468), f(), split_chn)
                @test FlexiChains.has_same_data(pdns1, pdns2)
                pdns3 = predict(Xoshiro(469), f(), split_chn)
                @test !FlexiChains.has_same_data(pdns1, pdns3)
            end
        end
    end

    @testset "MCMCChains conversion" begin
        @model function f()
            x ~ Normal()
            y ~ MvNormal(zeros(3), I)
            return z ~ LKJCholesky(3, 2.0)
        end
        mcmcc = sample(
            Xoshiro(468), f(), NUTS(), 20; chain_type=MCMCChains.Chains, verbose=false
        )
        flexic = sample(Xoshiro(468), f(), NUTS(), 20; chain_type=VNChain, verbose=false)
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
    end
end

end # module
