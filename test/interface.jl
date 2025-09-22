module FCInterfaceTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, @varname, VarName
using DimensionalData: DimensionalData as DD
using AbstractMCMC: AbstractMCMC
using Test

@testset verbose = true "interface.jl" begin
    @info "Testing interface.jl"

    @testset "equality" begin
        d = Dict(Parameter(:a) => 1, Extra(:section, "hello") => 3.0)
        chain1 = FlexiChain{Symbol,10,1}(fill(d, 10))
        chain2 = FlexiChain{Symbol,10,1}(fill(d, 10))
        @test chain1 == chain2
    end

    @testset "dictionary interface" begin
        N_iters, N_chains = 10, 2
        d = Dict(Parameter(:a) => 1, Parameter(:b) => 2, Extra(:section, "hello") => 3.0)
        dicts = fill(d, N_iters, N_chains)
        chain = FlexiChain{Symbol,N_iters,N_chains}(dicts)
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
        chain = FlexiChain{Symbol,N_iters,1}(fill(d, N_iters))

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
        @testset "DimArray is correctly constructed" begin
            N_iters = 10
            dicts = fill(Dict(Parameter(:a) => 1), N_iters)
            # Inject some chaos with non-default iter_indices and chain_indices
            chain = FlexiChain{Symbol,N_iters,1}(
                dicts; iter_indices=3:3:(N_iters * 3), chain_indices=[4]
            )

            returned_as = chain[Parameter(:a)]
            @test returned_as isa DD.DimMatrix
            @test size(returned_as) == (N_iters, 1)
            @test DD.dims(returned_as) isa Tuple{DD.Dim{:iter},DD.Dim{:chain}}
            @test parent(DD.val(DD.dims(returned_as), :iter)) == 3:3:(N_iters * 3)
            @test parent(DD.val(DD.dims(returned_as), :chain)) == [4]
        end

        @testset "unambiguous getindex" begin
            N_iters = 10
            dicts = fill(
                Dict(
                    Parameter(:a) => 1, Parameter(:b) => 2, Extra(:section, "hello") => 3.0
                ),
                N_iters,
            )
            chain = FlexiChain{Symbol,N_iters,1}(dicts)

            # Note that DimArrays compare equal to regular matrices with `==` if they have
            # the same contents, so these tests don't actually check that the types returned
            # are correct.

            # getindex directly with key
            @test chain[Parameter(:a)] == fill(1, N_iters, 1)
            @test chain[Parameter(:a)] == fill(1, N_iters, 1)
            @test chain[Parameter(:b)] == fill(2, N_iters, 1)
            @test chain[Extra(:section, "hello")] == fill(3.0, N_iters, 1)
            @test_throws KeyError chain[Parameter(:c)]
            @test_throws KeyError chain[Extra(:section, "world")]

            # getindex with symbol
            @test chain[:a] == fill(1, N_iters, 1)
            @test chain[:b] == fill(2, N_iters, 1)
            @test chain[:hello] == fill(3.0, N_iters, 1)
            @test_throws KeyError chain[:c]
            @test_throws KeyError chain[:world]
        end

        @testset "ambiguous symbol" begin
            N_iters = 10
            dicts = fill(Dict(Parameter(:a) => 1, Extra(:section, "a") => 3.0), N_iters)
            chain = FlexiChain{Symbol,N_iters,1}(dicts)

            # getindex with the full key should be fine
            @test chain[Parameter(:a)] == fill(1, N_iters, 1)
            @test chain[Extra(:section, "a")] == fill(3.0, N_iters, 1)
            # but getindex with the symbol should fail
            @test_throws KeyError chain[:a]
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
            chain = FlexiChain{VarName,N_iters,1}(fill(d, N_iters))
            @test chain[@varname(a)] == fill(1.0, N_iters, 1)
            @test chain[@varname(b)] == fill([2.0, 3.0], N_iters, 1)
            @test chain[@varname(c)] == fill((x=4.0, y=5.0), N_iters, 1)
            @test_throws KeyError chain[@varname(d)]
            @test chain[@varname(b[1])] == fill(2.0, N_iters, 1)
            @test chain[@varname(b[2])] == fill(3.0, N_iters, 1)
            @test_throws BoundsError chain[@varname(b[3])]
            @test chain[@varname(c.x)] == fill(4.0, N_iters, 1)
            @test chain[@varname(c.y)] == fill(5.0, N_iters, 1)
            @test_throws "has no field" chain[@varname(c.z)]
        end
    end

    @testset "extract dicts for single iter" begin
        N = 10
        c = FlexiChain{Symbol,N,1}(
            Dict(Parameter(:a) => rand(N), Extra(:b, "c") => rand(N))
        )

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

    @testset "keys merge: `merge`" begin
        @testset "basic merge" begin
            struct Foo end
            N_iters = 10
            dict1 = Dict(
                Parameter(:a) => 1, Parameter(:b) => "no", Extra(:hello, "foo") => 3.0
            )
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(dict1, N_iters))

            dict2 = Dict(
                Parameter(:c) => Foo(),
                Parameter(:b) => "yes",
                Extra(:hello, "bar") => "cheese",
            )
            ii = 3:3:(N_iters * 3)
            ci = [4]
            sampling_time = [2.5]
            last_sampler_state = ["finished"]
            chain2 = FlexiChain{Symbol,N_iters,1}(
                fill(dict2, N_iters);
                iter_indices=ii,
                chain_indices=ci,
                sampling_time=sampling_time,
                last_sampler_state=last_sampler_state,
            )
            chain3 = merge(chain1, chain2)

            @testset "values are taken from second chain" begin
                expected_chain3 = FlexiChain{Symbol,N_iters,1}(
                    fill(merge(dict1, dict2), N_iters);
                    iter_indices=ii,
                    chain_indices=ci,
                    sampling_time=sampling_time,
                    last_sampler_state=last_sampler_state,
                )
                for k in keys(expected_chain3)
                    @test chain3[k] == expected_chain3[k]
                end
                # An explicit test
                @test all(x -> x == "yes", chain3[Parameter(:b)])
            end

            @testset "metadata is taken from second chain" begin
                @test FlexiChains.iter_indices(chain3) == ii
                @test FlexiChains.chain_indices(chain3) == ci
                @test FlexiChains.sampling_time(chain3) == sampling_time
                @test FlexiChains.last_sampler_state(chain3) == last_sampler_state
            end

            @testset "underlying data still has the right types" begin
                # Essentially we want to avoid that the underlying data
                # is converted into SizedMatrix{N,M,Any} which would
                # lose type information.
                @test eltype(chain3[Parameter(:a)]) == Int
                @test eltype(chain3[Parameter(:b)]) == String
                @test eltype(chain3[Extra(:hello, "foo")]) == Float64
                @test eltype(chain3[Extra(:hello, "bar")]) == String
                @test eltype(chain3[Parameter(:c)]) == Foo
            end
        end

        @testset "size mismatch" begin
            # Sizes are just incompatible
            dict1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol,10,1}(fill(dict1, 10))
            dict2 = Dict(Parameter(:b) => 2.0)
            chain2 = FlexiChain{Symbol,100,1}(fill(dict2, 100))
            @test_throws DimensionMismatch merge(chain1, chain2)

            # This is OK (vector combined with N*1 matrix)
            dict3 = Dict(Parameter(:c) => 3.0)
            chain3 = FlexiChain{Symbol,10,1}(fill(dict3, 10, 1))
            @test merge(chain1, chain3) isa FlexiChain{Symbol}

            # This is not OK
            dict4 = Dict(Parameter(:d) => 3.0)
            chain4 = FlexiChain{Symbol,5,2}(fill(dict4, 5, 2))
            @test_throws DimensionMismatch merge(chain1, chain4)
        end

        @testset "key type promotion" begin
            dict1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol,10,1}(fill(dict1, 10))
            dict2 = Dict(Parameter("b") => "Hi")
            chain2 = FlexiChain{String,10,1}(fill(dict2, 10))
            @test_logs (:warn, r"different key types") merge(chain1, chain2)
            ch = merge(chain1, chain2)
            # Not sure why but `Base.promote_type(Symbol, String)` returns Any
            @test ch isa FlexiChain{Any}
            @test ch[Parameter(:a)] isa AbstractMatrix{Int}
            @test ch[Parameter(:a)] == fill(1, 10, 1)
            @test ch[Parameter("b")] isa AbstractMatrix{String}
            @test ch[Parameter("b")] == fill("Hi", 10, 1)
        end
    end

    @testset "keys subset: `subset`" begin
        @testset "basic application" begin
            N_iters = 10
            d = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain = FlexiChain{Symbol,N_iters,1}(fill(d, N_iters))

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
            chain = FlexiChain{Symbol,N_iters,1}(fill(d, N_iters))
            @test_throws KeyError FlexiChains.subset(chain, [Parameter(:x)])
        end

        @testset "subset parameters and extras" begin
            N_iters = 10
            d = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain = FlexiChain{Symbol,N_iters,1}(fill(d, N_iters))
            @test FlexiChains.subset_parameters(chain) ==
                FlexiChains.subset(chain, [Parameter(:a)])
            @test FlexiChains.subset_extras(chain) ==
                FlexiChains.subset(chain, [Extra(:b, "c")])
        end
    end

    @testset "vcat" begin
        @testset "basic application" begin
            niters1 = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,niters1,1}(fill(d1, niters1))
            niters2 = 20
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,niters2,1}(fill(d2, niters2))
            chain12 = vcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol,niters1 + niters2,1}
            @test size(chain12) == (niters1 + niters2, 1)
            @test chain12[Parameter(:a)] == vcat(fill(1, niters1, 1), fill(2, niters2, 1))
            @test chain12[Extra(:b, "c")] ==
                vcat(fill(3.0, niters1, 1), fill("foo", niters2, 1))
        end

        @testset "handling indices" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,N_iters,1}(
                fill(d1, N_iters); iter_indices=1:10, chain_indices=[1]
            )
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,N_iters,1}(
                fill(d2, N_iters); iter_indices=21:30, chain_indices=[2]
            )

            chain12 = vcat(chain1, chain2)
            @test FlexiChains.iter_indices(chain12) ==
                vcat(FlexiChains.iter_indices(chain1), FlexiChains.iter_indices(chain2))
            @test_logs (:warn, r"different chain indices") vcat(chain1, chain2)
            @test FlexiChains.chain_indices(chain12) == FlexiChains.chain_indices(chain1)
        end

        @testset "metadata" begin
            niters1 = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,niters1,1}(
                fill(d1, niters1); sampling_time=[1], last_sampler_state=["foo"]
            )
            niters2 = 20
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,niters2,1}(
                fill(d2, niters2); sampling_time=[2], last_sampler_state=["bar"]
            )
            chain12 = vcat(chain1, chain2)

            # Sampling times should be summed
            @test isapprox(FlexiChains.sampling_time(chain12), [3])
            # Last sampler state should be taken from the second chain
            @test FlexiChains.last_sampler_state(chain12) == ["bar"]
        end

        @testset "error on different number of chains" begin
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,10,1}(fill(d1, 10, 1))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,10,2}(fill(d2, 10, 2))
            @test_throws DimensionMismatch vcat(chain1, chain2)
        end

        @testset "error on different key type" begin
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol,10,1}(fill(d1, 10))
            d2 = Dict(Parameter("a") => 2)
            chain2 = FlexiChain{String,10,1}(fill(d2, 10))
            @test_throws ArgumentError vcat(chain1, chain2)
        end
    end

    @testset "hcat" begin
        @testset "basic application" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,N_iters,1}(fill(d2, N_iters))
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol,N_iters,2}
            @test size(chain12) == (N_iters, 2)
            @test chain12[Parameter(:a)] == repeat([1 2], N_iters)
            @test chain12[Extra(:b, "c")] == repeat([3.0 "foo"], N_iters)
        end

        @testset "handling indices" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(d1, N_iters); iter_indices=1:10)
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,N_iters,1}(fill(d2, N_iters); iter_indices=21:30)

            @test_logs (:warn, r"different iteration indices") hcat(chain1, chain2)
            chain12 = hcat(chain1, chain2)
            @test FlexiChains.iter_indices(chain12) == FlexiChains.iter_indices(chain1)
            @test FlexiChains.chain_indices(chain12) == [1, 2]
        end

        @testset "combination of metadata" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol,N_iters,1}(
                fill(d1, N_iters); sampling_time=[1], last_sampler_state=["foo"]
            )
            d2 = Dict(Parameter(:a) => 2)
            chain2 = FlexiChain{Symbol,N_iters,1}(
                fill(d2, N_iters); sampling_time=[2], last_sampler_state=["bar"]
            )
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol,N_iters,2}
            @test size(chain12) == (N_iters, 2)
            @test chain12[Parameter(:a)] == repeat([1 2], N_iters)
            @test FlexiChains.sampling_time(chain12) == [1, 2]
            @test FlexiChains.last_sampler_state(chain12) == ["foo", "bar"]
        end

        @testset "3 or more inputs" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,N_iters,1}(fill(d2, N_iters))
            d3 = Dict(Parameter(:x) => 4, Extra(:d, "e") => :y)
            chain3 = FlexiChain{Symbol,N_iters,1}(fill(d3, N_iters))
            chain123 = hcat(chain1, chain2, chain3)
            @test chain123 isa FlexiChain{Symbol,N_iters,3}
            @test size(chain123) == (N_iters, 3)
            # need isequal() rather than `==` to handle the `missing` values
            @test isequal(chain123[Parameter(:a)], repeat([1 2 missing], N_iters))
            @test isequal(chain123[Extra(:b, "c")], repeat([3.0 "foo" missing], N_iters))
            @test isequal(chain123[Parameter(:x)], repeat([missing missing 4], N_iters))
            @test isequal(chain123[Extra(:d, "e")], repeat([missing missing :y], N_iters))
        end

        @testset "stacking different numbers of chains" begin
            N_iters = 10
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(Dict(Parameter(:a) => 1), N_iters))
            chain2 = FlexiChain{Symbol,N_iters,2}(
                fill(Dict(Parameter(:a) => 3), N_iters, 2)
            )
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol,N_iters,3}
            @test size(chain12) == (N_iters, 3)
            @test chain12[Parameter(:a)] == repeat([1 3 3], N_iters)
        end

        @testset "error on different number of iters" begin
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,20,1}(fill(d1, 20))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,10,1}(fill(d2, 10))
            @test_throws DimensionMismatch hcat(chain1, chain2)
        end

        @testset "error on different key type" begin
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol,10,1}(fill(d1, 10))
            d2 = Dict(Parameter("a") => 2)
            chain2 = FlexiChain{String,10,1}(fill(d2, 10))
            @test_throws ArgumentError hcat(chain1, chain2)
        end

        @testset "different parameters in chains" begin
            chain1 = FlexiChain{Symbol,10,1}(fill(Dict(Parameter(:a) => 1), 10))
            chain2 = FlexiChain{Symbol,10,1}(fill(Dict(Parameter(:b) => 2), 10))
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol,10,2}
            @test size(chain12) == (10, 2)
            # need isequal() rather than `==` to handle the `missing` values
            @test isequal(chain12[Parameter(:a)], repeat([1 missing], 10))
            @test isequal(chain12[Parameter(:b)], repeat([missing 2], 10))
        end

        @testset "AbstractMCMC.chainscat and chainsstack" begin
            # These methods make use of hcat. We just do a basic test
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra(:b, "c") => 3.0)
            chain1 = FlexiChain{Symbol,N_iters,1}(fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra(:b, "c") => "foo")
            chain2 = FlexiChain{Symbol,N_iters,1}(fill(d2, N_iters))
            d3 = Dict(Parameter(:x) => 4, Extra(:d, "e") => :y)
            chain3 = FlexiChain{Symbol,N_iters,1}(fill(d3, N_iters))
            chain12 = hcat(chain1, chain2)
            @test isequal(AbstractMCMC.chainscat(chain1, chain2), chain12)
            @test isequal(AbstractMCMC.chainsstack([chain1, chain2]), chain12)
            chain123 = hcat(chain1, chain2, chain3)
            @test isequal(AbstractMCMC.chainscat(chain1, chain2, chain3), chain123)
            @test isequal(AbstractMCMC.chainsstack([chain1, chain2, chain3]), chain123)
        end
    end
end

end # module
