###################
# Makie overloads #
###################

module Makie

export traceplot,
    traceplot!,
    rankplot,
    rankplot!,
    mixeddensity,
    mixeddensity!,
    meanplot,
    meanplot!,
    autocorplot,
    autocorplot!,
    connquantiles,
    connquantiles!,
    discquantiles,
    discquantiles!,
    discquantiles_vert,
    discquantiles_vert!,
    histquantiles,
    histquantiles!

# The non-mutating versions have docstrings in the extension.

function traceplot end

"""
    FlexiChains.Makie.traceplot!

Mutating version of [`FlexiChains.Makie.traceplot`](@ref), for use with existing
`Makie.Axis` objects.
"""
function traceplot! end

function rankplot end

"""
    FlexiChains.Makie.rankplot!

Mutating version of [`FlexiChains.Makie.rankplot`](@ref), for use with existing `Makie.Axis`
objects.
"""
function rankplot! end

function mixeddensity end

"""
    FlexiChains.Makie.mixeddensity!

Mutating version of [`FlexiChains.Makie.mixeddensity`](@ref), for use with existing
`Makie.Axis` objects.
"""
function mixeddensity! end

function meanplot end

"""
    FlexiChains.Makie.meanplot!

Mutating version of [`FlexiChains.Makie.meanplot`](@ref), for use with existing `Makie.Axis`
objects.
"""
function meanplot! end

function autocorplot end

"""
    FlexiChains.Makie.autocorplot!

Mutating version of [`FlexiChains.Makie.autocorplot`](@ref), for use with existing
`Makie.Axis` objects.
"""
function autocorplot! end

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
function connquantiles end

"""Mutating version of [`FlexiChains.Makie.connquantiles`](@ref)."""
function connquantiles! end

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
function discquantiles end

"""Mutating version of [`FlexiChains.Makie.discquantiles`](@ref)."""
function discquantiles! end

"""
    FlexiChains.Makie.discquantiles_vert(chn, param; kwargs...)

Rotated form of [`FlexiChains.Makie.discquantiles`](@ref) using horizontal bars (component
index on the y-axis), helpful for long component labels.
"""
function discquantiles_vert end

"""Mutating version of [`FlexiChains.Makie.discquantiles_vert`](@ref)."""
function discquantiles_vert! end

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
function histquantiles end

"""Mutating version of [`FlexiChains.Makie.histquantiles`](@ref)."""
function histquantiles! end

end # module
