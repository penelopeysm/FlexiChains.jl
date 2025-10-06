using Documenter
using DocumenterInterLinks
using FlexiChains
using Statistics: Statistics
using StatsBase: StatsBase
using MCMCDiagnosticTools: MCMCDiagnosticTools
using PosteriorDB: PosteriorDB

links = InterLinks(
    "DimensionalData" => "https://rafaqz.github.io/DimensionalData.jl/stable/",
    "MCMCDiagnosticTools" => "https://turinglang.org/MCMCDiagnosticTools.jl/stable/",
    "PosteriorDB" => "https://sethaxen.github.io/PosteriorDB.jl/stable/",
)

FCPosteriorDBExt = Base.get_extension(FlexiChains, :FlexiChainsPosteriorDBExt)

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains, FCPosteriorDBExt],
    pages=[
        "index.md", "turing.md", "indexing.md", "integrations.md", "details.md", "whynew.md"
    ],
    checkdocs=:exports,
    doctest=false,
    plugins=[links],
)
