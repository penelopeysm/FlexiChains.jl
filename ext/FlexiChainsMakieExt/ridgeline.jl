function _default_ridgeline_axis()
    return (xlabel="value",)
end

function _get_kde(samples::AbstractArray, scale)
    kd = KernelDensity.kde(vec(samples))
    xs, density = kd.x, kd.density
    density = max.(density, 0.0)
    max_d = maximum(density)
    scaled_density = max_d > 0 ? (density * (scale / max_d)) : density
    return xs, scaled_density
end

"""
    FlexiChains.Makie.ridgeline(
        chn::FC.FlexiChain[, param_or_params];
        scale::Float64=0.8,
        pool_chains::Bool=false,
        kwargs...,
    )

Create a ridgeline (density ridge) plot for the specified parameters in the chain. Each
parameter is shown as a filled kernel density estimate stacked vertically.

$(FC.PlotUtils._PARAM_DOCSTRING("FlexiChains.Makie.ridgeline"))

# Keyword arguments

- `scale::Float64`: height of each ridge relative to the spacing between parameters. Values greater than `1.0` cause ridges to overlap. Defaults to `0.8`.
- `pool_chains::Bool`: whether to pool data from all chains or plot each chain separately. Defaults to `false`.

$(MAKIE_KWARGS_DOCSTRING)
"""
function FC.Makie.ridgeline(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    pool_chains::Bool=false,
    legend_position::Symbol=:bottom,
    figure=(;),
    axis=(;),
    legend=(;),
    kwargs...,
)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
    nparams = length(keys_to_plot)
    fig = Makie.Figure(;
        size=(
            FC.PlotUtils.DEFAULT_WIDTH,
            max(FC.PlotUtils.DEFAULT_HEIGHT, 60 * nparams + 100),
        ),
        figure...,
    )
    nchains = FC.nchains(chn)
    colors = determine_chain_colors(pool_chains ? 1 : nchains, NamedTuple(kwargs))
    a, p = FC.Makie.ridgeline!(
        Makie.Axis(fig[1, 1]; _default_ridgeline_axis()..., axis...),
        FC.PlotUtils.FlexiChainRidgeline(chn, collect(keys_to_plot), pool_chains);
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
function FC.Makie.ridgeline(
    grid::MakieGrids,
    chn::FC.FlexiChain,
    param_or_params;
    pool_chains::Bool=false,
    axis=(;),
    kwargs...,
)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    ks = collect(keys(chn))
    return FC.Makie.ridgeline!(
        Makie.Axis(grid; _default_ridgeline_axis()..., axis...),
        FC.PlotUtils.FlexiChainRidgeline(chn, ks, pool_chains);
        kwargs...,
    )
end

function FC.Makie.ridgeline!(
    ax::Makie.Axis,
    chn::FC.FlexiChain,
    param_or_params;
    pool_chains::Bool=false,
    kwargs...,
)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    ks = collect(keys(chn))
    return FC.Makie.ridgeline!(
        ax,
        FC.PlotUtils.FlexiChainRidgeline(chn, ks, pool_chains);
        kwargs...,
    )
end

function FC.Makie.ridgeline!(chn::FC.FlexiChain, param_or_params; kwargs...)
    return FC.Makie.ridgeline!(Makie.current_axis(), chn, param_or_params; kwargs...)
end

function FC.Makie.ridgeline!(
    ax::Makie.Axis,
    d::FC.PlotUtils.FlexiChainRidgeline;
    scale::Float64=0.8,
    kwargs...,
)
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
            xs, dens_scaled = _get_kde(data, scale)
            ys_upper = y_base .+ dens_scaled
            p = Makie.band!(
                ax,
                xs,
                fill(y_base, length(xs)),
                ys_upper;
                kwargs...,
                color=only(colors),
            )
        else
            for (j, datacol) in enumerate(eachcol(data))
                xs, dens_scaled = _get_kde(datacol, scale)
                ys_upper = y_base .+ dens_scaled
                p = Makie.band!(
                    ax,
                    xs,
                    fill(y_base, length(xs)),
                    ys_upper;
                    kwargs...,
                    color=colors[j],
                )
            end
        end
    end
    ax.yticks = (Float64.(nparams:-1:1), map(k -> string(k.name), params))
    Makie.ylims!(ax, 0.8, nparams + 1.1)
    return Makie.AxisPlot(ax, p)
end
