using DimensionalData: DimensionalData as DD

@public niters, nchains
@public has_same_data
@public subset_parameters, subset_extras
@public parameters, extras
@public values_at, parameters_at
@public to_varname_dict

using AbstractMCMC: AbstractMCMC

"""
    Base.size(chain::FlexiChain[, dim::Int])

Returns `(niters, nchains)`, or `niters` or `nchains` if `dim=1` or `dim=2` is specified.

!!! note "MCMCChains difference"
    
    MCMCChains returns a 3-tuple of `(niters, nkeys, nchains)` where `nkeys` is the total number of parameters. FlexiChains does not do this because the keys are not considered an axis of their own. If you want the total number of keys in a `FlexiChain`, you can use `length(keys(chain))`.
"""
function Base.size(chain::FlexiChain)::Tuple{Int,Int}
    return (niters(chain), nchains(chain))
end
function Base.size(chain::FlexiChain, dim::Int)::Int
    return if dim == 1
        niters(chain)
    elseif dim == 2
        nchains(chain)
    else
        throw(DimensionMismatch("Dimension $dim out of range for FlexiChain"))
    end
end
"""
    Base.size(summary::FlexiSummary[, dim::Int])

Returns `(niters, nchains, nstats)`, or `niters`, `nchains`, or `nstats` if `dim=1`,
`dim=2`, or `dim=3` is specified. If any of the dimensions have been collapsed, the
corresponding value will be 0.
"""
function Base.size(summary::FlexiSummary)::Tuple{Int,Int,Int}
    return (niters(summary), nchains(summary), nstats(summary))
end
function Base.size(summary::FlexiSummary, dim::Int)::Int
    return if dim == 1
        niters(summary)
    elseif dim == 2
        nchains(summary)
    elseif dim == 3
        nstats(summary)
    else
        throw(DimensionMismatch("Dimension $dim out of range for FlexiSummary"))
    end
end

"""
    FlexiChains.niters(chain::FlexiChain)

The number of iterations in the `FlexiChain`. Equivalent to `size(chain, 1)`.
"""
function niters(chain::FlexiChain)::Int
    return length(iter_indices(chain))
end
"""
    FlexiChains.niters(summary::FlexiSummary)

The number of iterations in the `FlexiSummary`. Equivalent to `size(summary, 1)`. Returns 0
if the iteration dimension has been collapsed.
"""
function niters(summary::FlexiSummary)::Int
    return if isnothing(iter_indices(summary))
        0
    else
        length(iter_indices(summary))
    end
end

"""
    FlexiChains.nchains(chain::FlexiChain)

The number of chains in the `FlexiChain`. Equivalent to `size(chain, 2)`.
"""
function nchains(chain::FlexiChain)::Int
    return length(chain_indices(chain))
end
"""
    FlexiChains.nchains(summary::FlexiSummary)

The number of chains in the `FlexiSummary`. Equivalent to `size(summary, 2)`. Returns 0 if
the chain dimension has been collapsed.
"""
function nchains(summary::FlexiSummary)::Int
    return if isnothing(chain_indices(summary))
        0
    else
        length(chain_indices(summary))
    end
end

"""
    FlexiChains.nstats(summary::FlexiSummary)

The number of statistics in the `FlexiSummary`. Equivalent to `size(summary, 3)`. Returns 0
if the statistics dimension has been collapsed (this means that there is a single statistic,
but its name is not stored or displayed to the user).
"""
function nstats(summary::FlexiSummary)::Int
    return if isnothing(stat_indices(summary))
        0
    else
        length(stat_indices(summary))
    end
end

_EQUALITY_DOCSTRING_SUPPLEMENT = """
!!! tip
    If you want to only compare equality of the data, you can use [`has_same_data`](@ref).

!!! danger
    Because `(==)` on `OrderedCollections.OrderedDict` does not check key order, two chains
    with the same keys but in different orders will also be considered equal. If you think
    this is a mistake, please see [this
    issue](https://github.com/JuliaCollections/OrderedCollections.jl/issues/82).
"""

