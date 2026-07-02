module FlexiChainsInferenceObjectsTests

using FlexiChains: FlexiChain, Parameter, Extra, VarName, @varname
using InferenceObjects: InferenceObjects
using DimensionalData: DimensionalData as DD
using OrderedCollections: OrderedDict
using Test

@testset verbose = true "InferenceObjects extension" begin
    @info "Testing InferenceObjects extension"

    N_iters, N_chains = 50, 3

    @testset "scalar parameters with extras" begin
        x_data = randn(N_iters, N_chains)
        y_data = randn(N_iters, N_chains)
        lp_data = randn(N_iters, N_chains)
        d = OrderedDict(
            Parameter(:x) => x_data,
            Parameter(:y) => y_data,
            Extra(:lp) => lp_data,
        )
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn)

        @test haskey(idata, :posterior)
        @test haskey(idata, :sample_stats)
        @test collect(keys(idata.posterior)) == [:x, :y]
        @test only(keys(idata.sample_stats)) == :lp

        # need to use `parent` here for comparison because the DimArrays have different dims
        @test parent(idata.posterior.x) == parent(chn[Parameter(:x)])
        @test parent(idata.posterior.y) == parent(chn[Parameter(:y)])
        @test parent(idata.sample_stats.lp) == parent(chn[Extra(:lp)])

        # check that `idata`'s `draw` dim is the same as FlexiChains' `iter` dim
        @test DD.lookup(idata.posterior.x, :draw) == DD.lookup(chn[Parameter(:x)], :iter)
        # check that the `chain` dims are the same
        @test DD.lookup(idata.posterior.x, :chain) == DD.lookup(chn[Parameter(:x)], :chain)
    end

    @testset "without extras" begin
        d = OrderedDict(Parameter(:x) => randn(N_iters, N_chains))
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn)
        @test haskey(idata, :posterior)
        @test !haskey(idata, :sample_stats)
    end

    @testset "array-valued parameters" begin
        d = [
            OrderedDict(Parameter(:x) => randn(2, 3), Parameter(:y) => randn()) for
            _ in 1:N_iters, _ in 1:N_chains
        ]
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn)

        @test size(idata.posterior.x) == (N_iters, N_chains, 2, 3)
        @test size(idata.posterior.y) == (N_iters, N_chains)

        @test parent(idata.posterior.x) == parent(chn[:x, stack=true])
    end

    @testset "stats key renaming" begin
        d = OrderedDict(
            Parameter(:x) => randn(N_iters, N_chains),
            Extra(:hamiltonian_energy) => randn(N_iters, N_chains),
            Extra(:hamiltonian_energy_error) => randn(N_iters, N_chains),
            Extra(:is_adapt) => randn(N_iters, N_chains),
            Extra(:max_hamiltonian_energy_error) => randn(N_iters, N_chains),
            Extra(:nom_step_size) => randn(N_iters, N_chains),
            Extra(:numerical_error) => randn(N_iters, N_chains),
        )
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn)

        stats_keys = keys(idata.sample_stats)
        @test :energy in stats_keys
        @test :energy_error in stats_keys
        @test :tune in stats_keys
        @test :max_energy_error in stats_keys
        @test :step_size_nom in stats_keys
        @test :diverging in stats_keys

        @test parent(idata.sample_stats.energy) == parent(chn[Extra(:hamiltonian_energy)])
        @test parent(idata.sample_stats.diverging) == parent(chn[Extra(:numerical_error)])
    end

    @testset "group=:prior" begin
        d = OrderedDict(
            Parameter(:x) => randn(N_iters, N_chains),
            Extra(:lp) => randn(N_iters, N_chains),
        )
        chn = FlexiChain{Symbol}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn; group=:prior)

        @test haskey(idata, :prior)
        @test haskey(idata, :sample_stats_prior)
        @test !haskey(idata, :posterior)
        @test !haskey(idata, :sample_stats)
    end

    @testset "VarName-keyed chain" begin
        d = [
            OrderedDict(
                Parameter(@varname(x)) => randn(),
                Parameter(@varname(y)) => randn(2),
                Extra(:lp) => randn(),
            ) for _ in 1:N_iters, _ in 1:N_chains
        ]
        chn = FlexiChain{VarName}(N_iters, N_chains, d)
        idata = InferenceObjects.convert_to_inference_data(chn)

        @test haskey(idata, :posterior)
        @test haskey(idata, :sample_stats)
        @test collect(keys(idata.posterior)) == [:x, :y]
        @test only(keys(idata.sample_stats)) == :lp

        @test parent(idata.posterior.x) == parent(chn[@varname(x)])
        @test parent(idata.posterior.y) == parent(chn[@varname(y), stack=true])
        @test parent(idata.sample_stats.lp) == parent(chn[Extra(:lp)])
    end
end

end # module
