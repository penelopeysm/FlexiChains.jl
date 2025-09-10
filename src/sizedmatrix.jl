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
function data(s::SizedMatrix{NIter,NChains,T}) where {NIter,NChains,T}
    return s._data
end
function data(s::SizedMatrix{NIter,1,T}) where {NIter,T}
    return vec(s._data)
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
function Base.convert(
    ::Type{SizedMatrix{NIter,NChains,Tdst}}, s::SizedMatrix{NIter,NChains,Tsrc}
) where {NIter,NChains,Tsrc,Tdst}
    Tsrc <: Tdst && return s
    # collect() will error if it can't be casted
    return SizedMatrix{NIter,NChains}(collect(Tdst, s))
end
