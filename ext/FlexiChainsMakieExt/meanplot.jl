function _default_meanplot_axis(k::FC.ParameterOrExtra)
    return (xlabel = "iteration number", ylabel = "mean", title = string(k.name))
end

"""
    FlexiChains.Makie.meanplot(
        chn::FC.FlexiChain[, param_or_params];
        kwargs...,
    )

Plot the running mean of the specified parameter(s) in the given `FlexiChain` using Makie.

$(FC.PlotUtils._PARAM_DOCSTRING("FlexiChains.Makie.meanplot"))

# Keyword arguments

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.Makie.meanplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
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
        a, p = FC.Makie.meanplot!(
            Makie.Axis(figure[row, col]; _default_meanplot_axis(k)..., axis...),
            FC.PlotUtils.FlexiChainMean(chn, k);
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
function FC.Makie.meanplot(grid::MakieGrids, chn::FC.FlexiChain, param; axis = (;), kwargs...)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    return FC.Makie.meanplot!(
        Makie.Axis(grid; _default_meanplot_axis(k)..., axis...), chn, param; kwargs...
    )
end
function FC.Makie.meanplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    a, p = FC.Makie.meanplot!(ax, FC.PlotUtils.FlexiChainMean(chn, k); kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.Makie.meanplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.meanplot!(Makie.current_axis(), chn, param; kwargs...)
end

function FC.Makie.meanplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainMean; kwargs...)
    x = FC.iter_indices(d.chn)
    data = FC._get_raw_data(d.chn, d.param)
    y = mapslices(FC.PlotUtils.runningmean, data; dims = 1)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))
    for (label, datacol, color) in zip(labels, eachcol(y), colors)
        p = Makie.lines!(ax, x, datacol; label = label, kwargs..., color = color)
    end
    return Makie.AxisPlot(ax, p)
end
