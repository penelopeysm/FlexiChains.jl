module FCSizedMatrixTests

using FlexiChains: FlexiChains
using DimensionalData: DimMatrix, Dim
using Test

@testset verbose = true "sizedmatrix.jl" begin
    @info "Testing sizedmatrix.jl"

    @testset "SizedMatrix" begin
        x = rand(2, 3)
        iter_indices = FlexiChains._make_lookup(1:2:3)
        chain_indices = FlexiChains._make_lookup(1:3)
        dimx = DimMatrix(x, (Dim{:iter}(iter_indices), Dim{:chain}(chain_indices)))
        sm = FlexiChains.SizedMatrix{2,3}(x)
        @test collect(sm) == x
        @test eltype(sm) == eltype(x)
        @test size(sm) == (2, 3)
        for i in 1:2, j in 1:3
            @test sm[i, j] == x[i, j]
        end
        @test_throws DimensionMismatch FlexiChains.SizedMatrix{2,2}(x)
    end
end

end # module
