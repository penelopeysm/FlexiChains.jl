@public has_same_data

_EQUALITY_DOCSTRING_SUPPLEMENT(strict) = """
!!! tip
    If you want to only compare equality of the data, you can use
    [`FlexiChains.has_same_data`](@ref)`(c1, c2; strict=$(strict))`.

!!! danger
    Because `(==)` on `OrderedCollections.OrderedDict` does not check key order, two chains
    with the same keys but in different orders will also be considered equal. If you think
    this is a mistake, please see [this
    issue](https://github.com/JuliaCollections/OrderedCollections.jl/issues/82).
"""

"""
    Base.:(==)(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}) where {TKey1,TKey2}
    Base.:(==)(c1::FlexiSummary{TKey1}, c2::FlexiSummary{TKey2}) where {TKey1,TKey2}

Equality operator for `FlexiChain`s and `FlexiSummary`s. Two chains (or summaries) are equal
if they have the same key type, the same size, the same data for each key, and the same
metadata (which includes dimensional indices, sampling time, and sampler states).

!!! note
    Because `missing == missing` returns `missing`, and `NaN == NaN` returns `false`, this
    function will not return `true` if there are any `missing` or `NaN` values in the
    chains, even if they appear in the same positions. To test for equality with such data,
    use `isequal(c1, c2)` instead.

$(_EQUALITY_DOCSTRING_SUPPLEMENT(true))
"""
function Base.:(==)(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}) where {TKey1,TKey2}
    return (TKey1 == TKey2) &
           (size(c1) == size(c2)) &
           (c1._data == c2._data) &
           (c1._metadata == c2._metadata)
end
function Base.:(==)(c1::FlexiSummary{TKey1}, c2::FlexiSummary{TKey2}) where {TKey1,TKey2}
    return (TKey1 == TKey2) &
           (size(c1) == size(c2)) &
           (c1._data == c2._data) &
           (c1._iter_indices == c2._iter_indices) &
           (c1._chain_indices == c2._chain_indices) &
           (c1._stat_indices == c2._stat_indices)
end

"""
    Base.isequal(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2})::Bool where {TKey1,TKey2}
    Base.isequal(c1::FlexiSummary{TKey1}, c2::FlexiSummary{TKey2})::Bool where {TKey1,TKey2}

Equality operator for `FlexiChain`s that treats `missing` and `NaN` values as equal if they
appear in the same positions.

$(_EQUALITY_DOCSTRING_SUPPLEMENT(false))
"""
function Base.isequal(
    c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}
)::Bool where {TKey1,TKey2}
    return TKey1 == TKey2 &&
           size(c1) == size(c2) &&
           isequal(c1._data, c2._data) &&
           isequal(c1._metadata, c2._metadata)
end
function Base.isequal(
    c1::FlexiSummary{TKey1}, c2::FlexiSummary{TKey2}
)::Bool where {TKey1,TKey2}
    return TKey1 == TKey2 &&
           size(c1) == size(c2) &&
           isequal(c1._data, c2._data) &&
           isequal(c1._iter_indices, c2._iter_indices) &&
           isequal(c1._chain_indices, c2._chain_indices) &&
           isequal(c1._stat_indices, c2._stat_indices)
end

"""
    FlexiChains.has_same_data(
        c1::FlexiChain{TKey1},
        c2::FlexiChain{TKey2};
        strict=false
    ) where {TKey1,TKey2}

Check if two `FlexiChain`s have the same data, ignoring metadata such as sampling time,
iteration indices, and chain indices.

If `strict=true`, then `Base.:(==)` is used to compare the data, which propagates `missing`
values and treats `NaN` values as unequal. If `strict=false` (the default), then
`Base.isequal` is used, which treats `missing` and `NaN` values as equal to themselves.
"""
function has_same_data(
    c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}; strict=false
) where {TKey1,TKey2}
    return if strict
        (TKey1 == TKey2) & (size(c1) == size(c2)) & (c1._data == c2._data)
    else
        (TKey1 == TKey2) && (size(c1) == size(c2)) && isequal(c1._data, c2._data)
    end
end
