module FlexiChainsStanCSVTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra
using DimensionalData: DimensionalData as DD
using Test

# Test fixture. See test/stan/README.md for details
const STAN_BASE = joinpath(@__DIR__, "stan", "eight_schools_centred-20260405212610")
const STAN_CSV_PATHS = ["$(STAN_BASE)_$(i).csv" for i in 1:4]

@testset verbose = true "from_stan_csv" begin
    @info "Testing stancsv.jl"

    @testset "with Vector{String}" begin
        chn = FlexiChains.from_stan_csv(STAN_CSV_PATHS)
        @test chn isa FlexiChain{Symbol}
        @test size(chn) == (20, 4)

        # Check parameters (theta.1, ..., theta.8, mu, tau)
        params = Set(FlexiChains.parameters(chn))
        @test length(params) == 10
        @test :mu in params
        @test :tau in params
        for i in 1:8
            @test Symbol("theta.$i") in params
        end

        # Check extras (columns ending in __)
        exts = Set(FlexiChains.extras(chn))
        @test Extra(:lp) in exts
        @test Extra(:accept_stat) in exts
        @test Extra(:stepsize) in exts
        @test Extra(:treedepth) in exts
        @test Extra(:n_leapfrog) in exts
        @test Extra(:divergent) in exts
        @test Extra(:energy) in exts

        # Check iteration indices (save_warmup=false, thin=1, num_warmup=10, num_samples=20)
        @test parent(FlexiChains.iter_indices(chn)) == 11:1:30
        @test parent(FlexiChains.chain_indices(chn)) == 1:4
    end

    @testset "with base_path" begin
        chn = FlexiChains.from_stan_csv(STAN_BASE, 4)
        @test chn isa FlexiChain{Symbol}
        @test size(chn) == (20, 4)
    end

    @testset "with subset of chains" begin
        chn = FlexiChains.from_stan_csv(STAN_CSV_PATHS[1:2])
        @test size(chn) == (20, 2)
    end

    @testset "error handling" begin
        @test_throws ArgumentError FlexiChains.from_stan_csv(String[])
        @test_throws ArgumentError FlexiChains.from_stan_csv("nonexistent", 1)
        @test_throws ArgumentError FlexiChains.from_stan_csv(["nonexistent.csv"])
        @test_throws ArgumentError FlexiChains.from_stan_csv("nonexistent", 0)
    end
end

end # module
