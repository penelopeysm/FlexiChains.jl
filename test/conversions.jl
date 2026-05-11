module FlexiChainsConversionsTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra
using AbstractMCMC
using Test

@testset "to_nt_and_stats" begin
    struct M <: AbstractMCMC.AbstractModel end
    struct S <: AbstractMCMC.AbstractSampler end
    struct T end
    function AbstractMCMC.step(rng, ::M, ::S, state = nothing; kwargs...)
        T(), nothing
    end
    FlexiChains.to_nt_and_stats(::T) = ((; hello = 1.0), (; world = 2.0))

    niters = 10
    chn = sample(M(), S(), niters; chain_type = FlexiChain{Symbol})
    @test chn isa FlexiChain{Symbol}
    @test Set(FlexiChains.parameters(chn)) == Set([:hello])
    @test Set(keys(chn)) == Set([Parameter(:hello), Extra(:world)])
    @test chn[:hello] == fill(1.0, niters, 1)
    @test chn[:world] == fill(2.0, niters, 1)
end

end
