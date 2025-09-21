module FCChainTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra
using Test

@testset verbose = true "chain.jl" begin
    @info "Testing chain.jl"

    @testset "constructors" begin
        @testset "from array-of-dicts" begin
            @testset "vector of dict" begin
                N_iters = 10
                dicts = fill(
                    Dict(
                        Parameter(:a) => 1,
                        Parameter(:b) => 2,
                        Extra(:section, "hello") => 3.0,
                    ),
                    N_iters,
                )
                chain = FlexiChain{Symbol,N_iters,1}(dicts)
                @test size(chain) == (N_iters, 1)

                @testset "with metadata" begin
                    chain2 = FlexiChain{Symbol,N_iters,1}(
                        dicts; sampling_time=1, last_sampler_state="foo"
                    )
                    @test size(chain2) == (N_iters, 1)
                    @test FlexiChains.sampling_time(chain2) == 1
                    @test FlexiChains.last_sampler_state(chain2) == "foo"
                end
            end

            @testset "matrix of dict" begin
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
                chain = FlexiChain{Symbol,N_iters,N_chains}(dicts)
                @test size(chain) == (N_iters, N_chains)

                @testset "with metadata" begin
                    chain2 = FlexiChain{Symbol,N_iters,N_chains}(
                        dicts; sampling_time=[1, 2], last_sampler_state=["foo", "bar"]
                    )
                    @test size(chain2) == (N_iters, N_chains)
                    @test FlexiChains.sampling_time(chain2) == [1, 2]
                    @test FlexiChains.last_sampler_state(chain2) == ["foo", "bar"]
                end

                @testset "wrong metadata size" begin
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        dicts; sampling_time=1
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        dicts; sampling_time=1:3
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        dicts; last_sampler_state="foo"
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        dicts; last_sampler_state=["foo", "bar", "baz"]
                    )
                end
            end
        end

        @testset "from dict-of-arrays" begin
            @testset "dict of vectors" begin
                N_iters = 10
                arrays = Dict(
                    Parameter(:a) => rand(N_iters),
                    Parameter(:b) => rand(N_iters),
                    Extra(:section, "hello") => rand(N_iters),
                )
                chain = FlexiChain{Symbol,N_iters,1}(arrays)
                @test size(chain) == (N_iters, 1)

                @testset "with metadata" begin
                    chain2 = FlexiChain{Symbol,N_iters,1}(
                        arrays; sampling_time=1, last_sampler_state="foo"
                    )
                    @test size(chain2) == (N_iters, 1)
                    @test FlexiChains.sampling_time(chain2) == 1
                    @test FlexiChains.last_sampler_state(chain2) == "foo"
                end
            end

            @testset "dict of matrices" begin
                N_iters, N_chains = 10, 2
                arrays = Dict(
                    Parameter(:a) => rand(N_iters, N_chains),
                    Parameter(:b) => rand(N_iters, N_chains),
                    Extra(:section, "hello") => rand(N_iters, N_chains),
                )
                chain = FlexiChain{Symbol,N_iters,N_chains}(arrays)
                @test size(chain) == (N_iters, N_chains)

                @testset "with metadata" begin
                    chain2 = FlexiChain{Symbol,N_iters,N_chains}(
                        arrays; sampling_time=[1, 2], last_sampler_state=["foo", "bar"]
                    )
                    @test size(chain2) == (N_iters, N_chains)
                    @test FlexiChains.sampling_time(chain2) == [1, 2]
                    @test FlexiChains.last_sampler_state(chain2) == ["foo", "bar"]
                end

                @testset "wrong metadata size" begin
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        arrays; sampling_time=1
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        arrays; sampling_time=1:3
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        arrays; last_sampler_state="foo"
                    )
                    @test_throws DimensionMismatch FlexiChain{Symbol,N_iters,N_chains}(
                        arrays; last_sampler_state=["foo", "bar", "baz"]
                    )
                end
            end
        end
    end
end

end # module
