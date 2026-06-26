function _discquantiles_bands(data, quantiles, baseline, residual)
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

# direction = :y -> vertical bars (x = index); direction = :x -> horizontal bars (y = index)
function _plot_discquantiles!(
        ax::Makie.Axis,
        data;
        quantiles = FC.PlotUtils.DEFAULT_QUANTILE_LEVELS,
        baseline = nothing,
        residual = false,
        color = Makie.Cycled(1),
        vertical::Bool = true,
        kwargs...,
    )
    qs = _discquantiles_bands(data, quantiles, baseline, residual)
    nq = size(qs, 1)
    n = size(qs, 2)
    n_bands = nq ÷ 2
    median_idx = (nq + 1) ÷ 2
    base_color = _resolve_base_color(color)
    positions = collect(1:n)
    medians = qs[median_idx, :]

    p = nothing

    for i in 1:n_bands
        p = Makie.barplot!(
            ax,
            positions,
            qs[nq + 1 - i, :];
            fillto = qs[i, :],
            color = (base_color, _band_alpha(i, n_bands)),
            strokewidth = 0,
            direction = vertical ? :y : :x,
            width = 0.6,
            kwargs...,
        )
    end

    median_p = if vertical
        Makie.scatter!(
            ax,
            positions,
            medians;
            color = base_color,
            marker = :hline,
            markersize = 16,
        )
    else
        Makie.scatter!(
            ax,
            medians,
            positions;
            color = base_color,
            marker = :vline,
            markersize = 16,
        )
    end

    p = p === nothing ? median_p : p # median-only case (n_bands == 0)

    if baseline !== nothing && !residual
        bl = collect(Float64, baseline)
        if vertical
            Makie.scatter!(
                ax,
                positions,
                bl;
                color = :black,
                marker = :xcross,
                markersize = 12,
            )
        else
            Makie.scatter!(
                ax,
                bl,
                positions;
                color = :black,
                marker = :xcross,
                markersize = 12,
            )
        end
    elseif residual
        if vertical
            Makie.hlines!(ax, [0.0]; color = :black, linestyle = :dash, linewidth = 1)
        else
            Makie.vlines!(ax, [0.0]; color = :black, linestyle = :dash, linewidth = 1)
        end
    end

    return Makie.AxisPlot(ax, p)
end

# Shared figure builder for the non-mutating variants. Index axis ticks are labelled with the
# component leaf names; `direction` selects which axis carries the index.
function _discquantiles_figure(chn, param, vertical; figure, axis, kwargs...)
    sub = FC.PlotUtils.subset_and_split_chain(chn, param)
    ks = collect(keys(sub))
    isempty(ks) && throw(ArgumentError("no parameters to plot"))
    data = map(ks) do k
        d = FC.PlotUtils._get_raw_data(sub, k)
        FC.PlotUtils.check_eltype_is_real(d)
        d
    end
    _, _, fig = setup_figure_and_layout(1, 1, nothing, figure)
    ticks = (1:length(ks), string.(FC.get_name.(ks)))

    ax_kw = if vertical
        (; xlabel = "index", ylabel = "value", xticks = ticks)
    else
        (; xlabel = "value", ylabel = "index", yticks = ticks)
    end

    ax = Makie.Axis(fig[1, 1]; ax_kw..., axis...)
    _, p = _plot_discquantiles!(ax, data; vertical, kwargs...)
    return Makie.FigureAxisPlot(fig, ax, p)
end

"""
    FlexiChains.Makie.discquantiles(chn, param; kwargs...)

Plot disconnected nested quantile intervals for an array variable's components, side by side
in one axis with vertical bars (Betancourt's `plot_disc_pushforward_quantiles`). x = component
index, y = marginal quantiles.

`param` is a single array-valued `VarName`/`Symbol` or a vector of scalar keys.

# Keyword arguments
- `quantiles`: odd-length vector of levels in 0–100. Default `[10,…,90]`.
- `baseline`: length-N vector overlaid per index.
- `residual`: if `true`, subtract `baseline` before banding (requires `baseline`).
- `figure`, `axis`: NamedTuples forwarded to `Makie.Figure` / `Makie.Axis`.
"""
function FC.Makie.discquantiles(
        chn::FC.FlexiChain,
        param;
        figure = (;),
        axis = (;),
        kwargs...,
    )
    return _discquantiles_figure(chn, param, true; figure, axis, kwargs...)
end

function FC.Makie.discquantiles!(ax::Makie.Axis, chn::FC.FlexiChain, param; kwargs...)
    sub = FC.PlotUtils.subset_and_split_chain(chn, param)
    ks = collect(keys(sub))
    isempty(ks) && throw(ArgumentError("no parameters to plot"))
    data = map(ks) do k
        d = FC.PlotUtils._get_raw_data(sub, k)
        FC.PlotUtils.check_eltype_is_real(d)
        d
    end
    return _plot_discquantiles!(ax, data; kwargs...)
end

function FC.Makie.discquantiles!(chn::FC.FlexiChain, param; kwargs...)
    return FC.Makie.discquantiles!(Makie.current_axis(), chn, param; kwargs...)
end
