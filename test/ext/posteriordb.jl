module FCPosteriorDBExtTests

using PosteriorDB
using DimensionalData: DimensionalData as DD
using FlexiChains: FlexiChains, FlexiChain, summarystats
using Test

@testset verbose = true "FlexiChainsPosteriorDBExt" begin
    @info "Testing ext/posteriordb.jl"

    pdb = PosteriorDB.database()

    @testset "check that all PDB refs load fine" begin
        for n in PosteriorDB.posterior_names(pdb)
            post = PosteriorDB.posterior(pdb, n)
            ref = PosteriorDB.reference_posterior(post)
            # not all posteriors have references
            if !isnothing(ref)
                @test FlexiChains.from_posteriordb_ref(ref) isa Any
            end
        end
    end

    @testset "check that the data are correct" begin
        post = PosteriorDB.posterior(pdb, "eight_schools-eight_schools_centered")
        ref = PosteriorDB.reference_posterior(post)

        chn = FlexiChains.from_posteriordb_ref(ref)
        @test chn isa FlexiChain{String}
        @test collect(FlexiChains.parameters(chn)) == [
            "theta[1]",
            "theta[2]",
            "theta[3]",
            "theta[4]",
            "theta[5]",
            "theta[6]",
            "theta[7]",
            "theta[8]",
            "mu",
            "tau",
        ]
        @test DD.parent(FlexiChains.iter_indices(chn)) == 10010:10:20000
        @test summarystats(chn) isa FlexiChains.FlexiSummary
    end
end

end # module
