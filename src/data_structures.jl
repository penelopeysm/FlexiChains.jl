using AbstractMCMC: AbstractMCMC

export FlexiChain, Parameter, Extra, FlexiChainKey

"""
    SizedMatrix{NIter,NChains,T}

A matrix type that is used to store the data in a `FlexiChain`. It is similar
to `StaticArrays.SMatrix` in terms of its type behaviour, but under the hood
uses plain `Array`s for storage. This allows us to have type-level guarantees
about the size of the matrix, without having to opt into the performance
characteristics and data structures of `StaticArrays`.

`T` is the element type.

The underlying data in a SizedMatrix can be accessed using
`data(::SizedMatrix)`. If the matrix has only one chain, it will be
returned as a vector. If it has multiple chains, it will be returned as a
matrix.

## Fields

$(TYPEDFIELDS)
"""
struct SizedMatrix{NIter,NChains,T} <: AbstractArray{T,2}
    """
    Internal data. Do not access this directly! Use `data(::SizedMatrix)` instead.
    """
    _data::Matrix{T}

    function SizedMatrix{NIter,NChains}(data::AbstractMatrix{T}) where {NIter,NChains,T}
        if size(data) != (NIter, NChains)
            msg = "expected matrix of size ($(NIter), $(NChains)), got $(size(data))."
            throw(DimensionMismatch(msg))
        end
        return new{NIter,NChains,T}(collect(T, data))
    end
    function SizedMatrix{NIter,1}(data::AbstractVector{T}) where {NIter,T}
        if length(data) != (NIter)
            msg = "expected vector of length $(NIter), got $(length(data))."
            throw(DimensionMismatch(msg))
        end
        return new{NIter,1,T}(reshape(data, NIter, 1)) # convert vector to matrix.
    end
end
"""
    data(s::SizedMatrix{NIter,NChains,T}) where {NIter,NChains,T}

Return the underlying data of a `SizedMatrix` as a matrix, or a vector if
`NChains` is 1.

Note that this differs from `Base.collect`, which always returns a matrix.
"""
function data(s::SizedMatrix{NIter,1,T}) where {NIter,T}
    return vec(s._data)
end
function data(s::SizedMatrix{NIter,NChains,T}) where {NIter,NChains,T}
    return s._data
end
function Base.collect(
    ::Type{Tdst}, s::SizedMatrix{NIter,NChains,T}
) where {NIter,NChains,T,Tdst}
    return collect(Tdst, s._data)
end
function Base.eltype(::Type{SizedMatrix{NIter,NChains,T}}) where {NIter,NChains,T}
    return T
end
function Base.size(::SizedMatrix{NIter,NChains}) where {NIter,NChains}
    return (NIter, NChains)
end
function Base.getindex(
    s::SizedMatrix{NIter,NChains,T}, i::Int, j::Int
) where {NIter,NChains,T}
    return s._data[i, j]
end
function Base.getindex(s::SizedMatrix{NIter,1,T}, i::Int) where {NIter,T}
    return s._data[i, 1]
end
"""
    cast_to_type(::Type{Tdst}, s::SizedMatrix{NIter,NChains,Tsrc}) where {NIter,NChains,Tsrc,Tdst}

Cast the underlying data of a `SizedMatrix` to a different element type.
"""
function Base.convert(
    ::Type{SizedMatrix{NIter,NChains,Tdst}}, s::SizedMatrix{NIter,NChains,Tsrc}
) where {NIter,NChains,Tsrc,Tdst}
    Tsrc <: Tdst && return s
    # collect() will error if it can't be casted
    return SizedMatrix{NIter,NChains}(collect(Tdst, s))
end

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
    FlexiChainKey{T}

Either a `Parameter{T}`, or an `Extra`.

All keys in a `FlexiChain{T}` must be a `FlexiChainKey{T}`.
"""
const FlexiChainKey{T} = Union{Parameter{<:T},Extra}

"""
    FlexiChain{TKey,NIter,NChains,Sections}

