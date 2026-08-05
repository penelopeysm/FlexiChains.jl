function _default_trankplot_axis()
    return (xlabel="iteration number", ylabel="value")
end

"""
    FlexiChains.Makie.trankplot(
        chn::FC.FlexiChain[, param_or_params];
        kwargs...,
    )

Create trank plots for the specified parameters in the chain.
Trankplots show the binned ranks of samples per chain and parameter.

$(FC.PlotUtils._PARAM_DOCSTRING("FlexiChains.Makie.trankplot"))

# Keyword arguments

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.Makie.trankplot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    bins=20,
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
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
        a, p = FC.Makie.trankplot!(
            Makie.Axis(figure[row, col]; _default_trankplot_axis()..., title=kstr, axis...),
            FC.PlotUtils.FlexiChainTrank(chn, k, bins);
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
function FC.Makie.trankplot(
    grid::MakieGrids,
    chn::FC.FlexiChain,
    param;
    bins=20,
    axis=(;),
    kwargs...,
)
    # TODO: Error if there is already something at the grid position?
    # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    return FC.Makie.trankplot!(
        Makie.Axis(grid; _default_trankplot_axis()..., title=kstr, axis...),
        chn,
        param;
        bins,
        kwargs...,
    )
end
function FC.Makie.trankplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; bins=20, kwargs...)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    a, p = FC.Makie.trankplot!(ax, FC.PlotUtils.FlexiChainTrank(chn, k, bins); kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.Makie.trankplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.trankplot!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the plotting.
"""
function FC.Makie.trankplot!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainTrank; kwargs...)
    iter_inds = FC.iter_indices(d.chn)
    # this wouldn't look nice with `stairs!`
    x = range(extrema(iter_inds)...; length=d.bins)
    x_padded = FC.PlotUtils.pad_x(x, FC.PlotUtils.centers(x))
    y = FC._get_raw_data(d.chn, d.param)
    y_binned = FC.PlotUtils.pad_y(FC.PlotUtils.trank_bins(y; bins=d.bins))
    nchains = size(y, 2)
    p = nothing
    labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))
    for (label, ybinnedcol, color) in zip(labels, eachcol(y_binned), colors)
        p = Makie.stairs!(
            ax,
            x_padded,
            ybinnedcol;
            label=label,
            step=:center,
            kwargs...,
            color=color,
        )
    end
    return Makie.AxisPlot(ax, p)
end
