module FCMakieExtTests

using CairoMakie: Makie
using FlexiChains: FlexiChains as FC, FlexiChain, Parameter, Extra
using StableRNGs: StableRNG
using Test

include("../reference_tests_utils.jl")

function make_test_chain(rng)
    N_iters, N_chains = 100, 2
    dicts = [
        Dict(
            Parameter(:a) => randn(rng),
            Parameter(:b) => randn(rng),
            Parameter(:c) => rand(rng, 1:10),
        )
        for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end

@testset verbose = true "FlexiChainsMakieExt" begin
    @info "Testing ext/makie.jl"

    rng = StableRNG(42)
    chn = make_test_chain(rng)

    reftest("mtraceplot") do
        FC.mtraceplot(chn)
    end

    reftest("mrankplot") do
        FC.mrankplot(chn)
    end

    reftest("mrankplot_overlay") do
        FC.mrankplot(chn; overlay=true)
    end

    reftest("mmixeddensity_float") do
        FC.mmixeddensity(chn, [Parameter(:a)])
    end

    reftest("mmixeddensity_int") do
        FC.mmixeddensity(chn, [Parameter(:c)])
    end

    reftest("makie_plot") do
        Makie.plot(chn)
    end
end

end
