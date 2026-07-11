module FlexiChainsPigeonsExtTests

using FlexiChains: FlexiChains, SymChain, VNChain, Extra
using Pigeons
using DynamicPPL
using Distributions
using Random
using Test

@testset "PigeonsExt" begin
    @testset "Callable struct" begin
        struct MyLogPotential
            n_trials::Int
            n_successes::Int
        end
        function (log_potential::MyLogPotential)(x)
            p1, p2 = x
            if !(0 < p1 < 1) || !(0 < p2 < 1)
                return -Inf
            end
            return logpdf(
                Binomial(log_potential.n_trials, p1 * p2),
                log_potential.n_successes,
            )
        end
        Pigeons.initialization(::MyLogPotential, ::Random.AbstractRNG, ::Int) = [0.5, 0.5]
        pt = pigeons(;
            target=MyLogPotential(100, 50),
            reference=MyLogPotential(0, 0),
            record=[traces],
        )

        chn = FlexiChains.from_pigeons(pt)
        @test chn isa SymChain
        # Should be a single parameter which is a length-2 vector
        @test only(FlexiChains.parameters(chn)) == :param
        @test size(first(chn[:param])) == (2,)
        # log density should be recorded as an extra
        @test only(FlexiChains.extras(chn)) == Extra(:log_density)
    end

    @testset "With Turing model" begin
        @model function f(n_trials, n_successes)
            p1 ~ filldist(Uniform(0, 1), 1, 2)
            n_successes ~ Binomial(n_trials, prod(p1))
            return n_successes
        end
        my_turing_target = TuringLogPotential(f(100, 50))
        pt = pigeons(; target=my_turing_target, record=[traces])

        chn = FlexiChains.from_pigeons(pt)
        @test chn isa VNChain
        @test only(FlexiChains.parameters(chn)) == @varname(p1)
        sample = first(chn[@varname(p1)])
        @test size(sample) == (1, 2)
        @test Extra(:logprior) in keys(chn)
        @test Extra(:loglikelihood) in keys(chn)
        @test Extra(:logjoint) in keys(chn)
    end

    @testset "Discrete parameters" begin
        @model function g()
            x ~ Normal()
            y ~ Poisson(1.0)
            1.0 ~ Normal(x + y)
        end
        pt = pigeons(; target=TuringLogPotential(g()), record=[traces])

        # Check that discrete variables are correctly handled (this essentially tests the
        # `_faithful_sample_array` function). If we used `Pigeons.sample_array` then `y`
        # would be converted to `Float64`.
        chn = FlexiChains.from_pigeons(pt)
        @test eltype(chn[@varname(x)]) == Float64
        @test eltype(chn[@varname(y)]) == Int
    end
end

end # module
