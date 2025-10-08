module FCInterfaceTests

using ComponentArrays: ComponentArray
using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, @varname, VarName
using DimensionalData: DimensionalData as DD
using OrderedCollections: OrderedDict
using AbstractMCMC: AbstractMCMC
using Test

@testset verbose = true "interface.jl" begin
    @info "Testing interface.jl"

    @testset "show doesn't error" begin
        ds = [
            Dict(Parameter(:a) => 1, Extra("hello") => 3.0),
            Dict(Parameter(:a) => 1),
            Dict(Extra("hello") => 3.0),
            Dict(),
        ]
        for d in ds
            chain = FlexiChain{Symbol}(10, 1, fill(d, 10))
            display(chain)
        end
    end

    @testset "_show_range" begin
        # Don't really want to test the full `show` output for FlexiChain, so just unit test
        # this function
        @test FlexiChains._show_range(1:10) == "1:10"
        @test FlexiChains._show_range(3:3:30) == "3:3:30"
        @test FlexiChains._show_range(FlexiChains._make_lookup(1:10)) == "1:10"
        @test FlexiChains._show_range(FlexiChains._make_lookup(3:3:30)) == "3:3:30"
        @test FlexiChains._show_range(FlexiChains._make_lookup(1:10)[DD.Not(4)]) ==
            "[1 … 10]"
        @test FlexiChains._show_range([1, 2, 3, 5, 7, 11]) == "[1 … 11]"
        @test FlexiChains._show_range([2, 3, 5, 7, 11]) == "[2, 3, 5, 7, 11]"
    end

    @testset "equality" begin
        d = Dict(Parameter(:a) => 1, Extra("hello") => 3.0)
        chain1 = FlexiChain{Symbol}(
            10, 1, fill(d, 10); sampling_time=[2.5], last_sampler_state=["finished"]
        )
        chain2 = FlexiChain{Symbol}(
            10, 1, fill(d, 10); sampling_time=[2.5], last_sampler_state=["finished"]
        )
        @test chain1 == chain2
        @test isequal(chain1, chain2)
        @test FlexiChains.has_same_data(chain1, chain2)
        # Different iter indices should make chains unequal
        chain3 = FlexiChain{Symbol}(
            10,
            1,
            fill(d, 10);
            iter_indices=21:30,
            sampling_time=[2.5],
            last_sampler_state=["finished"],
        )
        @test chain1 != chain3
        @test !isequal(chain1, chain3)
        # But if we compare the data it should be the same
        @test FlexiChains.has_same_data(chain1, chain3)
        @test Set(keys(chain1)) == Set(keys(chain3))
        # Note that == on DimData also takes indices into account
        @test !all(k -> chain1[k] == chain3[k], keys(chain1))
        # But isequal doesn't.
        @test all(k -> isequal(chain1[k], chain3[k]), keys(chain1))
        # A final test case with missing
        dmiss = Dict(Parameter(:a) => missing)
        chainmiss1 = FlexiChain{Symbol}(
            10, 1, fill(dmiss, 10); sampling_time=[2.5], last_sampler_state=["finished"]
        )
        chainmiss2 = FlexiChain{Symbol}(
            10, 1, fill(dmiss, 10); sampling_time=[2.5], last_sampler_state=["finished"]
        )
        @test ismissing(chainmiss1 == chainmiss2)
        @test isequal(chainmiss1, chainmiss2)
        @test FlexiChains.has_same_data(chainmiss1, chainmiss2)
        @test ismissing(FlexiChains.has_same_data(chainmiss1, chainmiss2; strict=true))
    end

    @testset "dictionary interface" begin
        N_iters, N_chains = 10, 2
        d = OrderedDict(Parameter(:a) => 1, Extra("hello") => 3.0, Parameter(:b) => 2)
        dicts = fill(d, N_iters, N_chains)
        chain = FlexiChain{Symbol}(N_iters, N_chains, dicts)
        # size
        @test chain isa FlexiChain{Symbol}
        @test size(chain) == (N_iters, N_chains)
        @test size(chain, 1) == N_iters
        @test size(chain, 2) == N_chains
        @test FlexiChains.niters(chain) == N_iters
        @test FlexiChains.nchains(chain) == N_chains
        # keys
        @test collect(keys(chain)) == [Parameter(:a), Extra("hello"), Parameter(:b)]
        for k in keys(d)
            @test haskey(chain, k)
        end
    end

    @testset "get key names" begin
        N_iters = 10
        # use OrderedDict when constructing so that we can also test order
        d = OrderedDict(
            Parameter(:a) => 1,
            Parameter(:b) => 2,
            Extra("hello") => 3.0,
            Extra("world") => 4.0,
            Extra("key") => 5.0,
        )
        chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))

        @testset "parameters" begin
            @test FlexiChains.parameters(chain) == [:a, :b]
        end
        @testset "extras" begin
            @test FlexiChains.extras(chain) ==
                [Extra("hello"), Extra("world"), Extra("key")]
        end
    end

    @testset "getindex" begin
        @testset "DimArray is correctly constructed" begin
            N_iters = 10
            dicts = fill(Dict(Parameter(:a) => 1), N_iters)
            # Inject some chaos with non-default iter_indices and chain_indices
            iter_range = 3:3:(N_iters * 3)
            chain = FlexiChain{Symbol}(
                N_iters, 1, dicts; iter_indices=iter_range, chain_indices=[4]
            )

            @testset "without iter/chain indexing" begin
                returned_as = chain[Parameter(:a)]
                @test returned_as isa DD.DimMatrix
                @test size(returned_as) == (N_iters, 1)
                @test DD.dims(returned_as) isa Tuple{DD.Dim{:iter},DD.Dim{:chain}}
                @test parent(DD.val(DD.dims(returned_as), :iter)) == iter_range
                @test parent(DD.val(DD.dims(returned_as), :chain)) == [4]
            end

            @testset "with iter/chain indexing" begin
                returned_as = chain[Parameter(:a), iter=4:5, chain=DD.At([4])]
                @test returned_as isa DD.DimMatrix
                @test size(returned_as) == (2, 1)
                @test DD.dims(returned_as) isa Tuple{DD.Dim{:iter},DD.Dim{:chain}}
                @test parent(DD.val(DD.dims(returned_as), :iter)) == iter_range[4:5]
                @test parent(DD.val(DD.dims(returned_as), :chain)) == [4]
            end

            @testset "indexing into single chain" begin
                returned_as = chain[Parameter(:a), chain=DD.At(4)]
                @test returned_as isa DD.DimVector
                @test length(returned_as) == N_iters
                @test DD.dims(returned_as) isa Tuple{DD.Dim{:iter}}
                @test parent(DD.val(DD.dims(returned_as), :iter)) == iter_range
            end

            @testset "indexing into single iter + single chain" begin
                returned_as = chain[Parameter(:a), iter=DD.At(6), chain=1]
                @test returned_as == 1
            end
        end

        @testset "unambiguous: TKey and ParameterOrExtra{TKey}" begin
            struct Shay
                T::String
            end

            N_iters = 10
            dicts = fill(
                Dict(
                    Parameter(Shay("a")) => 1,
                    Parameter(Shay("b")) => 2,
                    Extra("hello") => 3.0,
                ),
                N_iters,
            )
            chain = FlexiChain{Shay}(N_iters, 1, dicts)

            # Note that DimArrays compare equal to regular matrices with `==` if they have
            # the same contents, so these tests don't actually check that the types returned
            # are correct. We assume that that's handled in the DimArray testset above.
            @testset "TKey" begin
                @test chain[Shay("a")] == fill(1, N_iters, 1)
                @test chain[Shay("a")] == fill(1, N_iters, 1)
                @test chain[Shay("b")] == fill(2, N_iters, 1)
                @testset "with iter subsetting" begin
                    @test chain[Shay("a"), iter=4:6] == fill(1, 3, 1)
                    @test chain[Shay("a"), iter=4:6, chain=DD.At(1)] == fill(1, 3)
                end
            end

            @testset "ParameterOrExtra{TKey}" begin
                @test chain[Parameter(Shay("a"))] == fill(1, N_iters, 1)
                @test chain[Parameter(Shay("a"))] == fill(1, N_iters, 1)
                @test chain[Parameter(Shay("b"))] == fill(2, N_iters, 1)
                @test chain[Extra("hello")] == fill(3.0, N_iters, 1)
                @test_throws KeyError chain[Parameter(Shay("c"))]
                @test_throws KeyError chain[Extra("world")]
                @testset "with iter subsetting" begin
                    @test chain[Parameter(Shay("a")), iter=4:6] == fill(1, 3, 1)
                    @test chain[Parameter(Shay("a")), iter=4:6, chain=DD.At(1)] ==
                        fill(1, 3)
                end
            end
        end

        @testset "indexing with Symbol" begin
            @testset "no ambiguity" begin
                N_iters = 10
                dicts = fill(Dict(Parameter("a") => 1, Parameter("b") => 2), N_iters)
                chain = FlexiChain{String}(N_iters, 1, dicts)
                # This relies on there being a unique key that can be converted to the given
                # Symbol
                @test chain[:a] == fill(1, N_iters, 1)
                @test chain[:b] == fill(2, N_iters, 1)

                @testset "with iter subsetting" begin
                    @test chain[:a, iter=4:6] == fill(1, 3, 1)
                    @test chain[:a, iter=4:6, chain=DD.At(1)] == fill(1, 3)
                end
            end

            @testset "with ambiguity" begin
                # What happens if you have multiple keys that convert to the same Symbol?
                N_iters = 10
                dicts = fill(Dict(Parameter(@varname(a)) => 1, Extra("a") => 3.0), N_iters)
                chain = FlexiChain{VarName}(N_iters, 1, dicts)

                # getindex with the full key should be fine
                @test chain[Parameter(@varname(a))] == fill(1, N_iters, 1)
                @test chain[Extra("a")] == fill(3.0, N_iters, 1)
                # but getindex with the symbol should fail
                @test_throws KeyError chain[:a]
                # ... with the correct error message
                @test_throws "multiple keys" chain[:a]
            end
        end

        @testset "multiple keys: Colon and AbstractVector" begin
            # These methods all return FlexiChain
            N_iters = 10
            hellos = randn(N_iters)
            dicts = Dict(
                Parameter("a") => 1:N_iters,
                Parameter("b") => fill(2, N_iters),
                Extra("hello") => hellos,
            )
            chain = FlexiChain{String}(N_iters, 1, dicts; iter_indices=2:2:(N_iters * 2))

            @testset "No argument (should default to colon)" begin
                @test isequal(chain, chain[])
                @testset "with iter subsetting" begin
                    # Ordinary indices
                    c2 = chain[iter=4:6]
                    @test c2 isa FlexiChain{String}
                    @test size(c2) == (3, 1)
                    @test c2[Parameter("a")] == reshape(4:6, 3, 1)
                    # With DimensionalData selectors
                    c3 = chain[iter=DD.At([4, 6, 8])]
                    @test c3 isa FlexiChain{String}
                    @test size(c3) == (3, 1)
                    @test c3[Parameter("a")] == reshape(2:4, 3, 1)
                end
            end
            @testset "Explicit colon" begin
                @test isequal(chain, chain[:])
            end
            @testset "AbstractVector{ParameterOrExtra{TKey}}" begin
                keys = [Parameter("a"), Extra("hello")]
                c = chain[keys]
                @test c isa FlexiChain{String}
                @test size(c) == (N_iters, 1)
                @test c[Parameter("a")] == reshape(1:N_iters, N_iters, 1)
                @test c[Extra("hello")] == reshape(hellos, N_iters, 1)
                @test !haskey(c, Parameter("b"))
                @test_throws KeyError c[Parameter("b")]
            end
        end

        @testset "VarName" begin
            N_iters = 10
            d = Dict(
                Parameter(@varname(a)) => 1.0,
                Parameter(@varname(b)) => [2.0, 3.0],
                Parameter(@varname(c)) => (x=4.0, y=5.0),
            )
            chain = FlexiChain{VarName}(N_iters, 1, fill(d, N_iters))

            @testset "ordinary VarName" begin
                @test chain[@varname(a)] == fill(1.0, N_iters, 1)
                @test chain[@varname(b)] == fill([2.0, 3.0], N_iters, 1)
                @test chain[@varname(c)] == fill((x=4.0, y=5.0), N_iters, 1)
                @test_throws KeyError chain[@varname(d)]
                @test chain[@varname(b[1])] == fill(2.0, N_iters, 1)
                @test chain[@varname(b[2])] == fill(3.0, N_iters, 1)
                @test_throws KeyError chain[@varname(b[3])]
                @test chain[@varname(c.x)] == fill(4.0, N_iters, 1)
                @test chain[@varname(c.y)] == fill(5.0, N_iters, 1)
                @test_throws KeyError chain[@varname(c.z)]
            end

            @testset "using Symbol" begin
                @test chain[:a] == fill(1.0, N_iters, 1)
                @test chain[:b] == fill([2.0, 3.0], N_iters, 1)
                @test chain[:c] == fill((x=4.0, y=5.0), N_iters, 1)
                @test_throws KeyError chain[:d]
                # If you want to do fancy sub-indexing you had better use VarNames
                @test_throws KeyError chain[Symbol("b[1]")]
            end

            @testset "multiple keys" begin
                cs = chain[[@varname(a), @varname(b[1]), @varname(c.x)]]
                @test cs isa FlexiChain{VarName}
            end

            @testset "ragged data e.g. vectors of different lengths" begin
                # The first sample of `a` has `a[1]` only, but the second has
                # both `a[1]` and `a[2]`
                d = Dict(Parameter(@varname(a)) => [[1.0], [2.0, 3.0]])
                chn = FlexiChain{VarName}(2, 1, d; iter_indices=[6, 7])
                @test chn[@varname(a)] == reshape([[1.0], [2.0, 3.0]], 2, 1)
                @test chn[@varname(a[1])] == reshape([1.0, 2.0], 2, 1)
                # when indexing into `a[2]` we should get a `missing` for the first sample
                @test isequal(chn[@varname(a[2])], reshape([missing, 3.0], 2, 1))
                # and if we try to get `a[3]` we should get an error
                @test_throws KeyError chn[@varname(a[3])]

                # For good measure we'll throw in some iter subsetting too
                @test chn[@varname(a), iter=2] == [[2.0, 3.0]]
                @test chn[@varname(a[1]), iter=2] == [2.0]
                @test isequal(chn[@varname(a[2]), iter=1], [missing])
                @test chn[@varname(a[2]), iter=2] == [3.0]
                @test_throws KeyError chn[@varname(a[3]), iter=2]
                @test chn[@varname(a), iter=DD.At(7)] == [[2.0, 3.0]]
                @test chn[@varname(a[1]), iter=DD.At(7)] == [2.0]
                @test isequal(chn[@varname(a[2]), iter=1], [missing])
                @test chn[@varname(a[2]), iter=DD.At(7)] == [3.0]
                @test_throws KeyError chn[@varname(a[3]), iter=DD.At(7)]
                # and chain
                @test chn[@varname(a), chain=1] == [[1.0], [2.0, 3.0]]
                @test chn[@varname(a[1]), chain=1] == [1.0, 2.0]
                @test isequal(chn[@varname(a[2]), chain=1], [missing, 3.0])
                @test_throws KeyError chn[@varname(a[3]), chain=1]
            end
        end
    end

    @testset "values_at / parameters_at" begin
        N = 10
        c = FlexiChain{Symbol}(
            N, 1, OrderedDict(Parameter(:a) => rand(N), Extra("c") => rand(N))
        )

        @testset "values_at" begin
            for i in 1:N
                d = FlexiChains.values_at(c, i, 1)
                @test d isa OrderedDict
                @test length(d) == 2
                @test d[Parameter(:a)] == c[Parameter(:a)][i]
                @test d[Extra("c")] == c[Extra("c")][i]
                d = FlexiChains.values_at(c, i, 1, NamedTuple)
                @test d == (a=c[Parameter(:a)][i], c=c[Extra("c")][i])
                d = FlexiChains.values_at(c, i, 1, ComponentArray)
                @test d == ComponentArray(; a=c[Parameter(:a)][i], c=c[Extra("c")][i])
                d = FlexiChains.values_at(c, i, 1, ComponentArray{Real})
                @test d == ComponentArray{Real}(; a=c[Parameter(:a)][i], c=c[Extra("c")][i])
            end
        end

        @testset "parameters_at" begin
            for i in 1:N
                d = FlexiChains.parameters_at(c, i, 1)
                @test length(d) == 1
                @test d[:a] == c[Parameter(:a)][i]
                d = FlexiChains.parameters_at(c, i, 1, NamedTuple)
                @test d == (; a=c[Parameter(:a)][i])
                d = FlexiChains.parameters_at(c, i, 1, ComponentArray)
                @test d == ComponentArray(; a=c[Parameter(:a)][i])
                d = FlexiChains.parameters_at(c, i, 1, ComponentArray{Real})
                @test d == ComponentArray{Real}(; a=c[Parameter(:a)][i])
            end
        end
    end

    @testset "keys merge: `merge`" begin
        @testset "basic merge" begin
            struct Foo end
            N_iters = 10
            dict1 = Dict(Parameter(:a) => 1, Parameter(:b) => "no", Extra("foo") => 3.0)
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(dict1, N_iters))

            dict2 = Dict(
                Parameter(:c) => Foo(), Parameter(:b) => "yes", Extra("bar") => "cheese"
            )
            ii = 3:3:(N_iters * 3)
            ci = [4]
            sampling_time = [2.5]
            last_sampler_state = ["finished"]
            chain2 = FlexiChain{Symbol}(
                N_iters,
                1,
                fill(dict2, N_iters);
                iter_indices=ii,
                chain_indices=ci,
                sampling_time=sampling_time,
                last_sampler_state=last_sampler_state,
            )
            chain3 = merge(chain1, chain2)

            @testset "values are taken from second chain" begin
                expected_chain3 = FlexiChain{Symbol}(
                    N_iters,
                    1,
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
                # Essentially we want to avoid that the underlying data is converted into
                # Matrix{Any} which would lose type information.
                @test eltype(chain3[Parameter(:a)]) == Int
                @test eltype(chain3[Parameter(:b)]) == String
                @test eltype(chain3[Extra("foo")]) == Float64
                @test eltype(chain3[Extra("bar")]) == String
                @test eltype(chain3[Parameter(:c)]) == Foo
            end
        end

        @testset "size mismatch" begin
            # Sizes are just incompatible
            dict1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol}(10, 1, fill(dict1, 10))
            dict2 = Dict(Parameter(:b) => 2.0)
            chain2 = FlexiChain{Symbol}(100, 1, fill(dict2, 100))
            @test_throws DimensionMismatch merge(chain1, chain2)

            # This is OK (vector combined with N*1 matrix)
            dict3 = Dict(Parameter(:c) => 3.0)
            chain3 = FlexiChain{Symbol}(10, 1, fill(dict3, 10, 1))
            @test merge(chain1, chain3) isa FlexiChain{Symbol}

            # This is not OK
            dict4 = Dict(Parameter(:d) => 3.0)
            chain4 = FlexiChain{Symbol}(5, 2, fill(dict4, 5, 2))
            @test_throws DimensionMismatch merge(chain1, chain4)
        end

        @testset "key type promotion" begin
            dict1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol}(10, 1, fill(dict1, 10))
            dict2 = Dict(Parameter("b") => "Hi")
            chain2 = FlexiChain{String}(10, 1, fill(dict2, 10))
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

    @testset "subset parameters and extras" begin
        N_iters = 10
        d = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
        chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))
        @test isequal(FlexiChains.subset_parameters(chain), chain[[Parameter(:a)]])
        @test isequal(FlexiChains.subset_extras(chain), chain[[Extra("c")]])
    end

    @testset "vcat" begin
        @testset "basic application" begin
            niters1 = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(niters1, 1, fill(d1, niters1))
            niters2 = 20
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(niters2, 1, fill(d2, niters2))
            chain12 = vcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol}
            @test size(chain12) == (niters1 + niters2, 1)
            @test chain12[Parameter(:a)] == vcat(fill(1, niters1, 1), fill(2, niters2, 1))
            @test chain12[Extra("c")] ==
                vcat(fill(3.0, niters1, 1), fill("foo", niters2, 1))
        end

        @testset "handling indices" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(
                N_iters, 1, fill(d1, N_iters); iter_indices=1:10, chain_indices=[1]
            )
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(
                N_iters, 1, fill(d2, N_iters); iter_indices=21:30, chain_indices=[2]
            )

            chain12 = vcat(chain1, chain2)
            @test FlexiChains.iter_indices(chain12) ==
                vcat(FlexiChains.iter_indices(chain1), FlexiChains.iter_indices(chain2))
            @test_logs (:warn, r"different chain indices") vcat(chain1, chain2)
            @test FlexiChains.chain_indices(chain12) == FlexiChains.chain_indices(chain1)
        end

        @testset "metadata" begin
            niters1 = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(
                niters1, 1, fill(d1, niters1); sampling_time=[1], last_sampler_state=["foo"]
            )
            niters2 = 20
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(
                niters2, 1, fill(d2, niters2); sampling_time=[2], last_sampler_state=["bar"]
            )
            chain12 = vcat(chain1, chain2)

            # Sampling times should be summed
            @test isapprox(FlexiChains.sampling_time(chain12), [3])
            # Last sampler state should be taken from the second chain
            @test FlexiChains.last_sampler_state(chain12) == ["bar"]
        end

        @testset "error on different number of chains" begin
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(10, 1, fill(d1, 10, 1))
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(10, 2, fill(d2, 10, 2))
            @test_throws DimensionMismatch vcat(chain1, chain2)
        end

        @testset "error on different key type" begin
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol}(10, 1, fill(d1, 10))
            d2 = Dict(Parameter("a") => 2)
            chain2 = FlexiChain{String}(10, 1, fill(d2, 10))
            @test_throws ArgumentError vcat(chain1, chain2)
        end
    end

    @testset "hcat" begin
        @testset "basic application" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(N_iters, 1, fill(d2, N_iters))
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol}
            @test size(chain12) == (N_iters, 2)
            @test chain12[Parameter(:a)] == repeat([1 2], N_iters)
            @test chain12[Extra("c")] == repeat([3.0 "foo"], N_iters)
        end

        @testset "handling indices" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(d1, N_iters); iter_indices=1:10)
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(N_iters, 1, fill(d2, N_iters); iter_indices=21:30)

            @test_logs (:warn, r"different iteration indices") hcat(chain1, chain2)
            chain12 = hcat(chain1, chain2)
            @test FlexiChains.iter_indices(chain12) == FlexiChains.iter_indices(chain1)
            @test FlexiChains.chain_indices(chain12) == [1, 2]
        end

        @testset "combination of metadata" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol}(
                N_iters, 1, fill(d1, N_iters); sampling_time=[1], last_sampler_state=["foo"]
            )
            d2 = Dict(Parameter(:a) => 2)
            chain2 = FlexiChain{Symbol}(
                N_iters, 1, fill(d2, N_iters); sampling_time=[2], last_sampler_state=["bar"]
            )
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol}
            @test size(chain12) == (N_iters, 2)
            @test chain12[Parameter(:a)] == repeat([1 2], N_iters)
            @test FlexiChains.sampling_time(chain12) == [1, 2]
            @test FlexiChains.last_sampler_state(chain12) == ["foo", "bar"]
        end

        @testset "3 or more inputs" begin
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(N_iters, 1, fill(d2, N_iters))
            d3 = Dict(Parameter(:x) => 4, Extra("e") => :y)
            chain3 = FlexiChain{Symbol}(N_iters, 1, fill(d3, N_iters))
            chain123 = hcat(chain1, chain2, chain3)
            @test chain123 isa FlexiChain{Symbol}
            @test size(chain123) == (N_iters, 3)
            # need isequal() rather than `==` to handle the `missing` values
            @test isequal(chain123[Parameter(:a)], repeat([1 2 missing], N_iters))
            @test isequal(chain123[Extra("c")], repeat([3.0 "foo" missing], N_iters))
            @test isequal(chain123[Parameter(:x)], repeat([missing missing 4], N_iters))
            @test isequal(chain123[Extra("e")], repeat([missing missing :y], N_iters))
        end

        @testset "stacking different numbers of chains" begin
            N_iters = 10
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(Dict(Parameter(:a) => 1), N_iters))
            chain2 = FlexiChain{Symbol}(
                N_iters, 2, fill(Dict(Parameter(:a) => 3), N_iters, 2)
            )
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol}
            @test size(chain12) == (N_iters, 3)
            @test chain12[Parameter(:a)] == repeat([1 3 3], N_iters)
        end

        @testset "error on different number of iters" begin
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(20, 1, fill(d1, 20))
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(10, 1, fill(d2, 10))
            @test_throws DimensionMismatch hcat(chain1, chain2)
        end

        @testset "error on different key type" begin
            d1 = Dict(Parameter(:a) => 1)
            chain1 = FlexiChain{Symbol}(10, 1, fill(d1, 10))
            d2 = Dict(Parameter("a") => 2)
            chain2 = FlexiChain{String}(10, 1, fill(d2, 10))
            @test_throws ArgumentError hcat(chain1, chain2)
        end

        @testset "different parameters in chains" begin
            chain1 = FlexiChain{Symbol}(10, 1, fill(Dict(Parameter(:a) => 1), 10))
            chain2 = FlexiChain{Symbol}(10, 1, fill(Dict(Parameter(:b) => 2), 10))
            chain12 = hcat(chain1, chain2)
            @test chain12 isa FlexiChain{Symbol}
            @test size(chain12) == (10, 2)
            # need isequal() rather than `==` to handle the `missing` values
            @test isequal(chain12[Parameter(:a)], repeat([1 missing], 10))
            @test isequal(chain12[Parameter(:b)], repeat([missing 2], 10))
        end

        @testset "AbstractMCMC.chainscat and chainsstack" begin
            # These methods make use of hcat. We just do a basic test
            N_iters = 10
            d1 = Dict(Parameter(:a) => 1, Extra("c") => 3.0)
            chain1 = FlexiChain{Symbol}(N_iters, 1, fill(d1, N_iters))
            d2 = Dict(Parameter(:a) => 2, Extra("c") => "foo")
            chain2 = FlexiChain{Symbol}(N_iters, 1, fill(d2, N_iters))
            d3 = Dict(Parameter(:x) => 4, Extra("e") => :y)
            chain3 = FlexiChain{Symbol}(N_iters, 1, fill(d3, N_iters))
            chain12 = hcat(chain1, chain2)
            @test isequal(AbstractMCMC.chainscat(chain1, chain2), chain12)
            @test isequal(AbstractMCMC.chainsstack([chain1, chain2]), chain12)
            chain123 = hcat(chain1, chain2, chain3)
            @test isequal(AbstractMCMC.chainscat(chain1, chain2, chain3), chain123)
            @test isequal(AbstractMCMC.chainsstack([chain1, chain2, chain3]), chain123)
        end
    end

    @testset "split_varnames" begin
        N_iters = 10
        # use OrderedDict so that we can also test order
        d = OrderedDict(
            Parameter(@varname(a)) => 1.0,
            Parameter(@varname(c)) => (x=4.0, y=5.0),
            Parameter(@varname(b)) => [2.0, 3.0],
            Extra("hello") => 3.0,
        )
        chain = FlexiChain{VarName}(N_iters, 1, fill(d, N_iters))
        chain2 = FlexiChains.split_varnames(chain)
        @test collect(keys(chain2)) == ([
            Parameter(@varname(a)),
            Parameter(@varname(c.x)),
            Parameter(@varname(c.y)),
            Parameter(@varname(b[1])),
            Parameter(@varname(b[2])),
            Extra("hello"),
        ])
    end
end

end # module
