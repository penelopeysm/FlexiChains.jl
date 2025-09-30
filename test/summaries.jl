module FCSummariesTests

using DimensionalData: DimensionalData as DD
using FlexiChains:
    FlexiChains, FlexiChain, Parameter, ParameterOrExtra, Extra, VarName, @varname
using Statistics
using Test

const ENABLED_SUMMARY_FUNCS = [mean, median, minimum, maximum, std, var, sum, prod]
const WORKS_ON_STRING = [minimum, maximum, prod]

@testset verbose = true "summaries.jl" begin
    @info "Testing summaries.jl"

    N_iters, N_chains = 10, 3
    as = rand(N_iters, N_chains)
    bs = rand(1:100, N_iters, N_chains)
    cs = rand(Bool, N_iters, N_chains)
    ds = fill("hello", N_iters, N_chains)
    chain = FlexiChain{Symbol,N_iters,N_chains}(
        Dict(
            Parameter(:a) => as,
            Parameter(:b) => bs,
            Extra(:section, "c") => cs,
            Extra(:section, "actuallyString") => ds,
        );
        iter_indices=FlexiChains._make_lookup(4:4:(4 * N_iters)),
        chain_indices=FlexiChains._make_lookup(1:N_chains),
    )

    @testset "collapse" begin
        @testset for func in ENABLED_SUMMARY_FUNCS
            @testset "dims=:iter" begin
                name_and_func = (Symbol(func), x -> func(x; dims=1))
                fs = FlexiChains.collapse(chain, [name_and_func]; dims=:iter)
                @test fs[:a] isa DD.DimMatrix
                @test parent(parent(DD.dims(fs[:a], :chain))) ==
                    FlexiChains.chain_indices(chain) ==
                    FlexiChains.chain_indices(fs)
                @test parent(parent(DD.dims(fs[:a], :stat))) == [Symbol(func)]
                @test isapprox(fs[:a], vec(func(as; dims=1)); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = reshape(func(ds; dims=1), N_chains, 1)
                    @test fs[Extra(:section, "actuallyString")] == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [name_and_func]; dims=:iter
                    )
                end
            end

            @testset "dims=:chain" begin
                name_and_func = (Symbol(func), x -> func(x; dims=2))
                fs = FlexiChains.collapse(chain, [name_and_func]; dims=:chain)
                @test fs[:a] isa DD.DimMatrix
                @test parent(parent(DD.dims(fs[:a], :iter))) ==
                    FlexiChains.iter_indices(chain) ==
                    FlexiChains.iter_indices(fs)
                @test parent(parent(DD.dims(fs[:a], :stat))) == [Symbol(func)]
                @test isapprox(fs[:a], vec(func(as; dims=2)); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = reshape(func(ds; dims=2), N_iters, 1)
                    @test fs[Extra(:section, "actuallyString")] == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [name_and_func]; dims=:chain
                    )
                end
            end

            @testset "dims=:both" begin
                fs = FlexiChains.collapse(chain, [func]; dims=:both)
                @test fs[:a] isa DD.DimVector
                @test parent(parent(DD.dims(fs[:a], :stat))) == [Symbol(func)]
                @test isapprox(only(fs[:a]), func(as); nans=true)

                if func in WORKS_ON_STRING
                    # the 1 dim at the end is the stat dim
                    expected = func(ds)
                    @test only(fs[Extra(:section, "actuallyString")]) == expected
                else
                    # the key "actuallyString" should be skipped
                    @test_logs (:warn, r"\"actuallyString\"") FlexiChains.collapse(
                        chain, [func]; dims=:both
                    )
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
            @test isapprox(only(result), expected)
        end
    end

    @testset "getindex on summaries" begin
        N_iters, N_chains = 10, 3
        xs = Matrix{Vector{Float64}}(undef, N_iters, N_chains)
        for i in 1:N_iters, j in 1:N_chains
            xs[i, j] = rand(10)
        end
        chain = FlexiChain{VarName,N_iters,N_chains}(Dict(Parameter(@varname(x)) => xs))
        # We'll just test `mean` on `:iter`, because we're only testing the behaviour of
        # getindex (so we don't have to worry about other functions or other collapsed
        # dimensions).
        fs = mean(chain; dims=:iter)

        @testset "VarName" begin
            @test fs[@varname(x)] isa DD.DimMatrix
            @test parent(parent(DD.dims(fs[@varname(x)], :chain))) ==
                FlexiChains.chain_indices(chain) ==
                FlexiChains.chain_indices(fs)
            @test parent(parent(DD.dims(fs[@varname(x)], :stat))) == [:mean]
            @test isapprox(
                dropdims(fs[@varname(x)]; dims=:stat), dropdims(mean(xs; dims=1); dims=1)
            )
        end

        @testset "Symbol" begin
            @test fs[:x] isa DD.DimMatrix
            @test parent(parent(DD.dims(fs[:x], :chain))) ==
                FlexiChains.chain_indices(chain) ==
                FlexiChains.chain_indices(fs)
            @test parent(parent(DD.dims(fs[:x], :stat))) == [:mean]
            @test isapprox(dropdims(fs[:x]; dims=:stat), dropdims(mean(xs; dims=1); dims=1))
        end

        @testset "sub-VarName" begin
            @test fs[@varname(x[1])] isa DD.DimMatrix
            @test parent(parent(DD.dims(fs[@varname(x[1])], :chain))) ==
                FlexiChains.chain_indices(chain) ==
                FlexiChains.chain_indices(fs)
            @test parent(parent(DD.dims(fs[@varname(x[1])], :stat))) == [:mean]
            @test isapprox(
                dropdims(fs[@varname(x[1])]; dims=:stat),
                dropdims(mean(getindex.(xs, 1); dims=1); dims=1),
            )
        end

        @testset "nonexistent VarName" begin
            @test_throws KeyError fs[@varname(y)]
            @test_throws Exception fs[@varname(x.a)]
        end
    end
end

end # module
