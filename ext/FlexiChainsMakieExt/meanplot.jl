function _default_meanplot_axis(k::FC.ParameterOrExtra)
    return (xlabel = "iteration number", ylabel = "mean", title = string(k.name))
end

"""
    FlexiChains.mmeanplot(
        chn::FC.FlexiChain[, param_or_params];
        kwargs...,
    )

Plot the running mean of the specified parameter(s) in the given `FlexiChain` using Makie.

$(FC._PARAM_DOCSTRING("FlexiChains.mmeanplot"))

# Keyword arguments

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.mmeanplot(
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
        a, p = FC.mmeanplot!(
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
function FC.mmeanplot(grid::MakieGrids, chn::FC.FlexiChain, param; axis = (;), kwargs...)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    return FC.mmeanplot!(
        Makie.Axis(grid; _default_meanplot_axis(k)..., axis...), chn, param; kwargs...
    )
end
function FC.mmeanplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    a, p = FC.mmeanplot!(ax, FC.PlotUtils.FlexiChainMean(chn, k); kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.mmeanplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.mmeanplot!(Makie.current_axis(), chn, param; kwargs...)
end

function FC.mmeanplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainMean; kwargs...)
    x = FC.iter_indices(d.chn)
    data = FC._get_raw_data(d.chn, d.param)
    y = mapslices(FC.PlotUtils.runningmean, data; dims = 1)
    FC.PlotUtils.check_eltype_is_real(y)
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    color_kwargs = determine_color_kwargs(nchains, NamedTuple(kwargs))
    for (label, datacol, color_kwarg) in zip(labels, eachcol(y), color_kwargs)
        p = Makie.lines!(ax, x, datacol; label = label, kwargs..., color_kwarg...)
    end
    return Makie.AxisPlot(ax, p)
end
