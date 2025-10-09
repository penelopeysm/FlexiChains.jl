@public FlexiChain, Parameter, Extra, ParameterOrExtra
@public iter_indices, chain_indices, renumber_iters, renumber_chains
@public sampling_time, last_sampler_state

const ITER_DIM_NAME = :iter
const CHAIN_DIM_NAME = :chain

"""
    _make_lookup(AbstractRange)::DimensionalData.Lookup

Generate a `DimensionalData.Lookup` object from a range. The range is assumed to be
forward-ordered (i.e. step is positive), regular (which follows from it being a range), and
consisting of points (rather than intervals). Manually specifying these properties allows
the construction to be type-stable, rather than relying on DimensionalData's heuristics to
infer them based on the values.

See [the DimensionalData documentation on lookups](@extref DimensionalData Lookups) for more
information.
"""
function _make_lookup(r::AbstractRange)
    step(r) < 0 && throw(ArgumentError("cannot use range with negative step"))
    return DDL.Sampled(
        r, DDL.ForwardOrdered(), DDL.Regular(step(r)), DDL.Points(), DDL.NoMetadata()
    )
end
_make_lookup(l::DDL.Lookup) = l
function _make_lookup(v::AbstractVector{<:Integer})
    return DDL.Sampled(
        v,
        DDL.Unordered(),
        DDL.Irregular(minimum(v), maximum(v)),
        DDL.Points(),
        DDL.NoMetadata(),
    )
end

"""
    _check_size(data::AbstractArray, iters::Int, chains::Int; key_name=nothing)::Matrix

Check that `data` is either a size `(iters, chains)`, or if `chains==1` and `data` is a
vector, check that it has length `iters. Convert it to a `Matrix` if it is not one.

The `key_name` keyword argument is used only to provide a more informative error message.
"""
function _check_size(
    data::AbstractMatrix{T}, iters::Int, chains::Int; key_name=nothing
)::Matrix{T} where {T}
    if size(data) != (iters, chains)
        key_str = isnothing(key_name) ? "" : " for key $(key_name)"
        msg = "expected matrix of size ($(iters), $(chains))$(key_str), but got $(size(data))."
        throw(DimensionMismatch(msg))
    end
    return collect(data)
end
function _check_size(
    data::AbstractVector{T}, iters::Int, chains::Int; key_name=nothing
)::Matrix{T} where {T}
    if chains != 1
        throw(ArgumentError("expected chains=1 for vector input."))
    end
    if length(data) != iters
        key_str = isnothing(key_name) ? "" : " for key $(key_name)"
        msg = "expected vector of length $(iters)$(key_str), but got $(length(data))."
        throw(DimensionMismatch(msg))
    end
    return reshape(collect(data), iters, 1)
end

"""
    Parameter{T}(name::T)

A named parameter in a `FlexiChain`. The name can be of any type, but all
parameters in a `FlexiChain` must have the same type for their names.

Specifically, if you have a `FlexiChain{TKey}`, then all parameters must be of
type `Parameter{TKey}`.
"""
struct Parameter{T}
    name::T
end

"""
    Extra(name::Any)

A key in a `FlexiChain` that is not a parameter. The name of the key itself can be of any
type and is not constrained by the type of the `FlexiChain`.
"""
struct Extra{T}
    name::T
end

"""
    ParameterOrExtra{T}

Alias for `Union{Parameter{T},Extra}`.

All keys in a `FlexiChain{T}` must satisfy `k isa ParameterOrExtra{<:T}`.
"""
const ParameterOrExtra{T} = Union{Parameter{T},Extra}

function _check_length(n::Int, v::AbstractVector, s::AbstractString)
    if length(v) != n
        msg = "expected `$s` to have length $n, got $(length(v))."
        throw(DimensionMismatch(msg))
    end
    return v
end

