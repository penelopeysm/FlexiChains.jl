# Observations / samples run along `tfm.dims`
# This accessor should really be in StatsBase, I think
_obsdim(tfm::StatsBase.AbstractDataTransform) = tfm.dims

function _reconstruct_obsmat(
    tfm::StatsBase.AbstractDataTransform,
    m::AbstractMatrix{<:Real},
)
    if _obsdim(tfm) == 1
        StatsBase.reconstruct(tfm, m)
    else
        StatsBase.reconstruct(tfm, m')'
    end
end

# Scalar draws (Nx1, 1xN)
function _batch_reconstruct(
    tfm::StatsBase.AbstractDataTransform,
    vals::AbstractArray{<:Real},
)
    vec_as_matcol = reshape(vec(vals), :, 1)
    new_vals = _reconstruct_obsmat(tfm, vec_as_matcol)
    return reshape(vec(new_vals), size(vals))
end

# Vector draws (M vecs with N samples each)
function _batch_reconstruct(
    tfm::StatsBase.AbstractDataTransform,
    # `vec_of_vals` is a chain with vector-valued params
    vec_of_vals::AbstractArray{<:AbstractVector{<:Real}},
)
    m = length(first(vec_of_vals))
    if any(vals -> length(vals) != m, vec_of_vals)
        throw(DimensionMismatch("all draws must have equal length"))
    end

    X = reduce(hcat, vec_of_vals)' # NxM
    out = _reconstruct_obsmat(tfm, X)
    return reshape(collect.(eachrow(out)), size(vec_of_vals))
end

"""
    reconstruct(tfm::AbstractDataTransform, chn::FlexiChain{T}, param)

Perform a reconstruction into an original data scale from a transformed
parameter `param` using the transformation `tfm`.

See also https://juliastats.org/StatsBase.jl/stable/transformations/.
"""
function StatsBase.reconstruct(
    tfm::StatsBase.AbstractDataTransform,
    chn::FlexiChain{T},
    param,
) where {T}
    k = _resolve_getindex_key(T, keys(chn), param)
    data = copy(chn._data)
    data[k] = _batch_reconstruct(tfm, chn[k])
    return _replace_data(chn, T, data)
end
