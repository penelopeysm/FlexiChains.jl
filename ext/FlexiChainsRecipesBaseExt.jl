module FlexiChainsRecipesBaseExt

using FlexiChains: FlexiChains as FC
using RecipesBase: @recipe, @userplot, @series, plot, plot!
using StatsBase: StatsBase

const DEFAULT_MARGIN = (8, :mm)

####################
# custom overloads #
####################

const _TRACEPLOT_SERIESTYPE = :traceplot
function FC.traceplot(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype=_TRACEPLOT_SERIESTYPE)
end
function FC.traceplot!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args; kwargs..., seriestype=_TRACEPLOT_SERIESTYPE)
end

const _MIXEDDENSITY_SERIESTYPE = :mixeddensity
function FC.mixeddensity(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype=_MIXEDDENSITY_SERIESTYPE)
end
function FC.mixeddensity!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args...; kwargs..., seriestype=_MIXEDDENSITY_SERIESTYPE)
end

const _MEANPLOT_SERIESTYPE = :meanplot
function FC.meanplot(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype=_MEANPLOT_SERIESTYPE)
end
function FC.meanplot!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args...; kwargs..., seriestype=_MEANPLOT_SERIESTYPE)
end

const _AUTOCORPLOT_SERIESTYPE = :autocorplot
function FC.autocorplot(
    chn::FC.FlexiChain, args...; lags=FC.PlotUtils.default_lags(chn), demean=true, kwargs...
)
    return plot(chn, args...; lags, demean, kwargs..., seriestype=_AUTOCORPLOT_SERIESTYPE)
end
function FC.autocorplot!(
    chn::FC.FlexiChain, args...; lags=FC.PlotUtils.default_lags(chn), demean=true, kwargs...
)
    return plot!(chn, args...; lags, demean, kwargs..., seriestype=_AUTOCORPLOT_SERIESTYPE)
end

const _TRACEPLOT_AND_DENSITY_SERIESTYPE = :traceplot_and_density

###############################
# The actual plotting recipes #
###############################

"""
Main entry point for plotting.

If parameters are unspecified, all parameters in the chain will be plotted. Note that this
excludes non-parameter, `Extra` keys. `VarName` chains are additionally split up into
constituent real-valued parameters by default.
"""
@recipe function _(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    lags=nothing,
    demean=nothing,
    pool_chains=false,
    box=true,
)
    keys_to_plot = FC.PlotUtils.get_keys_to_plot(chn, param_or_params)
    # When the user calls `plot(chn[, params])` without specifying a `seriestype`, we
    # default to showing a side-by-side traceplot and density/histogram for each parameter.
    # Otherwise, if the user calls `traceplot`, `density`, `histogram`, etc. then there will
    # be a `seriestype` set for us. In either case, we can then use `seriestype` to set up
    # the layout, and dispatch to the appropriate recipe.
    seriestype = get(plotattributes, :seriestype, _TRACEPLOT_AND_DENSITY_SERIESTYPE)
    # Determine number of rows / columns in layout
    nplottypes = seriestype === _TRACEPLOT_AND_DENSITY_SERIESTYPE ? 2 : 1
    nkeys = length(keys_to_plot)
    given_layout = get(plotattributes, :layout, (nkeys, nplottypes))
    layout --> given_layout
    nrows, ncols = given_layout
    # Determine plot size
    size --> (FC.PlotUtils.DEFAULT_WIDTH * ncols, FC.PlotUtils.DEFAULT_HEIGHT * nrows)
    left_margin --> DEFAULT_MARGIN
    bottom_margin --> DEFAULT_MARGIN
    # Do the individual plots!
    for (i, k) in enumerate(keys_to_plot)
        if seriestype === _TRACEPLOT_AND_DENSITY_SERIESTYPE
            @series begin
                subplot := 2i - 1
                FC.PlotUtils.FlexiChainTrace(chn, k)
            end
            @series begin
                subplot := 2i
                FC.PlotUtils.FlexiChainMixedDensity(chn, k, pool_chains)
            end
        else
            @series begin
                subplot := i
                if seriestype === _TRACEPLOT_SERIESTYPE
                    return FC.PlotUtils.FlexiChainTrace(chn, k)
                elseif seriestype === _MIXEDDENSITY_SERIESTYPE
                    return FC.PlotUtils.FlexiChainMixedDensity(chn, k, pool_chains)
                elseif seriestype === :density
                    return FC.PlotUtils.FlexiChainDensity(chn, k, pool_chains)
                elseif seriestype === :histogram
                    return FC.PlotUtils.FlexiChainHistogram(chn, k, pool_chains)
                elseif seriestype === _MEANPLOT_SERIESTYPE
                    return FC.PlotUtils.FlexiChainMean(chn, k)
                elseif seriestype === _AUTOCORPLOT_SERIESTYPE
                    return FC.PlotUtils.FlexiChainAutoCor(chn, k, lags, demean)
                elseif seriestype === :violin
                    return FC.PlotUtils.FlexiChainViolin(chn, k, pool_chains, box)
                else
                    return (chn, k, seriestype)
                end
            end
        end
    end
