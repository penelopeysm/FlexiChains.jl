const ChainOrSummary{TKey} = Union{FlexiChain{TKey},FlexiSummary{TKey}}

const SUMMARY_GETINDEX_KWARGS = """
!!! note "Keyword arguments"

    The `iter`, `chain`, and `stat` keyword arguments further allow you to extract specific
    iterations, chains, or statistics from the data corresponding to the given `key`. Note
    that these keyword arguments can only be used if the corresponding dimension exists (for
    example, if the summary statistic has been calculated over all iterations, then the
    `iter` dimension will not exist and using the `iter` keyword argument will throw an
    error).
"""

const _UNSPECIFIED_KWARG = gensym("kwarg")

function _check_summary_kwargs(fs::FlexiSummary, iter, chain, stat)
    function err_msg(kw)
        return "The `$kw` keyword argument cannot be used because the `$kw` dimension does not exist in this summary."
    end
    kwargs = NamedTuple()
    if FlexiChains.iter_indices(fs) === nothing
        iter === _UNSPECIFIED_KWARG || throw(ArgumentError(err_msg(:iter)))
    else
        new_iter = iter === _UNSPECIFIED_KWARG ? Colon() : iter
        kwargs = merge(kwargs, (iter=new_iter,))
    end
    if FlexiChains.chain_indices(fs) === nothing
        chain === _UNSPECIFIED_KWARG || throw(ArgumentError(err_msg(:chain)))
    else
        new_chain = chain === _UNSPECIFIED_KWARG ? Colon() : chain
        kwargs = merge(kwargs, (chain=new_chain,))
    end
    if FlexiChains.stat_indices(fs) === nothing
        stat === _UNSPECIFIED_KWARG || throw(ArgumentError(err_msg(:stat)))
    else
        new_stat = stat === _UNSPECIFIED_KWARG ? Colon() : stat
        # common error: indexing with `stat=:mean` instead of `stat=At(:mean)`. Ordinarily,
        # we should like to catch this with an error hint. Unfortunately, this throws an
        # ArgumentError and that doesn't call Base.Experimental.show_error_hints, so
        # although it's possible to define error hints, they never get displayed to the
        # user. So we have to catch it here.
        if new_stat isa Symbol
            @warn "indexing with `stat=:$stat` will (most likely) error; you probably want to use `stat=At(:$stat)` instead."
        end
        kwargs = merge(kwargs, (stat=new_stat,))
    end
    return kwargs
end
function _maybe_getindex_with_summary_kwargs(user_data, summary_getindex_kwargs)
    if isempty(summary_getindex_kwargs)
        return user_data
    else
        return getindex(user_data; summary_getindex_kwargs...)
    end
end

############################
### Unambiguous indexing ###
############################

"""
    Base.getindex(
        fchain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey};
        iter=Colon(), chain=Colon()
    ) where {TKey}

Unambiguously access the data corresponding to the given `key` in the chain.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `Extra(:x)`.

The `iter` and `chain` keyword arguments further allow you to extract specific
iterations or chains from the data corresponding to the given `key`.
"""
function Base.getindex(
    fchain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey}; iter=Colon(), chain=Colon()
) where {TKey}
    return _raw_to_user_data(fchain, _get_raw_data(fchain, key))[iter=iter, chain=chain]
end
"""
    Base.getindex(
        fs::FlexiSummary{TKey}, key::ParameterOrExtra{<:TKey};
        [iter=Colon(),]
        [chain=Colon(),]
        [stat=Colon()]
    ) where {TKey}

Unambiguously access the data corresponding to the given `key` in the summary.

You will need to use this method if you have multiple keys that convert to the same
`Symbol`, such as a `Parameter(:x)` and an `Extra(:x)`.

$(SUMMARY_GETINDEX_KWARGS)
"""
function Base.getindex(
    fs::FlexiSummary{TKey,TIIdx,TCIdx},
    key::ParameterOrExtra{<:TKey};
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
) where {TKey,TIIdx,TCIdx}
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, key))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end

#################
### By Symbol ###
#################

