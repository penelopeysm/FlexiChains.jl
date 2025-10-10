using Documenter
using DocumenterInterLinks
using FlexiChains
using Statistics: Statistics
using StatsBase: StatsBase
using MCMCDiagnosticTools: MCMCDiagnosticTools
using PosteriorDB: PosteriorDB
using DynamicPPL: DynamicPPL
using MCMCChains: MCMCChains

links = InterLinks(
    "DimensionalData" => "https://rafaqz.github.io/DimensionalData.jl/stable/",
    "MCMCDiagnosticTools" => "https://turinglang.org/MCMCDiagnosticTools.jl/stable/",
    "PosteriorDB" => "https://sethaxen.github.io/PosteriorDB.jl/stable/",
    "Plots" => "https://docs.juliaplots.org/stable/",
    "StatsBase" => "https://juliastats.org/StatsBase.jl/stable/",
    "Julia" => "https://docs.julialang.org/en/v1/",
)

FCPosteriorDBExt = Base.get_extension(FlexiChains, :FlexiChainsPosteriorDBExt)
FCDynamicPPLExt = Base.get_extension(FlexiChains, :FlexiChainsDynamicPPLExt)
FCMCMCChainsExt = Base.get_extension(FlexiChains, :FlexiChainsMCMCChainsExt)

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains, FCPosteriorDBExt, FCDynamicPPLExt, FCMCMCChainsExt],
    pages=[
        "index.md",
        "turing.md",
        "indexing.md",
        "plotting.md",
        "integrations.md",
        "api.md",
        "internals.md",
        "why.md",
    ],
    checkdocs=:exports,
    warnonly=true,
    doctest=false,
    plugins=[links],
)
