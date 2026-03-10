@public subset_parameters, subset_extras, merge_structures

"""
    merge_structures(s1, s2)

Merge two structure objects. This is used when merging two `FlexiChain`s to combine the
per-iteration structure metadata.

The default implementation uses `Base.merge(s1, s2)`. If either argument is `nothing`, the
non-`nothing` argument is returned (or `nothing` if both are).
"""
merge_structures(s1, s2) = Base.merge(s1, s2)
merge_structures(::Nothing, ::Nothing) = nothing
merge_structures(::Nothing, s2) = s2
merge_structures(s1, ::Nothing) = s1

"""
    Base.merge(
        c1::FlexiChain{TKey1},
        c2::FlexiChain{TKey2}
    ) where {TKey1,TKey2}

Merge the contents of two `FlexiChain`s. If there are keys that are present in both chains,
the values from `c2` will overwrite those from `c1`.

If the key types are different, the resulting `FlexiChain` will have a promoted key type,
and a warning will be issued.

The two `FlexiChain`s being merged must have the same dimensions.

The chain indices and metadata are taken from the second chain. Those in the first chain are
silently ignored.
"""
function Base.merge(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}) where {TKey1,TKey2}
    # Check size
    size(c1) == size(c2) || throw(
        DimensionMismatch(
            "cannot merge FlexiChains with different sizes $(size(c1)) and $(size(c2))."
        ),
    )
    # Promote key type if necessary and warn
    TKeyNew = if TKey1 != TKey2
        new = Base.promote_type(TKey1, TKey2)
        @warn "Merging FlexiChains with different key types: $(TKey1) and $(TKey2). The resulting chain will have $(new) as the key type."
        new
    else
        TKey1
    end
    # Figure out value type
    # TODO: This function has to access internal data, urk
    TValNew = Base.promote_type(eltype(valtype(c1._data)), eltype(valtype(c2._data)))
    # Merge the data dictionaries
    d1 = OrderedDict{ParameterOrExtra{<:TKeyNew},Matrix{<:TValNew}}(c1._data)
    d2 = OrderedDict{ParameterOrExtra{<:TKeyNew},Matrix{<:TValNew}}(c2._data)
    merged_data = merge(d1, d2)
    # Merge structures element-wise
    merged_structures = map(merge_structures, c1._structures, c2._structures)
    return FlexiChain{TKeyNew}(
        niters(c1),
        nchains(c1),
        merged_data;
        structures=merged_structures,
        iter_indices=FlexiChains.iter_indices(c2),
        chain_indices=FlexiChains.chain_indices(c2),
        sampling_time=FlexiChains.sampling_time(c2),
        last_sampler_state=FlexiChains.last_sampler_state(c2),
    )
end

"""
    subset_parameters(cs::ChainOrSummary)

Subset a chain or summary, retaining only the `Parameter` keys.
"""
function subset_parameters(cs::ChainOrSummary)
    return cs[Parameter.(parameters(cs))]
end

"""
    subset_extras(cs::ChainOrSummary)

Subset a chain or summary, retaining only the keys that are `Extra`s (i.e. not parameters).
"""
function subset_extras(c::FlexiChain)
    # Extras don't need structures, so we can safely drop them
    return _drop_structures(c[extras(c)])
end
function subset_extras(s::FlexiSummary)
    return s[extras(s)]
end
