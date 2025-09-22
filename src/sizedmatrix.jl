using DimensionalData: DimensionalData as DD
using DimensionalData.Dimensions.Lookups: Sampled
using DimensionalData.Dimensions: AnonDim
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
"""
    data(
        s::SizedMatrix{NIter,NChains,T};
        iter_indices=1:NIter,
        chain_indices=1:NChains
    ) where {NIter,NChains,T}

Return the underlying data of a `SizedMatrix` as a [`DimensionalData.DimMatrix`](@extref DimensionalData DimArrays).

The returned `DimMatrix` has dimensions named `:iter` and `:chain`. By default the indices
along both dimensions simply count upwards from 1. You can override this by passing in
custom `iter_indices` and `chain_indices` keyword arguments.

Note that this differs from `Base.collect`, which always returns a plain `Matrix`.
"""
function data(
    s::SizedMatrix{NIter,NChains,T}; iter_indices=1:NIter, chain_indices=1:NChains
) where {NIter,NChains,T}
    return DD.DimMatrix(
        s._data,
        (DD.Dim{ITER_DIM_NAME}(iter_indices), DD.Dim{CHAIN_DIM_NAME}(chain_indices)),
    )
end
function data_anon_iter(
    s::SizedMatrix{1,NChains,T}; chain_indices=1:NChains
) where {NChains,T}
    return DD.DimMatrix(s._data, (AnonDim(), DD.Dim{CHAIN_DIM_NAME}(chain_indices)))
end
function data_anon_chain(s::SizedMatrix{NIter,1,T}; iter_indices=1:NIter) where {NIter,T}
    return DD.DimMatrix(s._data, (DD.Dim{ITER_DIM_NAME}(iter_indices), AnonDim()))
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