end

"""
Generic fallback recipe when the user specifies a `seriestype` we don't know how to deal
with.
"""
@recipe function _(
    chn::FC.FlexiChain{T}, param::FC.ParameterOrExtra{<:T}, seriestype::Symbol
) where {T}
    x = FC.iter_indices(chn)
    y = FC._get_raw_data(chn, param)
    FC.PlotUtils.check_eltype_is_real(y)
    @warn "unsupported seriestype `$seriestype` for FlexiChain; will attempt to plot data against iteration numbers, but your plot may not be meaningful"
    return x, y
end

"""
Plot a trace plot and a density/histogram plot side by side.
"""
struct FlexiChainTraceAndMixedDensity{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(tad::FlexiChainTraceAndMixedDensity)
    layout := (1, 2)  # 1 row and 2 columns
    size := (FC.PlotUtils.DEFAULT_WIDTH * 2, FC.PlotUtils.DEFAULT_HEIGHT)
    left_margin := DEFAULT_MARGIN
    bottom_margin := DEFAULT_MARGIN
    @series begin
        subplot := 1
        FC.PlotUtils.FlexiChainTrace(tad.chn, tad.param)
    end
    @series begin
        subplot := 2
        FC.PlotUtils.FlexiChainMixedDensity(tad.chn, tad.param)
    end
end

@recipe function _(t::FC.PlotUtils.FlexiChainTrace)
    seriestype := :line
    # Extract data
    x = FC.iter_indices(t.chn)
    y = FC._get_raw_data(t.chn, t.param)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "iteration number"
    yguide --> "value"
    label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(t.chn)))
    title --> t.param.name
    return x, y
end

"""
Plot of running mean.
"""
@recipe function _(t::FC.PlotUtils.FlexiChainMean)
    seriestype := :line
    # Extract data
    x = FC.iter_indices(t.chn)
    data = FC._get_raw_data(t.chn, t.param)
    y = mapslices(FC.PlotUtils.runningmean, data; dims=1)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "iteration number"
    yguide --> "mean"
    label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(t.chn)))
    title --> t.param.name
    return x, y
end

"""
Plot of autocorrelation.
"""
@recipe function _(t::FC.PlotUtils.FlexiChainAutoCor)
    seriestype := :line
    # Extract data
    x = t.lags
    data = FC._get_raw_data(t.chn, t.param)
    y = StatsBase.autocor(data, t.lags; demean=t.demean)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "lag"
    yguide --> "autocorrelation"
    label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(t.chn)))
    title --> t.param.name
    return x, y
end

"""
Plot of autocorrelation.
"""
@recipe function _(t::FC.PlotUtils.FlexiChainViolin)
    # Extract data
    # StatsPlots.violin wants data in quite a weird format.
    data = FC._get_raw_data(t.chn, t.param)
    nchains, niters = size(t.chn)
    y = vec(data)
    FC.PlotUtils.check_eltype_is_real(y)
    label --> nothing
    title --> t.param.name
    yguide --> "value"
    if t.pool_chains
        xticks --> []
        x = [1]
        return x, y
    else
        labels = map(cidx -> "chain $cidx", FC.chain_indices(t.chn))
        x = repeat(labels; inner=niters)
        return x, y
    end
end

"""
Detect whether data are discrete or continuous, and dispatch to the histogram and density
methods respectively.
"""
@recipe function _(ad::FC.PlotUtils.FlexiChainMixedDensity)
    # Extract data
    raw = FC._get_raw_data(ad.chn, ad.param)
    FC.PlotUtils.check_eltype_is_real(raw)
    # Detect if it's discrete or continuous. This is a bit of a hack!
    if eltype(raw) <: Integer
        return FC.PlotUtils.FlexiChainHistogram(ad.chn, ad.param, ad.pool_chains)
    else
        return FC.PlotUtils.FlexiChainDensity(ad.chn, ad.param, ad.pool_chains)
    end
end

"""
Density plot for continuous data.
"""
@recipe function _(d::FC.PlotUtils.FlexiChainDensity)
    seriestype := :density
    # Extract data
    x = FC.iter_indices(d.chn)
    raw = FC._get_raw_data(d.chn, d.param)
    y = d.pool_chains ? vec(raw) : raw
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "value"
    yguide --> "density"
    if d.pool_chains
        label --> "pooled"
    else
        label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    end
    title --> d.param.name
    return x, y
end

"""
Histogram for discrete data.
"""
@recipe function _(h::FC.PlotUtils.FlexiChainHistogram)
    seriestype := :histogram
    # Extract data
    raw = FC._get_raw_data(h.chn, h.param)
    x = h.pool_chains ? vec(raw) : raw
    FC.PlotUtils.check_eltype_is_real(x)
    # Set labels
    xguide --> "value"
    yguide --> "probability"
    if h.pool_chains
        label --> "pooled"
    else
        label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(h.chn)))
    end
    title --> h.param.name
    bins --> 25
    normalize --> :pdf
    return x
end

end # module
