module FlexiChainsTuringExt

using FlexiChains: FlexiChains, FlexiChain, Parameter, OtherKey, FlexiChainKey
using Turing
using Turing: AbstractMCMC
using DynamicPPL: DynamicPPL, Model, VarName

### Chain construction

function transition_to_dict(
    transition::Turing.Inference.Transition
)::Dict{FlexiChainKey{VarName},Any}
    d = Dict{FlexiChainKey{VarName},Any}()
    for (varname, value) in pairs(transition.θ)
        d[Parameter(varname)] = value
    end
    # add in the transition stats (if available)
    # TODO: This uses a really, really, internal function. It is prone to
    # breaking if a new Turing patch version happens. That's why Turing is
    # pinned to a specific patch version in the Project.toml.
    for (key, value) in pairs(Turing.Inference.getstats_with_lp(transition))
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

### Chain deconstruction

function get_parameters_and_values(
    chain::FlexiChain{Tvn}, iteration_number::Int, chain_number::Union{Int,Nothing}=nothing;
)::Dict{Tvn,Any} where {Tvn<:VarName}
    d = Dict{Tvn,Any}()
    for param_name in FlexiChains.get_parameter_names(chain)
        if chain_number === nothing
            d[param_name] = chain[Parameter(param_name)][iteration_number]
        else
            d[param_name] = chain[Parameter(param_name)][iteration_number, chain_number]
        end
    end
    return d
end

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

function DynamicPPL.returned(model::Model, chain::FlexiChain{<:VarName})::Array
    niters, _, nchains = size(chain)
    vi = DynamicPPL.VarInfo(model)
    # TODO: Maybe we do want to unify the single- and multiple-chain case.
    if nchains == 1
        return map(1:niters) do i
            vals = get_parameters_and_values(chain, i, nothing)
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            first(DynamicPPL.evaluate!!(new_model, vi))
        end
    else
        tuples = Iterators.product(1:niters, 1:nchains)
        return map(tuples) do (i, j)
            vals = get_parameters_and_values(chain, i, j)
            new_ctx = DynamicPPL.setleafcontext(model.context, InitContext(vals))
            new_model = DynamicPPL.contextualize(model, new_ctx)
            first(DynamicPPL.evaluate!!(new_model, vi))
        end
    end
end

end # module FlexiChainsTuringExt
