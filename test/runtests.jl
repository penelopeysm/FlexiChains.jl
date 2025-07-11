using FlexiChains: FlexiChains, FlexiChain
using Test

@testset "FlexiChains.jl" begin
    @testset "core.jl" begin
        @testset "Correct" begin
            params_data = Dict{Symbol,Matrix{Float64}}(
                :param1 => rand(100, 3), :param2 => rand(100, 3)
            )
            other_data = (;
                section1=Dict{Symbol,Matrix{Float64}}(
                    :other1 => rand(100, 3), :other2 => rand(100, 3)
                )
            )
            chain = FlexiChain{Symbol}(params_data, other_data)
            @test chain isa FlexiChain
        end

        @testset "Inconsistent size" begin
            params_data = Dict{Symbol,Matrix{Float64}}(
                :param1 => rand(100, 2), :param2 => rand(100, 3)
            )
            @test_throws ArgumentError FlexiChain{Symbol}(params_data, NamedTuple())
        end

        @testset "getters" begin
            x_data = rand(100, 3)
            y_data = rand(100, 3)
            some_other_stuff = fill("hello", 100, 3)
            params_data = Dict{Symbol,Matrix{Float64}}(:x => x_data, :y => y_data)
            other_data = (; section1=Dict{Symbol,Matrix}(:somestuff => some_other_stuff))
            chain = FlexiChain{Symbol}(params_data, other_data)

            @test FlexiChains.get_parameter(chain, :x) == x_data
            @test FlexiChains.get_parameter(chain, :y) == y_data
            @test FlexiChains.get_other(chain, :section1, :somestuff) == some_other_stuff
        end
    end
end
