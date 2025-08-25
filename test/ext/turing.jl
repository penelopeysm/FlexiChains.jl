module FCTuringExtTests

using FlexiChains: FlexiChains, VNChain, Parameter, OtherKey
import FlexiChains
using Random: Xoshiro
using SliceSampling: RandPermGibbs, SliceSteppingOut
using Test
using Turing
using Turing: MCMCChains, AbstractMCMC


Turing.setprogress!(false)

@testset verbose = true "FlexiChainTuringExt" begin
    @info "Testing ext/turing.jl"

    @testset "basic sampling" begin
        @model function gdemo(x, y)
            s2 ~ InverseGamma(2, 3)
            m ~ Normal(0, sqrt(s2))
            x ~ Normal(m, sqrt(s2))
            y ~ Normal(m, sqrt(s2))
        end
        model = gdemo(1.5, 2)

        @testset "single-chain sampling" begin
            chn = sample(model, NUTS(), 100; chain_type=VNChain, verbose=false)
            @test chn isa VNChain
            niters, _, nchains = size(chn)
            @test (niters, nchains) == (100, 1)
        end

        @testset "multi-chain sampling" begin
            chn = sample(model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false)
            @test chn isa VNChain
            niters, _, nchains = size(chn)
            @test (niters, nchains) == (100, 3)
        end

        @testset "rng is respected" begin
            @testset "single-chain" begin
                chn1 = sample(Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false)
                chn2 = sample(Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false)
                @test chn1 == chn2
                chn3 = sample(Xoshiro(469), model, NUTS(), 100; chain_type=VNChain, verbose=false)
                @test chn1 != chn3
            end

            @testset "multi-chain" begin
                chn1 = sample(Xoshiro(468), model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false)
                chn2 = sample(Xoshiro(468), model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false)
                @test chn1 == chn2
                chn3 = sample(Xoshiro(469), model, NUTS(), MCMCSerial(), 100, 3; chain_type=VNChain, verbose=false)
                @test chn1 != chn3
            end
        end

        @testset "underlying data is same as MCMCChains" begin
            chn_flexi = sample(Xoshiro(468), model, NUTS(), 100; chain_type=VNChain, verbose=false)
            chn_mcmc = sample(Xoshiro(468), model, NUTS(), 100; chain_type=MCMCChains.Chains, verbose=false)
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
            ("SliceSampling.jl", externalsampler(RandPermGibbs(SliceSteppingOut(2.0))))
        ]
            chn = sample(model, spl, 20; chain_type=VNChain)
            @test chn isa VNChain
            niters, _, nchains = size(chn)
            @test (niters, nchains) == (20, 1)
        end

        @testset "with a custom sampler" begin
            # Set up the sampler itself.
            struct S <: AbstractMCMC.AbstractSampler end
            struct Tn end
            AbstractMCMC.step(rng, model, ::S, state=nothing; kwargs...) = (Tn(), nothing)
            # Get it to work with FlexiChains
            FlexiChains.to_varname_dict(::Tn) = Dict(Parameter(@varname(x)) => 1, OtherKey(:a, :b) => "hi")
            # Then we should be able to sample
            chn = sample(model, S(), 20; chain_type=VNChain)
            @test chn isa VNChain
            niters, _, nchains = size(chn)
            @test (niters, nchains) == (20, 1)
            @test all(x -> x == 1, vec(chn[@varname(x)]))
            @test all(x -> x == "hi", vec(chn[:a, :b]))
        end
    end
end

end # module
