module AquaTests

using Aqua: Aqua
using FlexiChains: FlexiChains

@info "Testing Aqua.jl"
Aqua.test_all(
    FlexiChains;
    stale_deps=(; ignore=[:PNGFiles, :PixelMatch, :Plots, :StatsPlots, :PairPlots]),
)

end