"""
    FlexiChainMetadata

A struct to hold common kinds of metadata typically associated with a chain.
"""
struct FlexiChainMetadata{
    TIIdx<:DDL.Lookup,
    TCIdx<:DDL.Lookup,
    Ttime<:AbstractVector{<:Union{Real,Missing}},
    Tstate<:AbstractVector,
}
    """
    The indices of each MCMC iteration in the chain. This tries to reflect the actual
    iteration numbers from the sampler: for example, if you discard the first 100 iterations
    and sampled 100 iterations but with a thinning factor of 2, this will be `101:2:300`. Do
    not access this directly; you can use [`FlexiChains.iter_indices`](@ref) instead.
    """
    iter_indices::TIIdx
    """
    The indices of each MCMC chain in the chain. This will pretty much always be `1:NChains`
    (unless the chain has been subsetted). Do not access this directly; you can use
    [`FlexiChains.chain_indices`](@ref) instead.
    """
    chain_indices::TCIdx
    """
    The time taken to sample each chain (in seconds). This should be a vector of length `NChains`. If the time was not recorded for a chain, it will be `missing`.
    """
    sampling_time::Ttime
    """
    The final state of the sampler used to generate each chain, if the `save_state=true`
    keyword argument was passed to `sample`. This can be used for resuming MCMC sampling.
    This should be a vector of length `NChains`. If the state was not saved for a chain, it
    will be `missing`.
    """
    last_sampler_state::Tstate

    function FlexiChainMetadata(
        niter::Int,
        nchains::Int,
        iter_indices::AbstractVector{<:Integer},
        chain_indices::AbstractVector{<:Integer},
        sampling_time::AbstractVector{<:Union{Real,Missing}},
        last_sampler_state::AbstractVector,
    )
        iter_indices_checked = _make_lookup(
            _check_length(niter, iter_indices, "iter_indices")
        )
        chain_indices_checked = _make_lookup(
            _check_length(nchains, chain_indices, "chain_indices")
        )
        sampling_time_checked = _check_length(nchains, sampling_time, "sampling_time")
        last_sampler_state_checked = _check_length(
            nchains, last_sampler_state, "last_sampler_state"
        )
        return new{
            typeof(iter_indices_checked),
            typeof(chain_indices_checked),
            typeof(sampling_time_checked),
            typeof(last_sampler_state_checked),
        }(
            iter_indices_checked,
            chain_indices_checked,
            sampling_time_checked,
            last_sampler_state_checked,
        )
    end
end
function Base.:(==)(m1::FlexiChainMetadata, m2::FlexiChainMetadata)
    return (m1.iter_indices == m2.iter_indices) &
           (m1.chain_indices == m2.chain_indices) &
           (m1.sampling_time == m2.sampling_time) &
           (m1.last_sampler_state == m2.last_sampler_state)
end
function Base.isequal(m1::FlexiChainMetadata, m2::FlexiChainMetadata)
    return isequal(m1.iter_indices, m2.iter_indices) &&
           isequal(m1.chain_indices, m2.chain_indices) &&
           isequal(m1.sampling_time, m2.sampling_time) &&
           isequal(m1.last_sampler_state, m2.last_sampler_state)
end

