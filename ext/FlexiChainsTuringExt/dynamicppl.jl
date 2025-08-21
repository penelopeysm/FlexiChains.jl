### DELETE THIS WHEN POSSIBLE
struct InitContext{D<:AbstractDict} <: DynamicPPL.AbstractContext
    values::D
end
DynamicPPL.NodeTrait(::InitContext) = DynamicPPL.IsLeaf()
function DynamicPPL.tilde_assume(
    ctx::InitContext,
    dist::Turing.Distribution,
    vn::DynamicPPL.VarName,
    vi::DynamicPPL.AbstractVarInfo,
)
    in_varinfo = haskey(vi, vn)
    x = ctx.values[vn]
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
### END DELETE WHEN POSSIBLE

"""
Returns a tuple of (retval, varinfo) for each iteration in the chain.
"""
function reevaluate_with_chain(
    model::Model, chain::FlexiChain{<:VarName}
)::Array{Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}}
    niters, _, nchains = size(chain)
    vi = DynamicPPL.VarInfo(model)
    vi = DynamicPPL.setacc!!(vi, (DynamicPPL.ValuesAsInModelAccumulator(true),))
    # TODO: Maybe we do want to unify the single- and multiple-chain case.
    if nchains == 1
        return map(1:niters) do i
            vals = get_dict_from_iter(chain, i, nothing)
            # TODO: use InitFromParams when DPPL 0.38 is out
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            DynamicPPL.evaluate!!(new_model, vi)
        end
    else
        tuples = Iterators.product(1:niters, 1:nchains)
        return map(tuples) do (i, j)
            vals = get_dict_from_iter(chain, i, j)
            # TODO: use InitFromParams when DPPL 0.38 is out
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            DynamicPPL.evaluate!!(new_model, vi)
        end
    end
end

function DynamicPPL.returned(model::Model, chain::FlexiChain{<:VarName})::Array
    return map(first, reevaluate_with_chain(model, chain))
end

function DynamicPPL.predict(model::Model, chain::FlexiChain{<:VarName})::Array
    varinfos = map(last, reevaluate_with_chain(model, chain))
    # TODO: reconstruct chain from VarInfo
    # TODO: add stats back from the old chain
    return chain
end
