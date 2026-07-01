module FlexiChainsRecipesBaseExt

using FlexiChains: FlexiChains as FC
using RecipesBase: RecipesBase, @recipe, @userplot, @series, plot, plot!
using StatsBase: StatsBase

const DEFAULT_MARGIN = (8, :mm)
const DEFAULT_LEGEND_TITLE_FONT_SIZE = 10

####################
# custom overloads #
####################

const _TRACEPLOT_SERIESTYPE = :traceplot
function FC.Plots.traceplot(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype = _TRACEPLOT_SERIESTYPE)
end
function FC.Plots.traceplot!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args...; kwargs..., seriestype = _TRACEPLOT_SERIESTYPE)
end

const _MIXEDDENSITY_SERIESTYPE = :mixeddensity
function FC.Plots.mixeddensity(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype = _MIXEDDENSITY_SERIESTYPE)
end
function FC.Plots.mixeddensity!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args...; kwargs..., seriestype = _MIXEDDENSITY_SERIESTYPE)
end

const _MEANPLOT_SERIESTYPE = :meanplot
function FC.Plots.meanplot(chn::FC.FlexiChain, args...; kwargs...)
    return plot(chn, args...; kwargs..., seriestype = _MEANPLOT_SERIESTYPE)
end
function FC.Plots.meanplot!(chn::FC.FlexiChain, args...; kwargs...)
    return plot!(chn, args...; kwargs..., seriestype = _MEANPLOT_SERIESTYPE)
end

const _RANKPLOT_SERIESTYPE = :rankplot
const _RANKOVERLAY_SERIESTYPE = :rankplot_overlay
function FC.Plots.rankplot(chn::FC.FlexiChain, args...; overlay = false, kwargs...)
    seriestype = overlay ? _RANKOVERLAY_SERIESTYPE : _RANKPLOT_SERIESTYPE
    return plot(chn, args...; kwargs..., seriestype = seriestype)
end
function FC.Plots.rankplot!(chn::FC.FlexiChain, args...; overlay = false, kwargs...)
    seriestype = overlay ? _RANKOVERLAY_SERIESTYPE : _RANKPLOT_SERIESTYPE
    return plot!(chn, args...; kwargs..., seriestype = seriestype)
end

const _AUTOCORPLOT_SERIESTYPE = :autocorplot
function FC.Plots.autocorplot(
        chn::FC.FlexiChain, args...; lags = FC.PlotUtils.default_lags(chn), demean = true, kwargs...
    )
    return plot(chn, args...; kwargs..., lags, demean, seriestype = _AUTOCORPLOT_SERIESTYPE)
end
function FC.Plots.autocorplot!(
        chn::FC.FlexiChain, args...; lags = FC.PlotUtils.default_lags(chn), demean = true, kwargs...
    )
    return plot!(chn, args...; kwargs..., lags, demean, seriestype = _AUTOCORPLOT_SERIESTYPE)
end

const _VIOLINPLOT_SERIESTYPE = :violin

const _TRACEPLOT_AND_DENSITY_SERIESTYPE = :traceplot_and_density

###############################
# The actual plotting recipes #
###############################

@doc """
    Plots.plot(
        chn::FlexiChain[, param_or_params];
        pool_chains=false,
        kwargs...
    )

Plot a `FlexiChain` using Plots.jl. By default, this produces a trace plot and mixed density
side-by-side for each parameter.

$(FC.PlotUtils._PARAM_DOCSTRING("plot"))

$(FC.Plots._PLOTS_KWARGS_DOCSTRING)
""" RecipesBase.plot

