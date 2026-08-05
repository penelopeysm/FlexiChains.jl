module FlexiChainsMonteCarloMeasurementsExtTests

using FlexiChains: FlexiChain, VarName, Parameter, @varname
using LinearAlgebra: Diagonal
using OrderedCollections: OrderedDict
using MonteCarloMeasurements: Particles, pmean
using Statistics: mean

@testset verbose = true "MonteCarloMeasurements extension" begin
    @info "Testing MonteCarloMeasurements extension"

    @testset "VNChain" begin
        N_iters, N_chains = 100, 2
        N = N_iters * N_chains
        d = OrderedDict(
            Parameter(@varname(a)) => randn(N_iters, N_chains),
            Parameter(@varname(b)) => rand(1:10, N_iters, N_chains),
            Parameter(@varname(c)) => [randn(2) for _ in 1:N_iters, _ in 1:N_chains],
        )
        chain = FlexiChain{VarName}(N_iters, N_chains, d)

        @testset "to OrderedDict" begin
            p = Particles(chain)
            @test p isa OrderedDict{<:VarName}
            @test p[@varname(a)] isa Particles{Float64,N}
            @test p[@varname(b)] isa Particles{Int,N}
            @test p[@varname(c)] isa Vector{Particles{Float64,N}}
            @test length(p[@varname(c)]) == 2

            @test pmean(p[@varname(a)]) ≈ mean(chain[@varname(a)])
            @test pmean(p[@varname(b)]) ≈ mean(chain[@varname(b)])
            @test pmean(p[@varname(c)]) ≈ mean(chain[@varname(c)])
        end

        @testset "to Dict" begin
            p = Particles(chain, Dict)
            @test p isa Dict{<:VarName}
            @test p[@varname(a)] isa Particles{Float64,N}
            @test p[@varname(b)] isa Particles{Int,N}
            @test p[@varname(c)] isa Vector{Particles{Float64,N}}
            @test length(p[@varname(c)]) == 2

            @test pmean(p[@varname(a)]) ≈ mean(chain[@varname(a)])
            @test pmean(p[@varname(b)]) ≈ mean(chain[@varname(b)])
            @test pmean(p[@varname(c)]) ≈ mean(chain[@varname(c)])
        end

        @testset "to NamedTuple" begin
            p = Particles(chain, NamedTuple)
            @test p isa NamedTuple
            @test p.a isa Particles{Float64,N}
            @test p.b isa Particles{Int,N}
            @test p.c isa Vector{Particles{Float64,N}}
            @test length(p.c) == 2

            @test pmean(p.a) ≈ mean(chain[@varname(a)])
            @test pmean(p.b) ≈ mean(chain[@varname(b)])
            @test pmean(p.c) ≈ mean(chain[@varname(c)])
        end
    end

    @testset "SymChain" begin
        N_iters, N_chains = 100, 2
        N = N_iters * N_chains
        d = OrderedDict(
            Parameter(:a) => randn(N_iters, N_chains),
            Parameter(:b) => rand(1:10, N_iters, N_chains),
            Parameter(:c) => [randn(2) for _ in 1:N_iters, _ in 1:N_chains],
        )
        chain = FlexiChain{Symbol}(N_iters, N_chains, d)

        @testset "to OrderedDict" begin
            p = Particles(chain)
            @test p isa OrderedDict{Symbol}
            @test p[:a] isa Particles{Float64,N}
            @test p[:b] isa Particles{Int,N}
            @test p[:c] isa Vector{Particles{Float64,N}}
            @test length(p[:c]) == 2

            @test pmean(p[:a]) ≈ mean(chain[:a])
            @test pmean(p[:b]) ≈ mean(chain[:b])
            @test pmean(p[:c]) ≈ mean(chain[:c])
        end

        @testset "to NamedTuple" begin
            p = Particles(chain, NamedTuple)
            @test p isa NamedTuple
            @test p.a isa Particles{Float64,N}
            @test p.b isa Particles{Int,N}
            @test p.c isa Vector{Particles{Float64,N}}
            @test length(p.c) == 2

            @test pmean(p.a) ≈ mean(chain[:a])
            @test pmean(p.b) ≈ mean(chain[:b])
            @test pmean(p.c) ≈ mean(chain[:c])
        end
    end

    @testset "different parameter shapes" begin
        N_iters, N_chains = 100, 2
        N = N_iters * N_chains
        d = Dict(
            # multidimensional array
            Parameter(@varname(mat)) =>
                [randn(3, 4) for _ in 1:N_iters, _ in 1:N_chains],
            # namedtuple
            Parameter(@varname(nt)) =>
                [(a=randn(), b=randn(2)) for _ in 1:N_iters, _ in 1:N_chains],
        )
        chain = FlexiChain{VarName}(N_iters, N_chains, d)

        p = Particles(chain)

        @test p[@varname(mat)] isa Matrix{Particles{Float64,N}}
        @test size(p[@varname(mat)]) == (3, 4)
        @test map(pmean, p[@varname(mat)]) ≈ mean(chain[@varname(mat)])

        @test p[@varname(nt)] isa NamedTuple
        @test keys(p[@varname(nt)]) == (:a, :b)
        @test p[@varname(nt)].a isa Particles{Float64,N}
        @test p[@varname(nt)].b isa Vector{Particles{Float64,N}}
        @test length(p[@varname(nt)].b) == 2
        @test pmean(p[@varname(nt)].a) ≈ mean(getfield.(chain[@varname(nt)], :a))
        @test pmean(p[@varname(nt)].b) ≈ mean(getfield.(chain[@varname(nt)], :b))
    end
end

end # module
