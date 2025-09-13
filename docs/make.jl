using Documenter
using FlexiChains
using Statistics: Statistics

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=["index.md", "turing.md", "details.md", "whynew.md"],
    checkdocs=:exports,
    doctest=false,
)
