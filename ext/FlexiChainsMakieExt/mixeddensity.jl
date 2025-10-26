function isdiscrete(chn::FC.FlexiChain{T}, k::FC.ParameterOrExtra{<:T}) where {T}
    raw_data = FC._get_raw_data(chn, k)
    return eltype(raw_data) <: Integer
end

"""
This handles plotting onto a full Figure.
"""
function FC.mmixeddensity(
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
    # This order means that plots go from left to right before going to the next row
    indices = Iterators.product(1:ncols, 1:nrows)
    for ((col, row), k) in zip(indices, keys_to_plot)
        axis_kwargs = if isdiscrete(chn, k)
            _default_histogram_axis(k)
        else
            _default_density_axis(k)
        end
        a, p = FlexiChains.mmixeddensity!(
            Makie.Axis(figure[row, col]; axis_kwargs..., axis...),
            FC.PlotUtils.FlexiChainMixedDensity(chn, k, pool_chains);
            kwargs...,
        )
    end
    if pool_chains
        # Extract the colors used in the last axis
        colors = map(p -> p.color[], a.scene.plots)
        maybe_add_legend(figure, chn, colors, legend_position; legend...)
    end
    return Makie.FigureAxisPlot(figure, a, p)
end

"""
This handles plotting onto a single Axis.
"""
function FC.mtraceplot(grid::MakieGrids, chn::FC.FlexiChain, param; axis=(;), kwargs...)
    # TODO: Error if there is already something at the grid position?
    # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    axis_kwargs = if isdiscrete(chn, k)
        _default_histogram_axis(k)
    else
        _default_density_axis(k)
    end
    return FC.mmixeddensity!(
        Makie.Axis(grid; axis_kwargs..., axis...), chn, param; kwargs...
    )
end
function FC.mmixeddensity!(
    ax::Makie.Axis, chn::FC.FlexiChain, param; pool_chains::Bool=false, kwargs...
)
    k = only(FC.PlotUtils.get_keys_to_plot(chn, param))
    a, p = FC.mmixeddensity!(
        ax, FC.PlotUtils.FlexiChainMixedDensity(chn, k, pool_chains); kwargs...
    )
    return Makie.AxisPlot(a, p)
end
function FC.mmixeddensity!(chn::FC.FlexiChain, param; kwargs...)
    return FC.mmixeddensity!(Makie.current_axis(), chn, param; kwargs...)
end

"""
This is the actual function that does the density plotting.
"""
function FC.mmixeddensity!(
    ax::Makie.Axis, d::FC.PlotUtils.FlexiChainMixedDensity; kwargs...
)
    return if isdiscrete(d.chn, d.param)
        Makie.hist!(
            ax, FC.PlotUtils.FlexiChainHistogram(d.chn, d.param, d.pool_chains); kwargs...
        )
    else
        Makie.density!(
            ax, FC.PlotUtils.FlexiChainDensity(d.chn, d.param, d.pool_chains); kwargs...
        )
    end
end
