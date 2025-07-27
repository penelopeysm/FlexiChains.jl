"""
    size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}

Returns the size of the `FlexiChain` as a tuple `(NIter, num_objects, NChains)`,
where `num_objects` is the number of unique keys in the chain (both `Parameter`s
and `OtherKey`s).
"""
function Base.size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}
    num_objects = length(chain._data)
    return (NIter, num_objects, NChains)
end

"""
    keys(chain::FlexiChain{TKey}) where {TKey}

Returns the keys of the `FlexiChain` as an iterable collection.
"""
function Base.keys(chain::FlexiChain{TKey}) where {TKey}
    return keys(chain._data)
end

"""
    values(chain::FlexiChain{TKey}) where {TKey}

Returns the values of the `FlexiChain` as an iterable collection.
"""
function Base.values(chain::FlexiChain{TKey}) where {TKey}
    return values(chain._data)
end

"""
    pairs(chain::FlexiChain{TKey}) where {TKey}

Returns the pairs of the `FlexiChain` as an iterable collection of
(key, value) pairs.
"""
function Base.pairs(chain::FlexiChain{TKey}) where {TKey}
    return pairs(chain._data)
end

"""
    Base.getindex(chain::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}

Unambiguously access the data corresponding to the given `key` in the `chain`.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `OtherKey(:some_section, :x)`.
"""
function Base.getindex(chain::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}
    return collect(chain._data[key])  # errors if key not found
end
"""
    Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}

The most convenient method to index into a `FlexiChain` is using `Symbol`.

However, recall that the keys in a `FlexiChain{TKey}` are not stored as
`Symbol`s but rather as either `Parameter{TKey}` or `OtherKey`. Thus, to
access the data corresponding to a `Symbol`, we first convert all key names
(both parameters and other keys) to `Symbol`s, and then check if there is a
unique match.

If there is, then we can return that data. If there are no valid matches,
then we throw a `KeyError`.

If there are multiple matches: for example, if you have a `Parameter(:x)`
and also an `OtherKey(:some_section, :x)`, then this method will also
throw a `KeyError`. You will then have to index into it using the
actual key.
"""
function Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}
    # Convert all keys to symbols and see if there is a unique match
    potential_keys = FlexiChainKey{TKey}[]
    for k in keys(chain._data)
        sym = if k isa Parameter{<:TKey}
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.name)
        elseif k isa OtherKey
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.key_name)
        end
        if sym == sym_key
            push!(potential_keys, k)
        end
    end
    if length(potential_keys) == 0
        throw(ArgumentError("no key corresponding to symbol $sym_key"))
    elseif length(potential_keys) > 1
        s = "multiple keys correspond to symbol :$sym_key.\n"
        s *= "Possible options are: \n"
        for k in potential_keys
            if k isa Parameter{<:TKey}
                s *= "  - Parameter($(k.name))\n"
            elseif k isa OtherKey
                s *= "  - OtherKey(:$(k.section_name), $(k.key_name))\n"
            end
        end
        throw(ArgumentError(s))
    else
        return collect(chain._data[only(potential_keys)])
    end
end
"""
    Base.getindex(chain::FlexiChain{TKey}, section_name::Symbol, key_name::Any) where {TKey}

Convenience method for retrieving non-parameter keys. Equal to
`chain[OtherKey(section_name, key_name)]`.
"""
function Base.getindex(
    chain::FlexiChain{TKey}, section_name::Symbol, key_name::Any
) where {TKey}
    # This is a convenience method to access data in a section
    # using the section name and key name.
    return chain[OtherKey(section_name, key_name)]
end
"""
    Base.getindex(chain::FlexiChain{TKey}, parameter_name::TKey) where {TKey}

Convenience method for retrieving parameters. Equal to
`chain[Parameter(parameter_name)]`.
"""
function Base.getindex(chain::FlexiChain{TKey}, parameter_name::TKey) where {TKey}
    return chain[Parameter(parameter_name)]
end

"""
    get_parameter_names(chain::FlexiChain{TKey}) where {TKey}

Returns a vector of parameter names in the `FlexiChain`.
"""
function get_parameter_names(chain::FlexiChain{TKey}) where {TKey}
    parameter_names = TKey[]
    for k in keys(chain._data)
        if k isa Parameter{<:TKey}
            push!(parameter_names, k.name)
        end
    end
    return parameter_names
end

"""
    get_other_key_names(chain::FlexiChain{TKey}) where {TKey}

Returns a NamedTuple of `OtherKey` names, grouped by their section.
"""
function get_other_key_names(chain::FlexiChain{TKey}) where {TKey}
    other_keys = Dict{Symbol,Any}()
    for k in keys(chain._data)
        if k isa OtherKey
            section = k.section_name
            key_name = k.key_name
            if !haskey(other_keys, section)
                other_keys[section] = Vector{Any}()
            end
            push!(other_keys[section], key_name)
        end
    end
    for (section, keys) in other_keys
        other_keys[section] = map(identity, keys)
    end
    return NamedTuple(other_keys)
end
