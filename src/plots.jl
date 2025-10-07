module Plots

"""
    FlexiChains.traceplot(
        chn::FlexiChain{TKey}[, param_or_params];
        split_varname=(TKey <: VarName),
        kwargs...
    )

Create a trace plot of the specified parameter(s) in the given `FlexiChain`.

If no parameters are specified, this will plot all parameters in the chain.
Note that non-parameter, i.e. `Extra`, keys are excluded by default. If you want to plot _all_ keys,
you can explicitly pass all keys with `traceplot(chn, :)`.

If the chain uses `VarName` keys, these will be split up into their constituent real-valued
parameters, unless you pass `split_varname=false`. There is probably no good reason to
disable the VarName splitting.

Keyword arguments are forwarded to Plots.jl's functions.
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

end # module
