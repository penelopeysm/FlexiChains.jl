function _default_violin_axis()
    return (xlabel="chain", ylabel="value")
end

const _DEFAULT_BOXPLOT_KWARGS =
    (color=(:gray, 0.8), strokecolor=:black, strokewidth=1, mediancolor=:black, width=0.3)

"""
    Makie.violin(
        chn::FC.FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        with_box::Bool=false,
        box_kwargs::NamedTuple=(;),
        kwargs...,
    )

Create violin plots for the specified parameters in the chain.

$(FC.PlotUtils._PARAM_DOCSTRING("Makie.violin"))

# Keyword arguments

- `pool_chains::Bool`: whether to pool data from all chains into a single plot, or to plot each chain separately. Defaults to `false`.
- `with_box::Bool`: whether to overlay a box plot on each violin plot. Defaults to `false`.
- `box_kwargs::NamedTuple`: keyword arguments passed to `Makie.boxplot!` when
  `with_box=true`. FlexiChains has a set of default boxplot kwargs that are always used, but
  they can be overridden by passing `box_kwargs`.

$(MAKIE_KWARGS_DOCSTRING)
"""
function Makie.violin(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    pool_chains::Bool=false,
    with_box::Bool=false,
    layout::Union{Tuple{Int,Int},Nothing}=nothing,
    legend_position::Symbol=:bottom,
    figure=(;),
    axis=(;),
    legend=(;),
    box_kwargs=(;),
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nrows, ncols, fig = setup_figure_and_layout(length(keys_to_plot), 1, layout, figure)
    a, p = nothing, nothing
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
        a, p = Makie.violin!(
            Makie.Axis(fig[row, col]; _default_violin_axis()..., title=kstr, axis...),
            FC.PlotUtils.FlexiChainViolin(chn, k, pool_chains, with_box);
            box_kwargs,
            kwargs...,
        )
    end
    if !pool_chains
        colors = map(p -> p.color[], a.scene.plots[1:FC.nchains(chn)])
        maybe_add_legend(fig, chn, colors, legend_position; legend...)
    end
    return Makie.FigureAxisPlot(fig, a, p)
end

########################
# Single axis plotting #
########################
function Makie.violin(grid::MakieGrids, chn::FC.FlexiChain, param; axis=(;), kwargs...)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    return Makie.violin!(
        Makie.Axis(grid; _default_violin_axis()..., title=kstr, axis...),
        chn,
        param;
        kwargs...,
    )
end

function Makie.violin!(
    ax::Makie.Axis,
    chn::FC.FlexiChain,
    param;
    pool_chains::Bool=false,
    with_box::Bool=false,
    box_kwargs=(;),
    kwargs...,
)
    chn, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    k = only(keys(chn))
    kstr = FC.PlotUtils.get_plot_param_name(k, plot_names)
    a, p = Makie.violin!(
        ax,
        FC.PlotUtils.FlexiChainViolin(chn, k, pool_chains, with_box);
        box_kwargs,
        kwargs...,
    )
    return Makie.AxisPlot(a, p)
end

function Makie.violin!(chn::FC.FlexiChain, param; kwargs...)
    return Makie.violin!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the violin plotting.
"""
function Makie.violin!(
    ax::Makie.Axis,
    v::FC.PlotUtils.FlexiChainViolin;
    box_kwargs=(;),
    kwargs...,
)
    y = FC._get_raw_data(v.chn, v.param)
    FC.PlotUtils.check_eltype_is_real(y)
    nchains = FC.nchains(v.chn)
    colors = determine_chain_colors(nchains, NamedTuple(kwargs))

    p_violin = nothing
    p_box = nothing

    if v.pool_chains
        # Pool all chains into a single violin
        p_violin =
            Makie.violin!(ax, ones(Int, prod(size(y))), vec(y); label="pooled", kwargs...)
    else
        # One violin per chain
        chain_idxs = FC.chain_indices(v.chn)
        for (cidx, datacol, color) in zip(chain_idxs, eachcol(y), colors)
            p_violin = Makie.violin!(
                ax,
                fill(cidx, length(datacol)),
                datacol;
                label="chain $cidx",
                kwargs...,
                color=color,
            )
        end
    end

    if v.with_box
        if v.pool_chains
            p_box = Makie.boxplot!(
                ax,
                ones(Int, prod(size(y))),
                vec(y);
                label="",
                _DEFAULT_BOXPLOT_KWARGS...,
                box_kwargs...,
            )
        else
            chain_idxs = FC.chain_indices(v.chn)
            for (cidx, datacol, color) in zip(chain_idxs, eachcol(y), colors)
                p_box = Makie.boxplot!(
                    ax,
                    fill(cidx, length(datacol)),
                    datacol;
                    label="",
                    _DEFAULT_BOXPLOT_KWARGS...,
                    box_kwargs...,
                )
            end
        end
    end

    if v.pool_chains
        ax.xticks = ([], [])
    else
        ax.xticks = (1:nchains, map(string, FC.chain_indices(v.chn)))
    end

    return Makie.AxisPlot(ax, something(p_violin, p_box))
end