Note that the ordering of keys within a `FlexiChain` is an
implementation detail and is not guaranteed.

TODO: Document further.

## Fields

$(TYPEDFIELDS)
"""
struct FlexiChain{TKey,NIter,NChains} <: AbstractMCMC.AbstractChains
    """
    Internal data. Do not access this directly unless you know what you are doing!
    You should use the interface methods defined instead.
    """
    _data::Dict{<:FlexiChainKey{TKey},<:SizedMatrix{NIter,NChains,<:Any}}

    @doc """
        FlexiChain{TKey}(
            array_of_dicts::AbstractArray{<:AbstractDict,N}
        ) where {TKey,N}

    Construct a `FlexiChain` from a vector or matrix of dictionaries. Each
    dictionary corresponds to one iteration.

    Each dictionary must be a mapping from a `FlexiChainKey{TKey}` (i.e.,
    either a `Parameter{TKey}` or an `Extra`) to its value at that
    iteration.

    If `array_of_dicts` is a vector (i.e., `N = 1`), then `niter` is the length
    of the vector and `nchains` is 1. If `array_of_dicts` is a matrix (i.e., `N
    = 2`), then `(niter, nchains) = size(dicts)`.

    Other values of `N` will error.

    ## Example usage

    ```julia
    d = fill(
        Dict(Parameter(:x) => rand(), Extra(:section, "y") => rand()), 200, 3
    )
    chn = FlexiChain{Symbol}(d)
    ```
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
                    msg = "all keys should either be `Parameter{<:$TKey}` or `Extra`; got `$(typeof(k))`."
                    throw(ArgumentError(msg))
                end
                push!(keys_set, k)
            end
        end

        # We have data as matrices-of-dict; we want to convert to dict-of-matrices.
        data = Dict{FlexiChainKey{TKey},SizedMatrix{niter,nchains}}()
        for key in keys_set
            # Extract the values for this key from all dictionaries
            values = map(d -> get(d, key, missing), array_of_dicts)
            # Convert to SizedMatrix
            values_smat = SizedMatrix{niter,nchains}(values)
            # Store in the data dictionary
            data[key] = values_smat
        end

        return new{TKey,niter,nchains}(data)
    end

    @doc """
        FlexiChain{TKey}(
            dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
        ) where {TKey,N}

    Construct a `FlexiChain` from a dictionary of arrays.

    Each key in the dictionary must subtype `FlexiChainKey{TKey}` (i.e., it is
    either a `Parameter{TKey}` or an `Extra`). The values of the dictionary
    must all be of the same size.

    If the values are vectors (i.e., `N = 1`), then `niters` will be the length
    of the vector, and `nchains` will be 1. If the values are matrices (i.e.,
    `N = 2`), then `(niter, nchains) = size(array)`.

    Other values of `N` will error.

    ## Example usage

    ```julia
    d = Dict(
        Parameter(:x) => rand(200, 3),
        Extra(:section, "y") => rand(200, 3),
    )
    chn = FlexiChain{Symbol}(d)
    ```
    """
    function FlexiChain{TKey}(
        dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
    ) where {TKey,N}
        # If no data, assume 0 iters and 0 chains.
        if isempty(dict_of_arrays)
            return FlexiChain{TKey,0,0}(Dict{FlexiChainKey{TKey},SizedMatrix{0,0}}())
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

        data = Dict{FlexiChainKey{TKey},SizedMatrix{niter,nchains}}()
        for (key, array) in pairs(dict_of_arrays)
            # Check key type
            if !(key isa FlexiChainKey{TKey})
                msg = "all keys should either be `Parameter{<:$TKey}` or `Extra`; got `$(typeof(key))`."
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
            mat = SizedMatrix{niter,nchains}(array)
            data[key] = mat
        end

        return new{TKey,niter,nchains}(data)
    end
end
