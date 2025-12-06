using Documenter
using DocumenterInterLinks
using FlexiChains
using CairoMakie: CairoMakie, Makie
using StatsPlots: Plots
using Statistics: Statistics
using StatsBase: StatsBase
using MCMCDiagnosticTools: MCMCDiagnosticTools
using PosteriorDB: PosteriorDB
using PosteriorStats: PosteriorStats
using AbstractMCMC: AbstractMCMC
using DynamicPPL: DynamicPPL
using MCMCChains: MCMCChains
using Turing: Turing

links = InterLinks(
    "DimensionalData" => "https://rafaqz.github.io/DimensionalData.jl/stable/",
    "DynamicPPL" => "https://turinglang.org/DynamicPPL.jl/stable/",
    "MCMCDiagnosticTools" => "https://turinglang.org/MCMCDiagnosticTools.jl/stable/",
    "PosteriorDB" => "https://sethaxen.github.io/PosteriorDB.jl/stable/",
    "PosteriorStats" => "https://julia.arviz.org/PosteriorStats/stable/",
    "Plots" => "https://docs.juliaplots.org/stable/",
    "StatsBase" => "https://juliastats.org/StatsBase.jl/stable/",
    "Julia" => "https://docs.julialang.org/en/v1/",
)

modules = [
    FlexiChains,
    Base.get_extension(FlexiChains, :FlexiChainsPosteriorDBExt),
    Base.get_extension(FlexiChains, :FlexiChainsPosteriorStatsExt),
    Base.get_extension(FlexiChains, :FlexiChainsDynamicPPLExt),
    Base.get_extension(FlexiChains, :FlexiChainsMakieExt),
    Base.get_extension(FlexiChains, :FlexiChainsMCMCChainsExt),
    Base.get_extension(FlexiChains, :FlexiChainsTuringExt),
]

makedocs(;
    sitename="FlexiChains.jl",
    modules=modules,
    pages=[
        "index.md",
        "turing.md",
        "summarising.md",
        "indexing.md",
        "plotting.md",
        "plots.md",
        "makie.md",
        "integrations.md",
        "api.md",
        "why.md",
        "whynot.md",
    ],
    checkdocs=:exports,
    warnonly=true,
    doctest=false,
    plugins=[links],
)
