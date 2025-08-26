using Documenter
using FlexiChains

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=[
         "index.md",
         "mcmcchains.md",
    ],
    checkdocs=:exports,
    doctest=false,
)
