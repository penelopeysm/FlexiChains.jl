module FlexiChainsPosteriorStatsTests

using FlexiChains: FlexiChain, Parameter, Extra, VarName, @varname
using DimensionalData: DimensionalData as DD, val
using OrderedCollections: OrderedDict
using PosteriorStats: PosteriorStats
using Test

@testset verbose = true "PosteriorStats extension" begin
    @info "Testing PosteriorStats extension"

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
