module FCVarNameTests

using FlexiChains:
    FlexiChains,
    FlexiChain,
    FlexiSummary,
    Parameter,
    Extra,
    VarName,
    @varname,
    Prefixed
using AbstractPPL: Iden, @opticof
using DimensionalData: DimensionalData as DD
using OrderedCollections: OrderedDict
using Statistics: mean
using Test

@testset verbose = true "varname.jl" begin
    @info "Testing varname.jl"

    @testset "Prefixed" begin
        @testset "construction" begin
            for vn in (@varname(x), @varname(x[1]), @varname(x.a))
                p = Prefixed(vn)
                @test p.target_vn == vn
            end
            # construction from Symbol
            @test Prefixed(:y) == Prefixed(@varname(y))
        end

        @testset "show" begin
            @test sprint(show, Prefixed(@varname(x))) == "Prefixed(x)"
            @test sprint(show, Prefixed(:y)) == "Prefixed(y)"
            @test sprint(show, Prefixed(@varname(x[1]))) == "Prefixed(x[1])"
            @test sprint(show, Prefixed(@varname(x.a))) == "Prefixed(x.a)"
        end
    end

    @testset "shares_tail" begin
        st = FlexiChains.shares_tail

        @testset "exact match (no prefix)" begin
            @test st(@varname(x), @varname(x))
            @test !st(@varname(x), @varname(y))
        end

        @testset "single prefix" begin
            @test st(@varname(a.x), @varname(x))
            @test !st(@varname(a.x), @varname(y))
        end

        @testset "multiple prefixes" begin
            @test st(@varname(a.b.c), @varname(c))
            @test st(@varname(a.b.c), @varname(b.c))
            @test st(@varname(a.b.c), @varname(a.b.c))
            @test !st(@varname(a.b.c), @varname(d))
        end

        @testset "target longer than vn" begin
            @test !st(@varname(x), @varname(a.x))
            @test !st(@varname(b.c), @varname(a.b.c))
        end

        @testset "with indexing optics" begin
            @test st(@varname(a.x[1]), @varname(x[1]))
            @test !st(@varname(a.x[1]), @varname(x))
            @test !st(@varname(a.x[1]), @varname(x[2]))
        end
    end

    @testset "prefixed_get_key_and_optic" begin
        pgko = FlexiChains.prefixed_get_key_and_optic

        @testset "simple match with prefix" begin
            vns = Set([@varname(a.x), @varname(a.y), @varname(b)])
            k, o = pgko(vns, Prefixed(@varname(x)))
            @test k == @varname(a.x)
            @test o == Iden()
        end

        @testset "exact match (no prefix)" begin
            vns = Set([@varname(a.x), @varname(b)])
            k, o = pgko(vns, Prefixed(@varname(b)))
            @test k == @varname(b)
            @test o == Iden()
        end

        @testset "no match throws KeyError" begin
            vns = Set([@varname(a.x), @varname(b)])
            @test_throws KeyError pgko(vns, Prefixed(@varname(z)))
        end

        @testset "multiple matches throws ArgumentError" begin
            vns = Set([@varname(a.x), @varname(b.x)])
            @test_throws ArgumentError pgko(vns, Prefixed(@varname(x)))
        end

        @testset "optic stripping" begin
            # Prefixed(@varname(x.b)) with chain containing @varname(a.x)
            # should find @varname(a.x) with .b optic
            vns = Set([@varname(a.x)])
            k, o = pgko(vns, Prefixed(@varname(x.b)))
            @test k == @varname(a.x)
            @test o == @opticof(_.b)

            k, o = pgko(vns, Prefixed(@varname(x[1])))
            @test k == @varname(a.x)
            @test o == @opticof(_[1])
        end

        @testset "optic stripping, no match after full strip" begin
            vns = Set([@varname(a.y)])
            @test_throws KeyError pgko(vns, Prefixed(@varname(x.b)))
        end
    end

    @testset "getindex with Prefixed" begin
        N_iters, N_chains = 5, 2

        @testset "FlexiChain" begin
            d = Dict(
                Parameter(@varname(a.x)) => 1.0,
                Parameter(@varname(a.y)) => [2.0, 3.0],
                Parameter(@varname(b)) => 10.0,
                Parameter(@varname(m.p)) => (; q = 20.0),
            )
            chain = FlexiChain{VarName}(N_iters, N_chains, fill(d, N_iters, N_chains))

            @testset "simple prefix match" begin
                result = chain[Prefixed(:x)]
                @test result isa DD.DimMatrix
                @test all(==(1.0), result)
                @test size(result) == (N_iters, N_chains)
            end

            @testset "no prefix needed" begin
                result = chain[Prefixed(:b)]
                @test result isa DD.DimMatrix
                @test all(==(10.0), result)
            end

            @testset "array-valued parameter" begin
                result = chain[Prefixed(:y)]
                @test result isa DD.DimMatrix
                @test all(==([2.0, 3.0]), result)
            end

            @testset "optic stripping into array" begin
                result = chain[Prefixed(@varname(y[1]))]
                @test result isa DD.DimMatrix
                @test all(==(2.0), result)
            end

            @testset "with iter/chain kwargs" begin
                result = chain[Prefixed(:x), iter = 1:2]
                @test size(result) == (2, N_chains)
                result2 = chain[Prefixed(:x), chain = 1]
                @test size(result2) == (N_iters,)
            end

            @testset "with suboptic" begin
                result = chain[Prefixed(@varname(p.q))]
                @test result isa DD.DimMatrix
                @test all(==(20.0), result)
            end

            @testset "no match" begin
                @test_throws KeyError chain[Prefixed(:z)]
            end

            @testset "multiple matches" begin
                d2 = Dict(
                    Parameter(@varname(a.x)) => 1.0,
                    Parameter(@varname(b.x)) => 2.0,
                )
                chain2 = FlexiChain{VarName}(N_iters, 1, fill(d2, N_iters))
                @test_throws ArgumentError chain2[Prefixed(:x)]
            end
        end

        @testset "FlexiSummary" begin
            d = Dict(
                Parameter(@varname(a.x)) => 1.0,
                Parameter(@varname(a.y)) => 2.0,
                Parameter(@varname(b)) => 10.0,
            )
            chain = FlexiChain{VarName}(N_iters, N_chains, fill(d, N_iters, N_chains))
            fs = FlexiChains.collapse(chain, [mean]; dims = :iter)

            @testset "simple prefix match" begin
                result = fs[Prefixed(:x)]
                @test all(==(1.0), result)
            end

            @testset "no prefix needed" begin
                result = fs[Prefixed(:b)]
                @test all(==(10.0), result)
            end

            @testset "no match" begin
                @test_throws KeyError fs[Prefixed(:z)]
            end
        end
    end
end

end # module
