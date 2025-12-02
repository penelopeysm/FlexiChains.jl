module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra, ParameterOrExtra, VarName
using OrderedCollections: OrderedDict
using PrecompileTools: @setup_workload, @compile_workload
using Turing: Turing, AbstractMCMC

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

######################
# Chain construction #
#######################

function FlexiChains.to_varname_dict(
    transition::Turing.Inference.Transition
)::OrderedDict{ParameterOrExtra{<:VarName},Any}
    d = OrderedDict{ParameterOrExtra{<:VarName},Any}()
    for (varname, value) in pairs(transition.θ)
        d[Parameter(varname)] = value
    end
    # add in the transition stats (if available)
    for (key, value) in pairs(transition.stat)
        d[Extra(key)] = value
    end
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

using Turing: @model, sample, NUTS, Normal, MvNormal, I, LKJCholesky
using Turing: AbstractMCMC, DynamicPPL
using FlexiChains: VNChain, summarystats
@setup_workload begin
    @model function f()
        x ~ MvNormal(zeros(10), I)
        z ~ Normal()
        return y ~ LKJCholesky(3, 3.0)
    end
    model, spl = f(), NUTS()
    transitions = sample(model, spl, 10; chain_type=Any, progress=false, verbose=false)
    @compile_workload begin
        chn = AbstractMCMC.bundle_samples(transitions, model, spl, nothing, VNChain)
        summarystats(chn)
    end
end

end # module FlexiChainsTuringExt
