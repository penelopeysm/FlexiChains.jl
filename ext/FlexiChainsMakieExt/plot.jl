function Makie.plot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    pool_chains::Bool=false,
    figure=(;),
    axis=(;),
    legend=(;),
    kwargs...,
)
    keys_to_plot = FC.PlotUtils.get_keys_to_plot(chn, param_or_params)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols = if isnothing(layout)
        length(keys_to_plot), 2
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
    for (i, (col, row)) in enumerate(indices)
        key_index = div(i - 1, 2) + 1
        k = keys_to_plot[key_index]
        if i % 2 == 1
            a, p = FC.mtraceplot!(
                Makie.Axis(figure[row, col]; _default_traceplot_axis(k)..., axis...),
                FC.PlotUtils.FlexiChainTrace(chn, k);
                kwargs...,
            )
        else
            a, p = Makie.density!(
                Makie.Axis(figure[row, col]; _default_density_axis(k)..., axis...),
                FC.PlotUtils.FlexiChainDensity(chn, k, pool_chains);
                kwargs...,
            )
        end
    end
    # Extract the colors used in the last axis
    if !pool_chains
        colors = map(p -> p.color[], a.scene.plots)
        maybe_add_legend(figure, chn, colors, legend_position; legend...)
    end
    return Makie.FigureAxisPlot(figure, a, p)
end
