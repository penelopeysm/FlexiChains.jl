using Documenter
using FlexiChains

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=[
         "overview.md",
         "mcmcchains.md",
    ],
    checkdocs=:exports,
    doctest=false,
)
