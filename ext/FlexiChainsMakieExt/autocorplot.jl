function _default_autocorplot_axis(k::FC.ParameterOrExtra)
    return (xlabel = "lag", ylabel = "autocorrelation", title = string(k.name))
end

"""
    FlexiChains.mautocorplot(
        chn::FC.FlexiChain[, param_or_params];
        lags=FlexiChains.PlotUtils.default_lags(chn),
        demean=true,
        kwargs...,
    )

Plot the autocorrelation of the specified parameter(s) in the given `FlexiChain` using Makie.

$(FC._PARAM_DOCSTRING("FlexiChains.mautocorplot"))

# Keyword arguments

- `lags`: the lags at which to compute the autocorrelation. Defaults to `1:min(niters-1, round(Int, 10*log10(niters)))`.
- `demean`: whether to subtract the mean before computing the autocorrelation. Defaults to
  `true`.

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.mautocorplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        lags = FC.PlotUtils.default_lags(chn),
        demean::Bool = true,
        layout::Union{Tuple{Int, Int}, Nothing} = nothing,
        legend_position::Symbol = :bottom,
        figure = (;),
        axis = (;),
        legend = (;),
        kwargs...,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols, figure = setup_figure_and_layout(length(keys_to_plot), 1, layout, figure)
    a, p = nothing, nothing
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        a, p = FC.mautocorplot!(
            Makie.Axis(figure[row, col]; _default_autocorplot_axis(k)..., axis...),
            FC.PlotUtils.FlexiChainAutoCor(chn, k, lags, demean);
            kwargs...,
        )
    end
    colors = map(p -> p.color[], a.scene.plots)
    maybe_add_legend(figure, chn, colors, legend_position; legend...)
    return Makie.FigureAxisPlot(figure, a, p)
end

########################
# Single axis plotting #
########################
function FC.mautocorplot(
        grid::MakieGrids, chn::FC.FlexiChain, param;
        axis = (;), kwargs...,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    return FC.mautocorplot!(
        Makie.Axis(grid; _default_autocorplot_axis(k)..., axis...),
        chn, param; kwargs...,
    )
end
function FC.mautocorplot!(
        ax::Makie.Axis, chn::FC.FlexiChain, param;
        lags = FC.PlotUtils.default_lags(chn),
        demean::Bool = true,
        kwargs...,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    a, p = FC.mautocorplot!(
        ax, FC.PlotUtils.FlexiChainAutoCor(chn, k, lags, demean); kwargs...
    )
    return Makie.AxisPlot(a, p)
end
function FC.mautocorplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.mautocorplot!(Makie.current_axis(), chn, param; kwargs...)
end

# This performs the actual plotting
function FC.mautocorplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainAutoCor; kwargs...)
    x = d.lags
    data = FC._get_raw_data(d.chn, d.param)
    y = StatsBase.autocor(data, d.lags; demean = d.demean)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))
    for (label, datacol, color) in zip(labels, eachcol(y), colors)
        p = Makie.lines!(ax, x, datacol; label = label, kwargs..., color = color)
    end
    return Makie.AxisPlot(ax, p)
end
