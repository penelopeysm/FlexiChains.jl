module RefTests

using CairoMakie: CairoMakie, Makie
using PairPlots
using Plots
using StatsPlots
using OrderedCollections: OrderedDict
using FlexiChains: FlexiChains as FC, FlexiChain, Parameter
using StableRNGs: StableRNG
using PixelMatch
using PNGFiles
using Test

ENV["GKSwstype"] = "100"

const UPDATE_REFIMAGES = get(ENV, "UPDATE_REFIMAGES", "") == "1"
if UPDATE_REFIMAGES
    @info "Running with UPDATE_REFIMAGES=1: all reference images will be updated"
end

abstract type PlotBackend end
struct MakieBE <: PlotBackend end
struct PlotsBE <: PlotBackend end
save(::MakieBE, path, fig) = CairoMakie.save(path, fig; px_per_unit = 1, backend = CairoMakie)
save(::PlotsBE, path, fig) = Plots.savefig(fig, path)

struct RefTestSpec
    backend::PlotBackend
    name::String
    f::Function
end
function reftest(
        spec::RefTestSpec;
        update::Bool = false,
    )
    @info "running reference test for $(spec.name)"
    fig = spec.f()
    path = joinpath(@__DIR__, "images")
    mkpath(path)
    ref_path = joinpath(path, spec.name * "_ref.png")
    rec_path = joinpath(path, spec.name * "_rec.png")
    diff_path = joinpath(path, spec.name * "_diff.png")
    save(spec.backend, rec_path, fig)

    return if update
        cp(rec_path, ref_path; force = true)
        @testset "$(spec.name)" begin
            @test true
        end
    else
        @testset "$(spec.name)" begin
            file_exists = isfile(ref_path)
            if !file_exists
                println("Reference image not found for $(spec.name). Run the tests with UPDATE_REFIMAGES=1 to create it.")
                @test false
                return
            end

            img_ref = PNGFiles.load(ref_path)
            img_rec = PNGFiles.load(rec_path)

            if size(img_ref) != size(img_rec)
                println("Reference test failed for: $(spec.name)")
                println("  Reference: $ref_path")
                println("  Recorded:  $rec_path")
                println("  Size mismatch: ref=$(size(img_ref)), rec=$(size(img_rec))")
                @test false
            else
                num_pixels_diff, diff_image = PixelMatch.pixelmatch(img_ref, img_rec)
                if num_pixels_diff > 0
                    PNGFiles.save(diff_path, diff_image)
                    println("Reference test failed for: $(spec.name)")
                    println("  Reference: $ref_path")
                    println("  Recorded:  $rec_path")
                    println("  Diff:      $diff_path")
                    println("  Pixels different: $num_pixels_diff")
                end
                @test num_pixels_diff == 0
            end
        end
    end
end

