module FCSummariesTests

using DimensionalData: DimensionalData as DD
using FlexiChains:
    FlexiChains,
    FlexiChain,
    FlexiSummary,
    Parameter,
    ParameterOrExtra,
    Extra,
    VarName,
    @varname,
    summarystats
using Logging: Warn
using MCMCDiagnosticTools: ess, rhat, mcse
using OrderedCollections: OrderedDict
using PosteriorStats: hdi, eti
using Serialization: serialize, deserialize
using Statistics
using StatsBase: geomean, harmmean, mad, iqr
using Test

const ENABLED_SUMMARY_FUNCS = [mean, median, minimum, maximum, std, var, sum, prod]
const WORKS_ON_STRING = [minimum, maximum, prod]

@testset verbose = true "summaries.jl" begin
    @info "Testing summaries.jl"

    N_iters, N_chains = 10, 3
    as = rand(N_iters, N_chains)
    bs = rand(1:100, N_iters, N_chains)
    cs = rand(Bool, N_iters, N_chains)
    ds = fill("hello", N_iters, N_chains)
    chain = FlexiChain{Symbol}(
        N_iters,
        N_chains,
        Dict(
            Parameter(:a) => as,
            Parameter(:b) => bs,
            Extra("c") => cs,
            Extra("actuallyString") => ds,
        );
        iter_indices=FlexiChains._make_lookup(4:4:(4 * N_iters)),
        chain_indices=FlexiChains._make_lookup(1:N_chains),
    )

    @testset "collapse" begin
        @testset for func in ENABLED_SUMMARY_FUNCS
            @testset "dims=:iter" begin
                fs = FlexiChains.collapse(chain, [func]; dims=:iter)
                @test fs[:a] isa DD.DimMatrix
                @test parent(parent(DD.dims(fs[:a], :chain))) ==
                    FlexiChains.chain_indices(chain) ==
                    FlexiChains.chain_indices(fs)
                @test isapprox(fs[:a], vec(func(as; dims=1)); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = reshape(func(ds; dims=1), N_chains, 1)
                    @test fs[Extra("actuallyString")] == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [func]; dims=:iter, warn=true
                    )
                end
            end

            @testset "dims=:chain" begin
                fs = FlexiChains.collapse(chain, [func]; dims=:chain)
                @test fs[:a] isa DD.DimMatrix
                @test parent(parent(DD.dims(fs[:a], :iter))) ==
                    FlexiChains.iter_indices(chain) ==
                    FlexiChains.iter_indices(fs)
                @test parent(parent(DD.dims(fs[:a], :stat))) == [Symbol(func)]
                @test isapprox(fs[:a], vec(func(as; dims=2)); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = reshape(func(ds; dims=2), N_iters, 1)
                    @test fs[Extra("actuallyString")] == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [func]; dims=:chain, warn=true
                    )
                end
            end

            @testset "dims=:both" begin
                fs = FlexiChains.collapse(chain, [func]; dims=:both)
                @test fs[:a] isa DD.DimVector
                @test parent(parent(DD.dims(fs[:a], :stat))) == [Symbol(func)]
                @test isapprox(only(fs[:a]), func(as); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = func(ds)
                    @test only(fs[Extra("actuallyString")]) == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [func]; dims=:both, warn=true
                    )
                end
            end
        end
    end

    @testset "other summary functions" begin
        @test geomean(chain) isa FlexiSummary
        @test geomean(chain; dims=:iter) isa FlexiSummary
        @test geomean(chain; dims=:chain) isa FlexiSummary
        @test harmmean(chain) isa FlexiSummary
        @test harmmean(chain; dims=:iter) isa FlexiSummary
        @test harmmean(chain; dims=:chain) isa FlexiSummary
        @test mad(chain) isa FlexiSummary
        @test mad(chain; dims=:iter) isa FlexiSummary
        @test mad(chain; dims=:chain) isa FlexiSummary
        @test iqr(chain) isa FlexiSummary
        @test iqr(chain; dims=:iter) isa FlexiSummary
        @test iqr(chain; dims=:chain) isa FlexiSummary
        @test ess(chain) isa FlexiSummary
        @test ess(chain; dims=:iter) isa FlexiSummary
        @test ess(chain; dims=:chain) isa FlexiSummary
        @test ess(chain; kind=:tail) isa FlexiSummary
        @test ess(chain; dims=:iter, kind=:tail) isa FlexiSummary
        @test ess(chain; dims=:chain, kind=:tail) isa FlexiSummary
        @test rhat(chain) isa FlexiSummary
        @test rhat(chain; dims=:iter) isa FlexiSummary
        @test rhat(chain; dims=:chain) isa FlexiSummary
        @test mcse(chain) isa FlexiSummary
        @test mcse(chain; dims=:iter) isa FlexiSummary
        @test mcse(chain; dims=:chain) isa FlexiSummary
        @test hdi(chain) isa FlexiSummary
        @test hdi(chain; dims=:iter) isa FlexiSummary
        @test hdi(chain; dims=:chain) isa FlexiSummary
        @test eti(chain) isa FlexiSummary
        @test eti(chain; dims=:iter) isa FlexiSummary
        @test eti(chain; dims=:chain) isa FlexiSummary
        @test quantile(chain, 0.5) isa FlexiSummary
        @test quantile(chain, 0.5; dims=:iter) isa FlexiSummary
        @test quantile(chain, 0.5; dims=:chain) isa FlexiSummary
        @test quantile(chain, [0.5, 0.9]) isa FlexiSummary
        @test quantile(chain, [0.5, 0.9]; dims=:iter) isa FlexiSummary
        @test quantile(chain, [0.5, 0.9]; dims=:chain) isa FlexiSummary
    end

    @testset "summarystats" begin
        @test summarystats(chain) isa FlexiSummary
        # Not sure what else we want to test here; all the individual functions are
        # well-tested...
    end

    @testset "warn=false" begin
        # Check that no warnings are issued when warn=false
        @test_logs min_level = Warn mean(chain; warn=false)
        @test_logs min_level = Warn FlexiChains.collapse(
            chain, [mean]; dims=:both, warn=false
        )
    end

    @testset "drop_stat_dim=true" begin
        @testset "iter" begin
            fs = FlexiChains.collapse(chain, [mean]; dims=:iter, drop_stat_dim=true)
            @test fs[:a] isa DD.DimVector
            @test parent(parent(DD.dims(fs[:a], :chain))) ==
                FlexiChains.chain_indices(chain) ==
                FlexiChains.chain_indices(fs)
            @test isapprox(fs[:a], vec(mean(as; dims=1)))
        end

        @testset "chain" begin
            fs = FlexiChains.collapse(chain, [mean]; dims=:chain, drop_stat_dim=true)
            @test fs[:a] isa DD.DimVector
            @test parent(parent(DD.dims(fs[:a], :iter))) ==
                FlexiChains.iter_indices(chain) ==
                FlexiChains.iter_indices(fs)
            @test isapprox(fs[:a], vec(mean(as; dims=2)))
        end

        @testset "both" begin
            fs = FlexiChains.collapse(chain, [mean]; dims=:both, drop_stat_dim=true)
            @test fs[:a] isa Float64
            @test isapprox(fs[:a], mean(as))
        end
    end

    @testset "check that keyword arguments are forwarded" begin
        # We'll use `std` without Bessel correction here.
        N_iters, N_chains = 10, 3
        as = rand(N_iters, N_chains)
        chain = FlexiChain{Symbol}(N_iters, N_chains, Dict(Parameter(:a) => as))

        @testset "iter" begin
            expected = std(as; dims=1, corrected=false)
            result = std(chain; dims=:iter, corrected=false)[:a]
            @test isapprox(result, vec(expected))
        end
        @testset "chain" begin
            expected = std(as; dims=2, corrected=false)
            result = std(chain; dims=:chain, corrected=false)[:a]
            @test isapprox(result, vec(expected))
        end
        @testset "iter + chain" begin
            expected = std(chain[:a]; corrected=false)
            result = std(chain; corrected=false)[:a]
            @test isapprox(only(result), expected)
        end
    end

    @testset "show doesn't error" begin
        ds = [
            Dict(Parameter(:a) => 1, Extra("hello") => 3.0),
            Dict(Parameter(:a) => 1),
            Dict(Extra("hello") => 3.0),
            Dict(),
        ]
        for d in ds
            chain = FlexiChain{Symbol}(10, 3, fill(d, 10, 3))
            display(mean(chain; dims=:iter))
            display(median(chain; dims=:chain))
            display(std(chain; dims=:both))
            display(summarystats(chain))
        end
    end

    @testset "serialise" begin
        fs = summarystats(chain)
        fname = Base.Filesystem.tempname()
        serialize(fname, fs)
        fs2 = deserialize(fname)
        @test isequal(fs, fs2)
        # also test ordering of keys, since isequal doesn't check that
        @test collect(keys(fs)) == collect(keys(fs2))
    end

    @testset "summarystats when some functions fail" begin
        x = randn(2)
        d = Dict(Parameter(:x) => fill(x, 5, 2))
        chain = FlexiChain{Symbol}(5, 2, d)
        # Attempting to perform the summary here will result in some functions failing
        # because they can't handle vector-valued data. For example, ESS will fail.
        # We just want to check that summarystats still works and returns the results for the
        # functions that _do_ work.
        sm = summarystats(chain)
        @test haskey(sm, Parameter(:x))
        @test isapprox(sm[:x, stat=DD.At(:mean)], x)
        @test ismissing(sm[:x, stat=DD.At(:ess_bulk)])
    end

    @testset "getindex on summaries" begin
        N_iters, N_chains = 10, 3
        xs = Matrix{Vector{Float64}}(undef, N_iters, N_chains)
        ys = Matrix{Float64}(undef, N_iters, N_chains)
        for i in 1:N_iters, j in 1:N_chains
            xs[i, j] = rand(10)
            ys[i, j] = randn()
        end
        chain = FlexiChain{VarName}(
            N_iters,
            N_chains,
            Dict(Parameter(@varname(x)) => xs, Parameter(@varname(y)) => ys),
        )

        @testset "dims=:iter" begin
            fs = mean(chain; dims=:iter, split_varnames=false)

            @testset "VarName" begin
                @test fs[@varname(x)] isa DD.DimVector
                @test parent(parent(DD.dims(fs[@varname(x)], :chain))) ==
                    FlexiChains.chain_indices(chain) ==
                    FlexiChains.chain_indices(fs)
                @test isapprox(fs[@varname(x)], dropdims(mean(xs; dims=1); dims=1))
            end

            @testset "Symbol" begin
                @test fs[:x] isa DD.DimVector
                @test parent(parent(DD.dims(fs[:x], :chain))) ==
                    FlexiChains.chain_indices(chain) ==
                    FlexiChains.chain_indices(fs)
                @test isapprox(fs[:x], dropdims(mean(xs; dims=1); dims=1))
            end

            @testset "sub-VarName" begin
                @test fs[@varname(x[1])] isa DD.DimVector
                @test parent(parent(DD.dims(fs[@varname(x[1])], :chain))) ==
                    FlexiChains.chain_indices(chain) ==
                    FlexiChains.chain_indices(fs)
                @test isapprox(
                    fs[@varname(x[1])], dropdims(mean(getindex.(xs, 1); dims=1); dims=1)
                )
            end

            @testset "vector of keys" begin
                fs2 = fs[[Parameter(@varname(x)), Parameter(@varname(y))]]
                @test fs2 isa FlexiSummary
                @test FlexiChains.iter_indices(fs2) == FlexiChains.iter_indices(fs)
                @test FlexiChains.chain_indices(fs2) == FlexiChains.chain_indices(fs)
                @test FlexiChains.stat_indices(fs2) == FlexiChains.stat_indices(fs)
                @test fs2[@varname(x[1])] == fs[@varname(x[1])]
                @test fs2[@varname(x[2])] == fs[@varname(x[2])]
                @test fs2[@varname(x)] == fs[@varname(x)]
                @test fs2[@varname(y)] == fs[@varname(y)]
            end

            @testset "nonexistent VarName" begin
                @test_throws KeyError fs[@varname(z)]
                @test_throws Exception fs[@varname(x.a)]
            end
        end

        @testset "dims=:chain" begin
            fs = mean(chain; dims=:chain, split_varnames=false)

            @testset "VarName" begin
                @test fs[@varname(x)] isa DD.DimVector
                @test parent(parent(DD.dims(fs[@varname(x)], :iter))) ==
                    FlexiChains.iter_indices(chain) ==
                    FlexiChains.iter_indices(fs)
                @test isapprox(fs[@varname(x)], dropdims(mean(xs; dims=2); dims=2))
            end

            @testset "Symbol" begin
                @test fs[:x] isa DD.DimVector
                @test parent(parent(DD.dims(fs[:x], :iter))) ==
                    FlexiChains.iter_indices(chain) ==
                    FlexiChains.iter_indices(fs)
                @test isapprox(fs[:x], dropdims(mean(xs; dims=2); dims=2))
            end

            @testset "sub-VarName" begin
                @test fs[@varname(x[1])] isa DD.DimVector
                @test parent(parent(DD.dims(fs[@varname(x[1])], :iter))) ==
                    FlexiChains.iter_indices(chain) ==
                    FlexiChains.iter_indices(fs)
                @test isapprox(
                    fs[@varname(x[1])], dropdims(mean(getindex.(xs, 1); dims=2); dims=2)
                )
            end

            @testset "vector of keys" begin
                fs2 = fs[[Parameter(@varname(x)), Parameter(@varname(y))]]
                @test fs2 isa FlexiSummary
                @test FlexiChains.iter_indices(fs2) == FlexiChains.iter_indices(fs)
                @test FlexiChains.chain_indices(fs2) == FlexiChains.chain_indices(fs)
                @test FlexiChains.stat_indices(fs2) == FlexiChains.stat_indices(fs)
                @test fs2[@varname(x[1])] == fs[@varname(x[1])]
                @test fs2[@varname(x[2])] == fs[@varname(x[2])]
                @test fs2[@varname(x)] == fs[@varname(x)]
                @test fs2[@varname(y)] == fs[@varname(y)]
            end

            @testset "nonexistent VarName" begin
                @test_throws KeyError fs[@varname(z)]
                @test_throws Exception fs[@varname(x.a)]
            end
        end

        @testset "dims=:both" begin
            fs = mean(chain; split_varnames=false)

            @testset "VarName" begin
                @test fs[@varname(x)] isa Vector{Float64}
                @test isapprox(fs[@varname(x)], mean(xs))
            end

            @testset "Symbol" begin
                @test fs[:x] isa Vector{Float64}
                @test isapprox(fs[:x], mean(xs))
            end

            @testset "sub-VarName" begin
                @test fs[@varname(x[1])] isa Float64
                @test isapprox(fs[@varname(x[1])], mean(getindex.(xs, 1)))
            end

            @testset "vector of keys" begin
                fs2 = fs[[Parameter(@varname(x)), Parameter(@varname(y))]]
                @test fs2 isa FlexiSummary
                @test FlexiChains.iter_indices(fs2) == FlexiChains.iter_indices(fs)
                @test FlexiChains.chain_indices(fs2) == FlexiChains.chain_indices(fs)
                @test FlexiChains.stat_indices(fs2) == FlexiChains.stat_indices(fs)
                @test fs2[@varname(x[1])] == fs[@varname(x[1])]
                @test fs2[@varname(x[2])] == fs[@varname(x[2])]
                @test fs2[@varname(x)] == fs[@varname(x)]
                @test fs2[@varname(y)] == fs[@varname(y)]
            end

            @testset "nonexistent VarName" begin
                @test_throws KeyError fs[@varname(z)]
                @test_throws Exception fs[@varname(x.a)]
            end
        end

        @testset "with split_varnames" begin
            fs = mean(chain; dims=:iter)
            for i in 1:10
                @test haskey(fs, @varname(x[i]))
                @test isapprox(
                    fs[@varname(x[i])], dropdims(mean(getindex.(xs, i); dims=1); dims=1)
                )
            end
            @test haskey(fs, @varname(y))
            @test !haskey(fs, @varname(x))
            @test fs[@varname(x[1])] isa DD.DimVector
        end
    end

    @testset "kwarg handling for getindex" begin
        N_iters, N_chains = 10, 3
        xs = Matrix{Vector{Float64}}(undef, N_iters, N_chains)
        for i in 1:N_iters, j in 1:N_chains
            xs[i, j] = rand(10)
        end
        chain = FlexiChain{VarName}(N_iters, N_chains, Dict(Parameter(@varname(x)) => xs))

        @testset "iter and stat collapsed" begin
            # Test that attempting to index in with either `iter=...` or `stat=...` errors
            fs = mean(chain; dims=:iter, split_varnames=false)
            @test_throws ArgumentError FlexiChains._check_summary_kwargs(
                fs, Colon(), Colon(), Colon()
            )
            @test_throws ArgumentError fs[Parameter(@varname(x)), iter=:]
            @test_throws ArgumentError FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), Colon()
            )
            @test_throws ArgumentError fs[Parameter(@varname(x)), stat=:]
            # And that omitting both works
            @test FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), FlexiChains._UNSPECIFIED_KWARG
            ) == (chain=Colon(),)
            @test fs[Parameter(@varname(x))] isa Any
        end

        @testset "iter collapsed only" begin
            # Test that attempting to index in with `iter=...` errors, but `stat=...` works
            fs = FlexiChains.collapse(chain, [mean]; dims=:iter)
            @test_throws ArgumentError FlexiChains._check_summary_kwargs(
                fs, Colon(), Colon(), Colon()
            )
            @test_throws ArgumentError fs[Parameter(@varname(x)), iter=:]
            @test FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), Colon()
            ) isa Any
            @test fs[Parameter(@varname(x)), stat=:] isa Any
            @test FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), FlexiChains._UNSPECIFIED_KWARG
            ) == (chain=Colon(), stat=Colon())
            # check that we can use DD lookups for the stat dimension
            @test fs[Parameter(@varname(x)), stat=DD.At(:mean)] isa Any
            @test FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), DD.At(:mean)
            ) == (chain=Colon(), stat=DD.At(:mean))
            @test FlexiChains._check_summary_kwargs(
                fs, FlexiChains._UNSPECIFIED_KWARG, Colon(), DD.At(:mean)
            ) == (chain=Colon(), stat=DD.At(:mean))
            # check sub-varname too
            @test isapprox(
                fs[Parameter(@varname(x[1])), stat=DD.At(:mean)],
                vec(mean(getindex.(xs, 1); dims=1)),
            )
            # check with no kwargs too
            @test fs[Parameter(@varname(x))] isa Any
        end
    end

    @testset "map_keys" begin
        dicts = fill(
            OrderedDict(
                Parameter(:a) => randn(10, 3),
                Parameter(:b) => randn(10, 3),
                Extra("hello") => randn(10, 3),
            ),
            10,
            3,
        )
        chain = FlexiChain{Symbol}(10, 3, dicts)
        smy = FlexiChains.summarystats(chain)

        @testset "trivial identity mapping" begin
            idsmy = FlexiChains.map_keys(identity, smy)
            @test idsmy isa FlexiSummary{Symbol}
            @test isequal(smy, idsmy)
            @test collect(keys(idsmy)) == collect(keys(smy))
        end

        @testset "a working mapping" begin
            g(s::Parameter{Symbol}) = Parameter(String(s.name))
            g(e::Extra) = Extra(Symbol(e.name))
            gsmy = FlexiChains.map_keys(g, smy)
            @test gsmy isa FlexiSummary{String}
            # this checks that the order of keys is preserved
            @test collect(keys(gsmy)) == [Parameter("a"), Parameter("b"), Extra(:hello)]
            @test isequal(gsmy[Parameter("a")], smy[Parameter(:a)])
            @test isequal(gsmy[Parameter("b")], smy[Parameter(:b)])
            @test isequal(gsmy[Extra(:hello)], smy[Extra("hello")])
        end

        @testset "bad function output" begin
            # Doesn't return a valid key
            h(::Any) = 1
            @test_throws ArgumentError FlexiChains.map_keys(h, smy)
            # Returns duplicate keys
            j(::Any) = Parameter(:hello)
            @test_throws ArgumentError FlexiChains.map_keys(j, smy)
        end
    end

    @testset "map_parameters" begin
        dicts = fill(
            OrderedDict(
                Parameter(:a) => randn(10, 3),
                Parameter(:b) => randn(10, 3),
                Extra("hello") => randn(10, 3),
            ),
            10,
            3,
        )
        chain = FlexiChain{Symbol}(10, 3, dicts)
        smy = FlexiChains.summarystats(chain)

        @testset "trivial identity mapping" begin
            idsmy = FlexiChains.map_parameters(identity, smy)
            @test idsmy isa FlexiSummary{Symbol}
            @test isequal(smy, idsmy)
            @test collect(keys(idsmy)) == collect(keys(smy))
        end

        @testset "a working mapping" begin
            gsmy = FlexiChains.map_parameters(String, smy)
            @test gsmy isa FlexiSummary{String}
            # this checks that the order of keys is preserved
            @test collect(keys(gsmy)) == [Parameter("a"), Parameter("b"), Extra("hello")]
            @test isequal(gsmy[Parameter("a")], smy[Parameter(:a)])
            @test isequal(gsmy[Parameter("b")], smy[Parameter(:b)])
            @test isequal(gsmy[Extra("hello")], smy[Extra("hello")])
        end

        @testset "bad function output" begin
            # Returns duplicate keys
            j(::Any) = 1
            @test_throws ArgumentError FlexiChains.map_parameters(j, smy)
        end
    end
end

end # module
