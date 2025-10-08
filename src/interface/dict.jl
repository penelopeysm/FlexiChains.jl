@public parameters, extras

"""
    Base.keys(cs::ChainOrSummary)

Returns the keys of the `FlexiChain` (or summary thereof).
"""
function Base.keys(cs::ChainOrSummary)
    return keys(cs._data)
end

"""
    Base.keytype(cs::ChainOrSummary{TKey})

Returns `TKey`.
"""
Base.keytype(::ChainOrSummary{TKey}) where {TKey} = TKey

"""
    Base.haskey(cs::ChainOrSummary{TKey}, key::ParameterOrExtra{<:TKey}) where {TKey}

Returns `true` if the `FlexiChain` or summary contains the given key.
"""
function Base.haskey(cs::ChainOrSummary{TKey}, key::ParameterOrExtra{<:TKey}) where {TKey}
    return haskey(cs._data, key)
end
"""
    Base.haskey(cs::ChainOrSummary{TKey}, key::TKey) where {TKey}

Returns `true` if the `FlexiChain` or summary contains the given name as a parameter key.
"""
function Base.haskey(cs::ChainOrSummary{TKey}, key::TKey) where {TKey}
    return haskey(cs._data, Parameter(key))
end

"""
    Base.values(cs::ChainOrSummary)

Returns the values of the `FlexiChain` or `FlexiSummary`, i.e., the matrices obtained by
indexing into the chain with each key.
"""
function Base.values(cs::ChainOrSummary)
    return values(cs._data)
end

"""
    Base.pairs(cs::ChainOrSummary)

Returns an iterator over the key-value pairs of the `FlexiChain` or `FlexiSummary`.
"""
function Base.pairs(cs::ChainOrSummary)
    return pairs(cs._data)
end

"""
    parameters(cs::ChainOrSummary{TKey}) where {TKey}

Returns a vector of parameter names in the `FlexiChain` or summary thereof.
"""
function parameters(cs::ChainOrSummary{TKey})::Vector{TKey} where {TKey}
    parameter_names = TKey[]
    for k in keys(cs)
        if k isa Parameter{<:TKey}
            push!(parameter_names, k.name)
        end
    end
    return parameter_names
end

"""
    extras(cs::ChainOrSummary)

Returns a vector of non-parameter names in the `FlexiChain` or summary thereof.
"""
function extras(cs::ChainOrSummary)::Vector{Extra}
    other_key_names = Extra[]
    for k in keys(cs)
        if k isa Extra
            push!(other_key_names, k)
        end
    end
    return other_key_names
end
