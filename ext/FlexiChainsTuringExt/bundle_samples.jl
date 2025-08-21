function transition_to_dict(
    transition::Turing.Inference.Transition
)::Dict{FlexiChainKey{VarName},Any}
    d = Dict{FlexiChainKey{VarName},Any}()
    for (varname, value) in pairs(transition.θ)
        d[Parameter(varname)] = value
    end
    # add in the log probs
    d[OtherKey(:logprobs, :logprior)] = transition.logprior
    d[OtherKey(:logprobs, :loglikelihood)] = transition.loglikelihood
    d[OtherKey(:logprobs, :lp)] = transition.logprior + transition.loglikelihood
    # add in the transition stats (if available)
    for (key, value) in pairs(transition.stat)
        d[OtherKey(:stats, key)] = value
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
)::FlexiChain{VarName}
    dicts = map(transition_to_dict, transitions)
    return FlexiChain{VarName}(dicts)
end
