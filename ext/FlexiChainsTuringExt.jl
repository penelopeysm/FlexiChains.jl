module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, ParameterOrExtra, VarName
using Turing: Turing, AbstractMCMC

######################
# Chain construction #
#######################

function FlexiChains.to_varname_dict(
    transition::Turing.Inference.Transition
)::Dict{ParameterOrExtra{VarName},Any}
    d = Dict{ParameterOrExtra{VarName},Any}()
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
    last_sampler_state::Any,
    chain_type::Type{T};
    save_state=false,
    stats=missing,
    # discard_initial::Int=0,
    # thinning::Int=1,
    _kwargs...,
)::T where {TKey<:VarName,T<:FlexiChain{TKey}}
    NIter = length(transitions)
    dicts = map(FlexiChains.to_varname_dict, transitions)
    # timings
    tm = stats === missing ? nothing : stats.stop - stats.start
    # last sampler state
    st = save_state ? last_sampler_state : nothing
    return FlexiChain{TKey,NIter,1}(
        dicts;
        # TODO: Fix iter_indices
        iter_indices=1:NIter,
        # 1:1 gives nicer DimMatrix output than just [1]
        chain_indices=1:1,
        sampling_time=tm,
        last_sampler_state=st,
    )
end

end # module FlexiChainsTuringExt
