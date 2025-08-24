using Test: @testset

@testset verbose = true "FlexiChains.jl" begin
    include("data_structure.jl")
    include("interface.jl")
end
