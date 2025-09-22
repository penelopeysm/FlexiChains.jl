using Documenter
using DocumenterInterLinks
using FlexiChains
using Statistics: Statistics

links = InterLinks(
    "DimensionalData" => "https://rafaqz.github.io/DimensionalData.jl/stable/"
)

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=["index.md", "turing.md", "details.md", "whynew.md"],
    checkdocs=:exports,
    doctest=false,
    plugins=[links],
)
