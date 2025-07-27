using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey
using Test

@testset "FlexiChains.jl" begin
    @testset "data_structures.jl" begin
        @testset "constructors" begin

            @testset "from array-of-dicts" begin
                # Vector of dict
                N_iters = 10
                dicts = fill(Dict(Parameter(:a) => 1, Parameter(:b) => 2, OtherKey(:section, "hello") => 3.0), N_iters)
                chain = FlexiChain{Symbol}(dicts)
                @test size(chain) == (N_iters, 3, 1)

                # Matrix of dict
                N_iters, N_chains = 10, 2
                dicts = fill(Dict(Parameter(:a) => 1, Parameter(:b) => 2, OtherKey(:section, "hello") => 3.0), N_iters, N_chains)
                chain = FlexiChain{Symbol}(dicts)
                @test size(chain) == (N_iters, 3, N_chains)
            end

            @testset "from dict-of-arrays" begin
                # Dict of arrays
                N_iters = 10
                arrays = Dict(
                    Parameter(:a) => rand(N_iters),
                    Parameter(:b) => rand(N_iters),
                    OtherKey(:section, "hello") => rand(N_iters)
                )
                chain = FlexiChain{Symbol}(arrays)
                @test size(chain) == (N_iters, 3, 1)

                # Dict of matrices
                N_iters, N_chains = 10, 2
                arrays = Dict(
                    Parameter(:a) => rand(N_iters, N_chains),
                    Parameter(:b) => rand(N_iters, N_chains),
                    OtherKey(:section, "hello") => rand(N_iters, N_chains)
                )
                chain = FlexiChain{Symbol}(arrays)
                @test size(chain) == (N_iters, 3, N_chains)
            end

            @testset "wrong constructions" begin
                # TODO
            end
        end
    end

    @testset "interface.jl" begin
        # TODO test the other methods

        @testset "getindex" begin
            @testset "unambiguous getindex" begin
                N_iters = 10
                dicts = fill(Dict(Parameter(:a) => 1, Parameter(:b) => 2, OtherKey(:section, "hello") => 3.0), N_iters)
                chain = FlexiChain{Symbol}(dicts)

                # getindex directly with key
                @test chain[Parameter(:a)] == fill(1, N_iters)
                @test chain[Parameter(:b)] == fill(2, N_iters)
                @test chain[OtherKey(:section, "hello")] == fill(3.0, N_iters)
                @test_throws KeyError chain[Parameter(:c)]
                @test_throws KeyError chain[OtherKey(:section, "world")]

                # getindex with symbol
                @test chain[:a] == fill(1, N_iters)
                @test chain[:b] == fill(2, N_iters)
                @test chain[:hello] == fill(3.0, N_iters)
                @test_throws KeyError chain[:c]
                @test_throws KeyError chain[:world]
            end

            @testset "ambiguous symbol" begin
                N_iters = 10
                dicts = fill(Dict(Parameter(:a) => 1, OtherKey(:section, "a") => 3.0), N_iters)
                chain = FlexiChain{Symbol}(dicts)

                # getindex with the full key should be fine
                @test chain[Parameter(:a)] == fill(1, N_iters)
                @test chain[OtherKey(:section, "a")] == fill(3.0, N_iters)
                # but getindex with the symbol should fail
                @test_throws KeyError chain[:a]
                # ... with the correct error message
                @test_throws "multiple keys" chain[:a]
            end
        end
    end
end
