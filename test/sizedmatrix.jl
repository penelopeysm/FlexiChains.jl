module FCSizedMatrixTests

using FlexiChains: FlexiChains
using Test

@testset verbose = true "sizedmatrix.jl" begin
    @info "Testing sizedmatrix.jl"

    @testset "SizedMatrix" begin
        @testset "m * n" begin
            x = rand(2, 3)
            sm = FlexiChains.SizedMatrix{2,3}(x)
            @test FlexiChains.data(sm) == x
            @test collect(sm) == x
            @test eltype(sm) == eltype(x)
            @test size(sm) == (2, 3)
            for i in 1:2, j in 1:3
                @test sm[i, j] == x[i, j]
            end
            @test_throws DimensionMismatch FlexiChains.SizedMatrix{2,2}(x)
        end

        @testset "m * 1" begin
            x = rand(2)
            sm = FlexiChains.SizedMatrix{2,1}(x)
            @test FlexiChains.data(sm) == x
            @test collect(sm) == reshape(x, 2, 1)
            @test eltype(sm) == eltype(x)
            @test size(sm) == (2, 1)
            for i in 1:2
                @test sm[i, 1] == x[i]
            end
        end
    end
end

end # module
