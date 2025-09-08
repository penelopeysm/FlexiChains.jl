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
    end

    @testset "FlexiChains" begin
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
                    chain = FlexiChain{Symbol}(dicts)
                    @test size(chain) == (N_iters, 1)

                    @testset "with metadata" begin
                        chain2 = FlexiChain{Symbol}(
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
                    chain = FlexiChain{Symbol}(dicts)
                    @test size(chain) == (N_iters, N_chains)

                    @testset "with metadata" begin
                        chain2 = FlexiChain{Symbol}(
                            dicts; sampling_time=[1, 2], last_sampler_state=["foo", "bar"]
                        )
                        @test size(chain2) == (N_iters, N_chains)
                        @test FlexiChains.sampling_time(chain2) == [1, 2]
                        @test FlexiChains.last_sampler_state(chain2) == ["foo", "bar"]
                    end

                    @testset "wrong metadata size" begin
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            dicts; sampling_time=1
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            dicts; sampling_time=1:3
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            dicts; last_sampler_state="foo"
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
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
                    chain = FlexiChain{Symbol}(arrays)
                    @test size(chain) == (N_iters, 1)

                    @testset "with metadata" begin
                        chain2 = FlexiChain{Symbol}(
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
                    chain = FlexiChain{Symbol}(arrays)
                    @test size(chain) == (N_iters, N_chains)

                    @testset "with metadata" begin
                        chain2 = FlexiChain{Symbol}(
                            arrays; sampling_time=[1, 2], last_sampler_state=["foo", "bar"]
                        )
                        @test size(chain2) == (N_iters, N_chains)
                        @test FlexiChains.sampling_time(chain2) == [1, 2]
                        @test FlexiChains.last_sampler_state(chain2) == ["foo", "bar"]
                    end

                    @testset "wrong metadata size" begin
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            arrays; sampling_time=1
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            arrays; sampling_time=1:3
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            arrays; last_sampler_state="foo"
                        )
                        @test_throws DimensionMismatch FlexiChain{Symbol}(
                            arrays; last_sampler_state=["foo", "bar", "baz"]
                        )
                    end
                end
            end
        end
    end
end

end # module
