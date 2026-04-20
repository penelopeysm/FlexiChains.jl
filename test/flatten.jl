module FCFlattenTests

using FlexiChains:
    FlexiChains,
    FlexiChain,
    Parameter,
    Extra,
    Wide,
    Long,
    VarName,
    @varname,
    iter_indices,
    chain_indices
using DataFrames: DataFrame, names, nrow, ncol
using DimensionalData: DimensionalData as DD, val, At
using OrderedCollections: OrderedDict
using Test

@testset verbose = true "flatten.jl" begin
    @info "Testing flatten.jl"

    @testset "Array conversion" begin
        @testset "basic test case" begin
            N_iters, N_chains = 10, 2
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => 2.0,
                Extra(:lp) => -3.0,
            )
            chain = FlexiChain{Symbol}(N_iters, N_chains, fill(d, N_iters, N_chains))

            @testset "parameters_only=true (default)" begin
                da = DD.DimArray(chain; warn = false)
                @test da isa DD.DimArray{Float64, 3}
                @test size(da) == (N_iters, N_chains, 2)
                @test val(DD.dims(da, :iter)) == val(iter_indices(chain))
                @test val(DD.dims(da, :chain)) == val(chain_indices(chain))
                @test all(x -> x == 1.0, da[:, :, At(:a)])
                @test all(x -> x == 2.0, da[:, :, At(:b)])
                param_keys = collect(val(DD.dims(da, :param)))
                @test param_keys == [:a, :b]
            end

            @testset "parameters_only=false" begin
                da_all = DD.DimArray(chain; parameters_only = false, warn = false)
                @test da_all isa DD.DimArray{Float64, 3}
                @test size(da_all) == (N_iters, N_chains, 3)
                @test val(DD.dims(da_all, :iter)) == val(iter_indices(chain))
                @test val(DD.dims(da_all, :chain)) == val(chain_indices(chain))
                @test all(x -> x == 1.0, da_all[:, :, At(Parameter(:a))])
                @test all(x -> x == 2.0, da_all[:, :, At(Parameter(:b))])
                @test all(x -> x == -3.0, da_all[:, :, At(Extra(:lp))])
                param_keys = collect(val(DD.dims(da_all, :param)))
                @test param_keys == [Parameter(:a), Parameter(:b), Extra(:lp)]
            end

            @testset "Base.Array instead of DimArray" begin
                arr = Array(chain; warn = false)
                @test arr isa Array{Float64, 3}
                @test size(arr) == (N_iters, N_chains, 2)
                @test all(x -> x == 1.0, arr[:, :, 1])
                @test all(x -> x == 2.0, arr[:, :, 2])
            end
        end

        @testset "avoid over-concretisation of eltype" begin
            N_iters, N_chains = 10, 2
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => false,
            )
            chain = FlexiChain{Symbol}(N_iters, N_chains, fill(d, N_iters, N_chains))
            da = DD.DimArray(chain; warn = false)
            @test eltype(da) == Real
            @test eltype(map(identity, da[param = 1])) == Float64
            @test eltype(map(identity, da[param = 2])) == Bool
        end

        @testset "VarName-keyed chain with array-valued param" begin
            N_iters, N_chains = 8, 1
            d = OrderedDict(
                Parameter(@varname(a)) => 1.0,
                Parameter(@varname(b)) => [2.0, 3.0],
            )
            chain = FlexiChain{VarName}(N_iters, N_chains, fill(d, N_iters))
            da = DD.DimArray(chain; warn = false)
            @test size(da) == (N_iters, N_chains, 3)
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [@varname(a), @varname(b[1]), @varname(b[2])]
        end

        @testset "eltype_filter" begin
            N_iters = 5
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => "hello",
                Extra(:lp) => -1.0,
            )
            chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))
            da = DD.DimArray(chain; eltype_filter = Float64, warn = false)
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [:a]
        end

        @testset "warns about skipped keys" begin
            N_iters = 5
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => "hello",
            )
            chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))
            @test_logs (:warn, r"skipping.*b") DD.DimArray(chain; eltype_filter = Float64)
        end

        @testset "warn=false suppresses warnings" begin
            N_iters = 5
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => "hello",
            )
            chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))
            @test_logs DD.DimArray(chain; eltype_filter = Float64, warn = false)
        end

        @testset "empty DimArray when no keys match" begin
            N_iters = 5
            d = OrderedDict(Parameter(:a) => "hello")
            chain = FlexiChain{Symbol}(N_iters, 1, fill(d, N_iters))
            da = @test_logs (:warn,) (:warn, r"no keys") DD.DimArray(
                chain; eltype_filter = Float64
            )
            @test da isa DD.DimArray{Float64, 3}
            @test size(da) == (N_iters, 1, 0)
        end

        @testset "String-keyed chain" begin
            N_iters = 5
            d = OrderedDict(
                Parameter("a") => 1.0,
                Parameter("b") => [2.0, 3.0],
            )
            chain = FlexiChain{String}(N_iters, 1, fill(d, N_iters))
            da = DD.DimArray(chain; warn = false)
            @test size(da) == (N_iters, 1, 3)
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == ["a", "b[1]", "b[2]"]
        end
    end

    @testset "Tables.jl interface" begin
        N_iters, N_chains = 10, 2
        d = OrderedDict(
            Parameter(:a) => 1.0,
            Parameter(:b) => false,
            Extra(:lp) => -3.0,
        )
        chain = FlexiChain{Symbol}(N_iters, N_chains, fill(d, N_iters, N_chains))

        @testset "Wide" begin
            @testset "default (parameters_only=true, split_varnames=true)" begin
                df = DataFrame(Wide(chain))
                @test nrow(df) == N_iters * N_chains
                @test names(df) == ["iter", "chain", "a", "b"]
                @test df.iter == repeat(1:N_iters; outer = N_chains)
                @test df.chain == repeat(1:N_chains; inner = N_iters)
                @test all(df.a .== 1.0)
                @test all(df.b .== false)
            end

            @testset "parameters_only=false" begin
                df = DataFrame(Wide(chain; parameters_only = false))
                @test names(df) == ["iter", "chain", "a", "b", "lp"]
                @test all(df.lp .== -3.0)
            end
        end

        @testset "Long" begin
            @testset "default (parameters_only=true, split_varnames=true)" begin
                df = DataFrame(Long(chain))
                @test nrow(df) == N_iters * N_chains * 2
                @test names(df) == ["iter", "chain", "param", "value"]
                @test df.param == repeat([:a, :b]; inner = N_iters * N_chains)
                @test df.iter == repeat(1:N_iters; outer = N_chains * 2)
                @test df.chain == repeat(1:N_chains; inner = N_iters, outer = 2)
                a_rows = df.param .== :a
                b_rows = df.param .== :b
                @test all(df.value[a_rows] .== 1.0)
                @test all(df.value[b_rows] .== 0.0) # promoted from false
            end

            @testset "parameters_only=false" begin
                df = DataFrame(Long(chain; parameters_only = false))
                @test nrow(df) == N_iters * N_chains * 3
                @test :lp in df.param
            end
        end

        @testset "FlexiChain directly as table source" begin
            df = DataFrame(chain)
            df_wide = DataFrame(Wide(chain))
            @test names(df) == names(df_wide)
            @test nrow(df) == nrow(df_wide)
            for col in names(df)
                @test df[!, col] == df_wide[!, col]
            end
        end

        @testset "VarName-keyed chain with array-valued param" begin
            d_vn = OrderedDict(
                Parameter(@varname(a)) => 1.0,
                Parameter(@varname(b)) => [2.0, 3.0],
            )
            vn_chain = FlexiChain{VarName}(N_iters, N_chains, fill(d_vn, N_iters, N_chains))

            @testset "Wide" begin
                df = DataFrame(Wide(vn_chain))
                @test names(df) == ["iter", "chain", "a", "b[1]", "b[2]"]
                @test all(df[!, "a"] .== 1.0)
                @test all(df[!, "b[1]"] .== 2.0)
                @test all(df[!, "b[2]"] .== 3.0)
            end

            @testset "split_varnames=false" begin
                df = DataFrame(Wide(vn_chain; split_varnames = false))
                @test names(df) == ["iter", "chain", "a", "b"]
                @test all(df[!, "a"] .== 1.0)
                @test all(x -> x == [2.0, 3.0], df[!, "b"])
            end
        end

        @testset "duplicate column names error" begin
            d_dup = OrderedDict(
                Parameter("s") => 1.0,
                Extra(:s) => 2.0,
            )
            dup_chain = FlexiChain{Any}(5, 1, fill(d_dup, 5))
            @test_throws ArgumentError Wide(dup_chain; parameters_only = false)
            @test_throws ArgumentError Long(dup_chain; parameters_only = false)
        end
    end
end

end # module
