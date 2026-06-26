###########################################################
# Utility functions for plotting (shared across backends) #
###########################################################
#
# We stick these in a module to avoid cluttering the main FlexiChains namespace.

module PlotUtils

function _PARAM_DOCSTRING(funcname)
    return """
    If no parameters are specified, this will plot all parameters in the chain. Note that
    non-parameter, i.e. `Extra`, keys are excluded by default. If you want to plot _all_ keys,
    you can explicitly pass all keys with `$(funcname)(chn, :)`.
    """
end

const _POOL_CHAINS_DOCSTRING = """
The `pool_chains` keyword argument specifies whether to pool samples across multiple chains
when plotting. If `true` (the default), samples from all chains are pooled together; if
`false`, samples from each chain are plotted separately.
"""

const DEFAULT_WIDTH = 400
const DEFAULT_HEIGHT = 250

function get_hdi_intervals end  # Overloaded in PosteriorStatsExt
const DEFAULT_INTERVALS = (0.66, 0.95) # for forestplot

using ..FlexiChains:
    FlexiChain,
    ParameterOrExtra,
    VarName,
    _split_varnames,
    _get_raw_data,
    niters,
    _get_multi_keys,
    _get_multi_key
import DimensionalData as DD
import StatsBase
import Statistics

"""
Return a chain that has been:

1. Subsetted to just the parameters we want to plot; and

2. Split up such that each key corresponds to a single real-valued parameter.

This ensures that each plotting function can simply loop over the keys of the returned chain
and plot each one, without needing to worry about the structure of the data.
"""
function subset_and_split_chain(
        chn::FlexiChain{TKey}, param_or_params
    )::FlexiChain where {TKey}
    parameters_to_plot = if param_or_params isa Union{AbstractVector, Colon}
        _get_multi_keys(TKey, keys(chn), param_or_params)
    else
        # Assume it's a single key. No, don't ask what happens if the key type is an
        # AbstractVector...
        [_get_multi_key(TKey, keys(chn), param_or_params)]
    end
    # Subset the chain to just those parameters. Ordinarily we wouldn't need to do this; we
    # would just directly return `keys_to_plot`. However, there are some subtle
    # considerations when using VarName chains. See below for a full explanation.
    chn = chn[parameters_to_plot]
    # Split into real-valued parameters if possible.
    chn = _split_varnames(chn)
    return chn
end

"""
Check that the element type of the array is a subtype of `Real`.
"""
function check_eltype_is_real(::AbstractArray{T}) where {T}
    return if !(T <: Real)
        throw(
            ArgumentError(
                "plotting functions only support real-valued data; got data of type $T"
            ),
        )
    end
end

const DEFAULT_QUANTILE_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80, 90]

"""
Compute nested-quantile band values.

`quantile_levels` are in 0–100. For a matrix (`iter × chain`), each quantile is the
**ensemble estimate**: the empirical quantile is computed per chain (per column) and then
averaged across chains. For a vector (single chain) the quantile is computed directly.
Returns a vector of the same length as `quantile_levels`.
"""
function compute_quantile_bands(
        data::AbstractVector{<:Real},
        quantile_levels::AbstractVector{<:Real} = DEFAULT_QUANTILE_LEVELS,
    )
    return Statistics.quantile(Float64.(data), quantile_levels ./ 100)
end

function compute_quantile_bands(
        data::AbstractMatrix{<:Real},
        quantile_levels::AbstractVector{<:Real} = DEFAULT_QUANTILE_LEVELS,
    )
    probs = quantile_levels ./ 100
    nchains = size(data, 2)
    acc = zeros(Float64, length(probs))
    for c in axes(data, 2)
        acc .+= Statistics.quantile(Float64.(view(data, :, c)), probs)
    end
    return acc ./ nchains
end

"""Equal-width bin edges spanning the range of `values`; returns `nbins+1` edges.
`values` must be non-empty."""
function auto_bin_edges(values, nbins::Integer)
    isempty(values) && throw(ArgumentError("auto_bin_edges: `values` must be non-empty"))
    lo, hi = extrema(values)
    lo == hi && (hi = lo + 1)  # degenerate guard for constant input
    return collect(range(float(lo), float(hi); length = nbins + 1))
end

