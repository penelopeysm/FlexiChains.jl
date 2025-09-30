using DimensionalData.Dimensions.Lookups: Lookup, Selector, selectindices

const ChainOrSummary{TKey} = Union{FlexiChain{TKey},FlexiSummary{TKey}}

############################
### Unambiguous indexing ###
############################

"""
    Base.getindex(
        fchain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey};
        iter=Colon(), chain=Colon()
    ) where {TKey}

Unambiguously access the data corresponding to the given `key` in the `chain`.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `Extra(:x)`.

The `iter` and `chain` keyword arguments further allow you to extract specific
iterations or chains from the data corresponding to the given `key`.
"""
function Base.getindex(
    fchain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey}; iter=Colon(), chain=Colon()
) where {TKey}
    return data(
        fchain._data[key];
        iter_indices=iter_indices(fchain),
        chain_indices=chain_indices(fchain),
    )[
        iter, chain
    ]
end
# TODO: iter/chain/stat kwargs
function Base.getindex(
    fs::FlexiSummary{TKey,TIIdx,TCIdx}, key::ParameterOrExtra{<:TKey}
) where {TKey,TIIdx,TCIdx}
    return _get_data(fs, key)
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
    return fchain[_extract_potential_symbol_key(TKey, keys(fchain), sym_key)][
        iter=iter, chain=chain
    ]
end
# TODO: iter/chain/stat kwargs
function Base.getindex(fs::FlexiSummary{TKey}, sym_key::Symbol) where {TKey}
    return fs[_extract_potential_symbol_key(TKey, keys(fs), sym_key)]
end

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
    return fchain[Parameter(parameter_name)][iter=iter, chain=chain]
end
# TODO: iter/chain/stat kwargs
function Base.getindex(fs::FlexiSummary{TKey}, parameter_name::TKey) where {TKey}
    return fs[Parameter(parameter_name)]
end

"""
Helper function for `getindex` with `VarName`. Accesses the VarName `vn` in the chain (if it
is a parameter) and applies the `optic` function to the data before returning it.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _getindex_optic_and_vn(
    chain::ChainOrSummary{<:VarName},
    vn::VarName{sym},
    optic::Function,
    orig_vn::VarName{sym},
)::Tuple{AbstractPPL.ALLOWED_OPTICS,VarName} where {sym}
    if haskey(chain, vn)
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
            return _getindex_optic_and_vn(chain, new_vn, new_optic, orig_vn)
        end
    end
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
    optic, vn = _getindex_optic_and_vn(fchain, vn, identity, vn)
    return if optic === identity
        fchain[Parameter(vn), iter=iter, chain=chain]
    else
        # TODO: Would be nice to throw a nicer error if optic is incompatible with the
        # stored data.
        map(optic, fchain[Parameter(vn), iter=iter, chain=chain])
    end
end
# TODO: iter/chain/stat kwargs
function Base.getindex(fs::FlexiSummary{<:VarName}, vn::VarName)
    optic, vn = _getindex_optic_and_vn(fs, vn, identity, vn)
    return if optic === identity
        fs[Parameter(vn)]
    else
        map(optic, fs[Parameter(vn)])
    end
end

"""
    _selectindices(lookup::Lookup, s)

Helper function to determine the 1-based indices that the object `s` refers to in the
context of `lookup`.

This is very similar to `DimensionalData.selectindices` but with a special case for when the
length of the returned indices is 1: in that case we have to return a singleton vector
rather than just that index.

