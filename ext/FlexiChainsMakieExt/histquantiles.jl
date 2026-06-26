# Build "stairs" x-coordinates from bin edges: each bin contributes its two edges.
function _stair_x(edges)
    xs = Float64[]
    for b in 1:(length(edges)-1)
        push!(xs, edges[b], edges[b+1])
    end
    return xs
end

# Repeat each per-bin value twice to align with `_stair_x`.
_stair_y(vals) = repeat(vals, inner = 2)

function _plot_histquantiles!(
    ax::Makie.Axis,
    data;
    observed = nothing,
    nbins::Integer = 25,
    quantiles = FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
    color = Makie.Cycled(1),
    kwargs...,
)
    isodd(length(quantiles)) || throw(ArgumentError("`quantiles` must have odd length"))
    all_vals = reduce(vcat, vec.(data))
    edges = FC.PlotUtils.auto_bin_edges(all_vals, nbins)
    counts = FC.PlotUtils.bin_count_matrices(data, edges)   # vector length nbins of iter×chain

    nq = length(quantiles)
    n_bands = div(nq, 2)
    median_idx = div(nq + 1, 2)
    qs = Matrix{Float64}(undef, nq, nbins)

    for b in 1:nbins
        qs[:, b] = FC.PlotUtils.compute_quantile_bands(counts[b], quantiles)
    end

    base_color = _resolve_base_color(color)
    xs = _stair_x(edges)
    p = nothing

    for i in 1:n_bands
        p = Makie.band!(
            ax,
            xs,
            _stair_y(qs[i, :]),
            _stair_y(qs[nq+1-i, :]);
            color = (base_color, _band_alpha(i, n_bands)),
            kwargs...,
        )
    end

    median_p =
        Makie.lines!(ax, xs, _stair_y(qs[median_idx, :]); color = base_color, linewidth = 2)

    p = p === nothing ? median_p : p # median-only case (n_bands == 0)

    if observed !== nothing
        obs = FC.PlotUtils.histogram_counts(observed, edges)
        Makie.lines!(ax, xs, _stair_y(Float64.(obs)); color = :black, linewidth = 2)
    end

    return Makie.AxisPlot(ax, p)
end

"""
    FlexiChains.Makie.histquantiles(chn, param; observed=nothing, nbins=25, kwargs...)

Posterior-predictive histogram check (Betancourt's `plot_hist_quantiles`). `param` is one
predictive array variable. Its component values are binned per posterior draw; each bin's
count distribution is summarised with a nested quantile ribbon. x = value bins, y = counts.

# Keyword arguments
- `observed`: vector of observed values; its histogram (same bins) is overlaid as a line.
- `nbins`: number of equal-width bins. Default `25`.
- `quantiles`: odd-length vector of levels in 0–100. Default `[10,…,90]`.
- `figure`, `axis`: NamedTuples forwarded to `Makie.Figure` / `Makie.Axis`.
"""
function FC.Makie.histquantiles(
    chn::FC.FlexiChain,
    param;
    figure = (;),
    axis = (;),
    kwargs...,
)
    _, data = FC.PlotUtils.leaf_series(chn, param)
    _, _, fig = setup_figure_and_layout(1, 1, nothing, figure)
    ax = Makie.Axis(fig[1, 1]; xlabel = "value", ylabel = "counts", axis...)
    _, p = _plot_histquantiles!(ax, data; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, p)
end

function FC.Makie.histquantiles!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    _, data = FC.PlotUtils.leaf_series(chn, param)
    return _plot_histquantiles!(ax, data; kwargs...)
end

function FC.Makie.histquantiles!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.histquantiles!(Makie.current_axis(), chn, param; kwargs...)
end
