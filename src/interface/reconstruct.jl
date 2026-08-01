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
    draws::AbstractArray{<:Real},
)
    vec_as_matcol = reshape(draws, :, 1)
    new_vals = _reconstruct_obsmat(tfm, vec_as_matcol)
    return reshape(new_vals, size(draws))
end

# Vector draws
# `draws` is length N (iter, chain), each containing length M param
function _batch_reconstruct(
    tfm::StatsBase.AbstractDataTransform,
    draws::Matrix{<:AbstractVector},
)
    m = length(first(draws))
    X = reshape(stack(draws), m, :)' # N * M, where M = niters*nchains
    new_vals = _reconstruct_obsmat(tfm, X)
    return reshape(collect.(eachrow(new_vals)), size(draws))
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
    data[k] = _batch_reconstruct(tfm, data[k])
    return _replace_data(chn, T, data)
end
