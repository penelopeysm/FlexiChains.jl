module QuantileUtilsTests

using Test
using Statistics: Statistics
using FlexiChains: FlexiChains as FC
const PU = FC.PlotUtils

@testset "compute_quantile_bands" begin
    levels = [25, 50, 75]

    @testset "vector input = direct quantile" begin
        data = collect(1.0:100.0)
        bands = PU.compute_quantile_bands(data, levels)
        @test length(bands) == 3
        @test bands ≈ [25.75, 50.5, 75.25] atol = 1e-6
    end

    @testset "matrix input = ensemble (per-chain quantile, averaged)" begin
        col = collect(1.0:100.0)
        data = hcat(col, col)
        bands = PU.compute_quantile_bands(data, levels)
        single = PU.compute_quantile_bands(col, levels)
        @test bands ≈ single atol = 1e-9
    end

    @testset "ensemble differs from pooled when chains differ" begin
        # Distinct per-chain distributions + an asymmetric level so the ensemble
        # estimate provably differs from a naive pooled quantile.
        c1 = collect(1.0:100.0); c2 = collect(101.0:200.0)
        data = hcat(c1, c2)
        ensemble = PU.compute_quantile_bands(data, [25])
        expected = (PU.compute_quantile_bands(c1, [25]) .+ PU.compute_quantile_bands(c2, [25])) ./ 2
        pooled = Statistics.quantile(vec(data), 0.25)
        @test ensemble ≈ expected atol = 1e-9
        @test !isapprox(ensemble[1], pooled; atol = 1e-6)  # guards against pooling regression
    end

    @testset "default levels" begin
        bands = PU.compute_quantile_bands(collect(1.0:100.0))
        @test length(bands) == length(PU.DEFAULT_QUANTILE_LEVELS) == 9
    end
end

end # module