"""
    struct FlexiChain{
        TKey,TMetadata<:NTuple{N,FlexiChainMetadata}
    } <: AbstractMCMC.AbstractChains

An MCMC chain.

!!! warning

    Please note that all fields of the FlexiChain type are considered internal.

TODO: Document further.

## Fields

$(TYPEDFIELDS)
"""
struct FlexiChain{TKey,TMetadata<:FlexiChainMetadata} <: AbstractMCMC.AbstractChains
    """
    Internal per-iteration data for parameters and extra keys. To access the data
    in here, you should index into the chain.
    """
    _data::OrderedDict{ParameterOrExtra{<:TKey},Matrix{<:Any}}

    """
    Other items associated with the chain. These are not necessarily per-iteration (for
    example there may only be one per chain).

    You should not access this field directly; instead you should use the accessor functions
    provided: [`FlexiChains.iter_indices`](@ref), [`FlexiChains.chain_indices`](@ref),
    [`FlexiChains.sampling_time`](@ref), and [`FlexiChains.last_sampler_state`](@ref).
    """
    _metadata::TMetadata

    @doc """
        FlexiChain{TKey}(
            niters::Int,
            nchains::Int,
            array_of_dicts::AbstractArray{<:AbstractDict,N};
            iter_indices::AbstractVector{Int}=1:niters,
            chain_indices::AbstractVector{Int}=1:nchains,
            sampling_time::AbstractVector{<:Union{Real,Missing}}=fill(missing, nchains),
            last_sampler_state::AbstractVector=fill(missing, nchains),
        ) where {TKey,N}

    Construct a `FlexiChain` from a vector or matrix of dictionaries. Each dictionary
    corresponds to one iteration.

    ## Data

    Each dictionary must be a mapping from a `ParameterOrExtra{<:TKey}` (i.e., either a
    `Parameter{<:TKey}` or an `Extra`) to its value at that iteration.

    If `array_of_dicts` is a vector (i.e., `N = 1`), then `niter` is the length of the
    vector and `nchains` is 1. If `array_of_dicts` is a matrix (i.e., `N = 2`), then
    `(niter, nchains) = size(dicts)`.

    Other values of `N` will error.

    ## Metadata

    `iter_indices` and `chain_indices` can be used to specify the iteration and chain
    indices, respectively. By default, these are `1:niters` and `1:nchains`, but can be any
    vector of integers of the appropriate length. `sampling_time` and `last_sampler_state`
    are used to store metadata about each chain. They should be given as vectors of length
    `nchains` (even if there is only one chain).

    ## Example usage

    ```julia
    d = fill(
        Dict(Parameter(:x) => rand(), Extra("y") => rand()), 200, 3
    )
    chn = FlexiChain{Symbol}(200, 3, d)
    ```
    """
    function FlexiChain{TKey}(
        niters::Int,
        nchains::Int,
        array_of_dicts::AbstractArray{<:AbstractDict};
        iter_indices::AbstractVector{Int}=1:niters,
        chain_indices::AbstractVector{Int}=1:nchains,
        sampling_time::AbstractVector{<:Union{Real,Missing}}=fill(missing, nchains),
        last_sampler_state::AbstractVector=fill(missing, nchains),
    ) where {TKey}
        # Construct metadata. We do this early so that if any of the inputs have the
        # wrong length we get an error before doing any more work.
        metadata = FlexiChainMetadata(
            niters, nchains, iter_indices, chain_indices, sampling_time, last_sampler_state
        )

        # Extract all unique keys from the dictionaries
        keys_set = OrderedSet{ParameterOrExtra{<:TKey}}()
        for d in array_of_dicts
            for k in keys(d)
                if !(k isa ParameterOrExtra{<:TKey})
                    msg = "all keys should either be `Parameter{<:$TKey}` or `Extra`; got `$(typeof(k))`."
                    throw(ArgumentError(msg))
                end
                push!(keys_set, k)
            end
        end

        # We have data as matrices-of-dict; we want to convert to dict-of-matrices.
        data = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
        for key in keys_set
            # Extract the values for this key from all dictionaries
            values = map(d -> get(d, key, missing), array_of_dicts)
            # Store in the data dictionary
            data[key] = _check_size(values, niters, nchains; key_name=key)
        end
        return new{TKey,typeof(metadata)}(data, metadata)
    end

    @doc """
        FlexiChain{TKey}(
            niters::Int,
            nchains::Int,
            dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}};
            iter_indices::AbstractVector{Int}=1:niters,
            chain_indices::AbstractVector{Int}=1:nchains,
            sampling_time::AbstractVector{<:Union{Real,Missing}}=fill(missing, nchains),
            last_sampler_state::AbstractVector=fill(missing, nchains),
        ) where {TKey,N}

    Construct a `FlexiChain` from a dictionary of arrays.

    ## Data

    Each key in the dictionary must subtype `ParameterOrExtra{<:TKey}` (i.e., it is either a
    `Parameter{<:TKey}` or an `Extra`). The values of the dictionary must all be of the same
    size.

    If the values are vectors (i.e., `N = 1`), then `niters` will be the length of the
    vector, and `nchains` will be 1. If the values are matrices (i.e., `N = 2`), then
    `(niter, nchains) = size(array)`.

    Other values of `N` will error.

    ## Metadata

    `iter_indices` and `chain_indices` can be used to specify the iteration and chain
    indices, respectively. By default, these are `1:niters` and `1:nchains`, but can be any
    vector of integers of the appropriate length. `sampling_time` and `last_sampler_state`
    are used to store metadata about each chain. They should be given as vectors of length
    `nchains` (even if there is only one chain).

    ## Example usage

    ```julia
    d = Dict(
        Parameter(:x) => rand(200, 3),
        Extra("y") => rand(200, 3),
    )
    chn = FlexiChain{Symbol}(200, 3, d)
    ```
    """
    function FlexiChain{TKey}(
        niters::Int,
        nchains::Int,
        dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any}};
        iter_indices::AbstractVector{Int}=1:niters,
        chain_indices::AbstractVector{Int}=1:nchains,
        sampling_time::AbstractVector{<:Union{Real,Missing}}=fill(missing, nchains),
        last_sampler_state::AbstractVector=fill(missing, nchains),
    ) where {TKey}
        # Construct metadata. We do this early so that if any of the inputs have the
        # wrong length we get an error before doing any more work.
        metadata = FlexiChainMetadata(
            niters, nchains, iter_indices, chain_indices, sampling_time, last_sampler_state
        )

        data = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
        for (key, array) in pairs(dict_of_arrays)
            # Check key type
            if !(key isa ParameterOrExtra{<:TKey})
                msg = "all keys should either be `Parameter{<:$TKey}` or `Extra`; got `$(typeof(key))`."
                throw(ArgumentError(msg))
            end
            # Check size and store in dictionary
            data[key] = _check_size(array, niters, nchains; key_name=key)
        end

        return new{TKey,typeof(metadata)}(data, metadata)
    end
end

