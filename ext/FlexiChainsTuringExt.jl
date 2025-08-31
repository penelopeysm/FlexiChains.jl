module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, FlexiChainKey, VarName
using Turing: Turing, AbstractMCMC

######################
# Chain construction #
#######################

function FlexiChains.to_varname_dict(
    transition::Turing.Inference.Transition
)::Dict{FlexiChainKey{VarName},Any}
    d = Dict{FlexiChainKey{VarName},Any}()
    for (varname, value) in pairs(transition.θ)
        d[Parameter(varname)] = value
    end
    # add in the log probs
    d[Extra(:logprobs, :logprior)] = transition.logprior
    d[Extra(:logprobs, :loglikelihood)] = transition.loglikelihood
    d[Extra(:logprobs, :lp)] = transition.logprior + transition.loglikelihood
    # add in the transition stats (if available)
    for (key, value) in pairs(transition.stat)
        d[Extra(:sampler_stats, key)] = value
    end
    return d
end

function AbstractMCMC.bundle_samples(
    transitions::AbstractVector,
    ::AbstractMCMC.AbstractModel,
    ::AbstractMCMC.AbstractSampler,
    state::Any,
    chain_type::Type{T};
    # discard_initial::Int=0,
    # thinning::Int=1,
    _kwargs...,
)::T where {T<:FlexiChain{<:VarName}}
    dicts = map(FlexiChains.to_varname_dict, transitions)
    return T(dicts)
    # TODO: add extra information like iteration number, time,
    # chain save state, etc.
end

end # module FlexiChainsTuringExt
