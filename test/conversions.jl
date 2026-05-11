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

@testset verbose = true "FlexiChain from 3D array" begin
    arr = reshape(Float64.(1:30), 3, 2, 5)
    niters, nchains, ncols = size(arr)

    @testset "all scalar keys" begin
        chain = FlexiChain{Symbol}(
            arr,
            (Parameter(:a), Parameter(:b), Parameter(:c), Parameter(:d), Parameter(:e)),
        )
        @test chain isa FlexiChain{Symbol}
        @test size(chain) == (niters, nchains)
        @test Set(keys(chain)) == Set(Parameter.([:a, :b, :c, :d, :e]))
        @test getindex(chain, :a; iter = At(1), chain = At(1)) == 1.0
        @test getindex(chain, :e; iter = At(1), chain = At(1)) == 25.0
    end

    @testset "single vector key" begin
        chain = FlexiChain{Symbol}(arr, (Parameter(:x) => (5,),))
        @test chain isa FlexiChain{Symbol}
        @test size(chain) == (niters, nchains)
        @test Set(keys(chain)) == Set([Parameter(:x)])
        @test getindex(chain, :x; iter = At(1), chain = At(1)) == [1.0, 7.0, 13.0, 19.0, 25.0]
    end

    @testset "mix of scalar and vector keys" begin
        chain = FlexiChain{Symbol}(
            arr,
            (Parameter(:μ), Parameter(:σ), Parameter(:β) => (3,)),
        )
        @test chain isa FlexiChain{Symbol}
        @test Set(keys(chain)) == Set([Parameter(:μ), Parameter(:σ), Parameter(:β)])
        @test getindex(chain, :μ; iter = At(1), chain = At(1)) == 1.0
        @test getindex(chain, :σ; iter = At(1), chain = At(1)) == 7.0
        @test getindex(chain, :β; iter = At(1), chain = At(1)) == [13.0, 19.0, 25.0]
    end

    @testset "VarName keys" begin
        chain = FlexiChain{VarName}(
            arr,
            (Parameter(@varname(μ)), Parameter(@varname(σ)), Parameter(@varname(β)) => (3,)),
        )
        @test chain isa FlexiChain{<:VarName}
        @test getindex(chain, @varname(μ); iter = At(1), chain = At(1)) == 1.0
        @test getindex(chain, @varname(β); iter = At(1), chain = At(1)) == [13.0, 19.0, 25.0]
    end

    @testset "mix of Parameter and Extra" begin
        chain = FlexiChain{Symbol}(
            arr,
            (Parameter(:μ), Parameter(:σ), Parameter(:β) => (2,), Extra(:lp)),
        )
        @test chain isa FlexiChain{Symbol}
        @test Set(keys(chain)) == Set([Parameter(:μ), Parameter(:σ), Parameter(:β), Extra(:lp)])
        @test getindex(chain, :μ; iter = At(1), chain = At(1)) == 1.0
        @test getindex(chain, :σ; iter = At(1), chain = At(1)) == 7.0
        @test getindex(chain, :β; iter = At(1), chain = At(1)) == [13.0, 19.0, 25.0]
        @test getindex(chain, Extra(:lp); iter = At(1), chain = At(1)) == 25.0
    end

    @testset "matrix-valued key" begin
        arr6 = reshape(Float64.(1:36), 3, 2, 6)
        chain = FlexiChain{Symbol}(arr6, (Parameter(:M) => (2, 3),))
        @test chain isa FlexiChain{Symbol}
        val = getindex(chain, :M; iter = At(1), chain = At(1))
        @test size(val) == (2, 3)
        @test val == reshape([1.0, 7.0, 13.0, 19.0, 25.0, 31.0], 2, 3)
    end

    @testset "custom iter_indices and chain_indices" begin
        chain = FlexiChain{Symbol}(
            arr,
            (Parameter(:a), Parameter(:b) => (4,));
            iter_indices = 10:10:30,
            chain_indices = [5, 10],
        )
        @test size(chain) == (niters, nchains)
        @test getindex(chain, :a; iter = At(10), chain = At(5)) == 1.0
    end

    @testset "column count validation" begin
        @test_throws ArgumentError FlexiChain{Symbol}(
            arr,
            (Parameter(:a), Parameter(:b)),
        )
        @test_throws ArgumentError FlexiChain{Symbol}(
            arr,
            (Parameter(:a) => (6,),),
        )
    end
end

end
