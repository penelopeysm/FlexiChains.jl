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

    if update
        cp(rec_path, ref_path; force = true)
        @testset "$(spec.name)" begin
            @test true
        end
    else
        @testset "$(spec.name)" begin
            @test isfile(ref_path)
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
    return fig
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

const REFTEST_SPECS = [
    # MakieExt
    RefTestSpec(MakieBE(), "mtraceplot", () -> FC.mtraceplot(chn)),
    RefTestSpec(MakieBE(), "mrankplot", () -> FC.mrankplot(chn)),
    RefTestSpec(MakieBE(), "mrankplot_overlay", () -> FC.mrankplot(chn; overlay = true)),
    RefTestSpec(MakieBE(), "mmixeddensity_float", () -> FC.mmixeddensity(chn, [Parameter(:a)])),
    RefTestSpec(MakieBE(), "mmixeddensity_int", () -> FC.mmixeddensity(chn, [Parameter(:c)])),
    RefTestSpec(MakieBE(), "makie_plot", () -> Makie.plot(chn)),

    # PlotsExt
    RefTestSpec(PlotsBE(), "traceplot", () -> FC.traceplot(chn)),
    RefTestSpec(PlotsBE(), "rankplot", () -> FC.rankplot(chn)),
    RefTestSpec(PlotsBE(), "rankplot_overlay", () -> FC.rankplot(chn; overlay = true)),
    RefTestSpec(PlotsBE(), "mixeddensity_float", () -> FC.mixeddensity(chn[[Parameter(:a)]])),
    RefTestSpec(PlotsBE(), "mixeddensity_int", () -> FC.mixeddensity(chn[[Parameter(:c)]])),
    RefTestSpec(PlotsBE(), "meanplot", () -> FC.meanplot(chn)),
    RefTestSpec(PlotsBE(), "autocorplot", () -> FC.autocorplot(chn)),
    RefTestSpec(PlotsBE(), "plots_plot", () -> Plots.plot(chn)),

    # PairPlotsExt
    RefTestSpec(MakieBE(), "pairplot", () -> PairPlots.pairplot(chn; pool_chains = false)),
    RefTestSpec(MakieBE(), "pairplot_pooled", () -> PairPlots.pairplot(chn; pool_chains = true)),
]

@testset verbose = true "Reference tests" begin
    for spec in REFTEST_SPECS
        reftest(spec; update = UPDATE_REFIMAGES)
    end
end

end # module