"""Count how many of `values` fall in each `[edges[b], edges[b+1])` bin.
Values equal to the final edge land in the last bin; out-of-range values are ignored.
Returns a `Vector{Int}` of length `length(edges) - 1`."""
function histogram_counts(values, edges)
    nbins = length(edges) - 1
    counts = zeros(Int, nbins)
    last_edge = last(edges)
    for v in values
        b = if v == last_edge
            nbins # clamp to last bin
        else
            searchsortedlast(edges, v)
        end
        if 1 <= b <= nbins
            counts[b] += 1
        end
    end
    return counts
end

"""For a collection of component series (each an `iter × chain` matrix), compute, for every
bin, the `iter × chain` matrix of per-draw counts (number of components falling in that bin).
All component matrices must share the same axes. Returns a `Vector` of length `nbins`, each
element a 1-based `iter × chain` `Matrix{Int}`."""
function bin_count_matrices(components::AbstractVector{<:AbstractMatrix{<:Real}}, edges)
    n_iter, n_chain = size(first(components))
    n_bins = length(edges) - 1
    counts = [zeros(Int, (n_iter, n_chain)) for _ in 1:n_bins]

    for c in 1:n_chain, i in 1:n_iter
        draw_vals = (component[i, c] for component in components)
        hc = histogram_counts(draw_vals, edges)
        for b in 1:n_bins
            counts[b][i, c] = hc[b]
        end
    end

    return counts
end

struct FlexiChainTrace{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
end

struct FlexiChainRank{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    # indicates which one to plot
    chn_idx
    # indexed by iter/chain -- note this matrix contains ranks for all chains because we
    # need to calculate ranks across all chains, even if we only plot one.
    ranks::DD.DimMatrix{<:Real}
end
function get_ranks(chn::FlexiChain{TKey}, param::Tp) where {TKey, Tp <: ParameterOrExtra{<:TKey}}
    return StatsBase.tiedrank(chn[param])
end

struct FlexiChainRankOverlay{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    ranks::DD.DimMatrix{<:Real} # same as above
end

struct FlexiChainHistogram{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

function runningmean(v::AbstractVector{<:Union{Real, Missing}})
    y = similar(v, Float64)
    n = 0
    sum = zero(eltype(v))
    for i in eachindex(v)
        if !ismissing(v[i])
            n += 1
            sum += v[i]
        end
        y[i] = sum / n
    end
    return y
end
struct FlexiChainMean{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
end

"""
Calculate default lags for autocorrelation plots. This is directly taken from StatsBase.jl.
"""
function default_lags(chn::FlexiChain)
    return 1:min(niters(chn) - 1, round(Int, 10 * log10(niters(chn))))
end
struct FlexiChainAutoCor{TKey, Tp <: ParameterOrExtra{<:TKey}, Tl <: AbstractVector{Int}}
    chn::FlexiChain{TKey}
    param::Tp
    lags::Tl
    demean::Bool
end

struct FlexiChainMixedDensity{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

struct FlexiChainDensity{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

struct FlexiChainViolin{TKey, Tp <: ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
    with_box::Bool
end

struct FlexiChainForest{TKey}
    chn::FlexiChain{TKey}
    params::Vector
    pool_chains::Bool
    point::Symbol
    interval::Symbol
    hdi_method::Symbol
    levels::Vector{Float64}
    function FlexiChainForest(chn::FlexiChain{TKey}, params::Vector, pool_chains::Bool, point = :median, interval = :quantile, hdi_method = :unimodal, levels = DEFAULT_INTERVALS) where {TKey}
        point in (:mean, :median) ||
            throw(ArgumentError("point must be :mean or :median, got :$point"))
        interval in (:quantile, :hdi) ||
            throw(ArgumentError("interval must be :quantile or :hdi, got :$interval"))
        all(l -> 0 < l < 1, levels) ||
            throw(ArgumentError("interval levels must be in (0, 1)"))
        sorted_levels = sort(collect(Float64, levels))
        return new{TKey}(chn, params, pool_chains, point, interval, hdi_method, sorted_levels)
    end
end

struct FlexiChainRidgeline{TKey}
    chn::FlexiChain{TKey}
    params::Vector
    pool_chains::Bool
end

end # module PlotUtils
