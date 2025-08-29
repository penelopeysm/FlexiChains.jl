module FlexiChainsTuringExt

using FlexiChains:
    FlexiChains, FlexiChain, VNChain, Parameter, OtherKey, FlexiChainKey, VarName
using Turing
using Turing: AbstractMCMC, MCMCChains
using DynamicPPL: DynamicPPL
using OrderedCollections: OrderedDict, OrderedSet
using Random: Random

###############################
# DynamicPPL 0.38 compat shim #
#     DELETE WHEN POSSIBLE    #
###############################
struct InitContext{R<:Random.AbstractRNG,D<:AbstractDict} <: DynamicPPL.AbstractContext
    rng::R
    values::D
end
DynamicPPL.NodeTrait(::InitContext) = DynamicPPL.IsLeaf()
function DynamicPPL.tilde_assume(
    ctx::InitContext,
    dist::DynamicPPL.Distribution,
    vn::DynamicPPL.VarName,
    vi::DynamicPPL.AbstractVarInfo,
)
    in_varinfo = haskey(vi, vn)
    if haskey(ctx.values, vn)
        x = ctx.values[vn] # essentially InitFromParams
    else
        x = rand(ctx.rng, dist) # essentially InitFromPrior
    end
    insert_transformed_value =
        in_varinfo ? DynamicPPL.istrans(vi, vn) : DynamicPPL.istrans(vi)
    f = if insert_transformed_value
        DynamicPPL.link_transform(dist)
    else
        identity
    end
    y, logjac = DynamicPPL.with_logabsdet_jacobian(f, x)
    if in_varinfo
        vi = DynamicPPL.setindex!!(vi, y, vn)
    else
        vi = DynamicPPL.push!!(vi, vn, y, dist)
    end
    insert_transformed_value && DynamicPPL.settrans!!(vi, true, vn)
    vi = DynamicPPL.accumulate_assume!!(vi, x, logjac, vn, dist)
    return x, vi
end
function DynamicPPL.tilde_observe!!(::InitContext, right, left, vn, vi)
    return DynamicPPL.tilde_observe!!(DynamicPPL.DefaultContext(), right, left, vn, vi)
end
###############################
#             END             #
# DynamicPPL 0.38 compat shim #
#     DELETE WHEN POSSIBLE    #
###############################

###########################################
# DynamicPPL: predict, returned, logjoint #
###########################################

function _default_reevaluate_accs()
    return (
        DynamicPPL.LogPriorAccumulator(),
        DynamicPPL.LogJacobianAccumulator(),
        DynamicPPL.LogLikelihoodAccumulator(),
        DynamicPPL.ValuesAsInModelAccumulator(true),
    )
end

"""
Returns a tuple of (retval, varinfo) for each iteration in the chain.
"""
function reevaluate(
    rng::Random.AbstractRNG,
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName},
    accs::NTuple{N,DynamicPPL.AbstractAccumulator}=_default_reevaluate_accs(),
)::Array{Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    niters, _, nchains = size(chain)
    vi = DynamicPPL.VarInfo(model)
    vi = DynamicPPL.setaccs!!(vi, accs)
    # TODO: Ugly code repetition based on the fact that we 
    # return a vector for nchains == 1 and matrix otherwise.
    if nchains == 1
        return map(1:niters) do i
            vals = FlexiChains.get_parameter_dict_from_iter(chain, i, nothing)
            # TODO: use InitFromParams when DPPL 0.38 is out
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(rng, vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            DynamicPPL.evaluate!!(new_model, vi)
        end
    else
        tuples = Iterators.product(1:niters, 1:nchains)
        return map(tuples) do (i, j)
            vals = FlexiChains.get_parameter_dict_from_iter(chain, i, j)
            # TODO: use InitFromParams when DPPL 0.38 is out
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(rng, vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            DynamicPPL.evaluate!!(new_model, vi)
        end
    end
end
function reevaluate(
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName},
    accs::NTuple{N,DynamicPPL.AbstractAccumulator}=_default_reevaluate_accs(),
)::Array{Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    return reevaluate(Random.default_rng(), model, chain, accs)
end

function DynamicPPL.returned(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})::Array
    return map(first, reevaluate(model, chain))
end

function DynamicPPL.logjoint(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})::Array
    accs = (DynamicPPL.LogPriorAccumulator(), DynamicPPL.LogLikelihoodAccumulator())
    return map(DynamicPPL.getlogjoint ∘ last, reevaluate(model, chain, accs))
end

function DynamicPPL.loglikelihood(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::Array
    accs = (DynamicPPL.LogLikelihoodAccumulator(),)
    return map(DynamicPPL.getloglikelihood ∘ last, reevaluate(model, chain, accs))
end

function DynamicPPL.logprior(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})::Array
    accs = (DynamicPPL.LogPriorAccumulator(),)
    return map(DynamicPPL.getlogprior ∘ last, reevaluate(model, chain, accs))
end

function DynamicPPL.predict(
    rng::Random.AbstractRNG,
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName,NIter,NChain},
)::FlexiChain{VarName,NIter,NChain} where {NIter,NChain}
    param_dicts = map(reevaluate(rng, model, chain)) do (_, vi)
        # Dict{VarName}
        vn_dict = DynamicPPL.getacc(vi, Val(:ValuesAsInModel)).values
        # Dict{Parameter{VarName}}
        Dict(Parameter(vn) => val for (vn, val) in vn_dict)
    end
    chain_params_only = VNChain(param_dicts)
    chain_nonparams_only = FlexiChains.subset_other_keys(chain)
    return merge(chain_params_only, chain_nonparams_only)
end
function DynamicPPL.predict(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName,NIter,NChain}
)::FlexiChain{VarName,NIter,NChain} where {NIter,NChain}
    return DynamicPPL.predict(Random.default_rng(), model, chain)
end

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
        FlexiChains.get_parameter_dict_from_iter(vnchain, i, j) for i in 1:NIter,
        j in 1:NChain
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
        get(split_dicts[i, j], key, missing) for i in 1:NIter, key in varnames,
        j in 1:NChain
    ]
    varname_symbols = map(Symbol, varnames)

    # Handle non-parameter keys
    internal_keys = Symbol[]
    internal_values = Array{Real,3}(undef, NIter, 0, NChain)
    name_map = Dict{Symbol,Vector{Symbol}}()
    for k in FlexiChains.get_other_key_names(vnchain)
        v = map(identity, vnchain[k])
        if eltype(v) <: Real
            push!(internal_keys, Symbol(k.key_name))
            if haskey(name_map, k.section_name)
                push!(name_map[k.section_name], Symbol(k.key_name))
            else
                name_map[k.section_name] = [Symbol(k.key_name)]
            end
            internal_values = hcat(internal_values, reshape(v, NIter, 1, NChain))
        else
            @warn "key $k skipped in MCMCChains conversion as it is not Real-valued"
        end
    end

    all_symbols = vcat(varname_symbols, internal_keys)
    all_values = hcat(values, internal_values)

    info = (varname_to_symbol=OrderedDict(zip(varnames, varname_symbols)),)
    return MCMCChains.Chains(all_values, all_symbols, NamedTuple(name_map); info=info)
end

end # module FlexiChainsTuringExt
