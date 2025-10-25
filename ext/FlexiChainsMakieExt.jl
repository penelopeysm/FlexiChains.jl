module FlexiChainsMakieExt

import FlexiChains as FC
using Makie
using StatsBase
using Statistics

include("FlexiChainsMakieExt/utils.jl")
include("FlexiChainsMakieExt/density.jl")
include("FlexiChainsMakieExt/barplot.jl")
include("FlexiChainsMakieExt/hist.jl")
include("FlexiChainsMakieExt/traceplot.jl")
include("FlexiChainsMakieExt/trankplot.jl")
include("FlexiChainsMakieExt/ridgeline.jl")
include("FlexiChainsMakieExt/forestplot.jl")
include("FlexiChainsMakieExt/autocorplot.jl")
include("FlexiChainsMakieExt/meanplot.jl")
include("FlexiChainsMakieExt/violin.jl")
include("FlexiChainsMakieExt/plot.jl")

end
