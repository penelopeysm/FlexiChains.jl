const ChainOrSummary{TKey,NIter,NChain} = Union{
    <:FlexiChain{TKey,NIter,NChain},<:FlexiChainSummary{TKey,NIter,NChain}
}

"""
    Base.getindex(chain::ChainOrSummary{TKey}, key::ParameterOrExtra{TKey}) where {TKey}

Unambiguously access the data corresponding to the given `key` in the `chain`.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `Extra(:some_section, :x)`.
"""
function Base.getindex(
    chain::ChainOrSummary{TKey}, key::ParameterOrExtra{TKey}
) where {TKey}
    return _get(chain, key)
end
"""
    Base.getindex(chain::ChainOrSummary{TKey}, sym_key::Symbol) where {TKey}

The most convenient method to index into a `ChainOrSummary` is using `Symbol`.

However, recall that the keys in a `ChainOrSummary{TKey}` are not stored as
`Symbol`s but rather as either `Parameter{TKey}` or `Extra`. Thus, to
access the data corresponding to a `Symbol`, we first convert all key names
(both parameters and other keys) to `Symbol`s, and then check if there is a
unique match.

If there is, then we can return that data. If there are no valid matches,
then we throw a `KeyError`.

If there are multiple matches: for example, if you have a `Parameter(:x)`
and also an `Extra(:some_section, :x)`, then this method will also
throw a `KeyError`. You will then have to index into it using the
actual key.
"""
function Base.getindex(chain::ChainOrSummary{TKey}, sym_key::Symbol) where {TKey}
    # Convert all keys to symbols and see if there is a unique match
    potential_keys = ParameterOrExtra{TKey}[]
    for k in keys(chain._data)
        sym = if k isa Parameter{<:TKey}
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.name)
        elseif k isa Extra
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.key_name)
        end
        if sym == sym_key
            push!(potential_keys, k)
        end
    end
    if length(potential_keys) == 0
        throw(KeyError(sym_key))
    elseif length(potential_keys) > 1
        s = "multiple keys correspond to symbol :$sym_key.\n"
        s *= "Possible options are: \n"
        for k in potential_keys
            if k isa Parameter{<:TKey}
                s *= "  - Parameter($(k.name))\n"
            elseif k isa Extra
                s *= "  - Extra(:$(k.section_name), $(k.key_name))\n"
            end
        end
        throw(KeyError(s))
    else
        return chain[only(potential_keys)]
    end
end
"""
    Base.getindex(chain::ChainOrSummary{TKey}, section_name::Symbol, key_name::Any) where {TKey}

Convenience method for retrieving non-parameter keys. Equal to
`chain[Extra(section_name, key_name)]`.
"""
function Base.getindex(
    chain::ChainOrSummary{TKey}, section_name::Symbol, key_name::Any
) where {TKey}
    # This is a convenience method to access data in a section
    # using the section name and key name.
    return chain[Extra(section_name, key_name)]
end
"""
    Base.getindex(chain::ChainOrSummary{TKey}, parameter_name::TKey) where {TKey}

Convenience method for retrieving parameters. Equal to
`chain[Parameter(parameter_name)]`.
"""
function Base.getindex(chain::ChainOrSummary{TKey}, parameter_name::TKey) where {TKey}
    return chain[Parameter(parameter_name)]
end

"""
Helper function for `getindex` with `VarName`. Accesses the VarName `vn` in the chain (if it
is a parameter) and applies the `optic` function to the data before returning it.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _getindex_vn_with_map(
    chain::ChainOrSummary{<:VarName},
    vn::VarName{sym},
    optic::Function,
    orig_vn::VarName{sym},
) where {sym}
    if haskey(chain, vn)
        # Found
        if optic === identity
            return chain[Parameter(vn)]
        else
            # TODO: Nicer error if the optic is incompatible with the data shape?
            # Or do we just let it error naturally?
            return map(optic, chain[Parameter(vn)])
        end
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
            return _getindex_vn_with_map(chain, new_vn, new_optic, orig_vn)
        end
    end
end
"""
    Base.getindex(chain::ChainOrSummary{<:VarName}, vn::VarName)

An additional specialisation for `VarName`, meant for convenience when working with
Turing.jl models.

`chn[vn]` first checks if the VarName `vn` itself is stored in the chain. If not, it will
attempt to check if the 'parent' of `vn` is in the chain, and so on, until all possibilities
have been exhausted.

For example, the parent of `@varname(x[1])` is `@varname(x)`. If `@varname(x[1])` itself is
in the chain, then that will be returned. If not, then `@varname(x)` will be checked next,
and if that is a vector-valued parameter then all of its first entries will be returned.
"""
function Base.getindex(chain::ChainOrSummary{<:VarName}, vn::VarName)
    return _getindex_vn_with_map(chain, vn, identity, vn)
end
