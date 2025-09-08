module FCDataStructureTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra
using Test

@testset verbose = true "data_structure.jl" begin
    @info "Testing data_structure.jl"

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

        @testset "1 * 1" begin
            x = rand()
            sm = FlexiChains.SizedMatrix{1,1}([x])
            @test FlexiChains.data(sm) == x
            @test collect(sm) == reshape([x], 1, 1)
            @test eltype(sm) == typeof(x)
            @test size(sm) == (1, 1)
            @test sm[1, 1] == x
            @test sm[] == x
        end
    end

    @testset "FlexiChains" begin
        @testset "constructors" begin
            @testset "from array-of-dicts" begin
                # Vector of dict
                N_iters = 10
                dicts = fill(
                    Dict(
                        Parameter(:a) => 1,
                        Parameter(:b) => 2,
                        Extra(:section, "hello") => 3.0,
                    ),
                    N_iters,
                )
                chain = FlexiChain{Symbol}(dicts)
                @test size(chain) == (N_iters, 1)

                # Matrix of dict
                N_iters, N_chains = 10, 2
                dicts = fill(
                    Dict(
                        Parameter(:a) => 1,
                        Parameter(:b) => 2,
                        Extra(:section, "hello") => 3.0,
                    ),
                    N_iters,
                    N_chains,
                )
                chain = FlexiChain{Symbol}(dicts)
                @test size(chain) == (N_iters, N_chains)
            end

            @testset "from dict-of-arrays" begin
                # Dict of arrays
                N_iters = 10
                arrays = Dict(
                    Parameter(:a) => rand(N_iters),
                    Parameter(:b) => rand(N_iters),
                    Extra(:section, "hello") => rand(N_iters),
                )
                chain = FlexiChain{Symbol}(arrays)
                @test size(chain) == (N_iters, 1)

                # Dict of matrices
                N_iters, N_chains = 10, 2
                arrays = Dict(
                    Parameter(:a) => rand(N_iters, N_chains),
                    Parameter(:b) => rand(N_iters, N_chains),
                    Extra(:section, "hello") => rand(N_iters, N_chains),
                )
                chain = FlexiChain{Symbol}(arrays)
                @test size(chain) == (N_iters, N_chains)
            end

            @testset "wrong constructions" begin
                # TODO
            end
        end
    end
end

end # module
