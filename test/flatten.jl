module FCFlattenTests

using FlexiChains:
    FlexiChains,
    FlexiChain,
    Parameter,
    Extra,
    VarName,
    @varname,
    iter_indices,
    chain_indices
using DimensionalData: DimensionalData as DD, val, At
using OrderedCollections: OrderedDict
using Test

@testset verbose = true "flatten.jl" begin
    @info "Testing flatten.jl"

    @testset "DimArray conversion" begin
        @testset "Symbol-keyed chain with scalar params" begin
            N_iters, N_chains = 10, 2
            d = OrderedDict(
                Parameter(:a) => 1.0,
                Parameter(:b) => 2.0,
                Extra(:lp) => -3.0,
            )
            chain = FlexiChain{Symbol}(N_iters, N_chains, fill(d, N_iters, N_chains))

            # test that parameters_only=true by default
            da = DD.DimArray(chain; warn = false)
            @test da isa DD.DimArray{Float64, 3}
            @test size(da) == (N_iters, N_chains, 2)
            @test val(DD.dims(da, :iter)) == val(iter_indices(chain))
            @test val(DD.dims(da, :chain)) == val(chain_indices(chain))
            @test all(x -> x == 1.0, da[:, :, At(:a)])
            @test all(x -> x == 2.0, da[:, :, At(:b)])
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [:a, :b]

            # test parameters_only=false
            da_all = DD.DimArray(chain; parameters_only = false, warn = false)
            @test da isa DD.DimArray{Float64, 3}
            @test size(da_all) == (N_iters, N_chains, 3)
            @test val(DD.dims(da_all, :iter)) == val(iter_indices(chain))
            @test val(DD.dims(da_all, :chain)) == val(chain_indices(chain))
            @test all(x -> x == 1.0, da_all[:, :, At(Parameter(:a))])
            @test all(x -> x == 2.0, da_all[:, :, At(Parameter(:b))])
            @test all(x -> x == -3.0, da_all[:, :, At(Extra(:lp))])
            param_keys = collect(val(DD.dims(da_all, :param)))
            @test param_keys == [Parameter(:a), Parameter(:b), Extra(:lp)]
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
end

end # module
