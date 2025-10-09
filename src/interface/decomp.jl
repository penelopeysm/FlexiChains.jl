@public values_at, parameters_at

_VALUES_PARAMETER_AT_DOCSTRING = """
The desired `iter` and `chain` indices must be specified: they can either be an integer, or
a `DimensionalData.At` selector. The meaning of these is exactly the same as when indexing:
`iter=5` means the fifth row of the chain, whereas `iter=At(5)` means the row corresponding
to iteration number 5 in the MCMC process.
"""

_VALUES_PARAMETER_AT_WARNING = """
!!! warning "Using `NamedTuple` or `ComponentArray`

    This will throw an error if any key cannot be converted to a `Symbol`, or if there are
    duplicate key names after conversion. If you have parameter names that convert to the
    same `Symbol`, you can either use `OrderedDict`, subset the chain before calling this
    function, or rename your parameters. Furthermore, please be aware that this is a lossy
    conversion as it does not retain information about whether a key is a parameter or an
    extra.
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

$(_VALUES_PARAMETER_AT_WARNING)

For order-sensitive output types, such as `OrderedDict`, the keys are returned in the same
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
    chn::FlexiChain, iter::Union{Int,DD.At}, chain::Union{Int,DD.At}, ::Type{NamedTuple}
)
    # check for uniqueness of keys
    ks = collect(Base.keys(chn))
    N_expected = length(ks)
    N_unique = length(Set(Symbol(k.name) for k in ks))
    if N_expected != N_unique
        errmsg = "key names could not be converted to unique symbols"
        throw(ArgumentError(errmsg))
    end
    return NamedTuple(Symbol(k.name) => chn[k, iter=iter, chain=chain] for k in ks)
end
function values_at(chn::FlexiChain, iter, chain, ::Type{Tout}=OrderedDict) where {Tout}
    # Figure out which indices we are using -- these refer to the actual 1-based indices
    # that we use to index into the original Matrix
    new_iter_indices, new_iter_lookup, collapse_iter = _get_indices_and_lookup(
        chn, iter_indices, iter
    )
    new_chain_indices, new_chain_lookup, collapse_chain = _get_indices_and_lookup(
        chn, chain_indices, chain
    )
    # Instantiate an empty one
    mat = Matrix{Tout}(undef, length(new_iter_lookup), length(new_chain_lookup))
    new_iter_indices = if new_iter_indices isa Colon
        1:length(new_iter_lookup)
    else
        new_iter_indices
    end
    new_chain_indices = if new_chain_indices isa Colon
        1:length(new_chain_lookup)
    else
        new_chain_indices
    end
    for i in new_iter_indices, c in new_chain_indices
        mat[i, c] = values_at(chn, i, c, Tout)
    end
    dimmat = DD.DimMatrix(
        map(identity, mat),
        (DD.Dim{ITER_DIM_NAME}(new_iter_lookup), DD.Dim{CHAIN_DIM_NAME}(new_chain_lookup)),
    )
    if collapse_iter
        dimmat = dropdims(dimmat; dims=ITER_DIM_NAME)
    end
    if collapse_chain
        dimmat = dropdims(dimmat; dims=CHAIN_DIM_NAME)
    end
    return dimmat
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

$(_VALUES_PARAMETER_AT_WARNING)

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
    # check for uniqueness of keys
    ps = FlexiChains.parameters(chn)
    N_expected = length(ps)
    N_unique = length(Set(Symbol.(ps)))
    if N_expected != N_unique
        errmsg = "parameter names could not be converted to unique symbols"
        throw(ArgumentError(errmsg))
    end
    return NamedTuple(Symbol(k) => chn[Parameter(k), iter=iter, chain=chain] for k in ps)
end
function parameters_at(
    chn::FlexiChain{TKey}, iter, chain, ::Type{Tout}=OrderedDict
) where {TKey,Tout}
    # Figure out which indices we are using -- these refer to the actual 1-based indices
    # that we use to index into the original Matrix
    new_iter_indices, new_iter_lookup, collapse_iter = _get_indices_and_lookup(
        chn, iter_indices, iter
    )
    new_chain_indices, new_chain_lookup, collapse_chain = _get_indices_and_lookup(
        chn, chain_indices, chain
    )
    # Instantiate an empty one
    mat = Matrix{Tout}(undef, length(new_iter_lookup), length(new_chain_lookup))
    new_iter_indices = if new_iter_indices isa Colon
        1:length(new_iter_lookup)
    else
        new_iter_indices
    end
    new_chain_indices = if new_chain_indices isa Colon
        1:length(new_chain_lookup)
    else
        new_chain_indices
    end
    for i in new_iter_indices, c in new_chain_indices
        mat[i, c] = parameters_at(chn, i, c, Tout)
    end
    dimmat = DD.DimMatrix(
        map(identity, mat),
        (DD.Dim{ITER_DIM_NAME}(new_iter_lookup), DD.Dim{CHAIN_DIM_NAME}(new_chain_lookup)),
    )
    if collapse_iter
        dimmat = dropdims(dimmat; dims=ITER_DIM_NAME)
    end
    if collapse_chain
        dimmat = dropdims(dimmat; dims=CHAIN_DIM_NAME)
    end
    return dimmat
end