"""
    Base.:(==)(c1::FlexiChain{TKey1}, c2::FlexiChain{TKey2})::Bool where {TKey1,TKey2}
    Base.:(==)(c1::FlexiSummary{TKey1}, c2::FlexiSummary{TKey2})::Bool where {TKey1,TKey2}

Equality operator for `FlexiChain`s and `FlexiSummary`s. Two chains (or summaries) are equal
if they have the same key type, the same size, the same data for each key, and the same
metadata (which includes dimensional indices, sampling time, and sampler states).

If you only want to compare the data in a `FlexiChain`, you can use `Dict(Base.pairs(c1)) == Dict(Base.pairs(c2))`.

!!! note
    Because `missing == missing` returns `missing`, and `NaN == NaN` returns `false`, this
    function will return `false` if there are any `missing` or `NaN` values in the chains,
    even if they appear in the same positions. In this case, use `isequal(c1, c2)` instead.

$(_EQUALITY_DOCSTRING_SUPPLEMENT)
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

$(_EQUALITY_DOCSTRING_SUPPLEMENT)
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
    return FlexiChain{TKeyNew}(
        niters(c1),
        nchains(c1),
        merged_data;
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
    subset_extras(chain::FlexiChain)

Subset a chain, retaining only the keys that are `Extra`s (i.e. not parameters).
"""
function subset_extras(cs::ChainOrSummary)
    return cs[extras(cs)]
end

# Avoid printing the entire `Sampled` object if it's been constructed
_show_range(s::DD.Dimensions.Lookups.Lookup) = _show_range(parent(s))
_show_range(s::AbstractRange) = string(s)
function _show_range(s::AbstractVector)
    if length(s) > 5
        return "[$(first(s)) … $(last(s))]"
    else
        return string(s)
    end
end

function Base.show(io::IO, ::MIME"text/plain", chain::FlexiChain{TKey}) where {TKey}
    maybe_s(x) = x == 1 ? "" : "s"
    ni, nc = size(chain)
    printstyled(io, "FlexiChain | $ni iteration$(maybe_s(ni)) ("; bold=true)
    printstyled(
        io,
        "$(_show_range(FlexiChains.iter_indices(chain)))";
        color=DD.dimcolor(1),
        bold=true,
    )
    printstyled(io, ") | $nc chain$(maybe_s(nc)) ("; bold=true)
    printstyled(
        io,
        "$(_show_range(FlexiChains.chain_indices(chain)))";
        color=DD.dimcolor(2),
        bold=true,
    )
    printstyled(io, ")\n"; bold=true)
    # Print parameter names
    parameter_names = parameters(chain)
    printstyled(io, "Parameter type   "; bold=true)
    println(io, "$TKey")
    printstyled(io, "Parameters       "; bold=true)
    if isempty(parameter_names)
        println(io, "(none)")
    else
        println(io, join(parameter_names, ", "))
    end

    # Print extras
    extra_names = extras(chain)
    printstyled(io, "Extra keys       "; bold=true)
    if isempty(extra_names)
        println(io, "(none)")
    else
        println(io, join(map(e -> repr(e.name), extra_names), ", "))
    end

    # TODO: Summary statistics?
    return nothing
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

# Overloaded in TuringExt.
"""
    to_varname_dict(transition)::AbstractDict{VarName,Any}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler
into a dictionary mapping `VarName`s to their corresponding values.

If you are writing a custom sampler for Turing.jl and your sampler's
implementation of `AbstractMCMC.step` returns anything _but_ a
`Turing.Inference.Transition` as its first return value, then to use FlexiChains
with your sampler, you will have to overload this function.
"""
function to_varname_dict end

