using AbstractPPL: AbstractPPL, VarName, @varname
@public split_varname

"""
Helper function to apply an optic function to an array. Errors if none of the array elements
actually can be transformed by the optic. If only some of the array elements can be
transformed, then the transformed elements are returned and the rest are `missing`.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _map_optic(::typeof(identity), arr::AbstractArray, ::VarName)
    return arr
end
function _map_optic(optic::Function, arr::AbstractArray, orig_vn::VarName)
    found = false
    results = map(arr) do elem
        if AbstractPPL.canview(optic, elem)
            found = true
            optic(elem)
        else
            missing
        end
    end
    found || throw(KeyError(orig_vn))
    return results
end

"""
Helper function for `getindex` with `VarName`. Accesses the VarName `vn` in the chain (if it
is a parameter) and applies the `optic` function to the data before returning it.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _getindex_optic_and_vn(
    vn_keys::AbstractVector{<:VarName},
    vn::VarName{sym},
    optic::Function,
    orig_vn::VarName{sym},
)::Tuple{AbstractPPL.ALLOWED_OPTICS,VarName} where {sym}
    if vn in vn_keys
        return (optic, vn)
    else
        # Not found -- attempt to reduce.
        # TODO: This depends on AbstractPPL internals and is prone to breaking.
        # These should be exported from AbstractPPL.
        o = AbstractPPL.getoptic(vn)
        i, l = AbstractPPL._init(o), AbstractPPL._last(o)
        if l === identity
            # Cannot reduce further
            throw(KeyError(orig_vn))
        else
            new_vn = VarName{sym}(i)
            new_optic = optic ∘ l
            return _getindex_optic_and_vn(vn_keys, new_vn, new_optic, orig_vn)
        end
    end
end

"""
Overloaded method which provides extra functionality when indexing by VarNames.
"""
function _get_raw_data(cs::ChainOrSummary{<:VarName}, vn_param::Parameter{<:VarName})
    orig_vn = vn_param.name
    optic, vn = _getindex_optic_and_vn(
        FlexiChains.parameters(cs), orig_vn, identity, orig_vn
    )
    # can't use get_raw_data in this line or else it will recurse.
    raw = cs._data[Parameter(vn)]
    return _map_optic(optic, raw, orig_vn)
end

"""
    Base.getindex(
        fchain::FlexiChain{<:VarName}, vn::VarName;
        iter=Colon(), chain=Colon()
    )

An additional specialisation for `VarName`, meant for convenience when working with
Turing.jl models.

`chn[vn]` first checks if the VarName `vn` itself is stored in the chain. If not, it will
attempt to check if the 'parent' of `vn` is in the chain, and so on, until all possibilities
have been exhausted.

For example, the parent of `@varname(x[1])` is `@varname(x)`. If `@varname(x[1])` itself is
in the chain, then that will be returned. If not, then `@varname(x)` will be checked next,
and if that is a vector-valued parameter then all of its first entries will be returned.
"""
function Base.getindex(
    fchain::FlexiChain{<:VarName}, vn::VarName; iter=Colon(), chain=Colon()
)
    raw = _get_raw_data(fchain, Parameter(vn))
    return _raw_to_user_data(fchain, raw)[iter=iter, chain=chain]
end
"""
    Base.getindex(
        fs::FlexiSummary{<:VarName},
        vn::VarName;
        [iter=Colon(),]
        [chain=Colon(),]
        [stat=Colon()]
    )

An additional specialisation for `VarName`, meant for convenience when working with
Turing.jl models.

$(SUMMARY_GETINDEX_KWARGS)
"""
function Base.getindex(
    fs::FlexiSummary{<:VarName},
    vn::VarName;
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
)
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, Parameter(vn)))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end

"""
    FlexiChains.split_varnames(cs::ChainOrSummary{<:VarName})

Split up a chain, which in general may contain array- or other-valued parameters, into a
chain containing only scalar-valued parameters. This is done by replacing the original
`VarName` keys with appropriate _leaves_. For example, if `x` is a vector-valued parameter,
then it is replaced by `x[1]`, `x[2]`, etc.
"""
function split_varnames(cs::ChainOrSummary{<:VarName})
    vns = Set{VarName}()
    for vn in FlexiChains.parameters(cs)
        d = _get_raw_data(cs, Parameter(vn))
        for i in eachindex(d)
            vn_leaves = Set(AbstractPPL.varname_leaves(vn, d[i]))
            union!(vns, vn_leaves)
        end
    end
    return cs[[collect(vns)..., FlexiChains.extras(cs)...]]
end

##################################
## MOVE THIS TO ABSTRACTPPL!!!! ##
##################################
using AbstractPPL: IndexLens, PropertyLens, ComposedFunction
function Base.isless(::typeof(identity), ::Union{IndexLens,PropertyLens,ComposedFunction})
    return true
end
function Base.isless(::Union{IndexLens,PropertyLens,ComposedFunction}, ::typeof(identity))
    return false
end
Base.isless(opt1::IndexLens, opt2::PropertyLens) = true
Base.isless(opt1::PropertyLens, opt2::IndexLens) = false
function Base.isless(opt1::IndexLens, opt2::IndexLens)
    return isless(opt1.indices, opt2.indices)
end
function Base.isless(opt1::PropertyLens{sym1}, opt2::PropertyLens{sym2}) where {sym1,sym2}
    return isless(sym1, sym2)
end
function Base.isless(opt1::Union{IndexLens,PropertyLens}, opt2::ComposedFunction)
    if isequal(opt1, opt2.outer)
        return true
    else
        return isless(opt1, opt2.outer)
    end
end
function Base.isless(opt1::ComposedFunction, opt2::Union{IndexLens,PropertyLens})
    if isequal(opt1.outer, opt2)
        return false
    else
        return isless(opt1.outer, opt2)
    end
end
function Base.isless(vn1::VarName{sym1}, vn2::VarName{sym2}) where {sym1,sym2}
    if sym1 == sym2
        return isless(AbstractPPL.getoptic(vn1), AbstractPPL.getoptic(vn2))
    else
        return isless(sym1, sym2)
    end
end
_sort_param_names(v::AbstractVector{<:VarName}) = sort(v)
