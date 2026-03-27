using AbstractPPL: AbstractPPL, VarName, @varname
using OrderedCollections: OrderedSet

@public Prefixed

"""
Helper function to apply an optic function to an array. Errors if none of the array elements
actually can be transformed by the optic. If only some of the array elements can be
transformed, then the transformed elements are returned and the rest are `missing`.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _map_optic(::AbstractPPL.Iden, arr::AbstractArray, ::VarName)
    return arr
end
function _map_optic(optic::AbstractPPL.AbstractOptic, arr::AbstractArray, orig_vn::VarName)
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
        optic::AbstractPPL.AbstractOptic,
        orig_vn::VarName{sym},
    )::Tuple{AbstractPPL.AbstractOptic, VarName} where {sym}
    if vn in vn_keys
        return (optic, vn)
    else
        # Not found -- attempt to reduce.
        # TODO: This depends on AbstractPPL internals and is prone to breaking.
        # These should be exported from AbstractPPL.
        o = AbstractPPL.getoptic(vn)
        i, l = AbstractPPL.oinit(o), AbstractPPL.olast(o)
        if l isa AbstractPPL.Iden
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
        FlexiChains.parameters(cs), orig_vn, AbstractPPL.Iden(), orig_vn
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
        fchain::FlexiChain{<:VarName}, vn::VarName; iter = Colon(), chain = Colon()
    )
    raw = _get_raw_data(fchain, Parameter(vn))
    return _raw_to_user_data(fchain, raw; name = string(Parameter(vn)))[iter = iter, chain = chain]
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
        iter = _UNSPECIFIED_KWARG,
        chain = _UNSPECIFIED_KWARG,
        stat = _UNSPECIFIED_KWARG,
    )
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, Parameter(vn)); name = string(Parameter(vn)))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end

"""
    Prefixed(vn::VarName)

A struct that represents a VarName that might have an arbitrary prefix. This is useful for
indexing into a chain with VarNames when the exact prefix is not known (or too verbose to
construct). For example, with Turing.jl, this allows for data processing code that is
agnostic towards whether a submodel was used or not.

When indexing into a chain with a `Prefixed{VarName}` key, the chain will be searched for
any VarName that ends with the target VarName. For example, if the key is
`Prefixed(@varname(x))`, and the chain contains `@varname(a.x)`, the data corresponding to
`@varname(a.x)` will be returned. (If there are multiple matches, an error is thrown.)

Note that `Prefixed` is only supported for `VarName`s, and not for general keys.
"""
struct Prefixed{T <: VarName}
    target_vn::T
end
Base.show(io::IO, prefixed::Prefixed) = print(io, "Prefixed($(prefixed.target_vn))")
"""
    Prefixed(sym::Symbol)

Convenience function for `Prefixed(@varname(sym))`.
"""
Prefixed(sym::Symbol) = Prefixed(VarName{sym}())

function shares_tail(vn::VarName, target_vn::VarName)
    opt = AbstractPPL.varname_to_optic(vn)
    target_opt = AbstractPPL.varname_to_optic(target_vn)
    # TODO: Could be micro-optimised by stopping the loop as soon as opt is 'shorter' than
    # target_opt, but we don't yet have a function that gets the 'length' of a VarName, even
    # though the notion is quite well-defined.
    while !(opt isa AbstractPPL.Iden)
        if opt == target_opt
            return true
        else
            opt = AbstractPPL.otail(opt)
        end
    end
    return false
end
function get_vn_matching_prefixed(vns::Set{<:VarName}, prefixed::Prefixed)
    # TODO(penelopeysm): Fix the case where target_vn is something like @varname(x[1]) and
    # the chain contains @varname(a.x). To do so, we need to check if the following is
    # empty, and if so, call this again with `oinit(target_vn)`, etc. etc.
    target_vn = prefixed.target_vn
    matching_vns = collect(filter(vn -> shares_tail(vn, target_vn), vns))
    if isempty(matching_vns)
        throw(KeyError(prefixed))
    elseif length(matching_vns) > 1
        throw(ArgumentError("Multiple matches found for $(prefixed): ($(join(matching_vns, ", ")))"))
    else
        return only(matching_vns)
    end
end

"""
    Base.getindex(
        fchain::FlexiChain{<:VarName}, prefixed::Prefixed{<:VarName};
        iter=Colon(), chain=Colon()
    )

Get a parameter from the chain that matches the target VarName but with an arbitrary prefix.
See [`Prefixed`](@ref) for details.
"""
function Base.getindex(
        fchain::FlexiChain{<:VarName}, prefixed::Prefixed; iter = Colon(), chain = Colon()
    )
    vn = get_vn_matching_prefixed(Set(FlexiChains.parameters(fchain)), prefixed)
    return Base.getindex(fchain, Parameter(vn); iter = iter, chain = chain)
end
"""
    Base.getindex(
        fs::FlexiSummary{<:VarName},
        prefixed::Prefixed;
        [iter=Colon(),]
        [chain=Colon(),]
        [stat=Colon()]
    )

Get a parameter from the summary that matches the target VarName but with an arbitrary
prefix. See [`Prefixed`](@ref) for details.
"""
function Base.getindex(
        fs::FlexiSummary{<:VarName},
        prefixed::Prefixed;
        iter = _UNSPECIFIED_KWARG,
        chain = _UNSPECIFIED_KWARG,
        stat = _UNSPECIFIED_KWARG,
    )
    vn = get_vn_matching_prefixed(Set(FlexiChains.parameters(fs)), prefixed.target_vn)
    return Base.getindex(fs, Parameter(vn); iter = iter, chain = chain, stat = stat)
end

"""
    FlexiChains._split_varnames(cs::ChainOrSummary{<:VarName})

Split up a chain, which in general may contain array- or other-valued parameters, into a
chain containing only scalar-valued parameters. This is done by replacing the original
`VarName` keys with appropriate _leaves_. For example, if `x` is a vector-valued parameter,
then it is replaced by `x[1]`, `x[2]`, etc.

This function is only used for summarising and plotting: note that calling this on an
original chain, and subsequently using that chain for functions such as `returned` or
`predict`, **will** lead to errors!
"""
function _split_varnames(cs::ChainOrSummary{<:VarName})
    vns = OrderedSet{VarName}()
    for vn in FlexiChains.parameters(cs)
        d = _get_raw_data(cs, Parameter(vn))
        for i in eachindex(d)
            vn_leaves = collect(AbstractPPL.varname_leaves(vn, d[i]))
            union!(vns, vn_leaves)
        end
    end
    return cs[[collect(vns)..., FlexiChains.extras(cs)...]]
end
