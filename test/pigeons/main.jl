module FlexiChainsPigeonsExtTests

using FlexiChains: FlexiChains, VNChain, Extra
using Pigeons
using DynamicPPL
using Distributions
using Test

@testset "PigeonsExt" begin
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
end

end # module
