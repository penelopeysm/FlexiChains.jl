module FCInterfaceTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, @varname, VarName
using AbstractMCMC: AbstractMCMC
using Test

@testset verbose = true "interface.jl" begin
    @info "Testing interface.jl"

    @testset "equality" begin
        d = Dict(Parameter(:a) => 1, Extra(:section, "hello") => 3.0)
        chain1 = FlexiChain{Symbol}(fill(d, 10))
        chain2 = FlexiChain{Symbol}(fill(d, 10))
        @test chain1 == chain2
    end

    @testset "dictionary interface" begin
        N_iters, N_chains = 10, 2
        d = Dict(Parameter(:a) => 1, Parameter(:b) => 2, Extra(:section, "hello") => 3.0)
        dicts = fill(d, N_iters, N_chains)
        chain = FlexiChain{Symbol}(dicts)
        # size
        @test chain isa FlexiChain{Symbol,N_iters,N_chains}
        @test size(chain) == (N_iters, N_chains)
        @test size(chain, 1) == N_iters
        @test size(chain, 2) == N_chains
        @test FlexiChains.niters(chain) == N_iters
        @test FlexiChains.nchains(chain) == N_chains
        # keys
        @test Set(keys(chain)) == Set(keys(d))
        for k in keys(d)
            @test haskey(chain, k)
        end
    end

    @testset "get key names" begin
        N_iters = 10
        d = Dict(
            Parameter(:a) => 1,
            Parameter(:b) => 2,
            Extra(:section, "hello") => 3.0,
            Extra(:section, "world") => 4.0,
            Extra(:other, "key") => 5.0,
        )
        chain = FlexiChain{Symbol}(fill(d, N_iters))

        @testset "parameters" begin
            @test Set(FlexiChains.parameters(chain)) == Set([:a, :b])
        end
        @testset "extras" begin
            @test Set(FlexiChains.extras(chain)) == Set([
                Extra(:section, "hello"), Extra(:section, "world"), Extra(:other, "key")
            ])
        end
        @testset "extras_grouped" begin
            actual = FlexiChains.extras_grouped(chain)
            expected = (section=Set(["hello", "world"]), other=Set(["key"]))
            # we test by converting to Dict because we don't really care about which 
            # order the groups are presented in
            @test Dict(pairs(actual)...) == Dict(pairs(expected)...)
        end
    end

    @testset "getindex" begin
        @testset "unambiguous getindex" begin
            N_iters = 10
            dicts = fill(
                Dict(
                    Parameter(:a) => 1, Parameter(:b) => 2, Extra(:section, "hello") => 3.0
                ),
                N_iters,
            )
            chain = FlexiChain{Symbol}(dicts)

            # getindex directly with key
            @test chain[Parameter(:a)] == fill(1, N_iters)
            @test chain[Parameter(:b)] == fill(2, N_iters)
            @test chain[Extra(:section, "hello")] == fill(3.0, N_iters)
            @test_throws KeyError chain[Parameter(:c)]
            @test_throws KeyError chain[Extra(:section, "world")]

            # getindex with symbol
            @test chain[:a] == fill(1, N_iters)
            @test chain[:b] == fill(2, N_iters)
            @test chain[:hello] == fill(3.0, N_iters)
            @test_throws ArgumentError chain[:c]
            @test_throws ArgumentError chain[:world]
        end

        @testset "ambiguous symbol" begin
            N_iters = 10
            dicts = fill(Dict(Parameter(:a) => 1, Extra(:section, "a") => 3.0), N_iters)
            chain = FlexiChain{Symbol}(dicts)

            # getindex with the full key should be fine
            @test chain[Parameter(:a)] == fill(1, N_iters)
            @test chain[Extra(:section, "a")] == fill(3.0, N_iters)
            # but getindex with the symbol should fail
            @test_throws ArgumentError chain[:a]
            # ... with the correct error message
            @test_throws "multiple keys" chain[:a]
        end

        @testset "VarName" begin
            N_iters = 10
            d = Dict(
                Parameter(@varname(a)) => 1.0,
                Parameter(@varname(b)) => [2.0, 3.0],
                Parameter(@varname(c)) => (x=4.0, y=5.0),
            )
            chain = FlexiChain{VarName}(fill(d, N_iters))
            @test chain[@varname(a)] == fill(1.0, N_iters)
            @test chain[@varname(b)] == fill([2.0, 3.0], N_iters)
            @test chain[@varname(c)] == fill((x=4.0, y=5.0), N_iters)
            @test_throws KeyError chain[@varname(d)]
            @test chain[@varname(b[1])] == fill(2.0, N_iters)
            @test chain[@varname(b[2])] == fill(3.0, N_iters)
            @test_throws BoundsError chain[@varname(b[3])]
            @test chain[@varname(c.x)] == fill(4.0, N_iters)
            @test chain[@varname(c.y)] == fill(5.0, N_iters)
            @test_throws "has no field" chain[@varname(c.z)]
        end
    end

    @testset "extract dicts for single iter" begin
        N = 10
        c = FlexiChain{Symbol}(Dict(Parameter(:a) => rand(N), Extra(:b, "c") => rand(N)))

        @testset "get_dict_from_iter" begin
            for i in 1:N
                d = FlexiChains.get_dict_from_iter(c, i)
                @test length(d) == 2
                @test d[Parameter(:a)] == c[Parameter(:a)][i]
                @test d[Extra(:b, "c")] == c[Extra(:b, "c")][i]
            end
        end

        @testset "get_parameter_dict_from_iter" begin
            for i in 1:N
                d = FlexiChains.get_parameter_dict_from_iter(c, i)
                @test length(d) == 1
                @test d[:a] == c[Parameter(:a)][i]
            end
        end
    end

    @testset "dim-2 merge: `merge`" begin
        @testset "basic merge" begin
            struct Foo end
            N_iters = 10
            dict1 = Dict(
                Parameter(:a) => 1, Parameter(:b) => "no", Extra(:hello, "foo") => 3.0
            )
            chain1 = FlexiChain{Symbol}(fill(dict1, N_iters))

            dict2 = Dict(
                Parameter(:c) => Foo(),
                Parameter(:b) => "yes",
                Extra(:hello, "bar") => "cheese",
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
                @test chain3[Extra(:hello, "foo")] isa Vector{Float64}
                @test chain3[Extra(:hello, "bar")] isa Vector{String}
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

    @testset "dim-2 subset: `subset`" begin
        @testset "basic application" begin
            N_iters = 10
            d = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain = FlexiChain{Symbol}(fill(d, N_iters))

            subsetted1 = FlexiChains.subset(chain, [Parameter(:a)])
            @test typeof(subsetted1) == typeof(chain)
            @test size(subsetted1) == (N_iters, 1)
            @test Set(keys(subsetted1)) == Set([Parameter(:a)])
            @test subsetted1[:a] == chain[:a]

            subsetted2 = FlexiChains.subset(chain, [Extra(:b, "c")])
            @test typeof(subsetted2) == typeof(chain)
            @test size(subsetted2) == (N_iters, 1)
            @test Set(keys(subsetted2)) == Set([Extra(:b, "c")])
            @test subsetted2[:b, "c"] == chain[:b, "c"]
        end

        @testset "key not present" begin
            N_iters = 10
            d = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain = FlexiChain{Symbol}(fill(d, N_iters))
            @test_throws KeyError FlexiChains.subset(chain, [Parameter(:x)])
        end

        @testset "subset parameters and extras" begin
            N_iters = 10
            d = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain = FlexiChain{Symbol}(fill(d, N_iters))
            @test FlexiChains.subset_parameters(chain) ==
                FlexiChains.subset(chain, [Parameter(:a)])
            @test FlexiChains.subset_extras(chain) ==
                FlexiChains.subset(chain, [Extra(:b, "c")])
        end
    end

    @testset "dim-3 merge: `AbstractMCMC.chainscat`" begin
        @testset "basic application" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol}(fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol}(fill(d2, N_iters))
            chain3 = AbstractMCMC.chainscat(chain1, chain2)
            @test chain3 isa FlexiChain{Symbol,N_iters,2}
            @test size(chain3) == (N_iters, 2)
            @test chain3[Parameter(:a)] == repeat([1 2], N_iters)
            @test chain3[Extra(:b, "c")] == repeat([3.0 "foo"], N_iters)
        end

        @testset "stacking different numbers of chains" begin
            chain1 = FlexiChain{Symbol}(fill(Dict(Parameter(:a) => 1), 10))
            chain2 = FlexiChain{Symbol}(fill(Dict(Parameter(:a) => 3), 10, 2))
            chain3 = AbstractMCMC.chainscat(chain1, chain2)
            @test chain3 isa FlexiChain{Symbol,10,3}
            @test size(chain3) == (10, 3)
            @test chain3[Parameter(:a)] == repeat([1 3 3], 10)
        end

        @testset "different parameters in chains" begin
            chain1 = FlexiChain{Symbol}(fill(Dict(Parameter(:a) => 1), 10))
            chain2 = FlexiChain{Symbol}(fill(Dict(Parameter(:b) => 2), 10))
            chain3 = AbstractMCMC.chainscat(chain1, chain2)
            @test chain3 isa FlexiChain{Symbol,10,2}
            @test size(chain3) == (10, 2)
            # need isequal() rather than `==` to handle the `missing` values
            @test isequal(chain3[Parameter(:a)], repeat([1 missing], 10))
            @test isequal(chain3[Parameter(:b)], repeat([missing 2], 10))
        end
    end
end

end # module
