# No title: connquantiles plots an array variable as a whole, not a single leaf.
_default_connquantiles_axis() = (xlabel = "index", ylabel = "value")

"""
    FlexiChains.Makie.connquantiles(chn, param, plot_xs=nothing; kwargs...)

Plot nested quantile credible-interval bands of an array variable's components, connected
across `plot_xs` into a continuous "function envelope" (Betancourt's
`plot_conn_pushforward_quantiles`).

`param` is a single array-valued `VarName`/`Symbol` (auto-expanded to ordered leaves) or a
vector of scalar keys. `plot_xs` defaults to `1:N` (number of components).

# Keyword arguments
- `quantiles`: odd-length vector of levels in 0–100. Default `[10,…,90]`.
- `baseline`: length-N vector overlaid as a reference line.
- `residual`: if `true`, subtract `baseline` before banding (requires `baseline`).
- `figure`, `axis`: NamedTuples forwarded to `Makie.Figure` / `Makie.Axis`.
"""
function FC.Makie.connquantiles(
    chn::FC.FlexiChain,
    param,
    plot_xs = nothing;
    quantiles = FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
    figure = (;),
    axis = (;),
    kwargs...,
)
    _, _, fig = setup_figure_and_layout(1, 1, nothing, figure)
    ax = Makie.Axis(fig[1, 1]; _default_connquantiles_axis()..., axis...)
    _, p = FC.Makie.connquantiles!(ax, chn, param, plot_xs; quantiles, kwargs...)
    return Makie.FigureAxisPlot(fig, ax, p)
end

function FC.Makie.connquantiles!(
    ax::Makie.Axis,
    chn::FC.FlexiChain,
    param,
    plot_xs = nothing;
    quantiles = FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
    baseline = nothing,
    residual = false,
    color = Makie.Cycled(1),
    kwargs...,
)
    isodd(length(quantiles)) || throw(ArgumentError("`quantiles` must have odd length"))
    ks, data = FC.PlotUtils.leaf_series(chn, param)
    n = length(ks)
    xs = plot_xs === nothing ? collect(Float64, 1:n) : collect(Float64, plot_xs)

    if length(xs) != n
        throw(
            ArgumentError(
                "length of `plot_xs` ($(length(xs))) must match number of components ($n)",
            ),
        )
    end

    if residual && baseline === nothing
        throw(ArgumentError("`residual=true` requires `baseline`"))
    end

    if baseline !== nothing && length(baseline) != n
        throw(
            ArgumentError(
                "length of `baseline` ($(length(baseline))) must match number of components ($n)",
            ),
        )
    end

    nq = length(quantiles);
    n_bands = nq ÷ 2;
    median_idx = (nq + 1) ÷ 2
    qs = Matrix{Float64}(undef, nq, n)

    for j in 1:n
        d = residual ? (data[j] .- baseline[j]) : data[j]
        qs[:, j] = FC.PlotUtils.compute_quantile_bands(d, quantiles)
    end

    base_color = _resolve_base_color(color)
    p = nothing

    for i in 1:n_bands
        p = Makie.band!(
            ax,
            xs,
            qs[i, :],
            qs[nq+1-i, :];
            color = (base_color, _band_alpha(i, n_bands)),
            kwargs...,
        )
    end

    median_p = Makie.lines!(ax, xs, qs[median_idx, :]; color = base_color, linewidth = 2)
    p = p === nothing ? median_p : p  # median-only case (n_bands == 0)

    if residual
        Makie.hlines!(ax, [0.0]; color = :black, linestyle = :dash, linewidth = 1)
    elseif baseline !== nothing
        Makie.lines!(
            ax,
            xs,
            collect(Float64, baseline);
            color = :black,
            linestyle = :dash,
            linewidth = 2,
        )
    end

    return Makie.AxisPlot(ax, p)
end

function FC.Makie.connquantiles!(chn::FC.FlexiChain, param, plot_xs = nothing; kwargs...)
    return FC.Makie.connquantiles!(Makie.current_axis(), chn, param, plot_xs; kwargs...)
end
