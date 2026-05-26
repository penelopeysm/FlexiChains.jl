######################
# Plots.jl overloads #
######################

module Plots

import ..PlotUtils: _PARAM_DOCSTRING, _POOL_CHAINS_DOCSTRING

export traceplot,
    traceplot!,
    mixeddensity,
    mixeddensity!,
    meanplot,
    meanplot!,
    rankplot,
    rankplot!,
    autocorplot,
    autocorplot!

const _PLOTS_KWARGS_DOCSTRING = "Other keyword arguments are forwarded to the underlying Plots.jl functions."

"""
    FlexiChains.Plots.traceplot(
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
    FlexiChains.Plots.traceplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as [`FlexiChains.traceplot`](@ref), but uses `plot!` instead of `plot`.
"""
function traceplot! end

"""
    FlexiChains.Plots.mixeddensity(
        chn::FlexiChain{TKey}[, param_or_params];
        pool_chains::Bool=false,
        kwargs...
    )

Plot a density estimate or histogram for the specified parameter(s) in the given
`FlexiChain` using Plots.jl. Continuous-valued parameters are plotted as density estimates,
discrete-valued parameters as histograms.

$(_PARAM_DOCSTRING("mixeddensity"))

$(_POOL_CHAINS_DOCSTRING)

$(_PLOTS_KWARGS_DOCSTRING)
"""
function mixeddensity end

"""
    FlexiChains.Plots.mixeddensity!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as [`FlexiChains.Plots.mixeddensity`](@ref), but uses `plot!` instead of `plot`.
"""
function mixeddensity! end

"""
    FlexiChains.Plots.meanplot(
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
    FlexiChains.Plots.meanplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as [`FlexiChains.Plots.meanplot`](@ref), but uses `plot!` instead of `plot`.
"""
function meanplot! end

"""
    FlexiChains.Plots.rankplot(
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
    FlexiChains.Plots.rankplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        overlay::Bool=false,
        kwargs...
    )

Same as [`FlexiChains.Plots.rankplot`](@ref), but uses `plot!` instead of `plot`.
"""
function rankplot! end

"""
    FlexiChains.Plots.autocorplot(
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
    FlexiChains.Plots.autocorplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as [`FlexiChains.Plots.autocorplot`](@ref), but uses `plot!` instead of `plot`.
"""
function autocorplot! end

end
