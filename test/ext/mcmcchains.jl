module FlexiChainsMCMCChainsExtTests

using Turing
using DimensionalData: DimArray, Dim
using FlexiChains: FlexiChain, VNChain, Parameter, Extra
using AbstractMCMC
using Random: Xoshiro
using Test

@testset "FlexiChainsMCMCChainsExt" begin
    @testset "FlexiChain{VarName} -> MCMCChains" begin
        @model function f()
            x ~ Normal()
            y ~ MvNormal(zeros(3), I)
            return z ~ LKJCholesky(3, 2.0)
        end
        mcmcc = sample(
            Xoshiro(468), f(), NUTS(), 20; chain_type = MCMCChains.Chains, verbose = false
        )
        flexic = sample(Xoshiro(468), f(), NUTS(), 20; chain_type = VNChain, verbose = false)
        new_mcmcc = MCMCChains.Chains(flexic)

        @testset "the data itself" begin
            @test Set(keys(new_mcmcc)) == Set(keys(mcmcc))
            for k in keys(new_mcmcc)
                @test new_mcmcc[k] == mcmcc[k]
            end
        end

        @testset "iteration indices" begin
            @test FlexiChains.iter_indices(flexic) == range(new_mcmcc)
            @test range(new_mcmcc) == range(mcmcc)
        end

        @testset "grouping of data into sections" begin
            @test Set(keys(new_mcmcc.name_map)) == Set(keys(mcmcc.name_map))
            for k in keys(new_mcmcc.name_map)
                # each of these is a vector which may be in a different order
                @test Set(new_mcmcc.name_map[k]) == Set(mcmcc.name_map[k])
            end
        end

        @testset "sampling time is preserved" begin
            @test hasproperty(new_mcmcc.info, :start_time)
            @test hasproperty(new_mcmcc.info, :stop_time)
            durations = new_mcmcc.info.stop_time .- new_mcmcc.info.start_time
            @test durations ≈ FlexiChains.sampling_time(flexic)
        end

        @testset "sampler state is preserved with save_state=true" begin
            flexic_with_state = sample(
                Xoshiro(468), f(), NUTS(), 20;
                chain_type = VNChain, verbose = false, save_state = true,
            )
            mc_with_state = MCMCChains.Chains(flexic_with_state)
            @test hasproperty(mc_with_state.info, :samplerstate)
            @test mc_with_state.info.samplerstate ==
                FlexiChains.last_sampler_state(flexic_with_state)
        end
    end

    @testset "FlexiChain{Symbol} -> MCMCChains" begin
        # Mostly to test that it works; the VarName test above is responsible for checking
        # all the other fields.
        niters, nchains, nparams = 10, 3, 5
        rand_da() = DimArray(rand(nparams), Dim{:param}(1:nparams))
        dict_of_arrays = Dict{Parameter{Symbol}, Matrix}(
            Parameter(:params) => [rand_da() for _ in 1:niters, _ in 1:nchains]
        )
        chn = FlexiChain{Symbol}(niters, nchains, dict_of_arrays)
        @test size(chn[:params]) == (niters, nchains, nparams)

        mc = MCMCChains.Chains(chn)
        for i in 1:nparams
            @test Symbol("params[$i]") in keys(mc)
        end
        # MCMCChains is niters x nparams x nchains
        @test permutedims(mc.value.data, (1, 3, 2)) == chn[:params]
    end

    @testset "MCMCChains -> FlexiChain{Symbol}" begin
        @model function g()
            m ~ Normal(0, 1.0)
            s ~ InverseGamma(2, 3)
            return 1.5 ~ Normal(m, sqrt(s))
        end

        @testset "single chain" begin
            chn = sample(g(), MH(), 100; verbose = false)
            fc = FlexiChain{Symbol}(chn)

            @test fc isa FlexiChain{Symbol}
            @test size(fc) == (size(chn, 1), size(chn, 3))

            # Key names & grouping
            @test Set(FlexiChains.parameters(fc)) == Set(names(chn, :parameters))
            for name in names(chn, :internals)
                @test Extra(name) in FlexiChains.extras(fc)
            end
            # Data
            for name in names(chn)
                k = name in names(chn, :parameters) ? Parameter(name) : Extra(name)
                @test fc[k] == chn[:, name, :].data
            end
            # Iteration indices
            @test collect(FlexiChains.iter_indices(fc)) == collect(range(chn))
            # Sampling time
            @test !any(ismissing, FlexiChains.sampling_time(fc))
            @test only(FlexiChains.sampling_time(fc)) > 0
        end

        @testset "multiple chains" begin
            ni, nc = 100, 3
            chn = sample(g(), MH(), MCMCSerial(), ni, nc; verbose = false)
            fc = FlexiChain{Symbol}(chn)
            @test size(fc) == (ni, nc)
            for name in names(chn, :parameters)
                @test fc[Parameter(name)] == chn[:, name, :].data
            end
            st = FlexiChains.sampling_time(fc)
            @test length(st) == nc
            # Sometimes the sampling time is exactly 0 -- unsure why, so test for >= rather
            # than >.
            @test all(t -> t >= 0, st)
        end

        @testset "sampler state is preserved" begin
            chn = sample(g(), MH(), 50; verbose = false, save_state = true)
            @test hasproperty(chn.info, :samplerstate)
            fc = FlexiChain{Symbol}(chn)
            lss = FlexiChains.last_sampler_state(fc)
            @test !all(ismissing, lss)
        end
    end
end

end # module FlexiChainsMCMCChainsExtTests
