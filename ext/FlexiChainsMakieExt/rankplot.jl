function _default_rankplot_axis(k::FC.ParameterOrExtra, chn_idx)
    title = if chn_idx === nothing
        "$(FC.get_name(k))"
    else
        "$(FC.get_name(k)) (chain $(chn_idx))"
    end
    return (xlabel = "rank", title = title)
end

"""
    FlexiChains.mrankplot(
        chn::FC.FlexiChain[, param_or_params];
        overlay::Bool=false,
        kwargs...,
    )

Create rank plots for the specified parameters in the chain. If `param_or_params` is not
provided, plots all parameters in the chain.

If `overlay` is true, then the histograms for all chains are plotted on the same axis.

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.mrankplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        overlay::Bool = false,
        layout::Union{Tuple{Int, Int}, Nothing} = nothing,
        legend_position::Symbol = :bottom,
        figure = (;),
        axis = (;),
        legend = (;),
        kwargs...,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    nc = FC.nchains(chn)
    nc == 1 && @warn "Only one chain to plot, so the rank plot will be uninformative"
    keys_to_plot = collect(keys(chn))
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nplots_per_key = overlay ? 1 : nc
    nrows, ncols, figure = setup_figure_and_layout(length(keys_to_plot), nplots_per_key, layout, figure)
    a, p = nothing, nothing
    # Precompute ranks
    ranks = Dict(k => FC.PlotUtils.get_ranks(chn, k) for k in keys_to_plot)
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, repeat(keys_to_plot, inner = nplots_per_key))
        this_ranks = ranks[k]
        chn_idx, plot_obj = if overlay
            (nothing, FC.PlotUtils.FlexiChainRankOverlay(chn, k, this_ranks))
        else
            chn_idx = FC.chain_indices(chn)[col]
            (chn_idx, FC.PlotUtils.FlexiChainRank(chn, k, chn_idx, this_ranks))
        end
        a, p = FC.mrankplot!(
            Makie.Axis(figure[row, col]; _default_rankplot_axis(k, chn_idx)..., axis...),
            plot_obj;
            kwargs...,
        )
    end
    # Add legend (but only needed if overlayed)
    if overlay
        colors = map(p -> p.color[], a.scene.plots)
        maybe_add_legend(figure, chn, colors, legend_position; legend...)
    end
    return Makie.FigureAxisPlot(figure, a, p)
end

########################
# Single axis plotting #
########################
function FC.mrankplot(grid::MakieGrids, chn::FC.FlexiChain, param; axis = (;), kwargs...)
    # TODO: Error if there is already something at the grid position?
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    return FC.mrankplot!(
        Makie.Axis(grid; _default_rankplot_axis(k, nothing)..., axis...), chn, param; kwargs...
    )
end
function FC.mrankplot!(ax::Makie.Axis, chn::FC.FlexiChain, param; overlay = false, kwargs...)
    nc = FC.nchains(chn)
    if !overlay && nc > 1
        throw(ArgumentError("to plot onto a single axis, you must set overlay=true to plot all chains together"))
    end
    nc == 1 && @warn "Only one chain to plot, so the rank plot will be uninformative"
    chn = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    ranks = FC.PlotUtils.get_ranks(chn, k)
    plot_obj = if overlay
        FC.PlotUtils.FlexiChainRankOverlay(chn, k, ranks)
    else
        chn_idx = only(FC.chain_indices(chn))
        FC.PlotUtils.FlexiChainRank(chn, k, chn_idx, ranks)
    end
    a, p = FC.mrankplot!(ax, plot_obj; kwargs...)
    return Makie.AxisPlot(a, p)
end
function FC.mrankplot!(chn::FC.FlexiChain, param; kwargs...)
    return FC.mrankplot!(Makie.current_axis(), chn, param; kwargs...)
end

function FC.mrankplot!(ax::Makie.Axis, r::FC.PlotUtils.FlexiChainRank; kwargs...)
    data = r.ranks[chain = r.chn_idx]
    p = Makie.hist!(ax, data; bins = 25, kwargs...)
    return Makie.AxisPlot(ax, p)
end

function FC.mrankplot!(ax::Makie.Axis, r::FC.PlotUtils.FlexiChainRankOverlay; kwargs...)
    p = nothing
    for (chn_idx, data) in zip(FC.chain_indices(r.chn), eachcol(r.ranks))
        label = "chain $(chn_idx)"
        p = Makie.stephist!(ax, data; label = label, bins = 25, kwargs...)
    end
    return Makie.AxisPlot(ax, p)
end
