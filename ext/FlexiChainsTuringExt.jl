module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey, FlexiChainKey, VarName
using Turing
using Turing: AbstractMCMC, MCMCChains
using DynamicPPL: DynamicPPL
using OrderedCollections: OrderedDict, OrderedSet

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
    transitions::AbstractVector,
    ::AbstractMCMC.AbstractModel,
    ::AbstractMCMC.AbstractSampler,
    state::Any,
    chain_type::Type{T};
    _kwargs...,
)::T where {T<:FlexiChain{<:VarName}}
    dicts = map(FlexiChains.to_varname_dict, transitions)
    return T(dicts)
end

############################
# Conversion to MCMCChains #
############################

function MCMCChains.Chains(vnchain::FlexiChain{<:VarName,NIter,NChain}) where {NIter,NChain}
    array_of_dicts = [
        FlexiChains.get_parameter_dict_from_iter(vnchain, i, j) for i in 1:NIter, j in 1:NChain
    ]
    # Construct array of parameter names and array of values.
    # Most of this functionality is copied from _params_to_array in
    # Turing's src/mcmc/Inference.jl.
    names_set = OrderedSet{VarName}()
    # Extract the parameter names and values from each transition.
    split_dicts = map(array_of_dicts) do d
        nms_and_vs = if isempty(d)
            Tuple{VarName,Any}[]
        else
            iters = map(DynamicPPL.varname_and_value_leaves, Base.keys(d), Base.values(d))
            mapreduce(collect, vcat, iters)
        end
        nms = map(first, nms_and_vs)
        vs = map(last, nms_and_vs)
        for nm in nms
            push!(names_set, nm)
        end
        # Convert the names and values to a single dictionary.
        return OrderedDict(zip(nms, vs))
    end
    varnames = collect(names_set)
    values = [
        get(split_dicts[i, j], key, missing) for i in 1:NIter, key in varnames, j in 1:NChain
    ]
    varname_symbols = map(Symbol, varnames)

    # TODO: handle non-parameter keys

    info = (varname_to_symbol=OrderedDict(zip(varnames, varname_symbols)),)
    return MCMCChains.Chains(
        values,
        varname_symbols,
        (;);
        info=info,
    )
end

end # module FlexiChainsTuringExt
