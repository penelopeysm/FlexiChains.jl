function _PARAM_DOCSTRING(funcname)
    return """
    If no parameters are specified, this will plot all parameters in the chain. Note that
    non-parameter, i.e. `Extra`, keys are excluded by default. If you want to plot _all_ keys,
    you can explicitly pass all keys with `$(funcname)(chn, :)`.
    """
end

const _PLOTS_KWARGS_DOCSTRING = "Other keyword arguments are forwarded to the underlying Plots.jl functions."

######################
# Plots.jl overloads #
######################
"""
    FlexiChains.traceplot(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Plot the sample values against iteration number for the specified parameter(s) in the given
`FlexiChain` using Plots.jl.

$(_PARAM_DOCSTRING("traceplot"))

$(_PLOTS_KWARGS_DOCSTRING)
"""
function traceplot end

"""
    FlexiChains.traceplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.traceplot`, but uses `plot!` instead of `plot`.
"""
function traceplot! end

"""
    FlexiChains.mixeddensity(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Plot a density estimate or histogram for the specified parameter(s) in the given
`FlexiChain` using Plots.jl. Continuous-valued parameters are plotted as density estimates,
discrete-valued parameters as histograms.

$(_PARAM_DOCSTRING("mixeddensity"))

$(_PLOTS_KWARGS_DOCSTRING)
"""
function mixeddensity end

"""
    FlexiChains.mixeddensity!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.mixeddensity`, but uses `plot!` instead of `plot`.
"""
function mixeddensity! end

"""
    FlexiChains.meanplot(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Plot the running mean of the specified parameter(s) in the given `FlexiChain` using
Plots.jl.

$(_PARAM_DOCSTRING("meanplot"))

$(_PLOTS_KWARGS_DOCSTRING)
"""
function meanplot end

"""
    FlexiChains.meanplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.meanplot`, but uses `plot!` instead of `plot`.
"""
function meanplot! end

"""
    FlexiChains.rankplot(
        chn::FlexiChain{TKey}[, param_or_params];
        overlay::Bool=false,
        kwargs...
    )

Plot a histogram of ranks for the specified parameter(s) in the given `FlexiChain` using
Plots.jl.

$(_PARAM_DOCSTRING("rankplot"))

If `overlay` is `false` (the default), a separate histogram is plotted for each chain.
If `true`, the histograms for all chains are overlaid on a single plot with different
colours.

$(_PLOTS_KWARGS_DOCSTRING)
"""
function rankplot end

"""
    FlexiChains.rankplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        overlay::Bool=false,
        kwargs...
    )

Same as `FlexiChains.rankplot`, but uses `plot!` instead of `plot`.
"""
function rankplot! end

"""
    FlexiChains.autocorplot(
        chn::FlexiChain{TKey}[, param_or_params];
        lags=1:min(niters(chn)-1, round(Int,10*log10(niters(chn)))),
        demean=true,
        kwargs...
    )

Plot the autocorrelation of the specified parameter(s) in the given `FlexiChain` using
Plots.jl.

$(_PARAM_DOCSTRING("autocorplot"))

The `lags` keyword argument specifies which lags to plot. By default, this is set to the
integers from 1 to `min(niters-1, round(Int,10*log10(niters)))`, mimicking the default
behaviour of [`StatsBase.autocor`](@extref).

The `demean` keyword argument specifies whether to subtract the mean before computing the
autocorrelation (default `true`), and is passed to [`StatsBase.autocor`](@extref).

$(_PLOTS_KWARGS_DOCSTRING)
"""
function autocorplot end

"""
    FlexiChains.autocorplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.autocorplot`, but uses `plot!` instead of `plot`.
"""
function autocorplot! end

###################
# Makie overloads #
###################

function mtraceplot end

"""
    FlexiChains.mtraceplot!

Mutating version of `mtraceplot`, for use with existing Makie.Axis objects.
"""
function mtraceplot! end

function mrankplot end

"""
    FlexiChains.mrankplot!

Mutating version of `mrankplot`, for use with existing Makie.Axis objects.
"""
function mrankplot! end

function mmixeddensity end

"""
    FlexiChains.mmixeddensity!

Mutating version of `mmixeddensity`, for use with existing Makie.Axis objects.
"""
function mmixeddensity! end

###########################################################
# Utility functions for plotting (shared across backends) #
###########################################################
#
# We stick these in a module to avoid cluttering the main FlexiChains namespace.

module PlotUtils

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

end # module PlotUtils
