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

The two summaries must have the same iteration and chain indices.

The merged result contains the union of keys and the union of stat names from both summaries.
For each `(key, stat)` pair, the value from `s2` takes priority over `s1`. Pairs that exist
in neither summary are filled with `missing`.

If the key types are different, the resulting `FlexiSummary` will have a promoted key type,
and a warning will be issued.
"""
function Base.merge(
        s1::FlexiSummary{TKey1}, s2::FlexiSummary{TKey2}
    ) where {TKey1, TKey2}
    # Validate iter and chain indices match. This is stricter than merge on FlexiChain, but
    # for summaries, I'm genuinely unsure of how one can ever have a situation where one
    # would want to merge summaries with different iteration or chain indices. (To the
    # reader: please feel free to open issues / PRs if you have a use case!)
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
    # Collect stat names
    stats1 = parent(s1._stat_indices)
    stats2 = parent(s2._stat_indices)
    all_stats = union(stats1, stats2)
    # Collect key names
    TKeyNew = if TKey1 != TKey2
        new = Base.promote_type(TKey1, TKey2)
        @warn "Merging FlexiSummaries with different key types: $(TKey1) and $(TKey2). The resulting summary will have $(new) as the key type."
        new
    else
        TKey1
    end
    all_keys = union(collect(keys(s1._data)), collect(keys(s2._data)))
    # Build mappings from stat name to index along the 3rd dimension of data array
    s1_stat_idx = Dict(name => i for (i, name) in enumerate(stats1))
    s2_stat_idx = Dict(name => i for (i, name) in enumerate(stats2))
    all_stat_idx = Dict(name => i for (i, name) in enumerate(all_stats))
    # Determine sizes of output array
    iter_size = s1._iter_indices === nothing ? 1 : length(s1._iter_indices)
    chain_size = s1._chain_indices === nothing ? 1 : length(s1._chain_indices)
    stat_size = length(all_stats)
    # Merge data
    new_data = OrderedDict{ParameterOrExtra{<:TKeyNew}, Array{<:Any, 3}}()
    for k in all_keys
        arr = Array{Any, 3}(missing, iter_size, chain_size, stat_size)
        # Fill from s1 first.
        if haskey(s1._data, k)
            # In principle this could be optimised to check if s2 has the combination of key
            # `k` + stat `name` before filling from s1, but this is probably good enough.
            for (stat_name, i) in s1_stat_idx
                j = all_stat_idx[stat_name]
                arr[:, :, j] = s1._data[k][:, :, i]
            end
        end
        # Then overwrite from s2
        if haskey(s2._data, k)
            for (stat_name, i) in s2_stat_idx
                j = all_stat_idx[stat_name]
                arr[:, :, j] .= @view s2._data[k][:, :, i]
            end
        end
        new_data[k] = map(identity, arr)
    end
    new_si = _make_categorical(all_stats)
    # The result should only drop the stat dimension if both inputs dropped it and there's
    # only one stat in the result (for example, merge(mean(chn1), mean(chn2))).
    new_drop = s1._drop_stat_dim && s2._drop_stat_dim && length(all_stats) == 1
    return FlexiSummary{TKeyNew}(
        new_data, s1._iter_indices, s1._chain_indices, new_si, new_drop,
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
