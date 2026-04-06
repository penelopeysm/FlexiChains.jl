module FCSerialiseTests

using FlexiChains: FlexiChains, FlexiChain, FlexiSummary, VNChain, Parameter, Extra, summarystats
using JLD2: jldsave, load
using Serialization: serialize, deserialize
using Test
using Turing

Turing.setprogress!(false)

function test_isequal_and_same_keys(cs1::Union{FlexiChain, FlexiSummary}, cs2::Union{FlexiChain, FlexiSummary})
    @test isequal(cs1, cs2)
    # Check that ordering of keys is the same, because isequal() on FlexiChain/FlexiSummary
    # doesn't check that (because OrderedDict equality doesn't check order).
    return @test collect(keys(cs1)) == collect(keys(cs2))
end

@testset verbose = true "serialise.jl" begin
    @info "Testing serialise.jl"

    d = Dict(Parameter(:a) => 1, Parameter(:b) => [2.0, 3.0], Extra(:lp) => -1.5)
    chain = FlexiChain{Symbol}(10, 2, fill(d, 10, 2))

    @testset "Serialization.jl" begin
        @testset "FlexiChain" begin
            fname = Base.Filesystem.tempname()
            serialize(fname, chain)
            chain2 = deserialize(fname)
            test_isequal_and_same_keys(chain, chain2)
        end

        @testset "FlexiSummary" begin
            fs = summarystats(chain)
            fname = Base.Filesystem.tempname()
            serialize(fname, fs)
            fs2 = deserialize(fname)
            test_isequal_and_same_keys(fs, fs2)
        end

        @testset "VNChain" begin
            @model function demomodel(x)
                m ~ Normal(0, 1.0)
                x ~ Normal(m, 1.0)
                return nothing
            end
            model = demomodel(1.5)
            # Note that we can't test for equality with save_state=true because the states
            # don't compare equal :( That would need to be fixed upstream in Turing.
            chn = sample(
                model, NUTS(), MCMCSerial(), 100, 3; chain_type = VNChain, verbose = false
            )
            fname = Base.Filesystem.tempname()
            serialize(fname, chn)
            chn2 = deserialize(fname)
            test_isequal_and_same_keys(chn, chn2)
        end
    end

    @testset "JLD2.jl" begin
        @testset "FlexiChain" begin
            fname = Base.Filesystem.tempname() * ".jld2"
            jldsave(fname; chain)
            chain2 = load(fname, "chain")
            test_isequal_and_same_keys(chain, chain2)
        end

        @testset "FlexiSummary" begin
            fs = summarystats(chain)
            fname = Base.Filesystem.tempname() * ".jld2"
            jldsave(fname; fs)
            fs2 = load(fname, "fs")
            test_isequal_and_same_keys(fs, fs2)
        end
    end
end

end
