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

using ..FlexiChains:
    FlexiChain,
    ParameterOrExtra,
    VarName,
    _split_varnames,
    niters,
    _get_multi_keys,
    _get_multi_key
import DimensionalData as DD
import StatsBase

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

end # module PlotUtils
