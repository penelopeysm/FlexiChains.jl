using AbstractMCMC: AbstractChains

@public FlexiChain, Parameter, Extra, ParameterOrExtra
@public iter_indices, chain_indices, renumber_iter, renumber_chain
@public sampling_time, last_sampler_state

"""
    Parameter(name)

A named parameter in a `FlexiChain`. The name can be of any type, but all
parameters in a `FlexiChain` must have the same type for their names.

Specifically, if you have a `FlexiChain{TKey}`, then all parameters must be of
type `Parameter{TKey}`.
"""
struct Parameter{T}
    name::T
end

"""
    Extra(section_name::Symbol, key_name::Any)

A key in a `FlexiChain` that is not a parameter. FlexiChain allows for
such informations to be grouped into _sections_, which are identified by
`Symbol`s. The name of the key itself can be of any type and is not
constrained by the type of the `FlexiChain`.
"""
struct Extra{T}
    section_name::Symbol
    key_name::T
end

"""
    ParameterOrExtra{T}

Alias for `Union{Parameter{T},Extra}`.

All keys in a `FlexiChain{T}` must satisfy `k isa ParameterOrExtra{<:T}`.
"""
const ParameterOrExtra{T} = Union{Parameter{T},Extra}

"""
    FlexiChainMetadata

A struct to hold common kinds of metadata typically associated with a chain.
"""
struct FlexiChainMetadata{Ttime<:Union{Real,Missing},Tstate}
    sampling_time::Ttime
    last_sampler_state::Tstate
end

_check_length(n::Int, ::Missing, ::AbstractString) = fill(missing, n)
function _check_length(n::Int, v::AbstractVector, s::AbstractString)
    if length(v) != n
        msg = "expected `$s` to have length $n, got $(length(v))."
        throw(DimensionMismatch(msg))
    end
    return v
end
function _check_length(n::Int, v::Any, s::AbstractString)
    if n == 1
        return [v]
    else
        msg = "expected `$s` to be a vector of length $n, but got $(typeof(v))."
        throw(DimensionMismatch(msg))
    end
end

function _infer_size(array_of_dicts::AbstractArray{<:AbstractDict,N}) where {N}
    return if N == 1
        length(array_of_dicts), 1
    elseif N == 2
        size(array_of_dicts)
    else
        throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
    end
end
function _infer_size(dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}) where {N}
    return if isempty(dict_of_arrays)
        0, 0  # If no data, assume 0 iters and 0 chains
    elseif N == 1
        length(first(values(dict_of_arrays))), 1
    elseif N == 2
        size(first(values(dict_of_arrays)))
    else
        throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
    end
end

