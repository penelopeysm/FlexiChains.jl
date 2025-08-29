using Documenter
using FlexiChains

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=[
         "index.md",
         "turing.md",
         "mcmcchains.md",
         "manual.md",
    ],
    checkdocs=:exports,
    doctest=false,
)