TODO: Think carefully about whether we should really do this, or whether we should actually
allow chains to store `DimVector`s. (The latter would require a _lot_ of work to fix all the
`getindex` methods...)
"""
_selectindices(::Lookup, ::Colon) = Colon()
_selectindices(::Lookup, s::AbstractRange) = s
_selectindices(::Lookup, i::Integer) = i:i # Nicer output than just [i]
_selectindices(::Lookup, v::AbstractVector{<:Integer}) = v
function _selectindices(lookup::Lookup, s)
    # This just handles all other types, including Selectors, sets, etc.
    indices = selectindices(lookup, s)
    return if length(indices) == 1
        indices:indices
    else
        indices
    end
end

##############################

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
)::Vector{ParameterOrExtra{TKey}} where {TKey}
    # TODO: `all_keys` has too loose a type. See above. It's a Julia 1.10 issue.
    return collect(all_keys)
end
function _get_multi_keys(
    ::Type{TKey}, all_keys::Base.KeySet, keyvec::AbstractVector
)::Vector{ParameterOrExtra{TKey}} where {TKey}
    # TODO: `all_keys` has too loose a type. See above. It's a Julia 1.10 issue.
    ks = ParameterOrExtra{TKey}[]
    for k in keyvec
        if k isa Symbol
            push!(ks, _extract_potential_symbol_key(TKey, all_keys, k))
        elseif k isa ParameterOrExtra{<:TKey}
            push!(ks, k)
        elseif k isa TKey
            push!(ks, Parameter(k))
        else
            # TODO Fix this error message!
            error("go straight to jail")
        end
    end
    return ks
end

function _get_iter_indices_and_lookup(
    fchain::ChainOrSummary{TKey}, iter
)::Tuple{Union{Colon,AbstractVector{Int}},DD.Lookup} where {TKey}
    old_iter_lookup = FlexiChains.iter_indices(fchain)
    new_iter_indices = _selectindices(old_iter_lookup, iter)
    new_iter_lookup = old_iter_lookup[new_iter_indices]
    return new_iter_indices, new_iter_lookup
end
function _get_chain_indices_and_lookup(
    fchain::ChainOrSummary{TKey}, chain
)::Tuple{Union{Colon,AbstractVector{Int}},DD.Lookup} where {TKey}
    old_chain_lookup = FlexiChains.chain_indices(fchain)
    new_chain_indices = _selectindices(old_chain_lookup, chain)
    new_chain_lookup = old_chain_lookup[new_chain_indices]
    return new_chain_indices, new_chain_lookup
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
chn = FlexiChain{Symbol,100,1}(x; iter_indices=101:2:299)
```

!!! note
    If you sample a chain with, e.g., Turing.jl, the iteration numbers are automatically
calculated for you.

To subset to the first three stored iterations (i.e., the true iteration numbers `[101, 103,
105]`), you can do any of the following. They all return a new `FlexiChain{Symbol,3,1}`
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
    new_iter_indices, new_iter_lookup = _get_iter_indices_and_lookup(fchain, iter)
    new_chain_indices, new_chain_lookup = _get_chain_indices_and_lookup(fchain, chain)
    # Figure out which keys to include in the returned chain
    keys_to_include = _get_multi_keys(TKey, keys(fchain), keyvec)
    # Construct new data
    new_data = Dict{ParameterOrExtra{<:TKey},Matrix}()
    for k in keys_to_include
        # Note that fchain._data[k] is always a plain old Matrix, so we can assume that it
        # is using ordinary 1-based indexing.
        new_data[k] = fchain._data[k][new_iter_indices, new_chain_indices]
    end
    # Construct new chain
    return FlexiChain{TKey,length(new_iter_lookup),length(new_chain_lookup)}(
        new_data;
        iter_indices=new_iter_lookup,
        chain_indices=new_chain_lookup,
        sampling_time=FlexiChains.sampling_time(fchain),
        last_sampler_state=FlexiChains.last_sampler_state(fchain),
    )
end
# TODO: iter/chain/stat kwargs
function Base.getindex(
    fs::FlexiSummary{TKey}, keyvec::Union{Colon,AbstractVector}=Colon();
) where {TKey}
    keys_to_include = _get_multi_keys(TKey, keys(fs), keyvec)
    new_data = Dict{ParameterOrExtra{<:TKey},Any}()
    for k in keys_to_include
        # Note that fs._data[k] is always a plain old 3D matrix.
        new_data[k] = fs._data[k]
    end
    return FlexiSummary{TKey}(new_data)
end