"""
    iter_indices(chain::FlexiChain)::DimensionalData.Lookup

The indices of each MCMC iteration in the chain. This tries to reflect the actual iteration
numbers from the sampler: for example, if you discard the first 100 iterations and sampled
100 iterations but with a thinning factor of 2, this will be `101:2:300`.

The accuracy of this field is reliant on the sampler providing this information, though.
"""
iter_indices(chain::FlexiChain)::DDL.Lookup = chain._metadata.iter_indices

"""
    chain_indices(chain::FlexiChain)::DimensionalData.Lookup

The indices of each MCMC chain in the chain. This will pretty much always be
`1:nchains(chain)` (unless the chain has been subsetted, or chain indices have been manually
specified).
"""
chain_indices(chain::FlexiChain)::DDL.Lookup = chain._metadata.chain_indices

"""
    renumber_iters(
        chain::FlexiChain{TKey},
        iter_indices::AbstractVector{<:Integer}=1:niters(chain)
    )::FlexiChain{TKey} where {TKey}

Return a copy of `chain` with the iteration indices replaced by `iter_indices`.
"""
function renumber_iters(
    chain::FlexiChain{TKey}, iter_indices::AbstractVector{<:Integer}=1:niters(chain)
) where {TKey}
    return FlexiChain{TKey}(
        niters(chain),
        nchains(chain),
        chain._data;
        iter_indices=iter_indices,
        chain_indices=chain_indices(chain),
        sampling_time=sampling_time(chain),
        last_sampler_state=last_sampler_state(chain),
    )
end

"""
    renumber_chains(
        chain::FlexiChain{TKey},
        chain_indices::AbstractVector{<:Integer}=1:nchains(chain)
    )::FlexiChain{TKey} where {TKey}

Return a copy of `chain` with the chain indices replaced by `chain_indices`.
"""
function renumber_chains(
    chain::FlexiChain{TKey}, chain_indices::AbstractVector{<:Integer}=1:nchains(chain)
) where {TKey}
    return FlexiChain{TKey}(
        niters(chain),
        nchains(chain),
        chain._data;
        iter_indices=iter_indices(chain),
        chain_indices=chain_indices,
        sampling_time=sampling_time(chain),
        last_sampler_state=last_sampler_state(chain),
    )
end

"""
    sampling_time(chain::FlexiChain):Vector

Return the time taken to sample each chain (in seconds). If the time was not recorded, this
will be `missing`.

Note that this always returns a vector with length equal to the number of chains.
"""
sampling_time(chain::FlexiChain)::Vector{<:Union{Real,Missing}} =
    chain._metadata.sampling_time

const _INITIAL_STATE_DOCSTRING = """
!!! note "Returns a vector"

    This function *always* returns a vector of sampler states, even if there is only one chain.
    Consequently, if you are resuming a single-chain MCMC run like `sample(model, spl, N)`, you
    will need to extract the sole element of the returned vector before passing it as the
    `initial_state` keyword argument to `sample(). Please see the ['using with Turing'](@ref
    Saving-and-resuming-MCMC-sampling-progress) page, or [the Turing.jl documentation page
    on
    `initial_state`](https://turinglang.org/docs/usage/sampling-options/#saving-and-resuming-sampling),
    for more explanation of this.
"""

"""
    last_sampler_state(chain::FlexiChain)::Vector

Return the final state of the sampler used to generate the chain, if the `save_state=true`
keyword argument was passed to `sample`. This can be used for resuming MCMC sampling.

If the state was not saved for a given chain, its entry in the vector will be `missing`.

$(_INITIAL_STATE_DOCSTRING)
"""
function last_sampler_state(chain::FlexiChain)::Vector
    return chain._metadata.last_sampler_state
end

"""
    _get_raw_data(chain::FlexiChain{<:TKey}, key::ParameterOrExtra{<:TKey})

Extract the raw data (i.e. a matrix of samples) corresponding to a given key in the chain.

!!! important
    This function does not check if the key exists.
"""
function _get_raw_data(
    chain::FlexiChain{<:TKey}, key::ParameterOrExtra{<:TKey}
)::Matrix where {TKey}
    return chain._data[key]
end

"""
    _raw_to_user_data(chain::FlexiChain, data::Matrix)

Convert `data`, which is a raw matrix of samples, to a `DimensionalData.DimArray` using the
indices stored in in the `FlexiChain`. This is the format that users expect to obtain when
indexing into a `FlexiChain`.

!!! important
    This function performs no checks to make sure that the lengths of the indices stored in
the chain line up with the size of the matrix.
"""
function _raw_to_user_data(chain::FlexiChain, mat::Matrix)
    return DD.DimMatrix(
        mat,
        (
            DD.Dim{ITER_DIM_NAME}(iter_indices(chain)),
            DD.Dim{CHAIN_DIM_NAME}(chain_indices(chain)),
        ),
    )
end
