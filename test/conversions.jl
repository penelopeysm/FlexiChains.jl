module FlexiChainsConversionsTests

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra
using AbstractPPL: @varname, VarName
using AbstractMCMC
using DimensionalData: At
using Test

@testset "to_nt_and_stats" begin
    struct M <: AbstractMCMC.AbstractModel end
    struct S <: AbstractMCMC.AbstractSampler end
    struct T end
    function AbstractMCMC.step(rng, ::M, ::S, state = nothing; kwargs...)
        T(), nothing
    end
    FlexiChains.to_nt_and_stats(::T) = ((; hello = 1.0), (; world = 2.0))

    niters = 10
    chn = sample(M(), S(), niters; chain_type = FlexiChain{Symbol})
    @test chn isa FlexiChain{Symbol}
    @test Set(FlexiChains.parameters(chn)) == Set([:hello])
    @test Set(keys(chn)) == Set([Parameter(:hello), Extra(:world)])
    @test chn[:hello] == fill(1.0, niters, 1)
    @test chn[:world] == fill(2.0, niters, 1)
end

@testset verbose = true "from_parameter_array" begin
    arr = reshape(Float64.(1:30), 3, 2, 5)
    niters, nchains, nparams = size(arr)

    @testset "single VarName key" begin
        chain = FlexiChains.from_parameter_array(arr)
        @test chain isa FlexiChain{<:VarName}
        @test size(chain) == (niters, nchains)
        @test Set(keys(chain)) == Set([Parameter(@varname(x))])
        val = getindex(chain, @varname(x); iter = At(1), chain = At(1))
        @test val == [1.0, 7.0, 13.0, 19.0, 25.0]
    end

    @testset "single Symbol key" begin
        chain = FlexiChains.from_parameter_array(arr; parameters = :x)
        @test chain isa FlexiChain{Symbol}
        @test Set(keys(chain)) == Set([Parameter(:x)])
    end

    @testset "tuple of VarName => range pairs" begin
        chain = FlexiChains.from_parameter_array(
            arr;
            parameters = (@varname(μ) => 1:1, @varname(σ) => 2:2, @varname(β) => 3:5),
        )
        @test chain isa FlexiChain{<:VarName}
        @test Set(keys(chain)) == Set([Parameter(@varname(μ)), Parameter(@varname(σ)), Parameter(@varname(β))])
        # Length-1 ranges give scalars
        @test getindex(chain, @varname(μ); iter = At(1), chain = At(1)) == 1.0
        @test getindex(chain, @varname(σ); iter = At(1), chain = At(1)) == 7.0
        # Longer ranges give vectors
        @test getindex(chain, @varname(β); iter = At(1), chain = At(1)) == [13.0, 19.0, 25.0]
    end

    @testset "tuple of Symbol => range pairs" begin
        chain = FlexiChains.from_parameter_array(
            arr;
            parameters = (:mu => 1:2, :sigma => 3:3, :beta => 4:5),
        )
        @test chain isa FlexiChain{Symbol}
        @test Set(keys(chain)) == Set([Parameter(:mu), Parameter(:sigma), Parameter(:beta)])
        @test getindex(chain, :mu; iter = At(1), chain = At(1)) == [1.0, 7.0]
        @test getindex(chain, :sigma; iter = At(1), chain = At(1)) == 13.0
        @test getindex(chain, :beta; iter = At(1), chain = At(1)) == [19.0, 25.0]
    end

    @testset "custom iter_indices and chain_indices" begin
        chain = FlexiChains.from_parameter_array(
            arr;
            parameters = (@varname(a) => 1:3, @varname(b) => 4:5),
            iter_indices = 10:10:30,
            chain_indices = [5, 10],
        )
        @test size(chain) == (niters, nchains)
        @test getindex(chain, @varname(a); iter = At(10), chain = At(5)) == [1.0, 7.0, 13.0]
    end

    @testset "range validation" begin
        # Gap in ranges
        @test_throws ArgumentError FlexiChains.from_parameter_array(
            arr;
            parameters = (@varname(a) => 1:2, @varname(b) => 4:5),
        )
        # Overlapping ranges
        @test_throws ArgumentError FlexiChains.from_parameter_array(
            arr;
            parameters = (@varname(a) => 1:3, @varname(b) => 3:5),
        )
        # Out of bounds
        @test_throws ArgumentError FlexiChains.from_parameter_array(
            arr;
            parameters = (@varname(a) => 1:3, @varname(b) => 4:6),
        )
    end
end

end
