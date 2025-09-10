using Statistics: mean, median, std

abstract type FlexiChainSummary{TKey,NIter,NChains} end

"""
    FlexiChainSummaryI{TKey,NIter,NChains}

A summary where the iteration dimension has been collapsed. The type parameter `NIter`
refers to the original number of iterations (which have been collapsed).

If NChains > 1, indexing into this returns a (1 × NChains) matrix for each key; otherwise
it returns a scalar.
"""
struct FlexiChainSummaryI{TKey,NIter,NChains} <: FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{<:ParameterOrExtra{TKey},<:SizedMatrix{1,NChains,<:Any}}
end
_get(fcsi::FlexiChainSummaryI{T,Ni,Nc}, key) where {T,Ni,Nc} = collect(fcsi._data[key]) # matrix
_get(fcsi::FlexiChainSummaryI{T,Ni,1}, key) where {T,Ni} = only(collect(fcsi._data[key])) # scalar

"""
    FlexiChainSummaryC{TKey,NIter,NChains}

A summary where the chain dimension has been collapsed. The type parameter `NChain` refers to
the original number of chains (which have been collapsed).

If NChains > 1, indexing into this returns a (NIter × 1) matrix for each key; otherwise it
returns a vector.
"""
struct FlexiChainSummaryC{TKey,NIter,NChains} <: FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{<:ParameterOrExtra{TKey},<:SizedMatrix{NIter,1,<:Any}}
end
_get(fcsc::FlexiChainSummaryC{T,N,M}, key) where {T,N,M} = collect(fcsc._data[key]) # matrix
_get(fcsc::FlexiChainSummaryC{T,N,1}, key) where {T,N} = data(fcsc._data[key]) # vector

"""
    FlexiChainSummaryIC{TKey,NIter,NChains}

A summary where both the iteration and chain dimensions have been collapsed. The type
parameters `NIter` and `NChains` refer to the original number of iterations and chains
(which have been collapsed).

Indexing into this returns a scalar for each key.
"""
struct FlexiChainSummaryIC{TKey,NIter,NChains} <: FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{<:ParameterOrExtra{TKey},<:SizedMatrix{1,1,<:Any}}
end
_get(fcsic::FlexiChainSummaryIC, key) = only(collect(fcsic._data[key])) # scalar

"""
    _collapse_ic(
        chain::FlexiChain{TKey,NIter,NChains}, func::Function; warn::Bool=true
    )::FlexiChainSummaryIC{TKey,NIter,NChains} where {TKey,NIter,NChains}

Collapse both the iteration and chain dimensions of `chain` by applying `func` to each key in the chain with numeric values.

The function `func` must map a matrix or vector of numbers to a scalar.

Non-numeric keys are skipped (with a warning if `warn` is true).
"""
function _collapse_ic(
    chain::FlexiChain{TKey,NIter,NChains}, func::Function; warn::Bool=false
)::FlexiChainSummaryIC{TKey,NIter,NChains} where {TKey,NIter,NChains}
    data = Dict{ParameterOrExtra{TKey},SizedMatrix{1,1,<:Any}}()
    for (k, v) in chain._data
        if eltype(v) <: Number
            collapsed = func(chain[k])
            data[k] = SizedMatrix{1,1}(reshape([collapsed], 1, 1))
        else
            warn && @warn "cannot collapse non-numeric data for key $k; skipping."
        end
    end
    return FlexiChainSummaryIC{TKey,NIter,NChains}(data)
end

function mean(
    chain::FlexiChain{TKey,NIter,NChains}; warn::Bool=false
)::FlexiChainSummaryIC{TKey,NIter,NChains} where {TKey,NIter,NChains}
    return _collapse_ic(chain, mean; warn=warn)
end