"""
    Base.vcat(cs...::FlexiChain{TKey}) where {TKey}

Concatenate one or more `FlexiChain`s along the iteration dimension. Both `c1` and `c2` must
have the same number of chains and the same key type.

The resulting chain's keys are the union of both input chains' keys. Any keys that only have
data in one of the arguments will be assigned `missing` data in the other chain during
concatenation.

The resulting chain's sampling time is the sum of the input chains' sampling times, and
the last sampler state is taken from the second chain.
"""
function Base.vcat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    # Check sizes are compatible
    nchains(c1) == nchains(c2) || throw(
        DimensionMismatch(
            "cannot vcat FlexiChains with different number of chains: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
    # Warn if the chains don't line up in terms of chain indices
    ci1, ci2 = FlexiChains.chain_indices(c1), FlexiChains.chain_indices(c2)
    if ci1 != ci2
        @warn "concatenating FlexiChains with different chain indices: got $(ci1) and $(ci2). The resulting chain will have the chain indices of the first chain."
    end
    d = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
    allkeys = OrderedSet{ParameterOrExtra{<:TKey}}(keys(c1))
    union!(allkeys, keys(c2))
    for k in allkeys
        c1_data = if haskey(c1, k)
            _get_raw_data(c1, k)
        else
            fill(missing, size(c1)...)
        end
        c2_data = if haskey(c2, k)
            _get_raw_data(c2, k)
        else
            fill(missing, size(c2)...)
        end
        d[k] = vcat(c1_data, c2_data)
    end
    return FlexiChain{TKey}(
        niters(c1) + niters(c2),
        nchains(c1),
        d;
        iter_indices=vcat(FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2)),
        chain_indices=FlexiChains.chain_indices(c1),
        sampling_time=FlexiChains.sampling_time(c1) .+ FlexiChains.sampling_time(c2),
        last_sampler_state=FlexiChains.last_sampler_state(c2),
    )
end
function Base.vcat(::FlexiChain{TKey1}, ::FlexiChain{TKey2}) where {TKey1,TKey2}
    throw(
        ArgumentError(
            "cannot vcat FlexiChains with different key types $(TKey1) and $(TKey2)"
        ),
    )
end
Base.vcat(c1::FlexiChain) = c1
function Base.vcat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
    return Base.vcat(Base.vcat(c1, c2), cs...)
end

"""
    Base.hcat(cs...::FlexiChain{TKey}) where {TKey}

Concatenate one or more `FlexiChain`s along the chain dimension. Both `c1` and `c2` must
have the same number of iterations and the same key type.

The resulting chain's keys are the union of both input chains' keys. Any keys that only have
data in one of the arguments will be assigned `missing` data in the other chain during
concatenation.

The resulting chain's sampling times and last sampler states are obtained by concatenating
those of the input chains.
"""
function Base.hcat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    # Check sizes are compatible
    niters(c1) == niters(c2) || throw(
        DimensionMismatch(
            "cannot hcat FlexiChains with different number of iterations: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
    # Warn if the chains don't line up in terms of iteration indices
    ii1, ii2 = FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2)
    if ii1 != ii2
        @warn "concatenating FlexiChains with different iteration indices: got $(ii1) and $(ii2). The resulting chain will have the iteration indices of the first chain."
    end
    # Build up the new data dictionary
    d = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
    allkeys = OrderedSet{ParameterOrExtra{<:TKey}}(keys(c1))
    union!(allkeys, keys(c2))
    for k in allkeys
        c1_data = if haskey(c1, k)
            _get_raw_data(c1, k)
        else
            fill(missing, size(c1)...)
        end
        c2_data = if haskey(c2, k)
            _get_raw_data(c2, k)
        else
            fill(missing, size(c2)...)
        end
        d[k] = hcat(c1_data, c2_data)
    end
    # TODO: Do we want to use the chain indices passed in?
    return FlexiChain{TKey}(
        niters(c1),
        nchains(c1) + nchains(c2),
        d;
        iter_indices=FlexiChains.iter_indices(c1),
        chain_indices=1:(nchains(c1) + nchains(c2)),
        sampling_time=vcat(FlexiChains.sampling_time(c1), FlexiChains.sampling_time(c2)),
        last_sampler_state=vcat(
            FlexiChains.last_sampler_state(c1), FlexiChains.last_sampler_state(c2)
        ),
    )
end
Base.hcat(c1::FlexiChain) = c1
function Base.hcat(::FlexiChain{TKey1}, ::FlexiChain{TKey2}) where {TKey1,TKey2}
    throw(
        ArgumentError(
            "cannot hcat FlexiChains with different key types $(TKey1) and $(TKey2)"
        ),
    )
end
function Base.hcat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
    return Base.hcat(Base.hcat(c1, c2), cs...)
end

"""
    AbstractMCMC.chainscat(chains...)

Concatenate `FlexiChain`s along the chain dimension.
"""
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    return Base.hcat(c1, c2)
end
AbstractMCMC.chainscat(c1::FlexiChain) = c1
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
    return AbstractMCMC.chainscat(AbstractMCMC.chainscat(c1, c2), cs...)
end

_VALUES_PARAMETER_AT_DOCSTRING = """
The desired `iter` and `chain` indices must be specified: they can either be an integer, or
a `DimensionalData.At` selector. The meaning of these is exactly the same as when indexing:
`iter=5` means the fifth row of the chain, whereas `iter=At(5)` means the row corresponding
to iteration number 5 in the MCMC process.
"""

"""
    FlexiChains.values_at(
        chn::FlexiChain{TKey},
        iter::Union{Int,DD.At},
        chain::Union{Int,DD.At},
        Tout::Type{T}=OrderedDict
    ) where {TKey,T}

Extract all values from the chain corresponding to a single MCMC iteration.

$(_VALUES_PARAMETER_AT_DOCSTRING)

To get only the parameter keys, use [`FlexiChains.parameters_at`](@ref).

The output type can be specified with the `Tout` keyword argument. Possible options are:
- `Tout <: AbstractDict`: returns a dictionary mapping `ParameterOrExtra{TKey}` to their
  values. This is the most faithful representation of the data in the chain.
- `Tout = NamedTuple`, or `Tout = ComponentArrays: attempts to convert every key name to a
  Symbol, which is used as the field name in the output `NamedTuple` or `ComponentArray`.

!!! warning "Using `NamedTuple` or `ComponentArray`

    This will throw an error if any key cannot be converted to a `Symbol`, or if there are
    duplicate key names after conversion. Furthermore, please be aware that this is a lossy
    conversion as it does not retain information about whether a key is a parameter or an
    extra.

For order-sensitive output types, such as `OrderedDict`, The keys are returned in the same
order as they are stored in the `FlexiChain`. This also corresponds to the order returned by
`keys(chn)`.
"""
function values_at(
    chn::FlexiChain{TKey},
    iter::Union{Int,DD.At},
    chain::Union{Int,DD.At},
    Tout::Type{T}=OrderedDict,
) where {TKey,T<:AbstractDict}
    return Tout{ParameterOrExtra{TKey},Any}(
        k => chn[k, iter=iter, chain=chain] for k in keys(chn)
    )
end
function values_at(
    chn::FlexiChain{TKey},
    iter::Union{Int,DD.At},
    chain::Union{Int,DD.At},
    ::Type{NamedTuple},
) where {TKey}
    return NamedTuple(Symbol(k.name) => chn[k, iter=iter, chain=chain] for k in keys(chn))
end

"""
    FlexiChains.parameters_at(
        chn::FlexiChain{TKey},
        iter::Union{Int,DD.At},
        chain::Union{Int,DD.At},
        Tout::Type{T}=OrderedDict
    ) where {TKey,T}

Extract all *parameter* values from the chain corresponding to a single MCMC iteration,
discarding non-parameter (i.e. `Extra`) keys.

$(_VALUES_PARAMETER_AT_DOCSTRING)

To get all keys (not just parameters), use [`FlexiChains.values_at`](@ref).

The output type can be specified with the `Tout` keyword argument. Possible options are:
- `Tout <: AbstractDict`: returns a dictionary mapping `TKey` to their values
- `Tout = NamedTuple` or `Tout <: ComponentArray`: attempts to convert every parameter name
   to a Symbol, which is used as the field name in the output `NamedTuple` or
   `ComponentArray`.

!!! warning "Using `NamedTuple` or `ComponentArray`

    This will throw an error if any key cannot be converted to a `Symbol`, or if there are
    duplicate key names after conversion. Furthermore, please be aware that this is a lossy
    conversion as it does not retain information about whether a key is a parameter or an
    extra.

For order-sensitive output types, such as `OrderedDict`, the parameters are returned in the
same order as they are stored in the `FlexiChain`. This also corresponds to the order
returned by `FlexiChains.parameters(chn)`.
"""
function parameters_at(
    chn::FlexiChain{TKey},
    iter::Union{Int,DD.At},
    chain::Union{Int,DD.At},
    Tout::Type{T}=OrderedDict,
) where {TKey,T<:AbstractDict}
    return Tout{TKey,Any}(
        k => chn[Parameter(k), iter=iter, chain=chain] for k in FlexiChains.parameters(chn)
    )
end
function parameters_at(
    chn::FlexiChain{TKey},
    iter::Union{Int,DD.At},
    chain::Union{Int,DD.At},
    ::Type{NamedTuple},
) where {TKey}
    return NamedTuple(
        Symbol(k) => chn[Parameter(k), iter=iter, chain=chain] for
        k in FlexiChains.parameters(chn)
    )
end
