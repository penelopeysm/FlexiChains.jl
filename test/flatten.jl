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
            da = DD.DimArray(chain; warn = false)
            @test da isa DD.DimArray
            @test size(da) == (N_iters, N_chains, 3)
            @test val(DD.dims(da, :iter)) == val(iter_indices(chain))
            @test val(DD.dims(da, :chain)) == val(chain_indices(chain))
            @test all(x -> x == 1.0, da[:, :, At(Parameter(:a))])
            @test all(x -> x == 2.0, da[:, :, At(Parameter(:b))])
            @test all(x -> x == -3.0, da[:, :, At(Extra(:lp))])
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [Parameter(:a), Parameter(:b), Extra(:lp)]
        end

        @testset "VarName-keyed chain with array-valued param" begin
            N_iters, N_chains = 8, 1
            d = OrderedDict(
                Parameter(@varname(a)) => 1.0,
                Parameter(@varname(b)) => [2.0, 3.0],
                Extra(:lp) => -1.0,
            )
            chain = FlexiChain{VarName}(N_iters, N_chains, fill(d, N_iters))
            da = DD.DimArray(chain; warn = false)
            @test size(da) == (N_iters, N_chains, 4)
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [
                Parameter(@varname(a)),
                Parameter(@varname(b[1])),
                Parameter(@varname(b[2])),
                Extra(:lp),
            ]
        end

        @testset "parameters_only=true" begin
            N_iters, N_chains = 6, 2
            d = OrderedDict(
                Parameter(:x) => 1.0,
                Parameter(:y) => 2.0,
                Extra(:lp) => -5.0,
            )
            chain = FlexiChain{Symbol}(N_iters, N_chains, fill(d, N_iters, N_chains))
            da = DD.DimArray(chain; parameters_only = true, warn = false)
            @test size(da) == (N_iters, N_chains, 2)
            param_keys = collect(val(DD.dims(da, :param)))
            @test param_keys == [:x, :y]
            @test all(x -> x == 1.0, da[:, :, At(:x)])
            @test all(x -> x == 2.0, da[:, :, At(:y)])
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
            @test param_keys == [Parameter(:a), Extra(:lp)]
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
            @test param_keys == [Parameter("a"), Parameter("b[1]"), Parameter("b[2]")]
        end
    end
end

end # module