"""
    struct FlexiChain{
        TKey,NIter,NChains,
        TIIdx<:AbstractVector{<:Integer},
        TCIdx<:AbstractVector{<:Integer},
        TMetadata<:NTuple{NChains,FlexiChainMetadata}
    } <: AbstractMCMC.AbstractChains

An MCMC chain.

!!! warning

    Please note that all fields of the FlexiChain type are considered internal. Furthermore,
the ordering of keys within a `FlexiChain` is an implementation detail and is not
guaranteed.

TODO: Document further.

## Fields

$(TYPEDFIELDS)
"""
struct FlexiChain{
    TKey,
    NIter,
    NChains,
    TIIdx<:AbstractVector{<:Integer},
    TCIdx<:AbstractVector{<:Integer},
    TMetadata<:NTuple{NChains,FlexiChainMetadata},
} <: AbstractChains
    """
    Internal per-iteration data for parameters and extra keys. To access the data
    in here, you should index into the chain.
    """
    _data::Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,NChains,<:Any}}

    """
    The indices of each MCMC iteration in the chain. This tries to reflect the actual
    iteration numbers from the sampler: for example, if you discard the first 100 iterations
    and sampled 100 iterations but with a thinning factor of 2, this will be `101:2:300`. Do
    not access this directly; you can use [`FlexiChains.iter_indices`](@ref) instead.
    """
    _iter_indices::TIIdx

    """
    The indices of each MCMC chain in the chain. This will pretty much always be `1:NChains`
    (unless the chain has been subsetted). Do not access this directly; you can use
    [`FlexiChains.chain_indices`](@ref) instead.
    """
    _chain_indices::TCIdx

    """
    Other items associated with the chain. These are not necessarily per-iteration (for
    example there may only be one per chain).

    You should not access this directly; instead you should use the accessor functions (e.g.
    `sampling_time(chain)`).
    """
    _metadata::TMetadata

    @doc """
        FlexiChain{TKey,NIter,NChains}(
            array_of_dicts::AbstractArray{<:AbstractDict,N};
            iter_indices::AbstractVector{Int}=1:NIter,
            chain_indices::AbstractVector{Int}=1:NChains,
            sampling_time::Any=missing,
            last_sampler_state::Any=missing,
        ) where {TKey,N}

    Construct a `FlexiChain` from a vector or matrix of dictionaries. Each dictionary
    corresponds to one iteration.

    Each dictionary must be a mapping from a `ParameterOrExtra{<:TKey}` (i.e., either a
    `Parameter{<:TKey}` or an `Extra`) to its value at that iteration.

    If `array_of_dicts` is a vector (i.e., `N = 1`), then `niter` is the length of the
    vector and `nchains` is 1. If `array_of_dicts` is a matrix (i.e., `N = 2`), then
    `(niter, nchains) = size(dicts)`.

    Other values of `N` will error.

    `sampling_time` and `last_sampler_state` are used to store metadata about each chain. If
    there is more than one chain (i.e., if size(array_of_dicts, 2) > 1), the parameters
    `sampling_time` and `last_sampler_state` must be vectors with length equal to the number
    of chains. If there is only one chain, they should be scalars.

    ## Example usage

    ```julia
    d = fill(
        Dict(Parameter(:x) => rand(), Extra(:section, "y") => rand()), 200, 3
    )
    chn = FlexiChain{Symbol,200,3}(d)
    ```
    """
    function FlexiChain{TKey,NIter,NChains}(
        array_of_dicts::AbstractArray{<:AbstractDict};
        iter_indices::AbstractVector{Int}=1:NIter,
        chain_indices::AbstractVector{Int}=1:NChains,
        sampling_time::Any=missing,
        last_sampler_state::Any=missing,
    ) where {TKey,NIter,NChains}
        # Check iter and chain indices
        iter_indices = _check_length(NIter, iter_indices, "iter_indices")
        chain_indices = _check_length(NChains, chain_indices, "chain_indices")

        # Extract all unique keys from the dictionaries
        keys_set = Set{ParameterOrExtra{<:TKey}}()
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
        data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,NChains}}()
        for key in keys_set
            # Extract the values for this key from all dictionaries
            values = map(d -> get(d, key, missing), array_of_dicts)
            # Convert to SizedMatrix
            values_smat = SizedMatrix{NIter,NChains}(values)
            # Store in the data dictionary
            data[key] = values_smat
        end

        # Construct metadata
        sampling_time = _check_length(NChains, sampling_time, "sampling_time")
        last_sampler_state = _check_length(
            NChains, last_sampler_state, "last_sampler_state"
        )
        metadata = tuple(
            [
                FlexiChainMetadata(sampling_time[i], last_sampler_state[i]) for
                i in 1:NChains
            ]...,
        )

        return new{
            TKey,NIter,NChains,typeof(iter_indices),typeof(chain_indices),typeof(metadata)
        }(
            data, iter_indices, chain_indices, metadata
        )
    end

    @doc """
        FlexiChain{TKey,NIter,NChains}(
            dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}};
            sampling_time::Any=missing,
            last_sampler_state::Any=missing,
        ) where {TKey,N}

    Construct a `FlexiChain` from a dictionary of arrays.

    Each key in the dictionary must subtype `ParameterOrExtra{<:TKey}` (i.e., it is either a
    `Parameter{<:TKey}` or an `Extra`). The values of the dictionary must all be of the same
    size.

    If the values are vectors (i.e., `N = 1`), then `niters` will be the length of the
    vector, and `nchains` will be 1. If the values are matrices (i.e., `N = 2`), then
    `(niter, nchains) = size(array)`.

    Other values of `N` will error.

    `sampling_time` and `last_sampler_state` are used to store metadata about each chain. If
    there is more than one chain (i.e., for some value `v` in `dict_of_arrays`, size(v, 2) >
    1), the parameters `sampling_time` and `last_sampler_state` must be vectors with length
    equal to the number of chains. If there is only one chain, they should be scalars.

    ## Example usage

    ```julia
    d = Dict(
        Parameter(:x) => rand(200, 3),
        Extra(:section, "y") => rand(200, 3),
    )
    chn = FlexiChain{Symbol,200,3}(d)
    ```
    """
    function FlexiChain{TKey,NIter,NChains}(
        dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any}};
        iter_indices::AbstractVector{Int}=1:NIter,
        chain_indices::AbstractVector{Int}=1:NChains,
        sampling_time::Any=missing,
        last_sampler_state::Any=missing,
    ) where {TKey,NIter,NChains}
        # Check iter and chain indices
        iter_indices = _check_length(NIter, iter_indices, "iter_indices")
        chain_indices = _check_length(NChains, chain_indices, "chain_indices")

        data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,NChains}}()
        for (key, array) in pairs(dict_of_arrays)
            # Check key type
            if !(key isa ParameterOrExtra{<:TKey})
                msg = "all keys should either be `Parameter{<:$TKey}` or `Extra`; got `$(typeof(key))`."
                throw(ArgumentError(msg))
            end
            # Check size
            if array isa AbstractVector
                if length(array) != NIter
                    msg = "data for key $key has an inconsistent size: expected $(NIter), got $(length(array))."
                    throw(DimensionMismatch(msg))
                end
            elseif array isa AbstractMatrix
                if size(array) != (NIter, NChains)
                    msg = "data for key $key has an inconsistent size: expected ($(NIter), $(NChains)), got $(size(array))."
                    throw(DimensionMismatch(msg))
                end
            end
            # Convert to SMatrix
            mat = SizedMatrix{NIter,NChains}(array)
            data[key] = mat
        end

        # Construct metadata
        sampling_time = _check_length(NChains, sampling_time, "sampling_time")
        last_sampler_state = _check_length(
            NChains, last_sampler_state, "last_sampler_state"
        )
        metadata = tuple(
            [
                FlexiChainMetadata(sampling_time[i], last_sampler_state[i]) for
                i in 1:NChains
            ]...,
        )

        return new{
            TKey,NIter,NChains,typeof(iter_indices),typeof(chain_indices),typeof(metadata)
        }(
            data, iter_indices, chain_indices, metadata
        )
    end
