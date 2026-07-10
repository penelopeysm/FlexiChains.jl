function _default_autocorplot_axis()
    return (xlabel="lag", ylabel="autocorrelation")
end

"""
    FlexiChains.Makie.autocorplot(
        chn::FC.FlexiChain[, param_or_params];
        lags=FlexiChains.PlotUtils.default_lags(chn),
        demean=true,
        kwargs...,
    )

Plot the autocorrelation of the specified parameter(s) in the given `FlexiChain` using Makie.

$(FC.PlotUtils._PARAM_DOCSTRING("FlexiChains.Makie.autocorplot"))

# Keyword arguments

- `lags`: the lags at which to compute the autocorrelation. Defaults to `1:min(niters-1, round(Int, 10*log10(niters)))`.
- `demean`: whether to subtract the mean before computing the autocorrelation. Defaults to
  `true`.

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.Makie.autocorplot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    lags=FC.PlotUtils.default_lags(chn),
    demean::Bool=true,
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    figure=(;),
    axis=(;),
    legend=(;),
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols, figure = setup_figure_and_layout(length(keys_to_plot), 1, layout, figure)
    a, p = nothing, nothing
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
        a, p = FC.Makie.autocorplot!(
            Makie.Axis(
                figure[row, col];
                _default_autocorplot_axis()...,
                title=kstr,
                axis...,
            ),
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
function FC.Makie.autocorplot(
    grid::MakieGrids,
    chn::FC.FlexiChain,
    param;
    axis=(;),
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    return FC.Makie.autocorplot!(
        Makie.Axis(grid; _default_autocorplot_axis(k)..., title=kstr, axis...),
        chn,
        param;
        kwargs...,
    )
end
function FC.Makie.autocorplot!(
    ax::Makie.Axis,
    chn::FC.FlexiChain,
    param;
    lags=FC.PlotUtils.default_lags(chn),
    demean::Bool=true,
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    a, p = FC.Makie.autocorplot!(
        ax,
        FC.PlotUtils.FlexiChainAutoCor(chn, k, lags, demean);
        kwargs...,
    )
    return Makie.AxisPlot(a, p)
end
function FC.Makie.autocorplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.autocorplot!(Makie.current_axis(), chn, param; kwargs...)
end

# This performs the actual plotting
function FC.Makie.autocorplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainAutoCor; kwargs...)
    x = d.lags
    data = FC._get_raw_data(d.chn, d.param)
    y = StatsBase.autocor(data, d.lags; demean=d.demean)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))
    for (label, datacol, color) in zip(labels, eachcol(y), colors)
        p = Makie.lines!(ax, x, datacol; label=label, kwargs..., color=color)
    end
    return Makie.AxisPlot(ax, p)
end
