function _PLOT_DOCSTRING_SUPPLEMENTARY(funcname)
    return """
If no parameters are specified, this will plot all parameters in the chain. Note that
non-parameter, i.e. `Extra`, keys are excluded by default. If you want to plot _all_ keys,
you can explicitly pass all keys with `$(funcname)(chn, :)`.

If the chain uses `VarName` keys, these will be split up into their constituent real-valued
parameters, unless you pass `split_varname=false`. There is probably no good reason to
disable the VarName splitting.

Keyword arguments are forwarded to Plots.jl's functions.
"""
end

"""
    FlexiChains.traceplot(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Create a trace plot of the specified parameter(s) in the given `FlexiChain`.

$(_PLOT_DOCSTRING_SUPPLEMENTARY("traceplot"))
"""
function traceplot end

"""
    FlexiChains.traceplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Same as `FlexiChains.traceplot`, but uses `plot!` instead of `plot`.
"""
function traceplot! end

"""
    FlexiChains.mixeddensity(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Create either a density plot, or a histogram, of the specified parameter(s) in the given
`FlexiChain`. Continuous-valued parameters are plotted using density plots, discrete-valued
parameters with histograms.

$(_PLOT_DOCSTRING_SUPPLEMENTARY("mixeddensity"))
"""
function mixeddensity end

"""
    FlexiChains.mixeddensity!(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Same as `FlexiChains.mixeddensity`, but uses `plot!` instead of `plot`.
"""
function mixeddensity! end

"""
    FlexiChains.meanplot(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Plot the running mean of the specified parameter(s) in the given `FlexiChain`.

$(_PLOT_DOCSTRING_SUPPLEMENTARY("meanplot"))
"""
function meanplot end

"""
    FlexiChains.meanplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Same as `FlexiChains.meanplot`, but uses `plot!` instead of `plot`.
"""
function meanplot! end
