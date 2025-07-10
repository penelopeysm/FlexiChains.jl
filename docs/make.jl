using Documenter
using FlexiChains

makedocs(;
    sitename="FlexiChains.jl",
    modules=[FlexiChains],
    pages=[
        "Home" => "index.md",
    ],
    checkdocs=:exports,
    doctest=false,
)
