module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey, FlexiChainKey
using Turing
using Turing: AbstractMCMC
using DynamicPPL: DynamicPPL, Model, VarName

### Chain construction
include("FlexiChainsTuringExt/bundle_samples.jl")

### Chain deconstruction
"""
Extract a dictionary of (parameter varname => value) from one MCMC iteration.
"""
function get_dict_from_iter(
    chain::FlexiChain{Tvn}, iteration_number::Int, chain_number::Union{Int,Nothing}=nothing;
)::Dict{Tvn,Any} where {Tvn<:VarName}
    d = Dict{Tvn,Any}()
    for param_name in FlexiChains.get_parameter_names(chain)
        if chain_number === nothing
            d[param_name] = chain[Parameter(param_name)][iteration_number]
        else
            d[param_name] = chain[Parameter(param_name)][iteration_number, chain_number]
        end
    end
    return d
end

# Replacements for DynamicPPLMCMCChains
include("FlexiChainsTuringExt/dynamicppl.jl")

end # module FlexiChainsTuringExt
