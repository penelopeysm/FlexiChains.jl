function _default_density_axis(k::FC.ParameterOrExtra)
    return (xlabel="value", ylabel="density", title=string(k.name))
end

"""
This handles plotting onto a full Figure.
"""
function Makie.density(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    pool_chains::Bool=false,
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
    for (i, k) in enumerate(keys_to_plot)
        a, p = Makie.density!(
            Makie.Axis(figure[i, 1]; _default_density_axis(k)..., axis...),
            FC.PlotUtils.FlexiChainDensity(chn, k, pool_chains);
            kwargs...,
        )
    end
    # Extract the colors used in the last axis
    colors = map(p -> p.color[], a.scene.plots)
    # Don't create a legend if chains were pooled
    pool_chains || maybe_add_legend(figure, chn, colors, legend_position; legend...)
    return Makie.FigureAxisPlot(figure, a, p)
end

"""
This handles plotting onto a single Axis.
"""
function Makie.density(grid::MakieGrids, chn::FC.FlexiChain, param; axis=(;), kwargs...)
    # TODO: Error if there is already something at the grid position?
    # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    return Makie.density!(
        Makie.Axis(grid; _default_density_axis(k)..., axis...), chn, param; kwargs...
    )
end
function Makie.density!(
    ax::Makie.Axis, chn::FC.FlexiChain, param; pool_chains::Bool=false, kwargs...
)
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    a, p = Makie.density!(
        ax, FC.PlotUtils.FlexiChainDensity(chn, k, pool_chains); kwargs...
    )
    return Makie.AxisPlot(a, p)
end
function Makie.density!(chn::FC.FlexiChain, param; kwargs...)
    return Makie.density!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the density plotting.
"""
function Makie.density!(ax::Makie.Axis, d::FC.PlotUtils.FlexiChainDensity; kwargs...)
    y = FC._get_raw_data(d.chn, d.param)
    FC.PlotUtils.check_eltype_is_real(y)
    p = nothing
    if d.pool_chains
        p = Makie.density!(ax, vec(y); label="pooled", kwargs...)
    else
        labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
        nchains = size(y, 2)
        color_kwargs = determine_color_kwargs(nchains, NamedTuple(kwargs))
        for (label, datacol, color_kwarg) in zip(labels, eachcol(y), color_kwargs)
            p = Makie.density!(ax, datacol; label=label, kwargs..., color_kwarg...)
        end
    end
    return Makie.AxisPlot(ax, p)
end
