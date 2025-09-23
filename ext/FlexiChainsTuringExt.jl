module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, ParameterOrExtra, VarName
using PrecompileTools: @setup_workload, @compile_workload
using Turing: Turing, AbstractMCMC

######################
# Chain construction #
#######################

function FlexiChains.to_varname_dict(
    transition::Turing.Inference.Transition
)::Dict{ParameterOrExtra{<:VarName},Any}
    d = Dict{ParameterOrExtra{<:VarName},Any}()
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
    chain_type::Type{FlexiChain{VarName}};
    save_state=false,
    stats=missing,
    discard_initial::Int=0,
    thinning::Int=1,
    _kwargs...,
)::FlexiChain{VarName}
    NIter = length(transitions)
    dicts = map(FlexiChains.to_varname_dict, transitions)
    # timings
    tm = stats === missing ? missing : stats.stop - stats.start
    # last sampler state
    st = save_state ? last_sampler_state : missing
    # calculate iteration indices
    start = discard_initial + 1
    iter_indices = if thinning != 1
        range(start; step=thinning, length=NIter)
    else
        # This returns UnitRange not StepRange -- a bit cleaner
        start:(start + NIter - 1)
    end
    return FlexiChain{VarName,NIter,1}(
        dicts;
        iter_indices=iter_indices,
        # 1:1 gives nicer DimMatrix output than just [1]
        chain_indices=1:1,
        sampling_time=[tm],
        last_sampler_state=[st],
    )
end

using Turing: @model, sample, MH, Normal, MvNormal, I
using FlexiChains: VNChain
@setup_workload begin
    @model f() = x ~ Normal()
    model, spl = f(), MH()
    @compile_workload begin
        sample(model, spl, 100; chain_type=VNChain, progress=false)
    end
end

end # module FlexiChainsTuringExt
