using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey
using Test

@testset "FlexiChains.jl" begin
    @testset "data_structures.jl" begin
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

    @testset "interface.jl" begin
        # TODO test the other methods

        @testset "getindex" begin
            @testset "unambiguous getindex" begin
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
                @test_throws ArgumentError chain[:c]
                @test_throws ArgumentError chain[:world]
            end

            @testset "ambiguous symbol" begin
                N_iters = 10
                dicts = fill(
                    Dict(Parameter(:a) => 1, OtherKey(:section, "a") => 3.0), N_iters
                )
                chain = FlexiChain{Symbol}(dicts)

                # getindex with the full key should be fine
                @test chain[Parameter(:a)] == fill(1, N_iters)
                @test chain[OtherKey(:section, "a")] == fill(3.0, N_iters)
                # but getindex with the symbol should fail
                @test_throws ArgumentError chain[:a]
                # ... with the correct error message
                @test_throws "multiple keys" chain[:a]
            end
        end

        @testset "merge" begin
            @testset "basic merge" begin
                struct Foo end
                N_iters = 10
                dict1 = Dict(
                    Parameter(:a) => 1,
                    Parameter(:b) => "no",
                    OtherKey(:hello, "foo") => 3.0,
                )
                chain1 = FlexiChain{Symbol}(fill(dict1, N_iters))

                dict2 = Dict(
                    Parameter(:c) => Foo(),
                    Parameter(:b) => "yes",
                    OtherKey(:hello, "bar") => "cheese",
                )
                chain2 = FlexiChain{Symbol}(fill(dict2, N_iters))

                chain3 = merge(chain1, chain2)
                expected_chain3 = FlexiChain{Symbol}(fill(merge(dict1, dict2), N_iters))
                @test chain3 == expected_chain3

                @testset "values are taken from second chain" begin
                    @test all(x -> x == "yes", chain3[Parameter(:b)])
                end

                @testset "underlying data still has the right types" begin
                    # Essentially we want to avoid that the underlying data
                    # is converted into SizedMatrix{N,M,Any} which would
                    # lose type information.
                    @test chain3[Parameter(:a)] isa Vector{Int}
                    @test chain3[Parameter(:b)] isa Vector{String}
                    @test chain3[OtherKey(:hello, "foo")] isa Vector{Float64}
                    @test chain3[OtherKey(:hello, "bar")] isa Vector{String}
                    @test chain3[Parameter(:c)] isa Vector{Foo}
                end
            end

            @testset "size mismatch" begin
                # Sizes are just incompatible
                dict1 = Dict(Parameter(:a) => 1)
                chain1 = FlexiChain{Symbol}(fill(dict1, 10))
                dict2 = Dict(Parameter(:b) => 2.0)
                chain2 = FlexiChain{Symbol}(fill(dict2, 100))
                @test_throws DimensionMismatch merge(chain1, chain2)

                # This is OK (vector combined with N*1 matrix)
                dict3 = Dict(Parameter(:c) => 3.0)
                chain3 = FlexiChain{Symbol}(fill(dict3, 10, 1))
                @test merge(chain1, chain3) isa FlexiChain{Symbol}

                # This is not OK
                dict4 = Dict(Parameter(:d) => 3.0)
                chain4 = FlexiChain{Symbol}(fill(dict4, 5, 2))
                @test_throws DimensionMismatch merge(chain1, chain4)
            end

            @testset "key type promotion" begin
                dict1 = Dict(Parameter(:a) => 1)
                chain1 = FlexiChain{Symbol}(fill(dict1, 10))
                dict2 = Dict(Parameter("b") => "Hi")
                chain2 = FlexiChain{String}(fill(dict2, 10))
                @test_logs (:warn, r"different key types") merge(chain1, chain2)
                ch = merge(chain1, chain2)
                # Not sure why but `Base.promote_type(Symbol, String)` returns Any
                @test ch isa FlexiChain{Any}
                @test ch[Parameter(:a)] isa Vector{Int}
                @test ch[Parameter(:a)] == fill(1, 10)
                @test ch[Parameter("b")] isa Vector{String}
                @test ch[Parameter("b")] == fill("Hi", 10)
            end
        end
    end
end
