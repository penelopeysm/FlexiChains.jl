module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, VarName
using Turing: Turing

"""
    Turing.loadstate(chain::FlexiChain{<:VarName})

Extracts the last sampler state from a `FlexiChain`. This is the same function as 
[`FlexiChains.last_sampler_state`](@ref).

!!! warning

    This function is provided for maximum ease of use with Turing's interface, but it is
    recommended to use [`FlexiChains.last_sampler_state`](@ref) as it guards against future
    changes to Turing's API. In particular, it is unclear whether `loadstate` will be
    preserved if/when MCMCChains is no longer the default chain type in Turing.

$(FlexiChains._INITIAL_STATE_DOCSTRING)
"""
function Turing.loadstate(chain::FlexiChain{<:VarName})
    return FlexiChains.last_sampler_state(chain)
end

end # module FlexiChainsTuringExt
