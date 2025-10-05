using Test: @testset

@testset verbose = true "FlexiChains.jl" begin
    include("chain.jl")
    include("summaries.jl")
    include("interface.jl")
    include("ext/turing.jl")
end
