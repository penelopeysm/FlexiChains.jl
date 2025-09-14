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
using Statistics
using Test

ENABLED_SUMMARY_FUNCS = [mean, median, minimum, maximum, std, var]

@testset verbose = true "summaries.jl" begin
    @info "Testing summaries.jl"

    @testset "FlexiChainSummaryI" begin
        @testset "constructor and getindex" begin
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

        @testset "collapse_iter" begin
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
                # for 1 chain, the returned results should just be a scalar because
                # we are collapsing over the only non-trivial dimension
                # for 3 chains, we expect a 1xN_chains matrix
                maybe_only = N_chains == 1 ? only : identity
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    # via `collapse_iter`
                    function func_wrapper(x; kwargs...)
                        return func(x; dims=1, kwargs...)
                    end
                    collapsed = FlexiChains.collapse_iter(chain, func_wrapper)
                    @test isapprox(collapsed[:a], maybe_only(func(as; dims=1)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:a)], maybe_only(func(as; dims=1)); nans=true
                    )
                    @test isapprox(collapsed[:b], maybe_only(func(bs; dims=1)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:b)], maybe_only(func(bs; dims=1)); nans=true
                    )
                    @test isapprox(
                        collapsed[:section, "c"], maybe_only(func(cs; dims=1)); nans=true
                    )
                    @test isapprox(
                        collapsed[Extra(:section, "c")],
                        maybe_only(func(cs; dims=1));
                        nans=true,
                    )
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") FlexiChains.collapse_iter_chain(
                        chain, func; warn=true
                    )
                    # via user-facing function
                    collapsed = func(chain; dims=:iter)
                    @test isapprox(collapsed[:a], maybe_only(func(as; dims=1)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:a)], maybe_only(func(as; dims=1)); nans=true
                    )
                    @test isapprox(collapsed[:b], maybe_only(func(bs; dims=1)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:b)], maybe_only(func(bs; dims=1)); nans=true
                    )
                    @test isapprox(
                        collapsed[:section, "c"], maybe_only(func(cs; dims=1)); nans=true
                    )
                    @test isapprox(
                        collapsed[Extra(:section, "c")],
                        maybe_only(func(cs; dims=1));
                        nans=true,
                    )
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") func(chain; dims=:iter, warn=true)
                end
            end
        end
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

        @testset "collapse_chain" begin
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
                # for 1 chain, the returned results should just be a vector because
                # the chain dimension isn't represented in the output.
                # for 3 chains, we expect a Nx1 matrix
                maybe_vec = N_chains == 1 ? vec : identity
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    # via `collapse_chain`
                    function func_wrapper(x; kwargs...)
                        return func(x; dims=2, kwargs...)
                    end
                    collapsed = FlexiChains.collapse_chain(chain, func_wrapper)
                    @test isapprox(collapsed[:a], maybe_vec(func(as; dims=2)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:a)], maybe_vec(func(as; dims=2)); nans=true
                    )
                    @test isapprox(collapsed[:b], maybe_vec(func(bs; dims=2)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:b)], maybe_vec(func(bs; dims=2)); nans=true
                    )
                    @test isapprox(
                        collapsed[:section, "c"], maybe_vec(func(cs; dims=2)); nans=true
                    )
                    @test isapprox(
                        collapsed[Extra(:section, "c")],
                        maybe_vec(func(cs; dims=2));
                        nans=true,
                    )
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") FlexiChains.collapse_iter_chain(
                        chain, func; warn=true
                    )
                    # via user-facing function
                    collapsed = func(chain; dims=:chain)
                    @test isapprox(collapsed[:a], maybe_vec(func(as; dims=2)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:a)], maybe_vec(func(as; dims=2)); nans=true
                    )
                    @test isapprox(collapsed[:b], maybe_vec(func(bs; dims=2)); nans=true)
                    @test isapprox(
                        collapsed[Parameter(:b)], maybe_vec(func(bs; dims=2)); nans=true
                    )
                    @test isapprox(
                        collapsed[:section, "c"], maybe_vec(func(cs; dims=2)); nans=true
                    )
                    @test isapprox(
                        collapsed[Extra(:section, "c")],
                        maybe_vec(func(cs; dims=2));
                        nans=true,
                    )
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") func(chain; dims=:chain, warn=true)
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

        @testset "collapse_iter_chain" begin
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
                @testset "$func" for func in ENABLED_SUMMARY_FUNCS
                    # via `collapse_iter_chain`
                    collapsed = FlexiChains.collapse_iter_chain(chain, func)
                    @test isapprox(collapsed[:a], func(as); nans=true)
                    @test isapprox(collapsed[Parameter(:a)], func(as); nans=true)
                    @test isapprox(collapsed[:b], func(bs); nans=true)
                    @test isapprox(collapsed[Parameter(:b)], func(bs); nans=true)
                    @test isapprox(collapsed[:section, "c"], func(cs); nans=true)
                    @test isapprox(collapsed[Extra(:section, "c")], func(cs); nans=true)
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") FlexiChains.collapse_iter_chain(
                        chain, func; warn=true
                    )
                    # via user-facing function
                    collapsed = func(chain)
                    @test isapprox(collapsed[:a], func(as); nans=true)
                    @test isapprox(collapsed[Parameter(:a)], func(as); nans=true)
                    @test isapprox(collapsed[:b], func(bs); nans=true)
                    @test isapprox(collapsed[Parameter(:b)], func(bs); nans=true)
                    @test isapprox(collapsed[:section, "c"], func(cs); nans=true)
                    @test isapprox(collapsed[Extra(:section, "c")], func(cs); nans=true)
                    @test_throws KeyError collapsed[Extra(:section, "d")]
                    @test_logs (:warn, r"non-numeric") func(chain; warn=true)
                end
            end
        end
    end

    @testset "check that keyword arguments are forwarded" begin
        # We'll use `std` without Bessel correction here.
        N_iters, N_chains = 10, 3
        as = rand(N_iters, N_chains)
        chain = FlexiChain{Symbol}(Dict(Parameter(:a) => as))

        @testset "iter" begin
            expected = std(as; dims=1, corrected=false)
            result = std(chain; dims=:iter, corrected=false)[:a]
            @test isapprox(result, expected)
        end
        @testset "chain" begin
            expected = std(as; dims=2, corrected=false)
            result = std(chain; dims=:chain, corrected=false)[:a]
            @test isapprox(result, expected)
        end
        @testset "iter + chain" begin
            expected = std(chain[:a]; corrected=false)
            result = std(chain; corrected=false)[:a]
            @test isapprox(result, expected)
        end
    end
end

end # module
