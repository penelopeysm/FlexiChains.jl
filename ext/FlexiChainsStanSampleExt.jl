module FlexiChainsStanSampleExt

using FlexiChains: FlexiChains, FlexiChain
using StanSample: SampleModel

"""
    FlexiChain{Symbol}(sm::StanSample.SampleModel)

Convert a `StanSample.SampleModel` object to a `FlexiChain{Symbol}`.

Parameters in the `:parameters` section of the `Chains` are stored as `Parameter{Symbol}`
keys, while parameters in all other sections (e.g. `:internals`) are stored as `Extra` keys.

Iteration indices, chain indices, and per-chain sampling times are preserved where possible.
"""
function FlexiChains.FlexiChain{Symbol}(sm::SampleModel)
    if sm.thin > 1
        @info "Note that StanSample.jl does not pass the `thin` argument to CmdStan, so the saved Stan CSV file and the resulting FlexiChain will contain all iterations. If you want to thin the chain, you can do so by indexing, using e.g. `chn[iter=At(1001:4:2000)]`."
    end
    return FlexiChains.from_stan_csv(sm.output_base * "_chain", sm.num_chains)
end

end # module
