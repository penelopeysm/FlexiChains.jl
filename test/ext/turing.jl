module FCTuringExtTests

using FlexiChains: FlexiChains, VNChain, Parameter, Extra
using FlexiChains: FlexiChains
using Random: Random, Xoshiro
using SliceSampling: RandPermGibbs, SliceSteppingOut
using Test
using Turing
using Turing: MCMCChains, AbstractMCMC

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

        @testset "rng is respected" begin
            @testset "single-chain" begin
                chn1 = sample(
                    Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                chn2 = sample(
                    Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                @test chn1 == chn2
                chn3 = sample(
                    Xoshiro(469), model, NUTS(), 100; chain_type=VNChain, verbose=false
                )
                @test chn1 != chn3
            end

            @testset "single-chain with seed!" begin
                Random.seed!(468)
                chn1 = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
                Random.seed!(468)
                chn2 = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
                @test chn1 == chn2
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
                @test chn1 == chn2
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
                @test chn1 != chn3
            end
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
            for lp_type in [:lp, :logprior, :loglikelihood]
                @test vec(chn_flexi[:logprobs, lp_type]) == vec(chn_mcmc[lp_type])
            end
        end

        @testset "with another sampler: $spl_name" for (spl_name, spl) in [
            ("MH", MH()),
            ("HMC", HMC(0.1, 10)),
            ("PG", PG(5)),
            ("SliceSampling.jl", externalsampler(RandPermGibbs(SliceSteppingOut(2.0)))),
        ]
            chn = sample(model, spl, 20; chain_type=VNChain)
            @test chn isa VNChain
            @test size(chn) == (20, 1)
        end

        @testset "with a custom sampler" begin
            # Set up the sampler itself.
            struct S <: AbstractMCMC.AbstractSampler end
            struct Tn end
            AbstractMCMC.step(rng, model, ::S, state=nothing; kwargs...) = (Tn(), nothing)
            # Get it to work with FlexiChains
            FlexiChains.to_varname_dict(::Tn) =
                Dict(Parameter(@varname(x)) => 1, Extra(:a, :b) => "hi")
            # Then we should be able to sample
            chn = sample(model, S(), 20; chain_type=VNChain)
            @test chn isa VNChain
            @test size(chn) == (20, 1)
            @test all(x -> x == 1, vec(chn[@varname(x)]))
            @test all(x -> x == "hi", vec(chn[:a, :b]))
        end
    end

    @testset "chain metadata" begin
        @test "sampling time exists" begin
            @model f() = x ~ Normal()
            model = f()
            chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
            @test FlexiChains.sampling_time(chn) isa AbstractFloat
        end

        @testset "save_state and resume_from" begin
            Random.seed!(468)
            @model f() = x ~ Normal()
            model = f()
            chn1 = sample(
                model, NUTS(), 100; chain_type=VNChain, verbose=false, save_state=true
            )
            @test isapprox(mean(chn1[@varname(x)]), 0.0; atol=0.1)
            # check that the sampler state is stored
            @test FlexiChains.last_sampler_state(chn1) !== nothing
            # check that it can be resumed from
            chn2 = sample(
                model, NUTS(), 100; chain_type=VNChain, verbose=false, resume_from=chn1
            )
            @test isapprox(mean(chn2[@varname(x)]), 0.0; atol=0.1)
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
        end
        @testset "loglikelihood" begin
            llike = loglikelihood(model, chn)
            @test isapprox(llike, expected_loglike)
        end
        @testset "logjoint" begin
            ljoint = logjoint(model, chn)
            @test isapprox(ljoint, expected_logprior .+ expected_loglike)
        end
    end

    @testset "returned" begin
        @model function f()
            x ~ Normal()
            return x + 1
        end
        model = f()
        chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
        expected_rtnd = chn[:x] .+ 1
        rtnd = returned(model, chn)
        @test isapprox(rtnd, expected_rtnd)
    end

    @testset "predict" begin
        @model function f()
            x ~ Normal()
            return y ~ Normal(x)
        end
        model = f() | (; y=4.0)
        # We sample larger numbers so that we have some confidence that
        # the results weren't obtained by sheer luck.
        # TODO: Use StableRNG. I couldn't download the package because
        # train WiFi.
        chn = sample(
            Xoshiro(468),
            model,
            NUTS(),
            1000;
            chain_type=VNChain,
            discard_initial=1000,
            verbose=false,
        )
        # Sanity check
        @test isapprox(mean(chn[@varname(x)]), 2.0; atol=0.1)

        @testset "chain values are actually used" begin
            # TODO: Use StableRNG. I couldn't download the package because
            # train WiFi.
            pdns = predict(Xoshiro(468), f(), chn)
            # Sanity check.
            @test pdns[@varname(x)] == chn[@varname(x)]
            # Since the model was conditioned with y = 4.0, we should
            # expect that the chain's mean of x is approx 2.0.
            # So the posterior predictions for y should be centred on
            # 1.0 (ish).
            @test isapprox(mean(pdns[@varname(y)]), 2.0; atol=0.1)
        end

        @testset "non-parameter keys are preserved" begin
            chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
            pdns = predict(f(), chn)
            # Check that the only new thing added was the prediction for y.
            @test only(setdiff(Set(keys(pdns)), Set(keys(chn)))) == Parameter(@varname(y))
            # Check that no other keys originally in `chn` were removed.
            @test isempty(setdiff(Set(keys(chn)), Set(keys(pdns))))
        end

        @testset "rng is respected" begin
            pdns1 = predict(Xoshiro(468), f(), chn)
            pdns2 = predict(Xoshiro(468), f(), chn)
            @test pdns1 == pdns2
            pdns3 = predict(Xoshiro(469), f(), chn)
            @test pdns1 != pdns3
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

        # In general because the ordering of parameters in FlexiChains is not guaranteed
        # we cannot directly compare the two chains.
        @testset "the data itself" begin
            @test Set(keys(new_mcmcc)) == Set(keys(mcmcc))
            for k in keys(new_mcmcc)
                @test new_mcmcc[k] == mcmcc[k]
            end
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
