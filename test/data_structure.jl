module FCDataStructureTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey
using Test

@testset verbose = true "data_structure.jl" begin
    @info "Testing data_structure.jl"

    @testset "constructors" begin
        @testset "from array-of-dicts" begin
            # Vector of dict
            N_iters = 10
            dicts = fill(
                Dict(
                    Parameter(:a) => 1,
                    Parameter(:b) => 2,
                    OtherKey(:section, "hello") => 3.0,
                ),
                N_iters,
            )
            chain = FlexiChain{Symbol}(dicts)
            @test size(chain) == (N_iters, 3, 1)

            # Matrix of dict
            N_iters, N_chains = 10, 2
            dicts = fill(
                Dict(
                    Parameter(:a) => 1,
                    Parameter(:b) => 2,
                    OtherKey(:section, "hello") => 3.0,
                ),
                N_iters,
                N_chains,
            )
            chain = FlexiChain{Symbol}(dicts)
            @test size(chain) == (N_iters, 3, N_chains)
        end

        @testset "from dict-of-arrays" begin
            # Dict of arrays
            N_iters = 10
            arrays = Dict(
                Parameter(:a) => rand(N_iters),
                Parameter(:b) => rand(N_iters),
                OtherKey(:section, "hello") => rand(N_iters),
            )
            chain = FlexiChain{Symbol}(arrays)
            @test size(chain) == (N_iters, 3, 1)

            # Dict of matrices
            N_iters, N_chains = 10, 2
            arrays = Dict(
                Parameter(:a) => rand(N_iters, N_chains),
                Parameter(:b) => rand(N_iters, N_chains),
                OtherKey(:section, "hello") => rand(N_iters, N_chains),
            )
            chain = FlexiChain{Symbol}(arrays)
            @test size(chain) == (N_iters, 3, N_chains)
        end

        @testset "wrong constructions" begin
            # TODO
        end
    end
end

end # module
