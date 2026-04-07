module FCDiagnosticsTests

using DimensionalData: DimensionalData as DD
using FlexiChains:
    FlexiChains,
    FlexiChain,
    FlexiSummary,
    Parameter,
    ParameterOrExtra,
    Extra,
    VarName,
    @varname
using Logging: Warn
using MCMCDiagnosticTools: gelmandiag, gelmandiag_multivariate, discretediag
using OrderedCollections: OrderedDict
using Test

@testset verbose = true "diagnostics.jl" begin
    @info "Testing diagnostics.jl"

    @testset "gelmandiag" begin
        N_iters, N_chains = 100, 3
        as = randn(N_iters, N_chains)
        bs = randn(N_iters, N_chains)

        @testset "Symbol chain, scalar params" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains, Dict(Parameter(:a) => as, Parameter(:b) => bs)
            )
            gd = gelmandiag(chain)
            @test gd isa FlexiSummary{Symbol}
            @test haskey(gd, Parameter(:a))
            @test haskey(gd, Parameter(:b))
            @test length(gd[:a]) == 2  # psrf and psrfci
            @test all(gd[:a] .> 0)
        end

        @testset "Symbol chain, array-valued params" begin
            xs = [randn(3) for _ in 1:N_iters, _ in 1:N_chains]
            chain = FlexiChain{Symbol}(
                N_iters, N_chains,
                Dict(Parameter(:x) => xs, Parameter(:y) => as),
            )
            gd = gelmandiag(chain)
            @test gd isa FlexiSummary{Symbol}
            @test haskey(gd, Parameter(Symbol("x[1]")))
            @test haskey(gd, Parameter(Symbol("x[2]")))
            @test haskey(gd, Parameter(Symbol("x[3]")))
            @test haskey(gd, Parameter(:y))
        end

        @testset "VarName chain" begin
            xs = [randn(2) for _ in 1:N_iters, _ in 1:N_chains]
            chain = FlexiChain{VarName}(
                N_iters, N_chains,
                Dict(Parameter(@varname(x)) => xs, Parameter(@varname(y)) => as),
            )
            gd = gelmandiag(chain)
            @test gd isa FlexiSummary{VarName}
            @test haskey(gd, @varname(x[1]))
            @test haskey(gd, @varname(x[2]))
            @test haskey(gd, @varname(y))
        end

        @testset "non-Real params skipped with warning" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains,
                Dict(
                    Parameter(:a) => as,
                    Extra("str") => fill("hello", N_iters, N_chains),
                ),
            )
            gd = @test_logs (:warn, r"str") gelmandiag(chain)
            @test haskey(gd, Parameter(:a))
            @test !haskey(gd, Extra("str"))
            @test_logs gelmandiag(chain; warn = false)
        end

        @testset "errors with single chain" begin
            chain = FlexiChain{Symbol}(
                N_iters, 1, Dict(Parameter(:a) => randn(N_iters, 1))
            )
            @test_throws ErrorException gelmandiag(chain)
        end
    end

    @testset "gelmandiag_multivariate" begin
        N_iters, N_chains = 100, 3
        as = randn(N_iters, N_chains)
        bs = randn(N_iters, N_chains)
        chain = FlexiChain{Symbol}(
            N_iters, N_chains, Dict(Parameter(:a) => as, Parameter(:b) => bs)
        )

        @testset "returns NamedTuple with summary and psrf_multivariate" begin
            gdm = gelmandiag_multivariate(chain)
            @test gdm.summary isa FlexiSummary{Symbol}
            @test gdm.psrf_multivariate isa Float64
            @test gdm.psrf_multivariate > 0
            # per-parameter stats should match gelmandiag
            gd = gelmandiag(chain)
            @test gd[:a] == gdm.summary[:a]
            @test gd[:b] == gdm.summary[:b]
        end

        @testset "errors with single parameter" begin
            chain1 = FlexiChain{Symbol}(
                N_iters, N_chains, Dict(Parameter(:a) => as)
            )
            @test_throws ErrorException gelmandiag_multivariate(chain1)
        end
    end

    @testset "discretediag" begin
        N_iters, N_chains = 100, 3
        as = rand(1:5, N_iters, N_chains)
        bs = rand(1:3, N_iters, N_chains)

        @testset "Symbol chain, scalar params" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains, Dict(Parameter(:a) => as, Parameter(:b) => bs)
            )
            result = discretediag(chain)
            @test result.between isa FlexiSummary{Symbol}
            @test result.within isa FlexiSummary{Symbol}
            # Between-chain: per-parameter stats
            @test haskey(result.between, Parameter(:a))
            @test haskey(result.between, Parameter(:b))
            @test length(result.between[:a]) == 3  # stat, df, pvalue
            # Within-chain: per-parameter-per-chain stats
            @test haskey(result.within, Parameter(:a))
            @test haskey(result.within, Parameter(:b))
            @test size(result.within[:a]) == (N_chains, 3)
        end

        @testset "Symbol chain, array-valued params" begin
            xs = [rand(1:4, 2) for _ in 1:N_iters, _ in 1:N_chains]
            chain = FlexiChain{Symbol}(
                N_iters, N_chains,
                Dict(Parameter(:x) => xs, Parameter(:y) => as),
            )
            result = discretediag(chain)
            @test result.between isa FlexiSummary{Symbol}
            @test haskey(result.between, Parameter(Symbol("x[1]")))
            @test haskey(result.between, Parameter(Symbol("x[2]")))
            @test haskey(result.between, Parameter(:y))
        end

        @testset "VarName chain" begin
            xs = [rand(1:4, 2) for _ in 1:N_iters, _ in 1:N_chains]
            chain = FlexiChain{VarName}(
                N_iters, N_chains,
                Dict(Parameter(@varname(x)) => xs, Parameter(@varname(y)) => as),
            )
            result = discretediag(chain)
            @test result.between isa FlexiSummary{VarName}
            @test result.within isa FlexiSummary{VarName}
            @test haskey(result.between, @varname(x[1]))
            @test haskey(result.between, @varname(x[2]))
            @test haskey(result.between, @varname(y))
        end

        @testset "non-Real params skipped with warning" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains,
                Dict(
                    Parameter(:a) => as,
                    Extra("str") => fill("hello", N_iters, N_chains),
                ),
            )
            result = @test_logs (:warn, r"str") discretediag(chain)
            @test haskey(result.between, Parameter(:a))
            @test !haskey(result.between, Extra("str"))
            @test_logs discretediag(chain; warn = false)
        end

        @testset "method kwarg forwarded" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains, Dict(Parameter(:a) => as)
            )
            result = discretediag(chain; method = :hangartner)
            @test result.between isa FlexiSummary{Symbol}
        end

        @testset "within-chain has correct chain indices" begin
            chain = FlexiChain{Symbol}(
                N_iters, N_chains,
                Dict(Parameter(:a) => as);
                chain_indices = FlexiChains._make_lookup(2:2:6),
            )
            result = discretediag(chain)
            @test FlexiChains.chain_indices(result.within) ==
                FlexiChains.chain_indices(chain)
        end
    end
end

end # module
