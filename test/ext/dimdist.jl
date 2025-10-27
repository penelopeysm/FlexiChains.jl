module FlexiChainsDimensionalDistributionsTests

# Because DimensionalDistributions isn't yet registered, we need to manually add it as a dep
# (instead of using [sources] in Project.toml, since that fails on 1.10).
using Pkg
Pkg.add(; url="https://github.com/sethaxen/DimensionalDistributions.jl")

using DimensionalData: DimensionalData as DD
using FlexiChains
using Turing
using DimensionalDistributions: withdims
using Test

@testset "Sampling from DimensionalDistribution" begin
    schools = [
        "Choate",
        "Deerfield",
        "Phillips Andover",
        "Phillips Exeter",
        "Hotchkiss",
        "Lawrenceville",
        "St. Paul's",
        "Mt. Hermon",
    ]

    school_dim = DD.Dim{:school}(schools)
    y = DD.DimArray([28.0, 8.0, -3.0, 7.0, -1.0, 1.0, 18.0, 12.0], school_dim)
    σ = DD.DimArray([15.0, 10.0, 16.0, 11.0, 9.0, 11.0, 10.0, 18.0], school_dim)

    @model function noncentered_eight(σ; dim=only(DD.dims(σ)), n=length(σ))
        μ ~ Normal(0, 5)
        τ ~ truncated(Cauchy(0, 5); lower=0)
        θ_tilde ~ withdims(filldist(Normal(), n), dim)
        θ := @. μ + τ * θ_tilde
        return y ~ withdims(arraydist(Normal.(θ, σ)), dim)
    end

    chn = sample(
        noncentered_eight(σ),
        NUTS(),
        MCMCThreads(),
        1000,
        3;
        chain_type=VNChain,
        progress=false,
        verbose=false,
    )

    @testset "indexing" begin
        thetas = chn[@varname(θ)]
        @test thetas isa DD.DimArray{Float64,3}
        @test parent(DD.val(DD.dims(thetas), :iter)) == FlexiChains.iter_indices(chn)
        @test parent(DD.val(DD.dims(thetas), :chain)) == FlexiChains.chain_indices(chn)
        @test last(DD.dims(thetas)) == school_dim
    end

    @testset "summarising" begin
        mean_theta = mean(chn; split_varnames=false)[@varname(θ)]
        @test mean_theta isa DD.DimVector{Float64}
        @test only(DD.dims(mean_theta)) == school_dim

        mean_theta = mean(chn; dims=:iter, split_varnames=false)[@varname(θ)]
        @test mean_theta isa DD.DimMatrix{Float64}
        @test parent(DD.val(DD.dims(mean_theta), :chain)) == FlexiChains.chain_indices(chn)
        @test last(DD.dims(mean_theta)) == school_dim

        mean_theta = mean(chn; dims=:chain, split_varnames=false)[@varname(θ)]
        @test mean_theta isa DD.DimMatrix{Float64}
        @test parent(DD.val(DD.dims(mean_theta), :iter)) == FlexiChains.iter_indices(chn)
        @test last(DD.dims(mean_theta)) == school_dim

        ss = summarystats(chn; split_varnames=false)
        mean_theta = ss[@varname(θ), stat=DD.At(:mean)]
        @test mean_theta isa DD.DimVector{Float64}
        @test only(DD.dims(mean_theta)) == school_dim

        @testset "multiple stats at once" begin
            # This is currently broken, see
            # https://github.com/penelopeysm/FlexiChains.jl/issues/79
            #
            # mean_and_std_theta = ss[@varname(θ), stat=DD.At(:mean, :std)]
            # @test mean_and_std_theta isa DD.DimMatrix{Float64}
            # @test parent(DD.val(DD.dims(mean_theta), :stat)) == FlexiChains.stat_indices(ss)
            # @test last(DD.dims(mean_and_std_theta)) == school_dim
        end
    end
end

end
