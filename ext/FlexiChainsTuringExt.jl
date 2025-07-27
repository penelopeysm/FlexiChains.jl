module FlexiChainsTuringExt

using FlexiChains: FlexiChain, Parameter, OtherKey, FlexiChainKey
using Turing
using Turing: AbstractMCMC
using Turing.DynamicPPL: VarName

function transition_to_dict(
    transition::Turing.Inference.Transition
)::Dict{FlexiChainKey{VarName},Any}
    # up until 0.39.7, Turing.Inference.Transition contains a vector of 
    # (varname, value) pairs
    d = Dict{FlexiChainKey{VarName},Any}()
    for (varname, value) in transition.θ
        d[Parameter(varname)] = value
    end
    # add in other bits
    d[OtherKey(:stats, :lp)] = transition.lp
    # add in the stats (if available)
    if transition.stat isa NamedTuple
        for (key, value) in pairs(transition.stat)
            d[OtherKey(:stats, key)] = value
        end
    end
    return d
end

function AbstractMCMC.bundle_samples(
    transitions::AbstractVector{<:Turing.Inference.Transition},
    ::AbstractMCMC.AbstractModel,
    ::AbstractMCMC.AbstractSampler,
    state::Any,
    chain_type::Type{<:FlexiChain{<:VarName}};
    _kwargs...,
)
    # up until 0.39.7, Turing.Inference.Transition contains a vector of 
    # (varname, value) pairs
    dicts = map(transition_to_dict, transitions)
    return FlexiChain{VarName}(dicts)
end

end # module FlexiChainsTuringExt