@recipe function _(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        # NOTE: If you want FlexiChains' custom kwargs to be correctly captured here, you
        # have to make sure that they don't overlap with any of the kwargs that
        # Plots/StatsPlots itself defines, otherwise they will be swallowed!
        lags = nothing,
        demean = nothing,
        with_box = false,
        pool_chains = false,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    # When the user calls `plot(chn[, params])` without specifying a `seriestype`, we
    # default to showing a side-by-side traceplot and density/histogram for each parameter.
    # Otherwise, if the user calls `traceplot`, `density`, `histogram`, etc. then there will
    # be a `seriestype` set for us. In either case, we can then use `seriestype` to set up
    # the layout, and dispatch to the appropriate recipe.
    seriestype = get(plotattributes, :seriestype, _TRACEPLOT_AND_DENSITY_SERIESTYPE)
    # Determine number of rows / columns in layout
    nplots_per_key = if seriestype === _TRACEPLOT_AND_DENSITY_SERIESTYPE
        2
    elseif seriestype === _RANKPLOT_SERIESTYPE
        FC.nchains(chn)
    else
        1
    end
    nkeys = length(keys_to_plot)
    given_layout = get(plotattributes, :layout, (nkeys, nplots_per_key))
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
        elseif seriestype === _RANKPLOT_SERIESTYPE
            ranks = FC.PlotUtils.get_ranks(chn, k)
            for (j, cidx) in enumerate(FC.chain_indices(chn))
                @series begin
                    subplot := nplots_per_key * (i - 1) + j
                    FC.PlotUtils.FlexiChainRank(chn, k, cidx, ranks)
                end
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
                elseif seriestype === _RANKOVERLAY_SERIESTYPE
                    ranks = FC.PlotUtils.get_ranks(chn, k)
                    return FC.PlotUtils.FlexiChainRankOverlay(chn, k, ranks)
                elseif seriestype === _AUTOCORPLOT_SERIESTYPE
                    return FC.PlotUtils.FlexiChainAutoCor(chn, k, lags, demean)
                elseif seriestype === _VIOLINPLOT_SERIESTYPE
                    return FC.PlotUtils.FlexiChainViolin(chn, k, pool_chains, with_box)
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

@recipe function _(t::FC.PlotUtils.FlexiChainTrace)
    seriestype := :line
    # Extract data
    x = FC.iter_indices(t.chn)
    y = FC._get_raw_data(t.chn, t.param)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "iteration number"
    yguide --> "value"
    label --> permutedims(map(string, FC.chain_indices(t.chn)))
    legend_title --> "chain"
    legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
    title --> t.param.name
    return x, y
end

@recipe function _(r::FC.PlotUtils.FlexiChainRank)
    rank_vec = r.ranks[chain = r.chn_idx]
    seriestype := :histogram
    xguide --> "rank"
    yticks --> nothing
    yshowaxis --> false
    title --> "$(FC.get_name(r.param)) (chain $(r.chn_idx))"
    bins --> 25
    normalize --> :pdf
    label --> nothing
    return rank_vec
end

@recipe function _(r::FC.PlotUtils.FlexiChainRankOverlay)
    for (rank_vec, chn_idx) in zip(eachcol(r.ranks), FC.chain_indices(r.chn))
        @series begin
            seriestype := :stephist
            xguide --> "rank"
            yticks --> nothing
            yshowaxis --> false
            title --> "$(FC.get_name(r.param))"
            label --> string(chn_idx)
            legend_title --> "chain"
            legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
            bins --> 25
            normalize --> :pdf
            rank_vec
        end
    end
end

"""
Plot of running mean.
"""
@recipe function _(t::FC.PlotUtils.FlexiChainMean)
    seriestype := :line
    # Extract data
    x = FC.iter_indices(t.chn)
    data = FC._get_raw_data(t.chn, t.param)
    y = mapslices(FC.PlotUtils.runningmean, data; dims = 1)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "iteration number"
    yguide --> "mean"
    label --> permutedims(map(string, FC.chain_indices(t.chn)))
    legend_title --> "chain"
    legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
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
    y = StatsBase.autocor(data, t.lags; demean = t.demean)
    FC.PlotUtils.check_eltype_is_real(y)
    # Set labels
    xguide --> "lag"
    yguide --> "autocorrelation"
    label --> permutedims(map(string, FC.chain_indices(t.chn)))
    legend_title --> "chain"
    legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
    title --> t.param.name
    return x, y
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
        label --> permutedims(map(string, FC.chain_indices(d.chn)))
        legend_title --> "chain"
        legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
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
        label --> permutedims(map(string, FC.chain_indices(h.chn)))
        legend_title --> "chain"
        legend_title_font_pointsize --> DEFAULT_LEGEND_TITLE_FONT_SIZE
    end
    title --> h.param.name
    bins --> 25
    normalize --> :pdf
    return x
end

"""
Violin plot, with optional box plot overlay.
"""
@recipe function _(t::FC.PlotUtils.FlexiChainViolin)
    data = FC._get_raw_data(t.chn, t.param)
    nchains, niters = size(t.chn)
    y = vec(data)
    FC.PlotUtils.check_eltype_is_real(y)
    title --> t.param.name
    yguide --> "value"
    if t.pool_chains
        xticks --> []
        x = [1]
    else
        labels = map(string, FC.chain_indices(t.chn))
        x = repeat(labels; inner = niters)
        xguide --> "chain"
    end
    @series begin
        seriestype := :violin
        label --> nothing
        x, y
    end
    if t.with_box
        @series begin
            seriestype := :boxplot
            label --> nothing
            fillalpha --> 0.75
            x, y
        end
    end
end

end # module
