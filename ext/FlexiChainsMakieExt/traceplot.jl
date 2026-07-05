function _default_traceplot_axis()
    return (xlabel="iteration number", ylabel="value")
end

"""
    FlexiChains.Makie.traceplot(
        chn::FC.FlexiChain[, param_or_params];
        kwargs...,
    )

Create trace plots for the specified parameters in the chain.

$(FC.PlotUtils._PARAM_DOCSTRING("FlexiChains.Makie.traceplot"))

# Keyword arguments

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.Makie.traceplot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    figure=(;),
    axis=(;),
    legend=(;),
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    @info plot_names
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols, figure = setup_figure_and_layout(length(keys_to_plot), 1, layout, figure)
    a, p = nothing, nothing
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
        a, p = FC.Makie.traceplot!(
            Makie.Axis(figure[row, col]; _default_traceplot_axis()..., title=kstr, axis...),
            FC.PlotUtils.FlexiChainTrace(chn, k);
            kwargs...,
        )
    end
    # Extract the colors used in the last axis
    colors = map(p -> p.color[], a.scene.plots)
    maybe_add_legend(figure, chn, colors, legend_position; legend...)
    return Makie.FigureAxisPlot(figure, a, p)
end

########################
# Single axis plotting #
########################
function FC.Makie.traceplot(
    grid::MakieGrids,
    chn::FC.FlexiChain,
    param;
    axis=(;),
    kwargs...,
)
    # TODO: Error if there is already something at the grid position?
    # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    return FC.Makie.traceplot!(
        Makie.Axis(grid; _default_traceplot_axis()..., title=kstr, axis...),
        chn,
        param;
        kwargs...,
    )
end
function FC.Makie.traceplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    a, p = FC.Makie.traceplot!(ax, FC.PlotUtils.FlexiChainTrace(chn, k); kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.Makie.traceplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.traceplot!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the density plotting.
"""
function FC.Makie.traceplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainTrace; kwargs...)
    x = FC.iter_indices(d.chn)
    y = FC._get_raw_data(d.chn, d.param)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))
    for (label, datacol, color) in zip(labels, eachcol(y), colors)
        p = Makie.lines!(ax, x, datacol; label=label, kwargs..., color=color)
    end
    return Makie.AxisPlot(ax, p)
end
