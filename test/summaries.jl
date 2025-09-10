module FCSummariesTests

using FlexiChains:
    FlexiChains,
    FlexiChain,
    FlexiChainSummaryI,
    FlexiChainSummaryC,
    FlexiChainSummaryIC,
    Parameter,
    ParameterOrExtra,
    Extra,
    VarName,
    @varname
using Test

@testset verbose = true "summaries.jl" begin
    @info "Testing summaries.jl"

    @testset "FlexiChainSummaryI" begin
        data = rand(1, 3)
        fcsi = FlexiChainSummaryI{VarName,100,3}(
            Dict{Parameter{<:VarName},FlexiChains.SizedMatrix{1,3,Float64}}(
                Parameter(@varname(a)) => FlexiChains.SizedMatrix{1,3}(data)
            ),
        )
        @test fcsi[Parameter(@varname(a))] == data
        @test fcsi[@varname(a)] == data
        @test fcsi[:a] == data
        @test_throws KeyError fcsi[:b]
    end

    @testset "FlexiChainSummaryC" begin
        data = rand(100, 1)
        fcsi = FlexiChainSummaryC{VarName,100,3}(
            Dict{Parameter{<:VarName},FlexiChains.SizedMatrix{100,1,Float64}}(
                Parameter(@varname(a)) => FlexiChains.SizedMatrix{100,1}(data)
            ),
        )
        @test fcsi[Parameter(@varname(a))] == data
        @test fcsi[@varname(a)] == data
        @test fcsi[:a] == data
        @test_throws KeyError fcsi[:b]
    end

    @testset "FlexiChainSummaryIC" begin
        @testset "constructor and getindex" begin
            data = rand(1, 1)
            fcsi = FlexiChainSummaryIC{VarName,100,3}(
                Dict{Parameter{<:VarName},FlexiChains.SizedMatrix{1,1,Float64}}(
                    Parameter(@varname(a)) => FlexiChains.SizedMatrix{1,1}(data)
                ),
            )
            @test fcsi[Parameter(@varname(a))] == only(data)
            @test fcsi[@varname(a)] == only(data)
            @test fcsi[:a] == only(data)
            @test_throws KeyError fcsi[:b]
        end

        @testset "_collapse_ic" begin
            @testset "N_chains=$N_chains" for N_chains in [1, 3]
                N_iters = 10
                as = rand(N_iters, N_chains)
                bs = rand(Int, N_iters, N_chains)
                cs = rand(Bool, N_iters, N_chains)
                ds = fill("hello", N_iters, N_chains)
                chain = FlexiChain{Symbol}(
                    Dict(
                        Parameter(:a) => as,
                        Parameter(:b) => bs,
                        Extra(:section, "c") => cs,
                        Extra(:section, "d") => ds,
                    ),
                )
                collapsed = FlexiChains._collapse_ic(chain, mean)
                @test collapsed[:a] == mean(as)
                @test collapsed[Parameter(:a)] == mean(as)
                @test collapsed[:b] == mean(bs)
                @test collapsed[Parameter(:b)] == mean(bs)
                @test collapsed[:section, "c"] == mean(cs)
                @test collapsed[Extra(:section, "c")] == mean(cs)
                @test_throws KeyError collapsed[Extra(:section, "d")]
            end
        end
    end
end

end # module