end

"""
    iter_indices(chain::FlexiChain)

The indices of each MCMC iteration in the chain. This tries to reflect the actual iteration
numbers from the sampler: for example, if you discard the first 100 iterations and sampled
100 iterations but with a thinning factor of 2, this will be `101:2:300`.

The accuracy of this field is reliant on the sampler providing this information, though.
"""
iter_indices(chain::FlexiChain{T,NI,NC,TIIdx}) where {T,NI,NC,TIIdx} = chain._iter_indices

"""
    renumber_iter(
        chain::FlexiChain,
        iter_indices::AbstractVector{<:Integer}=1:NIter
    )

Return a copy of `chain` with the iteration indices replaced by `iter_indices`.
"""
function renumber_iter(
    chain::FlexiChain{TKey,NIter,NChain}, iter_indices::AbstractVector{<:Integer}=1:NIter
)::FlexiChain{TKey,NIter,NChain} where {TKey,NIter,NChain}
    return FlexiChain{TKey,NIter,NChain}(
        chain._data;
        iter_indices=iter_indices,
        chain_indices=chain_indices(chain),
        sampling_time=sampling_time(chain),
        last_sampler_state=last_sampler_state(chain),
    )
end

"""
    renumber_chain(
        chain::FlexiChain,
        chain_indices::AbstractVector{<:Integer}=1:NChains
    )

Return a copy of `chain` with the chain indices replaced by `chain_indices`.
"""
function renumber_chain(
    chain::FlexiChain{TKey,NIter,NChains},
    chain_indices::AbstractVector{<:Integer}=1:NChains,
)::FlexiChain{TKey,NIter,NChains} where {TKey,NIter,NChains}
    return FlexiChain{TKey,NIter,NChains}(
        chain._data;
        iter_indices=iter_indices(chain),
        chain_indices=chain_indices,
        sampling_time=sampling_time(chain),
        last_sampler_state=last_sampler_state(chain),
    )
end

"""
    chain_indices(chain::FlexiChain)

The indices of each MCMC chain in the chain. This will pretty much always be `1:NChains`
(unless the chain has been subsetted).
"""
chain_indices(chain::FlexiChain{T,NI,NC,TIIdx,TCIdx}) where {T,NI,NC,TIIdx,TCIdx} =
    chain._chain_indices

"""
    sampling_time(chain::FlexiChain):Vector

Return the time taken to sample the chain (in seconds). If the time was not recorded, this
will be `missing`.

Note that this always returns a vector with length equal to the number of chains.
"""
function sampling_time(
    chain::FlexiChain{TKey,NIter,NChains}
)::Vector{<:Union{Real,Missing}} where {TKey,NIter,NChains}
    return collect(map(m -> m.sampling_time, chain._metadata))
end

"""
    last_sampler_state(chain::FlexiChain)::Vector

Return the final state of the sampler used to generate the chain, if the `save_state=true`
keyword argument was passed to `sample`. This can be used for resuming MCMC sampling.

Note that this always returns a vector with length equal to the number of chains.

If the state was not saved, this will be `missing` (or a vector thereof).
"""
function last_sampler_state(
    chain::FlexiChain{TKey,NIter,NChains}
)::Vector where {TKey,NIter,NChains}
    return collect(map(m -> m.last_sampler_state, chain._metadata))
end