"""
    _extract_potential_symbol_key(
        all_keys::Base.KeySet{ParameterOrExtra{TKey}},
        target_sym::Symbol
    )::ParameterOrExtra{TKey} where {TKey}

Helper function that, given a list of keys and a target `Symbol`, attempts to find
a unique key that corresponds to the `Symbol`.
"""
function _extract_potential_symbol_key(
    ::Type{TKey}, all_keys::Base.KeySet, target_sym::Symbol
)::ParameterOrExtra{<:TKey} where {TKey}
    # TODO: `all_keys` should _really_ have the type
    #     all_keys::Base.KeySet{<:ParameterOrExtra{<:TKey}}
    # But again this fails on Julia 1.10. It's probably related to
    # https://github.com/JuliaLang/julia/issues/59626
    potential_keys = ParameterOrExtra{<:TKey}[]
    for k in all_keys
        # TODO: What happens if Symbol(...) fails on some weird type?
        if Symbol(k.name) == target_sym
            push!(potential_keys, k)
        end
    end
    if length(potential_keys) == 0
        throw(KeyError(target_sym))
    elseif length(potential_keys) > 1
        s = "multiple keys correspond to symbol :$target_sym.\n"
        s *= "Possible options are: \n"
        for k in potential_keys
            if k isa Parameter{<:TKey}
                s *= "  - Parameter($(k.name))\n"
            elseif k isa Extra
                s *= "  - Extra(:$(k.name))\n"
            end
        end
        throw(KeyError(s))
    else
        return only(potential_keys)
    end
end

"""
    Base.getindex(
        chain::FlexiChain, sym_key::Symbol;
        iter=Colon(), chain=Colon()
    )

The least verbose method to index into a `FlexiChain` is using `Symbol`.

However, recall that the keys in a `FlexiChain{TKey}` are not stored as `Symbol`s but rather
as either `Parameter{TKey}` or `Extra`. Thus, to access the data corresponding to a
`Symbol`, we first convert all key names (both parameters and other keys) to `Symbol`s, and
then check if there is a unique match.

If there is, then we can return that data. If there are no valid matches, then we throw a
`KeyError`.

If there are multiple matches: for example, if you have a `Parameter(:x)` and also an
`Extra(:x)`, then this method will also throw a `KeyError`. You will then have to index into
it using the actual key.
"""
function Base.getindex(
    fchain::FlexiChain{TKey}, sym_key::Symbol; iter=Colon(), chain=Colon()
) where {TKey}
    k = _extract_potential_symbol_key(TKey, keys(fchain), sym_key)
    return fchain[k, iter=iter, chain=chain]
end
"""
    Base.getindex(
        fs::FlexiSummary{TKey},
        key::Symbol;
        [iter=Colon(),]
        [chain=Colon(),]
        [stat=Colon()]
    ) where {TKey}

Index into a summary using an unambiguous `Symbol` key. This requires that the summary has a
unique key `k` for which `Symbol(k)` matches the provided `Symbol`. Errors if such a key
does not exist, or if it is not unique.

$(SUMMARY_GETINDEX_KWARGS)
"""
function Base.getindex(
    fs::FlexiSummary{TKey},
    sym_key::Symbol;
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
) where {TKey}
    k = _extract_potential_symbol_key(TKey, keys(fs), sym_key)
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, k))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end

####################
### By parameter ###
####################

"""
    Base.getindex(
        fchain::FlexiChain{TKey}, parameter_name::TKey;
        iter=Colon(), chain=Colon()
    ) where {TKey}

Convenience method for retrieving parameters. Equal to `chain[Parameter(parameter_name)]`.
"""
function Base.getindex(
    fchain::FlexiChain{TKey}, parameter_name::TKey; iter=Colon(), chain=Colon()
) where {TKey}
    return fchain[Parameter(parameter_name), iter=iter, chain=chain]
end
function Base.getindex(
    fchain::FlexiChain{Symbol}, parameter_name::Symbol; iter=Colon(), chain=Colon()
)
    # Explicitly specify the behaviour for TKey==Symbol so that it doesn't direct to the Symbol method above.
    return fchain[Parameter(parameter_name), iter=iter, chain=chain]
end
"""
    Base.getindex(
        fs::FlexiSummary{TKey},
        parameter_name::TKey;
        [iter=Colon(),]
        [chain=Colon(),]
        [stat=Colon()]
    ) where {TKey}

Convenience method for retrieving parameters. Equal to `summary[Parameter(parameter_name)]`.

$(SUMMARY_GETINDEX_KWARGS)
"""
function Base.getindex(
    fs::FlexiSummary{TKey},
    parameter_name::TKey;
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
) where {TKey}
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, Parameter(parameter_name)))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end
function Base.getindex(
    fs::FlexiSummary{Symbol},
    parameter_name::Symbol;
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
)
    # Explicitly specify the behaviour for TKey==Symbol so that it doesn't direct to the Symbol method above.
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    user_data = _raw_to_user_data(fs, _get_raw_data(fs, Parameter(parameter_name)))
    return _maybe_getindex_with_summary_kwargs(user_data, relevant_kwargs)
end

############################
### With vectors of keys ###
############################

