# Note that this file isn't in a module. Hence, all the imports / exports are
# global.

using AbstractMCMC: AbstractMCMC
using StaticArrays: SMatrix

export FlexiChain, Parameter, OtherKey

"""
    Parameter(name::Any)

A named parameter in a `FlexiChain`.
"""
struct Parameter{T}
    name::T
end

"""
    OtherKey(section_name::Symbol, key::Any)

A key in a `FlexiChain` that is not a parameter. FlexiChain allows for
such informations to be grouped into _sections_, which are identified by
`Symbol`s. The name of the key itself can be of any type.
"""
struct OtherKey{T}
    section_name::Symbol
    key::T
end

"""
    FlexiChainKey{T}

Either a `Parameter{T}`, or an `OtherKey`.
"""
const FlexiChainKey{T} = Union{Parameter{<:T},OtherKey{<:Any}}

"""
    FlexiChain{TKey,NIter,NChains,Sections}

TODO: Document further.

StaticArrays.jl is used not for performance but rather for type-level storage
of the number of iterations and chains. This allows us to have compile-time
guarantees that the sizes of the arrays are constant across all parameters
(which must necessarily be true for a Markov chain).
"""
struct FlexiChain{TKey,NIter,NChains} <: AbstractMCMC.AbstractChains
    data::Dict{FlexiChainKey{TKey},SMatrix{NIter,NChains,Any}}

    """
        FlexiChain{TKey}(
            array_of_dicts::AbstractArray{<:AbstractDict}
        ) where {TKey}

    Construct a `FlexiChain` from a vector or matrix of dictionaries. Each
    dictionary corresponds to one iteration.

    Each dictionary must be a mapping from a `FlexiChainKey{TKey}` (i.e.,
    either a `Parameter{TKey}` or an `OtherKey`) to its value at that
    iteration.

    If `dicts` is a vector, then `niter` is the length of the vector and
    `nchains` is 1. If `dicts` is a matrix, then `(niter, nchains) =
    size(dicts)`.
    """
    function FlexiChain{TKey}(
        array_of_dicts::AbstractArray{<:AbstractDict,N}
    ) where {TKey,N}
        # Determine size
        niter, nchains = if N == 1
            length(array_of_dicts), 1
        elseif N == 2
            size(array_of_dicts)
        else
            throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
        end

        # Extract all unique keys from the dictionaries
        keys_set = Set{FlexiChainKey{TKey}}()
        for d in array_of_dicts
            for k in keys(d)
                if !(k isa FlexiChainKey{TKey})
                    msg = "all keys should either be `Parameter{<:$TKey}` or `OtherKey`; got `$(typeof(k))`."
                    throw(ArgumentError(msg))
                end
                push!(keys_set, k)
            end
        end
        @show keys_set

        # We have data as matrices-of-dict; we want to convert to dict-of-matrices.
        data = Dict{FlexiChainKey{TKey},SMatrix{niter,nchains,Any}}()
        for key in keys_set
            # Extract the values for this key from all dictionaries
            values = map(d -> get(d, key, missing), array_of_dicts)
            # Convert to SMatrix
            values_smat = SMatrix{niter,nchains}(values)
            # Store in the data dictionary
            data[key] = values_smat
        end

        return new{TKey,niter,nchains}(data)
    end

    """
        FlexiChain{TKey}(
            dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
        ) where {TKey,N}
    """
    function FlexiChain{TKey}(
        dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
    ) where {TKey,N}
        # If no data, assume 0 iters and 0 chains.
        if isempty(dict_of_arrays)
            return FlexiChain{TKey,0,0}(Dict{FlexiChainKey{TKey},SMatrix{0,0}}())
        end

        # dict_of_arrays is already in the correct form, but we need to do some
        # upfront work to check the keys are consistent, and also ensure that
        # the sizes are consistent (and convert to SMatrix).
        niter, nchains = if N == 1
            length(first(values(dict_of_arrays))), 1
        elseif N == 2
            size(first(values(dict_of_arrays)))
        else
            throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
        end

        data = Dict{FlexiChainKey{TKey},SMatrix{niter,nchains,Any}}()
        for (key, array) in pairs(dict_of_arrays)
            # Check key type
            if !(key isa FlexiChainKey{TKey})
                msg = "all keys should either be `Parameter{<:$TKey}` or `OtherKey`; got `$(typeof(key))`."
                throw(ArgumentError(msg))
            end
            # Check size
            if array isa AbstractVector
                if length(array) != niter
                    msg = "data for key $key has an inconsistent size: expected $(niter), got $(length(array))."
                    throw(DimensionMismatch(msg))
                end
            elseif array isa AbstractMatrix
                if size(array) != (niter, nchains)
                    msg = "data for key $key has an inconsistent size: expected ($(niter), $(nchains)), got $(size(array))."
                    throw(DimensionMismatch(msg))
                end
            end
            # Convert to SMatrix
            mat = SMatrix{niter,nchains}(array)
            data[key] = mat
        end

        return new{TKey,niter,nchains}(data)
    end
end

function Base.size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}
    num_objects = length(chain.data)
    return (NIter, num_objects, NChains)
end
