module FlexiChainsPlotsExtRefTests

ENV["GKSwstype"] = "100"

using Plots
using StatsPlots
using FlexiChains: FlexiChains as FC, FlexiChain, Parameter, Extra
using StableRNGs: StableRNG
using Test

include("../reference_tests_utils.jl")

save_plots(path, fig) = Plots.savefig(fig, path)

function make_test_chain()
    rng = StableRNG(42)
    N_iters = 100
    N_chains = 2
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

@testset "Plots.jl reference tests" begin
    chn = make_test_chain()

    reftest("traceplot"; save=save_plots) do
        FC.traceplot(chn)
    end

    reftest("rankplot"; save=save_plots) do
        FC.rankplot(chn)
    end

    reftest("rankplot_overlay"; save=save_plots) do
        FC.rankplot(chn; overlay=true)
    end

    reftest("mixeddensity_float"; save=save_plots) do
        FC.mixeddensity(chn[[Parameter(:a)]])
    end

    reftest("mixeddensity_int"; save=save_plots) do
        FC.mixeddensity(chn[[Parameter(:c)]])
    end

    reftest("meanplot"; save=save_plots) do
        FC.meanplot(chn)
    end

    reftest("autocorplot"; save=save_plots) do
        FC.autocorplot(chn)
    end

    reftest("plots_plot"; save=save_plots) do
        Plots.plot(chn)
    end
end

end # module
