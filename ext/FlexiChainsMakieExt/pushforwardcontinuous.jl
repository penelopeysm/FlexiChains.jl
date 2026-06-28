# No title: pushforwardcontinuous plots an array variable as a whole, not a single leaf.
_default_pushforwardcontinuous_axis() = (xlabel = "index", ylabel = "value")

"""
    FlexiChains.Makie.pushforwardcontinuous(chn, param_or_params; x_grid=nothing; kwargs...)

Plot the marginal posterior of each component of an array parameter as a quantile ribbon,
forming a "function envelope" over `x_grid`. Useful for visualising how a functional
quantity (e.g. a fitted curve or spectrum) varies with posterior uncertainty.

This is a port of [Michael Betancourt's
`plot_conn_pushforward_quantiles`](https://github.com/betanalpha/mcmc_visualization_tools).

# Keyword arguments
- `x_grid`: the x-values to plot against. Defaults to `1:N`, where `N` is the number of
  components being plotted.
- `quantiles`: odd-length vector of levels in 0–1. Defaults to `[0.1, 0.2, ..., 0.9]`.
- `baseline`: length-N vector overlaid as a reference line.
- `residual`: if `true`, subtract `baseline` before banding (requires `baseline`).
- `figure`, `axis`: `NamedTuple`s forwarded to `Makie.Figure` / `Makie.Axis`.
"""
function FC.Makie.pushforwardcontinuous(
        chn::FC.FlexiChain,
        param;
        figure = (;),
        axis = (;),
        kwargs...,
    )
    _, _, fig = setup_figure_and_layout(1, 1, nothing, figure)
    ax = Makie.Axis(fig[1, 1]; _default_pushforwardcontinuous_axis()..., axis...)
    _, p = FC.Makie.pushforwardcontinuous!(ax, chn, param; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, p)
end

function FC.Makie.pushforwardcontinuous!(
        ax::Makie.Axis,
        chn::FC.FlexiChain,
        param;
        x_grid = nothing,
        quantiles = FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
        baseline = nothing,
        residual = false,
        color = Makie.Cycled(1),
        kwargs...,
    )
    isodd(length(quantiles)) || throw(ArgumentError("`quantiles` must have odd length"))
    sub = FC.PlotUtils.subset_and_split_chain(chn, param)
    ks = collect(keys(sub))
    isempty(ks) && throw(ArgumentError("no parameters to plot"))
    data = map(ks) do k
        d = FC.PlotUtils._get_raw_data(sub, k)
        FC.PlotUtils.check_eltype_is_real(d)
        d
    end

    n = length(ks)
    xs = x_grid === nothing ? collect(Float64, 1:n) : collect(Float64, x_grid)
    if length(xs) != n
        throw(
            ArgumentError(
                "connquantile: length of `x_grid` ($(length(xs))) must match number of components ($n)",
            ),
        )
    end

    if residual && baseline === nothing
        throw(ArgumentError("connquantile: `residual=true` requires `baseline`"))
    end

    if baseline !== nothing && length(baseline) != n
        throw(
            ArgumentError(
                "length of `baseline` ($(length(baseline))) must match number of components ($n)",
            ),
        )
    end

    nq = length(quantiles)
    n_bands = div(nq, 2)
    median_idx = div(nq + 1, 2)
    qs = Matrix{Float64}(undef, nq, n)

    for j in 1:n
        d = residual ? (data[j] .- baseline[j]) : data[j]
        qs[:, j] = FC.PlotUtils.compute_quantile_bands(d, quantiles)
    end

    for i in 1:n_bands
        Makie.band!(
            ax,
            xs,
            qs[i, :],
            qs[nq + 1 - i, :];
            alpha = _band_alpha(i, n_bands),
            color = color,
            kwargs...,
        )
    end
    p = Makie.lines!(ax, xs, qs[median_idx, :]; color = color, linewidth = 2)

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

function FC.Makie.pushforwardcontinuous!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.pushforwardcontinuous!(Makie.current_axis(), chn, param; kwargs...)
end
