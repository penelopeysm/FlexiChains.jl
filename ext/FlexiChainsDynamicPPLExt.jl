module FlexiChainsDynamicPPLExt

using FlexiChains: FlexiChains, FlexiChain, VarName, Parameter, VNChain
using DynamicPPL: DynamicPPL
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

function DynamicPPL.loadstate(chain::FlexiChain)
    st = FlexiChains.last_sampler_state(chain)
    st === nothing && error(
        "attempted to resume sampling from a chain without a saved state; you must pass `save_state=true` when sampling the previous chain",
    )
    return st
end

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
    niters, nchains = size(chain)
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
    chain_nonparams_only = FlexiChains.subset_extras(chain)
    return merge(chain_params_only, chain_nonparams_only)
end
function DynamicPPL.predict(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName,NIter,NChain}
)::FlexiChain{VarName,NIter,NChain} where {NIter,NChain}
    return DynamicPPL.predict(Random.default_rng(), model, chain)
end

end # module FlexiChainsDynamicPPLExt