"""
    _selectindices(lookup::DimensionalData.Lookup, s)

Helper function to determine the 1-based indices that the object `s` refers to in the
context of `lookup`.

This is very similar to `DimensionalData.selectindices` but with a special case for when the
length of the returned indices is 1: in that case we have to return a singleton vector
rather than just that index.

Additionally return a boolean indicating whether the dimension should be collapsed (i.e., if
`s` was a single integer, or `At(i)`).
"""
_selectindices(::Nothing, ::Any) = Colon(), false # this happens with collapsed stat dimension
_selectindices(::DD.Lookup, ::Colon) = Colon(), false
_selectindices(::DD.Lookup, s::AbstractRange) = s, false
_selectindices(::DD.Lookup, i::Integer) = i:i, true # Nicer output than just [i]
_selectindices(::DD.Lookup, v::AbstractVector{<:Integer}) = v, false
function _selectindices(lookup::DD.Lookup, s)
    # This just handles all other types, including Selectors, sets, etc.
    indices = DDL.selectindices(lookup, s)
    return if indices isa Integer
        indices:indices, true
    else
        indices, false
    end
end

"""
    _get_multi_key(
        ::Type{TKey},
        all_keys::Base.KeySet{ParameterOrExtra{TKey}},
        k
    )::ParameterOrExtra{TKey} where {TKey}

Given a list of all keys and a user-specified `k` (which may be a `Symbol`, a `TKey` assumed
to be a parameter, or directly a `ParameterOrExtra{TKey}`), identify the single
`ParameterOrExtra{TKey}` that the user wants to select.
"""
function _get_multi_key(
    ::Type{TKey}, all_keys::Base.KeySet, k
)::ParameterOrExtra{<:TKey} where {TKey}
    if k isa Symbol
        return _extract_potential_symbol_key(TKey, all_keys, k)
    elseif k isa ParameterOrExtra{<:TKey}
        return k
    elseif k isa TKey
        return Parameter(k)
    else
        errmsg = "cannot index using keys of type $(typeof(k))"
        throw(ArgumentError(errmsg))
    end
end
"""
    _get_multi_keys(
        ::Type{TKey},
        all_keys::Base.KeySet{ParameterOrExtra{TKey}},
        keyvec::Union{Colon,AbstractVector}
    )::Vector{ParameterOrExtra{TKey}} where {TKey}

Given a list of all keys and a user-specified `keyvec` (which may be `Colon` or an
`AbstractVector`), return a `Vector{ParameterOrExtra{TKey}}` corresponding to the keys
that the user wants to select.
"""
function _get_multi_keys(
    ::Type{TKey}, all_keys::Base.KeySet, ::Colon
)::Vector{ParameterOrExtra{<:TKey}} where {TKey}
    # TODO: `all_keys` has too loose a type.
    # https://github.com/JuliaLang/julia/issues/59626jg
    return collect(all_keys)
end
function _get_multi_keys(
    ::Type{TKey}, all_keys::Base.KeySet, keyvec::AbstractVector
)::Vector{ParameterOrExtra{<:TKey}} where {TKey}
    # TODO: `all_keys` has too loose a type.
    # https://github.com/JuliaLang/julia/issues/59626jg
    return map(k -> _get_multi_key(TKey, all_keys, k), keyvec)
end

"""
    _get_indices_and_lookup(
        fcs::ChainOrSummary,
        indices_function::Union{
            typeof(iter_indices),typeof(chain_indices),typeof(stat_indices)
        },
        index,
    )

Helper function that, given a `FlexiChain` or `FlexiSummary`, a function to retrieve
the indices, and an object to select a subset of those indices, return:

- the 1-based indices to use to index into the raw data
- the actual indices (i.e. the output of `indices_function(fcs)`) that correspond to
  those 1-based indices
- whether the dimension should be collapsed (i.e., if `index` was a single integer,
  or `At(i)`)

Right now, `getindex` doesn't make use of the last return value. See
https://github.com/penelopeysm/FlexiChains.jl/issues/51. However, `values_at` and
`parameters_at` do make use of it.
"""
function _get_indices_and_lookup(
    fcs::ChainOrSummary,
    indices_function::Union{
        typeof(iter_indices),typeof(chain_indices),typeof(stat_indices)
    },
    index,
)
    old_lookup = indices_function(fcs)
    # handle collapsed stat dimension
    isnothing(old_lookup) && return Colon(), nothing, true
    new_indices, collapse = _selectindices(old_lookup, index)
    new_lookup = old_lookup[new_indices]
    return new_indices, new_lookup, collapse
end

