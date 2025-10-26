function _default_traceplot_axis(k::FC.ParameterOrExtra)
    return (xlabel="iteration number", ylabel="value", title=string(k.name))
end

"""
This handles plotting onto a full Figure.
"""
function FC.mtraceplot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    figure=(;),
    axis=(;),
    legend=(;),
    kwargs...,
)
    keys_to_plot = FC.PlotUtils.get_keys_to_plot(chn, param_or_params)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols = if isnothing(layout)
        length(keys_to_plot), 1
    else
        layout
    end
    figure = Makie.Figure(;
        size=(FC.PlotUtils.DEFAULT_WIDTH * ncols, FC.PlotUtils.DEFAULT_HEIGHT * nrows),
        figure...,
    )
    a, p = nothing, nothing
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        a, p = FC.mtraceplot!(
            Makie.Axis(figure[row, col]; _default_traceplot_axis(k)..., axis...),
            FC.PlotUtils.FlexiChainTrace(chn, k);
            kwargs...,
        )
    end
    # Extract the colors used in the last axis
    colors = map(p -> p.color[], a.scene.plots)
    maybe_add_legend(figure, chn, colors, legend_position; legend...)
    return Makie.FigureAxisPlot(figure, a, p)
end

"""
This handles plotting onto a single Axis.
"""
function FC.mtraceplot(grid::MakieGrids, chn::FC.FlexiChain, param; axis=(;), kwargs...)
    # TODO: Error if there is already something at the grid position?
    # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    return FC.mtraceplot!(
        Makie.Axis(grid; _default_traceplot_axis(k)..., axis...), chn, param; kwargs...
    )
end
function FC.mtraceplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    a, p = FC.mtraceplot!(ax, FC.PlotUtils.FlexiChainTrace(chn, k); kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.mtraceplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.mtraceplot!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the density plotting.
"""
function FC.mtraceplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainTrace; kwargs...)
    x = FC.iter_indices(d.chn)
    y = FC._get_raw_data(d.chn, d.param)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    color_kwargs = determine_color_kwargs(nchains, NamedTuple(kwargs))
    for (label, datacol, color_kwarg) in zip(labels, eachcol(y), color_kwargs)
        # note the careful ordering of keyword arguments here: `label` is a default, so we
        # want user-specified `kwargs` to override it; but `color_kwarg` was determined from
        # `kwargs`, so we want to apply it last to ensure the color obtained from
        # `determine_color_kwargs` is respected.
        p = Makie.lines!(ax, datacol; label=label, kwargs..., color_kwarg...)
    end
    return Makie.AxisPlot(ax, p)
end
