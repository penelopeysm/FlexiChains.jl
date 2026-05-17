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
function Base.merge(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2}) where {TKey1, TKey2}
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
    d1 = OrderedDict{ParameterOrExtra{<:TKeyNew}, Matrix{<:TValNew}}(c1._data)
    d2 = OrderedDict{ParameterOrExtra{<:TKeyNew}, Matrix{<:TValNew}}(c2._data)
    merged_data = merge(d1, d2)
    # Merge structures element-wise
    merged_structures = map(merge_structures, c1._structures, c2._structures)
    return FlexiChain{TKeyNew}(
        niters(c1),
        nchains(c1),
        merged_data;
        structures = merged_structures,
        iter_indices = FlexiChains.iter_indices(c2),
        chain_indices = FlexiChains.chain_indices(c2),
        sampling_time = FlexiChains.sampling_time(c2),
        last_sampler_state = FlexiChains.last_sampler_state(c2),
    )
end

"""
    Base.merge(
        s1::FlexiSummary{TKey1},
        s2::FlexiSummary{TKey2},
    ) where {TKey1,TKey2}

Merge two `FlexiSummary`s along both the key and statistic dimensions.

The two summaries must have the same iteration and chain indices, and both must have known
stat names (i.e. `_stat_indices !== nothing`).

The merged result contains the union of keys and the union of stat names from both summaries.
For each `(key, stat)` pair, the value from `s2` takes priority over `s1`. Pairs that exist
in neither summary are filled with `missing`.

If the key types are different, the resulting `FlexiSummary` will have a promoted key type,
and a warning will be issued.
"""
function Base.merge(
        s1::FlexiSummary{TKey1}, s2::FlexiSummary{TKey2}
    ) where {TKey1, TKey2}
    # Validate iter and chain indices match
    s1._iter_indices == s2._iter_indices || throw(
        DimensionMismatch(
            "cannot merge FlexiSummaries with different iteration indices."
        ),
    )
    s1._chain_indices == s2._chain_indices || throw(
        DimensionMismatch(
            "cannot merge FlexiSummaries with different chain indices."
        ),
    )
    # Both must have known stat names
    si1 = s1._stat_indices
    si2 = s2._stat_indices
    si1 === nothing && throw(
        ArgumentError("cannot merge: first FlexiSummary has unknown stat names")
    )
    si2 === nothing && throw(
        ArgumentError("cannot merge: second FlexiSummary has unknown stat names")
    )
    names1 = parent(si1)
    names2 = parent(si2)
    # Promote key type if necessary
    TKeyNew = if TKey1 != TKey2
        new = Base.promote_type(TKey1, TKey2)
        @warn "Merging FlexiSummaries with different key types: $(TKey1) and $(TKey2). The resulting summary will have $(new) as the key type."
        new
    else
        TKey1
    end
    # Merged stat names and keys: s1's order first, then new from s2
    merged_names = union(names1, names2)
    all_keys = union(collect(keys(s1._data)), collect(keys(s2._data)))
    # Build index maps: stat name -> position in original arrays
    s1_stat_idx = Dict(name => i for (i, name) in enumerate(names1))
    s2_stat_idx = Dict(name => i for (i, name) in enumerate(names2))
    # Determine sizes for padding with missing
    iter_size = s1._iter_indices === nothing ? 1 : length(s1._iter_indices)
    chain_size = s1._chain_indices === nothing ? 1 : length(s1._chain_indices)
    # Merge data: for each (key, stat), s2 wins if it has the pair
    new_data = OrderedDict{ParameterOrExtra{<:TKeyNew}, Array{<:Any, 3}}()
    for k in all_keys
        arr = Array{Any, 3}(undef, iter_size, chain_size, length(merged_names))
        fill!(arr, missing)
        # Fill from s1
        if haskey(s1._data, k)
            for (name, i) in s1_stat_idx
                j = findfirst(==(name), merged_names)
                arr[:, :, j] .= @view s1._data[k][:, :, i]
            end
        end
        # Overwrite from s2 (s2 wins)
        if haskey(s2._data, k)
            for (name, i) in s2_stat_idx
                j = findfirst(==(name), merged_names)
                arr[:, :, j] .= @view s2._data[k][:, :, i]
            end
        end
        new_data[k] = map(identity, arr)
    end
    new_si = _make_categorical(merged_names)
    return FlexiSummary{TKeyNew}(
        new_data, s1._iter_indices, s1._chain_indices, new_si, false,
    )
end

function Base.merge(s1::FlexiSummary, s2::FlexiSummary, rest::FlexiSummary...)
    return foldl(merge, rest; init = merge(s1, s2))
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