"""
    Base.getindex(
        fchain::FlexiChain{TKey},
        keys=Colon();
        iter=Colon(),
        chain=Colon()
    )::FlexiChain{TKey} where {TKey}

Select specific iterations or chains from a `FlexiChain`.

!!! important
    `iter` and `chain` must be specified as keyword arguments, not positional arguments.
    The only permitted positional argument to `getindex` is the parameter key.

The indexing behaviour is similar to [that used in DimensionalData.jl](@extref
DimensionalData Dimensional-Indexing). A few examples are shown here for ease of reference.

## Examples

Suppose that you have sampled a chain with 100 iterations, where the first 100 steps of
MCMC are dropped, and the remaining samples have been thinned by a factor of 2. That means
that the actual iteration numbers stored in the chain are 101, 103, 105, ..., 299.

```julia
using FlexiChains: FlexiChain, Parameter
x = Dict(Parameter(:a) => randn(100, 1))
chn = FlexiChain{Symbol}(100, 1, x; iter_indices=101:2:299)
```

!!! note
    If you sample a chain with, e.g., Turing.jl, the iteration numbers are automatically
calculated for you.

To subset to the first three stored iterations (i.e., the true iteration numbers `[101, 103,
105]`), you can do any of the following. They all return a new `FlexiChain{Symbol}`
object.

```julia
chn[iter=1:3]            # No special syntax means 1-based indexing.
chn[iter=[1, 2, 3]]      # Same behaviour as above.

using DimensionalData: At, (..)
chn[iter=At(101:2:105)]  # The `At` selector uses the stored 'actual' indices.
chn[iter=101..105]       # This too.
```

Other selectors are also possible. For example, maybe you want to drop the second stored iteration (i.e. iteration 103).

```julia
using DimensionalData: Not
chn[iter=Not(2)]        # Drops the second stored iteration.
chn[iter=Not(At(103))]  # Selectors can be composed too.
```

The same behaviour applies to the `chain` dimension

For full details on the indexing syntax please refer to [the DimensionalData.jl documentation](@extref DimensionalData Dimensional-Indexing).
"""
function Base.getindex(
    fchain::FlexiChain{TKey},
    keyvec::Union{Colon,AbstractVector}=Colon();
    iter=Colon(),
    chain=Colon(),
) where {TKey}
    # Figure out which indices we are using -- these refer to the actual 1-based indices
    # that we use to index into the original Matrix
    new_iter_indices, new_iter_lookup, _ = _get_indices_and_lookup(
        fchain, iter_indices, iter
    )
    new_chain_indices, new_chain_lookup, _ = _get_indices_and_lookup(
        fchain, chain_indices, chain
    )
    # Figure out which keys to include in the returned chain
    keys_to_include = _get_multi_keys(TKey, keys(fchain), keyvec)
    # Construct new data
    new_data = OrderedDict{ParameterOrExtra{<:TKey},Matrix}(
        k => _get_raw_data(fchain, k)[new_iter_indices, new_chain_indices] for
        k in keys_to_include
    )
    # Construct new chain
    return FlexiChain{TKey}(
        length(new_iter_lookup),
        length(new_chain_lookup),
        new_data;
        iter_indices=new_iter_lookup,
        chain_indices=new_chain_lookup,
        sampling_time=FlexiChains.sampling_time(fchain)[new_chain_indices],
        last_sampler_state=FlexiChains.last_sampler_state(fchain)[new_chain_indices],
    )
end
function Base.getindex(
    fs::FlexiSummary{TKey},
    keyvec::Union{Colon,AbstractVector}=Colon();
    iter=_UNSPECIFIED_KWARG,
    chain=_UNSPECIFIED_KWARG,
    stat=_UNSPECIFIED_KWARG,
) where {TKey}
    # Follows exactly the same pattern as above except for the additional kwarg handling.
    relevant_kwargs = _check_summary_kwargs(fs, iter, chain, stat)
    new_iter_indices, new_iter_lookup = _get_indices_and_lookup(
        fs, iter_indices, get(relevant_kwargs, :iter, Colon())
    )
    new_chain_indices, new_chain_lookup = _get_indices_and_lookup(
        fs, chain_indices, get(relevant_kwargs, :chain, Colon())
    )
    new_stat_indices, new_stat_lookup = _get_indices_and_lookup(
        fs, stat_indices, get(relevant_kwargs, :stat, Colon())
    )
    keys_to_include = _get_multi_keys(TKey, keys(fs), keyvec)
    new_data = OrderedDict{ParameterOrExtra{<:TKey},AbstractArray{<:Any,3}}(
        k => _get_raw_data(fs, k)[new_iter_indices, new_chain_indices, new_stat_indices] for
        k in keys_to_include
    )
    return FlexiSummary{TKey}(new_data, new_iter_lookup, new_chain_lookup, new_stat_lookup)
end
