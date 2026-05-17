module FlexiChainsPosteriorStatsTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, VarName, @varname, FlexiSummary
using DimensionalData: DimensionalData as DD, val
using OrderedCollections: OrderedDict
using PosteriorStats: PosteriorStats
using Test

@testset verbose = true "PosteriorStats extension" begin
    @info "Testing PosteriorStats extension"

    @testset "hdi/eti" begin
        N_iters, N_chains = 10, 3
        as = rand(N_iters, N_chains)
        bs = rand(N_iters, N_chains)
        cs = rand(N_iters, N_chains)
        chain = FlexiChain{Symbol}(
            N_iters,
            N_chains,
            OrderedDict(
                Parameter(:a) => as,
                Parameter(:b) => bs,
                Extra("c") => cs,
            )
        )

        @testset "basic return types" begin
            for func in (PosteriorStats.hdi, PosteriorStats.eti)
                fs = func(chain; prob = 0.95)
                @test fs isa FlexiSummary
                @test FlexiChains.iter_indices(fs) === nothing
                @test FlexiChains.chain_indices(fs) === nothing
                @test FlexiChains.stat_indices(fs) === nothing

                fsi = func(chain; prob = 0.95, dims = :chain)
                @test fsi isa FlexiSummary
                @test FlexiChains.iter_indices(fsi) == FlexiChains.iter_indices(chain)
                @test FlexiChains.chain_indices(fsi) === nothing
                @test FlexiChains.stat_indices(fsi) === nothing

                fsc = func(chain; prob = 0.95, dims = :iter)
                @test fsc isa FlexiSummary
                @test FlexiChains.iter_indices(fsc) === nothing
                @test FlexiChains.chain_indices(fsc) == FlexiChains.chain_indices(chain)
                @test FlexiChains.stat_indices(fsc) === nothing
            end
        end

        @testset "split_interval kwarg" begin
            fs_split_hdi = PosteriorStats.hdi(chain; prob = 0.95, split_interval = true)
            @test FlexiChains.stat_indices(fs_split_hdi) == [:hdi_lower, :hdi_upper]

            fs_split_eti = PosteriorStats.eti(chain; prob = 0.95, split_interval = true)
            @test FlexiChains.stat_indices(fs_split_eti) == [:eti_lower, :eti_upper]

            # If we use method=:multimodal, split_interval should be ignored
            @test_logs (:warn, r"Returning the original FlexiSummary without splitting") PosteriorStats.hdi(chain; prob = 0.95, method = :multimodal, split_interval = true)
            fs_multimodal = PosteriorStats.hdi(chain; prob = 0.95, method = :multimodal, split_interval = true)
            @test FlexiChains.stat_indices(fs_multimodal) === nothing
        end

        @testset "test info message when prob isn't passed" begin
            expected_message = r"`prob` keyword argument not provided"
            @test_logs (:info, expected_message) PosteriorStats.hdi(chain)
            @test_logs (:info, expected_message) PosteriorStats.eti(chain)

            @test_logs PosteriorStats.hdi(chain; prob = 0.95)
            @test_logs PosteriorStats.eti(chain; prob = 0.95)
        end
    end

    @testset "loo with Symbol-keyed chain" begin
        N_iters, N_chains = 100, 2
        loglikes = -rand(N_iters, N_chains, 3)
        d = OrderedDict(
            Parameter(:y1) => loglikes[:, :, 1],
            Parameter(:y2) => loglikes[:, :, 2],
            Extra(:wut) => loglikes[:, :, 3],
        )
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        result = PosteriorStats.loo(chn)
        # This also tests that the extra keys are dropped
        @test result.param_names == [:y1, :y2]
        @test result.loo isa PosteriorStats.PSISLOOResult
        # check that the result is same as if we had passed the loglikelihood array directly
        result_direct = PosteriorStats.loo(loglikes[:, :, 1:2])
        @test PosteriorStats.elpd_estimates(result.loo) == PosteriorStats.elpd_estimates(result_direct)
    end

    @testset "loo with VarName-keyed chain and array-valued params" begin
        N_iters, N_chains = 100, 2
        d = [
            OrderedDict(
                    Parameter(@varname(y)) => [-rand(), -rand()],
                )
                for _ in 1:N_iters, _ in 1:N_chains
        ]
        chn = FlexiChain{VarName}(N_iters, N_chains, d)
        result = PosteriorStats.loo(chn)
        @test result.param_names == [@varname(y[1]), @varname(y[2])]
        @test result.loo isa PosteriorStats.PSISLOOResult
    end
end

end # module
