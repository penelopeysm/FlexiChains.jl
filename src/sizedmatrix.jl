function check_size(data::AbstractMatrix, iters::Int, chains::Int; key_name=nothing)::Matrix
    if size(data) != (iters, chains)
        key_str = isnothing(key_name) ? "" : " for key $(key_name)"
        msg = "expected matrix of size ($(iters), $(chains))$(key_str), but got $(size(data))."
        throw(DimensionMismatch(msg))
    end
    return collect(data)
end
function check_size(data::AbstractVector, iters::Int, chains::Int; key_name=nothing)::Matrix
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

using DimensionalData: DimensionalData as DD
using DimensionalData.Dimensions.Lookups: Sampled
const ITER_DIM_NAME = :iter
const CHAIN_DIM_NAME = :chain

"""
    SizedMatrix{NIter,NChain,T} <: AbstractMatrix

A matrix type that is used to store the data in a [`FlexiChain`](@ref). It is just a plain
wrapper type, but with type parameters for the number of iterations and chains. This allows
us to have type-level guarantees about the size of the matrix.

`T` is the element type.

!!! warning
    Note that this is not part of FlexiChains's public API. Use this at your own risk.

## Fields

$(TYPEDFIELDS)
"""
struct SizedMatrix{NIter,NChain,T} <: AbstractArray{T,2}
    """
    Internal data.
    """
    _data::AbstractMatrix{T}

    function SizedMatrix{NIter,NChain}(data::AbstractMatrix{T}) where {NIter,NChain,T}
        if size(data) != (NIter, NChain)
            msg = "expected matrix of size ($(NIter), $(NChain)), got $(size(data))."
            throw(DimensionMismatch(msg))
        end
        return new{NIter,NChain,T}(collect(T, data))
    end
    function SizedMatrix{NIter,1}(data::AbstractVector{T}) where {NIter,T}
        if length(data) != (NIter)
            msg = "expected vector of length $(NIter), got $(length(data))."
            throw(DimensionMismatch(msg))
        end
        data = reshape(collect(T, data), NIter, 1) # Convert to matrix
        return new{NIter,1,T}(data)
    end
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
function Base.convert(
    ::Type{SizedMatrix{NIter,NChains,Tdst}}, s::SizedMatrix{NIter,NChains,Tsrc}
) where {NIter,NChains,Tsrc,Tdst}
    # collect() will error if it can't be casted
    return SizedMatrix{NIter,NChains,Tdst}(collect(Tdst, s))
end
