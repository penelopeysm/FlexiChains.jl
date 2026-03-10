@public values_at, parameters_at, reconstruct_values, reconstruct_parameters

_VALUES_PARAMETER_AT_DOCSTRING = """
The `iter` and `chain` arguments can be anything used to index into the respective
dimensions of a `FlexiChain`, such as an integer, a range, or a DimensionalData.jl
selector.

In particular, you can convert the entire chain into a `DimMatrix` of the desired output
type by passing `:` for both arguments.
"""

_VALUES_PARAMETER_AT_WARNING = """
!!! warning "Using `NamedTuple` or `ComponentArray`"

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
        iter,
        chain,
        [::Type{T}]
    ) where {TKey,T}

Extract all values from the chain corresponding to a particular set of MCMC iterations(s).

$(_VALUES_PARAMETER_AT_DOCSTRING)

To get only the parameter keys, use [`FlexiChains.parameters_at`](@ref).

The output type can be specified with the final (optional) argument. Possible options are:

- unspecified: uses the `structure` stored in the chain to determine the output type.
  Specifically, for chains sampled with Turing.jl, the stored `structure` will be
  `VarNamedTuple`, and consequently the output of `parameters_at` will be a
  `DynamicPPL.ParamsWithStats` per iteration (which stores the parameters as a
  `VarNamedTuple`, and the stats/extras as a `NamedTuple`).

  For chains that do not have a stored `structure`, the default output will be an
  `OrderedDict`.

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
    # We could just omit this, but having it here is useful for the multi-iter/multi-chain
    # version to explicitly dispatch on.
    ::Type{Nothing}=Nothing,
) where {TKey}
    return reconstruct_values(chn, iter, chain, chn._structures[iter=iter, chain=chain])
end
function values_at(
    chn::FlexiChain{TKey}, iter::Union{Int,DD.At}, chain::Union{Int,DD.At}, ::Type{T}
)::T{ParameterOrExtra{<:TKey},Any} where {TKey,T<:AbstractDict}
    return T{ParameterOrExtra{<:TKey},Any}(
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

"""
    reconstruct_values(chn::FlexiChain{T}, iter, chain, structure) where {T}

Given a `FlexiChain`, an iteration index, a chain index, and the `structure` stored in the
chain, reconstruct the values (both parameters and extras) for that iteration and chain.

The default behaviour is to simply return an `OrderedDict` of `ParameterOrExtra` to their
values, but this can be overloaded for specific `structure` types to return more informative
output types.
"""
function reconstruct_values(chn::FlexiChain{TKey}, iter, chain, structure) where {TKey}
    return OrderedDict{ParameterOrExtra{<:TKey},Any}(
        k => chn[k, iter=iter, chain=chain] for k in keys(chn)
    )
end

"""
    FlexiChains.parameters_at(
        chn::FlexiChain{TKey},
        iter,
        chain,
        Tout::Type{T}=Nothing,
    ) where {TKey,T}

Extract all *parameter* values from the chain corresponding to a particular set of MCMC
iteration(s), discarding non-parameter (i.e. `Extra`) keys.

$(_VALUES_PARAMETER_AT_DOCSTRING)

To get all keys (not just parameters), use [`FlexiChains.values_at`](@ref).

The output type for each iteration can be specified with the `Tout` keyword argument.
Possible options are:

- unspecified: uses the `structure` stored in the chain to determine the output type.
  Specifically, for chains sampled with Turing.jl, the stored `structure` will be
  `VarNamedTuple`, and consequently the output of `parameters_at` will be a `VarNamedTuple`
  per iteration.

  For chains that do not have a stored `structure`, the default output will be an
  `OrderedDict`.

- `Tout <: AbstractDict`: returns a dictionary mapping `TKey` to their values.

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
    # We could just omit this, but having it here is useful for the multi-iter/multi-chain
    # version to explicitly dispatch on.
    ::Type{Nothing}=Nothing,
) where {TKey}
    return reconstruct_parameters(chn, iter, chain, chn._structures[iter=iter, chain=chain])
end
function parameters_at(
    chn::FlexiChain{TKey}, iter::Union{Int,DD.At}, chain::Union{Int,DD.At}, ::Type{T}
)::T{TKey,Any} where {TKey,T<:AbstractDict}
    return T{TKey,Any}(
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

"""
    reconstruct_parameters(chn::FlexiChain{T}, iter, chain, structure) where {T}

Given a `FlexiChain`, an iteration index, a chain index, and the `structure` stored in the
chain, reconstruct the parameter values for that iteration and chain.

The default behaviour is to simply return an `OrderedDict` of parameter keys to their
values, but this can be overloaded for specific `structure` types to return more informative
output types.
"""
function reconstruct_parameters(chn::FlexiChain{TKey}, iter, chain, structure) where {TKey}
    return OrderedDict{TKey,Any}(
        k => chn[Parameter(k), iter=iter, chain=chain] for k in FlexiChains.parameters(chn)
    )
end

# Multi-iter/multi-chain versions.
for f in (:values_at, :parameters_at)
    @eval begin
        function $f(chn::FlexiChain, iter, chain, ::Type{Tout}=Nothing) where {Tout}
            # Figure out which indices we are using -- these refer to the actual 1-based indices
            # that we use to index into the original Matrix
            new_iter_indices, new_iter_lookup, collapse_iter = _get_indices_and_lookup(
                chn, iter_indices, iter
            )
            new_chain_indices, new_chain_lookup, collapse_chain = _get_indices_and_lookup(
                chn, chain_indices, chain
            )
            # Instantiate an empty one
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
            mat = map(CartesianIndices((new_iter_indices, new_chain_indices))) do ci
                $f(chn, ci..., Tout)
            end
            dimmat = DD.DimMatrix(
                map(identity, mat),
                (
                    DD.Dim{ITER_DIM_NAME}(new_iter_lookup),
                    DD.Dim{CHAIN_DIM_NAME}(new_chain_lookup),
                ),
            )
            if collapse_iter
                dimmat = dropdims(dimmat; dims=ITER_DIM_NAME)
            end
            if collapse_chain
                dimmat = dropdims(dimmat; dims=CHAIN_DIM_NAME)
            end
            return dimmat
        end
    end
end