function make_test_chain(rng)
    N_iters, N_chains = 100, 2
    dicts = [
        OrderedDict(
                Parameter(:a) => randn(rng),
                Parameter(:b) => randn(rng),
                Parameter(:c) => rand(rng, 1:10),
            )
            for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end
rng = StableRNG(42)
chn = make_test_chain(rng)

# --- Betancourt demo chains: analytic, structured, deterministic ---

# conn: f_grid[n] ~ N(alpha + beta * x[n], s) over an x-grid -> real linear trend
const CONN_XGRID = collect(range(-3.0, 3.0; length = 12))
function make_conn_chain(rng)
    N_iters, N_chains = 150, 2
    alpha_true, beta_true, s = 1.0, 2.0, 0.8
    dicts = [
        OrderedDict(
            Parameter(:f_grid) => [
                (alpha_true + beta_true * x) + s * randn(rng) for x in CONN_XGRID
            ],
        )
        for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end
const CONN_BASELINE = [1.0 + 2.0 * x for x in CONN_XGRID]   # true line for overlay/residual

# disc: beta[1..5] with distinct, spread means
const DISC_MEANS = [-2.0, -0.5, 0.0, 1.5, 3.0]
function make_disc_chain(rng)
    N_iters, N_chains = 150, 2
    dicts = [
        OrderedDict(
            Parameter(:beta) => [m + 0.5 * randn(rng) for m in DISC_MEANS],
        )
        for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end
const DISC_BASELINE = copy(DISC_MEANS)

# hist: predictive array y_pred[1..40], skewed shape; plus observed data
function make_hist_chain(rng)
    N_iters, N_chains = 150, 2
    dicts = [
        OrderedDict(
            Parameter(:y_pred) => [exp(0.5 * randn(rng)) for _ in 1:40],
        )
        for _ in 1:N_iters, _ in 1:N_chains
    ]
    return FlexiChain{Symbol}(N_iters, N_chains, dicts)
end
const HIST_OBSERVED = [exp(0.5 * randn(StableRNG(7))) for _ in 1:40]

rng_conn = StableRNG(101); conn_chn = make_conn_chain(rng_conn)
rng_disc = StableRNG(202); disc_chn = make_disc_chain(rng_disc)
rng_hist = StableRNG(303); hist_chn = make_hist_chain(rng_hist)

const REFTEST_SPECS = [
    # MakieExt
    RefTestSpec(MakieBE(), "mtraceplot", () -> FC.Makie.traceplot(chn)),
    RefTestSpec(MakieBE(), "mrankplot", () -> FC.Makie.rankplot(chn)),
    RefTestSpec(MakieBE(), "mrankplot_overlay", () -> FC.Makie.rankplot(chn; overlay = true)),
    RefTestSpec(MakieBE(), "mmixeddensity_float", () -> FC.Makie.mixeddensity(chn, [Parameter(:a)])),
    RefTestSpec(MakieBE(), "mmixeddensity_int", () -> FC.Makie.mixeddensity(chn, [Parameter(:c)])),
    RefTestSpec(MakieBE(), "mmeanplot", () -> FC.Makie.meanplot(chn)),
    RefTestSpec(MakieBE(), "mautocorplot", () -> FC.Makie.autocorplot(chn)),
    RefTestSpec(MakieBE(), "mautocorplot_lags", () -> FC.Makie.autocorplot(chn; lags = 1:40)),
    RefTestSpec(MakieBE(), "makie_plot", () -> Makie.plot(chn)),

    # PlotsExt
    RefTestSpec(PlotsBE(), "traceplot", () -> FC.Plots.traceplot(chn)),
    RefTestSpec(PlotsBE(), "rankplot", () -> FC.Plots.rankplot(chn)),
    RefTestSpec(PlotsBE(), "rankplot_overlay", () -> FC.Plots.rankplot(chn; overlay = true)),
    RefTestSpec(PlotsBE(), "mixeddensity_float", () -> FC.Plots.mixeddensity(chn[[Parameter(:a)]])),
    RefTestSpec(PlotsBE(), "mixeddensity_int", () -> FC.Plots.mixeddensity(chn[[Parameter(:c)]])),
    RefTestSpec(PlotsBE(), "meanplot", () -> FC.Plots.meanplot(chn)),
    RefTestSpec(PlotsBE(), "autocorplot", () -> FC.Plots.autocorplot(chn)),
    RefTestSpec(PlotsBE(), "autocorplot_lags", () -> FC.Plots.autocorplot(chn; lags = 1:40)),
    RefTestSpec(PlotsBE(), "plots_plot", () -> Plots.plot(chn)),
    RefTestSpec(PlotsBE(), "violinplot", () -> Plots.violin(chn)),
    RefTestSpec(PlotsBE(), "violinplotwbox", () -> Plots.violin(chn; with_box = true)),

    # StatsPlotsExt
    RefTestSpec(PlotsBE(), "cornerplot", () -> StatsPlots.cornerplot(chn)),

    # PairPlotsExt
    RefTestSpec(MakieBE(), "pairplot", () -> PairPlots.pairplot(chn; pool_chains = false)),
    RefTestSpec(MakieBE(), "pairplot_pooled", () -> PairPlots.pairplot(chn; pool_chains = true)),

    # Betancourt quantile plots
    RefTestSpec(MakieBE(), "connquantiles",
        () -> FC.Makie.connquantiles(conn_chn, :f_grid, CONN_XGRID; baseline = CONN_BASELINE)),
    RefTestSpec(MakieBE(), "connquantiles_residual",
        () -> FC.Makie.connquantiles(conn_chn, :f_grid, CONN_XGRID; baseline = CONN_BASELINE, residual = true)),
]

@testset verbose = true "Reference tests" begin
    for spec in REFTEST_SPECS
        reftest(spec; update = UPDATE_REFIMAGES)
    end
end

end # module
