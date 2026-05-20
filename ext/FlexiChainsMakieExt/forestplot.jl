function _default_forestplot_axis()
    return (xlabel = "value",)
end

function _draw_intervals!(ax, data, point_val, y, color, levels)
    nlevels = length(levels)
    for (k, level) in enumerate(reverse(levels))
        α = (1 - level) / 2
        lo = FC.quantile(data, α)
        hi = FC.quantile(data, 1 - α)
        lw = nlevels == 1 ? 3.0 : 1.5 + 2.5 * ((k - 1) / (nlevels - 1))
        Makie.linesegments!(
            ax, [Makie.Point2f(lo, y), Makie.Point2f(hi, y)];
            color = color, linewidth = lw
        )
    end
    return Makie.scatter!(ax, [point_val], [y]; color = color, markersize = 10)
end

###################
# mforestplot     #
###################

"""
    FlexiChains.mforestplot(
        chn::FC.FlexiChain[, param_or_params];
        point::Symbol=:median,
        levels::Tuple{Vararg{Real}}=(0.5, 0.94),
        pool_chains::Bool=false,
        kwargs...,
    )

Create a forest (caterpillar) plot for the specified parameters in the chain. Each parameter
is shown as a point estimate with one or more credible interval bars.

$(FC._PARAM_DOCSTRING("FlexiChains.mforestplot"))

# Keyword arguments

- `point::Symbol`: the point estimate to use. Must be `:mean` or `:median`. Defaults to `:median`.
- `levels`: a tuple of credible interval widths, e.g. `(0.5, 0.94)` for 50% and 94% intervals. Wider intervals are drawn with thinner lines.
- `pool_chains::Bool`: whether to pool data from all chains or plot each chain separately. Defaults to `false`.
$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.mforestplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        pool_chains::Bool = false,
        legend_position::Symbol = :bottom,
        figure = (;),
        axis = (;),
        legend = (;),
        kwargs...,
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nparams = length(keys_to_plot)
    fig = Makie.Figure(;
        size = (
            FC.PlotUtils.DEFAULT_WIDTH,
            max(FC.PlotUtils.DEFAULT_HEIGHT, 50 * nparams + 100),
        ),
        figure...,
    )
    nchains = FC.nchains(chn)
    colors = determine_chain_colors(pool_chains ? 1 : nchains, NamedTuple(kwargs))
    a, p = FC.mforestplot!(
        Makie.Axis(fig[1, 1]; _default_forestplot_axis()..., axis...),
        FC.PlotUtils.FlexiChainForest(chn, collect(keys_to_plot), pool_chains);
        kwargs...,
    )
    if !pool_chains
        maybe_add_legend(fig, chn, colors, legend_position; legend...)
    end
    return Makie.FigureAxisPlot(fig, a, p)
end

########################
# Single axis plotting #
########################
function FC.mforestplot(
        grid::MakieGrids, chn::FC.FlexiChain, param_or_params;
        pool_chains::Bool = false, axis = (;), kwargs...
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    ks = collect(keys(chn))
    return FC.mforestplot!(
        Makie.Axis(grid; _default_forestplot_axis()..., axis...),
        FC.PlotUtils.FlexiChainForest(chn, ks, pool_chains);
        kwargs...,
    )
end

function FC.mforestplot!(
        ax::Makie.Axis, chn::FC.FlexiChain, param_or_params;
        pool_chains::Bool = false, kwargs...
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    ks = collect(keys(chn))
    return FC.mforestplot!(
        ax, FC.PlotUtils.FlexiChainForest(chn, ks, pool_chains); kwargs...
    )
end

function FC.mforestplot!(chn::FC.FlexiChain, param_or_params; kwargs...)
    return FC.mforestplot!(Makie.current_axis(), chn, param_or_params; kwargs...)
end

function FC.mforestplot!(
        ax::Makie.Axis, d::FC.PlotUtils.FlexiChainForest;
        point::Symbol = :median, levels = (0.5, 0.94), kwargs...
    )
    point in (:mean, :median) ||
        throw(ArgumentError("point must be :mean or :median, got :$point"))
    all(l -> 0 < l < 1, levels) ||
        throw(ArgumentError("interval levels must be in (0, 1)"))
    sorted_levels = sort(collect(Float64, levels))

    params = d.params
    nparams = length(params)
    nchains = FC.nchains(d.chn)
    colors = determine_chain_colors(d.pool_chains ? 1 : nchains, NamedTuple(kwargs))

    p = nothing
    for (i, param) in enumerate(params)
        y_base = Float64(nparams - i + 1)
        data = FC._get_raw_data(d.chn, param)
        FC.PlotUtils.check_eltype_is_real(data)

        if d.pool_chains
            pooled = vec(data)
            point_val = point === :median ? FC.median(pooled) : FC.mean(pooled)
            p = _draw_intervals!(
                ax, pooled, point_val, y_base, only(colors), sorted_levels
            )
        else
            dodge_total = min(0.4, 0.15 * nchains)
            offsets = nchains > 1 ?
                collect(range(dodge_total / 2, -dodge_total / 2; length = nchains)) :
                [0.0]
            for (j, (datacol, offset)) in enumerate(zip(eachcol(data), offsets))
                col = collect(datacol)
                point_val = point === :median ? FC.median(col) : FC.mean(col)
                p = _draw_intervals!(
                    ax, col, point_val, y_base + offset, colors[j], sorted_levels
                )
            end
        end
    end
    ax.yticks = (Float64.(nparams:-1:1), map(k -> string(k.name), params))
    Makie.ylims!(ax, 0.8, nparams + 1.1)
    return Makie.AxisPlot(ax, p)
end
