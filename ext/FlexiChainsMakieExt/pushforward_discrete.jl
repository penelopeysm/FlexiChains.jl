function _pushforward_discrete_bands(data, quantiles, baseline, residual)
    isodd(length(quantiles)) || throw(ArgumentError("`quantiles` must have odd length"))
    n = length(data)
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
    nq = length(quantiles)
    qs = Matrix{Float64}(undef, nq, n)

    for j in 1:n
        d = residual ? (data[j] .- baseline[j]) : data[j]
        qs[:, j] = FC.PlotUtils.compute_quantile_bands(d, quantiles)
    end

    return qs
end

function _plot_pushforward_discrete!(
    ax::Makie.Axis,
    data;
    quantiles=FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
    baseline=nothing,
    residual=false,
    color=Makie.Cycled(1),
    vertical::Bool=true,
    kwargs...,
)
    qs = _pushforward_discrete_bands(data, quantiles, baseline, residual)
    nq = size(qs, 1)
    n = size(qs, 2)
    n_bands = div(nq, 2)
    positions = collect(1:n)

    p = nothing
    for i in 1:n_bands
        p = Makie.barplot!(
            ax,
            positions,
            qs[nq+1-i, :];
            fillto=qs[i, :],
            alpha=_band_alpha(i, n_bands),
            color=color,
            strokewidth=0,
            direction=vertical ? :y : :x,
            width=0.6,
            kwargs...,
        )
    end

    if baseline !== nothing && !residual
        Makie.scatter!(
            ax,
            vertical ? positions : baseline,
            vertical ? baseline : positions;
            color=:black,
            marker=:xcross,
            markersize=12,
        )
    elseif residual
        func! = vertical ? Makie.hlines! : Makie.vlines!
        func!(ax, [0.0]; color=:black, linestyle=:dash, linewidth=1)
    end

    return Makie.AxisPlot(ax, p)
end


"""
    FlexiChains.Makie.pushforward_discrete(chn, param_or_params; vertical=true, kwargs...)

Plot each component of an array parameter as an independent quantile bar, with nested
intervals shown as stacked bands. Unlike [`pushforward_continuous`](@ref
FlexiChains.Makie.pushforward_continuous), components are not connected; each bar is separated from
its neighbours , making this appropriate when the components have no natural ordering or
functional relationship (e.g. group-level intercepts in a hierarchical model).

This function is a port of [Michael Betancourt's
`plot_disc_pushforward_quantiles`](https://github.com/betanalpha/mcmc_visualization_tools).

# Keyword arguments
#
- `vertical`: if `true`, bars are vertical; otherwise horizontal. Defaults to `true`.
- `quantiles`: odd-length vector of levels in 0–1. Defaults to `[0.1, 0.2, ..., 0.9]`.
- `baseline`: length-N vector overlaid per index.
- `residual`: if `true`, subtract `baseline` before banding (requires `baseline`).
- `figure`, `axis`: `NamedTuple`s forwarded to `Makie.Figure` / `Makie.Axis`.
"""
function FC.Makie.pushforward_discrete(
    chn::FC.FlexiChain,
    param;
    figure=(;),
    axis=(;),
    kwargs...,
)
    fig = isempty(figure) ? Figure() : Figure(; figure...)
    ax = Makie.Axis(fig[1, 1]; axis...)
    _, p = FC.Makie.pushforward_discrete!(ax, chn, param; kwargs...)
    return Makie.FigureAxisPlot(fig, ax, p)
end

function FC.Makie.pushforward_discrete!(
    ax::Makie.Axis,
    chn::FC.FlexiChain,
    param;
    vertical::Bool=true,
    kwargs...,
)
    sub, plot_names = FC.PlotUtils.subset_and_split_chain(chn, param)
    ks = collect(keys(sub))
    kstrs = [FC.PlotUtils.get_plot_param_name(k, plot_names) for k in ks]
    isempty(ks) && throw(ArgumentError("no parameters to plot"))
    data = map(ks) do k
        d = FC.PlotUtils._get_raw_data(sub, k)
        FC.PlotUtils.check_eltype_is_real(d)
        d
    end
    ticks = (1:length(ks), kstrs)
    if vertical
        ax.xticks = ticks
        ax.xlabel = "parameter"
        ax.ylabel = "value"
    else
        ax.yticks = ticks
        ax.xlabel = "value"
        ax.ylabel = "parameter"
    end
    return _plot_pushforward_discrete!(ax, data; vertical, kwargs...)
end

function FC.Makie.pushforward_discrete!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.pushforward_discrete!(Makie.current_axis(), chn, param; kwargs...)
end
