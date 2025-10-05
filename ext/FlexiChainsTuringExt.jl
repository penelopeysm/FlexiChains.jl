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
    # add in the transition stats (if available)
    for (key, value) in pairs(transition.stat)
        # Note that if `transition.stat` contains `lp`, `logprior`, or `loglikelihood`, it
        # will be overwritten below...
        d[Extra(key)] = value
    end
    # add in the log probs
    d[Extra(:logprior)] = transition.logprior
    d[Extra(:loglikelihood)] = transition.loglikelihood
    d[Extra(:lp)] = transition.logprior + transition.loglikelihood
    return d
end

function AbstractMCMC.bundle_samples(
    transitions::AbstractVector,
    @nospecialize(m::AbstractMCMC.AbstractModel),
    @nospecialize(s::AbstractMCMC.AbstractSampler),
    last_sampler_state::Any,
    chain_type::Type{FlexiChain{VarName}};
    save_state=false,
    stats=missing,
    discard_initial::Int=0,
    thinning::Int=1,
    _kwargs...,
)::FlexiChain{VarName}
    niters = length(transitions)
    dicts = map(FlexiChains.to_varname_dict, transitions)
    # timings
    tm = stats === missing ? missing : stats.stop - stats.start
    # last sampler state
    st = save_state ? last_sampler_state : missing
    # calculate iteration indices
    start = discard_initial + 1
    iter_indices = if thinning != 1
        range(start; step=thinning, length=niters)
    else
        # This returns UnitRange not StepRange -- a bit cleaner
        start:(start + niters - 1)
    end
    return FlexiChain{VarName}(
        niters,
        1,
        dicts;
        iter_indices=iter_indices,
        # 1:1 gives nicer DimMatrix output than just [1]
        chain_indices=1:1,
        sampling_time=[tm],
        last_sampler_state=[st],
    )
end

using Turing: @model, sample, NUTS, Normal, MvNormal, I
using Turing: AbstractMCMC, DynamicPPL
using FlexiChains: VNChain, summarystats
@setup_workload begin
    @model function f()
        x ~ Normal()
        return y ~ MvNormal(zeros(2), I)
    end
    model, spl = f(), NUTS()
    transitions = sample(model, spl, 10; chain_type=Any, progress=false, verbose=false)
    @compile_workload begin
        chn = AbstractMCMC.bundle_samples(
            transitions, model, DynamicPPL.Sampler(spl), nothing, VNChain
        )
        summarystats(chn)
    end
end

end # module FlexiChainsTuringExt
