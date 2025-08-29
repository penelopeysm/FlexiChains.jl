using Documenter
using FlexiChains

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=[
         "index.md",
         "turing.md",
         "manual.md",
         "whynew.md",
    ],
    checkdocs=:exports,
    doctest=false,
)
