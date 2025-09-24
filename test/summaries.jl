module FCSummariesTests

using DimensionalData: DimensionalData as DD
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
using Statistics
using Test

ENABLED_SUMMARY_FUNCS = [mean, median, minimum, maximum, std, var]

@testset verbose = true "summaries.jl" begin
    @info "Testing summaries.jl"

    @testset "FlexiChainSummaryI" begin
        @testset "constructor and getindex" begin
            N_chains = 3
            data = rand(1, N_chains)
            fcsi = FlexiChainSummaryI{VarName,100,N_chains}(
                Dict{Parameter{<:VarName},FlexiChains.SizedMatrix{1,N_chains,Float64}}(
                    Parameter(@varname(a)) => FlexiChains.SizedMatrix{1,N_chains}(data)
                ),
                FlexiChains._make_lookup(1:N_chains),
            )
            @test fcsi[Parameter(@varname(a))] == vec(data)
            @test fcsi[@varname(a)] == vec(data)
            @test fcsi[:a] == vec(data)
            @test_throws KeyError fcsi[:b]
        end

        @testset "collapse_iter" begin
            @testset "N_chains=$N_chains" for N_chains in [1, 3]
                N_iters = 10
                as = rand(N_iters, N_chains)
                bs = rand(Int, N_iters, N_chains)
                cs = rand(Bool, N_iters, N_chains)
                ds = fill("hello", N_iters, N_chains)
                chain = FlexiChain{Symbol,N_iters,N_chains}(
                    Dict(
                        Parameter(:a) => as,
                        Parameter(:b) => bs,
                        Extra(:section, "c") => cs,
                        Extra(:section, "d") => ds,
                    ),
                )
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    # via `collapse_iter`
                    function func_wrapper(x; kwargs...)
                        return func(x; dims=1, kwargs...)
                    end
                    @testset "$name" for (name, collapsed) in [
                        (
                            "via collapse_iter",
                            FlexiChains.collapse_iter(chain, func_wrapper),
                        ),
                        ("via user-facing function", func(chain; dims=:iter)),
                    ]
                        @test collapsed[:a] isa DD.DimVector
                        @test parent(parent(DD.dims(collapsed[:a], :chain))) ==
                            FlexiChains.chain_indices(chain)
                        @test isapprox(collapsed[:a], vec(func(as; dims=1)); nans=true)
                        @test isapprox(
                            collapsed[Parameter(:a)], vec(func(as; dims=1)); nans=true
                        )
                        @test isapprox(collapsed[:b], vec(func(bs; dims=1)); nans=true)
                        @test isapprox(
                            collapsed[Parameter(:b)], vec(func(bs; dims=1)); nans=true
                        )
                        @test isapprox(
                            collapsed[:section, "c"], vec(func(cs; dims=1)); nans=true
                        )
                        @test isapprox(
                            collapsed[Extra(:section, "c")],
                            vec(func(cs; dims=1));
                            nans=true,
                        )
                        @test_throws KeyError collapsed[Extra(:section, "d")]
                        @test_logs (:warn, r"non-numeric") FlexiChains.collapse(
                            chain, func; warn=true
                        )
                    end
                end
            end
        end
    end

    @testset "FlexiChainSummaryC" begin
        @testset "constructor and getindex" begin
            N_iters = 100
            data = rand(N_iters, 1)
            fcsi = FlexiChainSummaryC{VarName,N_iters,3}(
                Dict{Parameter{<:VarName},FlexiChains.SizedMatrix{N_iters,1,Float64}}(
                    Parameter(@varname(a)) => FlexiChains.SizedMatrix{N_iters,1}(data)
                ),
                FlexiChains._make_lookup(1:N_iters),
            )
            @test fcsi[Parameter(@varname(a))] == vec(data)
            @test fcsi[@varname(a)] == vec(data)
            @test fcsi[:a] == vec(data)
            @test_throws KeyError fcsi[:b]
        end

        @testset "collapse_chain" begin
            @testset "N_chains=$N_chains" for N_chains in [1, 3]
                N_iters = 10
                as = rand(N_iters, N_chains)
                bs = rand(Int, N_iters, N_chains)
                cs = rand(Bool, N_iters, N_chains)
                ds = fill("hello", N_iters, N_chains)
                chain = FlexiChain{Symbol,N_iters,N_chains}(
                    Dict(
                        Parameter(:a) => as,
                        Parameter(:b) => bs,
                        Extra(:section, "c") => cs,
                        Extra(:section, "d") => ds,
                    ),
                )
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    # via `collapse_chain`
                    function func_wrapper(x; kwargs...)
                        return func(x; dims=2, kwargs...)
                    end
                    @testset "$name" for (name, collapsed) in [
                        (
                            "via collapse_chain",
                            FlexiChains.collapse_chain(chain, func_wrapper),
                        ),
                        ("via user-facing function", func(chain; dims=:chain)),
                    ]
                        @test collapsed[:a] isa DD.DimVector
                        @test parent(parent(DD.dims(collapsed[:a], :iter))) ==
                            FlexiChains.iter_indices(chain)
                        @test isapprox(collapsed[:a], vec(func(as; dims=2)); nans=true)
                        @test isapprox(
                            collapsed[Parameter(:a)], vec(func(as; dims=2)); nans=true
                        )
                        @test isapprox(collapsed[:b], vec(func(bs; dims=2)); nans=true)
                        @test isapprox(
                            collapsed[Parameter(:b)], vec(func(bs; dims=2)); nans=true
                        )
                        @test isapprox(
                            collapsed[:section, "c"], vec(func(cs; dims=2)); nans=true
                        )
                        @test isapprox(
                            collapsed[Extra(:section, "c")],
                            vec(func(cs; dims=2));
                            nans=true,
                        )
                        @test_throws KeyError collapsed[Extra(:section, "d")]
                        @test_logs (:warn, r"non-numeric") FlexiChains.collapse(
                            chain, func; warn=true
                        )
                    end
                end
            end
        end
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

        @testset "collapse" begin
            @testset "N_chains=$N_chains" for N_chains in [1, 3]
                N_iters = 10
                as = rand(N_iters, N_chains)
                bs = rand(Int, N_iters, N_chains)
                cs = rand(Bool, N_iters, N_chains)
                ds = fill("hello", N_iters, N_chains)
                chain = FlexiChain{Symbol,N_iters,N_chains}(
                    Dict(
                        Parameter(:a) => as,
                        Parameter(:b) => bs,
                        Extra(:section, "c") => cs,
                        Extra(:section, "d") => ds,
                    ),
                )
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    @testset "$name" for (name, collapsed) in [
                        ("via collapse", FlexiChains.collapse(chain, func)),
                        ("via user-facing function", func(chain)),
                    ]
                        @test collapsed[:a] isa Number
                        @test isapprox(collapsed[:a], func(as); nans=true)
                        @test isapprox(collapsed[Parameter(:a)], func(as); nans=true)
                        @test isapprox(collapsed[:b], func(bs); nans=true)
                        @test isapprox(collapsed[Parameter(:b)], func(bs); nans=true)
                        @test isapprox(collapsed[:section, "c"], func(cs); nans=true)
                        @test isapprox(collapsed[Extra(:section, "c")], func(cs); nans=true)
                        @test_throws KeyError collapsed[Extra(:section, "d")]
                        @test_logs (:warn, r"non-numeric") FlexiChains.collapse(
                            chain, func; warn=true
                        )
                    end
                end
            end
        end
    end

    @testset "check that keyword arguments are forwarded" begin
        # We'll use `std` without Bessel correction here.
        N_iters, N_chains = 10, 3
        as = rand(N_iters, N_chains)
        chain = FlexiChain{Symbol,N_iters,N_chains}(Dict(Parameter(:a) => as))

        @testset "iter" begin
            expected = std(as; dims=1, corrected=false)
            result = std(chain; dims=:iter, corrected=false)[:a]
            @test isapprox(result, vec(expected))
        end
        @testset "chain" begin
            expected = std(as; dims=2, corrected=false)
            result = std(chain; dims=:chain, corrected=false)[:a]
            @test isapprox(result, vec(expected))
        end
        @testset "iter + chain" begin
            expected = std(chain[:a]; corrected=false)
            result = std(chain; corrected=false)[:a]
            @test isapprox(result, expected)
        end
    end
end

end # module
