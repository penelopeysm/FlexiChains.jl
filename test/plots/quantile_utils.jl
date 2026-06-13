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

@testset "binning utilities" begin
    @testset "auto_bin_edges spans the range" begin
        edges = PU.auto_bin_edges([0.0, 10.0, 5.0], 5)
        @test length(edges) == 6
        @test first(edges) == 0.0
        @test last(edges) == 10.0
    end

    @testset "auto_bin_edges degenerate + empty" begin
        edges = PU.auto_bin_edges([5.0, 5.0], 4)   # constant input
        @test length(edges) == 5
        @test first(edges) == 5.0
        @test last(edges) == 6.0
        @test_throws ArgumentError PU.auto_bin_edges(Float64[], 4)
    end

    @testset "histogram_counts interior edge is left-closed" begin
        edges = range(0.0, 10.0; length = 6)  # [0,2)[2,4)[4,6)[6,8)[8,10]
        @test PU.histogram_counts([2.0], edges) == [0, 1, 0, 0, 0]
    end

    @testset "histogram_counts" begin
        edges = range(0.0, 10.0; length = 6)  # bins: [0,2)[2,4)[4,6)[6,8)[8,10]
        counts = PU.histogram_counts([1.0, 3.0, 3.5, 9.0, 10.0], edges)
        @test counts == [1, 2, 0, 0, 2]   # 10.0 (== last edge) lands in last bin
        @test sum(counts) == 5
    end

    @testset "histogram_counts ignores out-of-range" begin
        edges = range(0.0, 10.0; length = 6)
        counts = PU.histogram_counts([-1.0, 11.0, 5.0], edges)
        @test sum(counts) == 1
    end

    @testset "bin_count_matrices preserves iter×chain shape" begin
        edges = range(0.0, 10.0; length = 6)
        comp1 = fill(1.0, 3, 2)   # all in bin 1
        comp2 = fill(9.0, 3, 2)   # all in bin 5
        mats = PU.bin_count_matrices([comp1, comp2], edges)
        @test length(mats) == 5
        @test all(==(1), mats[1])
        @test all(==(1), mats[5])
        @test all(==(0), mats[2])
        @test size(mats[1]) == (3, 2)
    end
end

end # module
