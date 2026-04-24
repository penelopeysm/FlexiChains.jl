module FlexiChainsPairPlotsExtRefTests

using CairoMakie
using PairPlots
using FlexiChains: FlexiChain, Parameter
using StableRNGs: StableRNG
using Test

include("../reference_tests_utils.jl")

function make_test_chain()
    rng = StableRNG(42)
    N_iters = 100
    N_chains = 2
    dicts = [
        Dict(
                Parameter(:a) => randn(rng),
                Parameter(:b) => randn(rng),
            )
            for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end

@testset verbose = true "PairPlots reference tests" begin
    chn = make_test_chain()

    reftest("pairplot") do
        PairPlots.pairplot(chn; pool_chains = false)
    end

    reftest("pairplot_pooled") do
        PairPlots.pairplot(chn; pool_chains = true)
    end
end

end # module
