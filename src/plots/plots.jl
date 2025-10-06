using FlexiChains: FlexiChains as FC
using RecipesBase: @recipe, @userplot, @series, plot, plot!

function _check_eltype(::AbstractArray{T}) where {T}
    if !(T <: Real)
        throw(
            ArgumentError(
                "plotting functions only support real-valued data; got data of type $T"
            ),
        )
    end
end

const DEFAULT_WIDTH = 380
const DEFAULT_HEIGHT = 250

#########################
# Convenience functions #
#########################

# These have the same effect as doing `@userplot Trace`, but avoid cluttering the namespace
# with an extra struct, plus macro obfuscation.
# Note that these are later exported from FlexiChains.
trace(chn::FC.FlexiChain, params; kw...) = plot(chn, params; kw..., seriestype=:trace)
trace!(chn::FC.FlexiChain, params; kw...) = plot!(chn, params; kw..., seriestype=:trace)

###############################
# The actual plotting recipes #
###############################

"""
Main entry point for multiple-parameter plotting.
"""
@recipe function _(chn::FC.FlexiChain{T}, params::Union{AbstractVector,Colon}) where {T}
    # Figure out the keys to plot
    keys_to_plot = FC._get_multi_keys(T, keys(chn), params)
    st = get(plotattributes, :seriestype, missing)
    # We can then use that to dispatch to the appropriate recipe.
    ncols = ismissing(st) ? 2 : 1
    nrows = length(keys_to_plot)
    layout := (nrows, ncols)
    size := (DEFAULT_WIDTH * ncols, DEFAULT_HEIGHT * nrows)
    for (i, p) in enumerate(keys_to_plot)
        if ismissing(st)
            left_margin := (5, :mm)
            bottom_margin := (5, :mm)
            @series begin
                subplot := 2i - 1
                FlexiChainTrace(chn, p)
            end
            @series begin
                subplot := 2i
                FlexiChainAutoDensity(chn, p)
            end
        else
            @series begin
                subplot := i
                chn, p
            end
        end
    end
end

"""
Main entry point for single-parameter plotting using RecipesBase methods (e.g. `plot`,
`density`, `histogram`. The only thing this recipe does is to decide which custom
type to dispatch to, based on the `seriestype` argument.
"""
@recipe function _(chn::FC.FlexiChain{T}, param::FC.ParameterOrExtra{<:T}) where {T}
    # If the user calls `plot(chn, param)`, then `seriestype` will not be populated; we can set
    # it to `traceplot` in that case. On the other hand, if the user calls (for example)
    # `density(chn, param)`, then `seriestype` will be `:density`.
    st = get(plotattributes, :seriestype, missing)
    # We can then use that to dispatch to the appropriate recipe.
    if ismissing(st)
        return FlexiChainTraceAndAutoDensity(chn, param)
    elseif st === :trace
        return FlexiChainTrace(chn, param)
    elseif st === :density
        return FlexiChainDensity(chn, param)
    elseif st === :histogram
        return FlexiChainHistogram(chn, param)
    else
        return (chn, param, st)
    end
end

"""
Generic fallback recipe when the user specifies a `seriestype` we don't know how to deal
with.
"""
@recipe function _(
    chn::FC.FlexiChain{T}, param::FC.ParameterOrExtra{<:T}, seriestype::Symbol
) where {T}
    x = FC.iter_indices(chn)
    y = FC._get_raw_data(chn, param)
    _check_eltype(y)
    @warn "unsupported seriestype `$seriestype` for FlexiChain; will attempt to plot data against iteration numbers, but your plot may not be meaningful"
    return x, y
end

"""
Plot a trace plot and a density/histogram plot side by side.
"""
struct FlexiChainTraceAndAutoDensity{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(tad::FlexiChainTraceAndAutoDensity)
    layout := (1, 2)  # 1 row and 2 columns
    size := (DEFAULT_WIDTH * 2, DEFAULT_HEIGHT)
    left_margin := (5, :mm)
    bottom_margin := (5, :mm)
    @series begin
        subplot := 1
        FlexiChainTrace(tad.chn, tad.param)
    end
    @series begin
        subplot := 2
        FlexiChainAutoDensity(tad.chn, tad.param)
    end
end

"""
Standard MCMC trace plot.
"""
struct FlexiChainTrace{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(t::FlexiChainTrace)
    seriestype := :line
    # Extract data
    x = FC.iter_indices(t.chn)
    y = FC._get_raw_data(t.chn, t.param)
    _check_eltype(y)
    # Set labels
    xguide --> "iteration number"
    yguide --> "value"
    label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(t.chn)))
    title --> t.param.name
    return x, y
end

"""
Detect whether data are discrete or continuous, and dispatch to the histogram and density
methods respectively.
"""
struct FlexiChainAutoDensity{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(ad::FlexiChainAutoDensity)
    # Extract data
    raw = FC._get_raw_data(ad.chn, ad.param)
    _check_eltype(raw)
    # Detect if it's discrete or continuous. This is a bit of a hack!
    if eltype(raw) <: Integer
        return FlexiChainHistogram(ad.chn, ad.param)
    else
        return FlexiChainDensity(ad.chn, ad.param)
    end
end

"""
Density plot for continuous data. The `pool_chains` keyword argument indicates whether to
plot each chain separately (`false`)`, or to combine all chains into a single density
estimate (`true`).
"""
struct FlexiChainDensity{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(d::FlexiChainDensity; pool_chains=false)
    seriestype := :density
    # Extract data
    x = FC.iter_indices(d.chn)
    raw = FC._get_raw_data(d.chn, d.param)
    y = pool_chains ? vec(raw) : raw
    _check_eltype(y)
    # Set labels
    xguide --> "value"
    yguide --> "density"
    if pool_chains
        label --> "pooled"
    else
        label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
    end
    title --> d.param.name
    return x, y
end

"""
Histogram for discrete data. The `pool_chains` keyword argument indicates whether to plot
each chain separately (`false`)`, or to combine all chains into a single histogram (`true`).
"""
struct FlexiChainHistogram{TKey,Tp<:FC.ParameterOrExtra{<:TKey}}
    chn::FC.FlexiChain{TKey}
    param::Tp
end
@recipe function _(h::FlexiChainHistogram; pool_chains=false)
    seriestype := :histogram
    # Extract data
    raw = FC._get_raw_data(h.chn, h.param)
    x = pool_chains ? vec(raw) : raw
    _check_eltype(x)
    # Set labels
    xguide --> "value"
    yguide --> "probability"
    if pool_chains
        label --> "pooled"
    else
        label --> permutedims(map(cidx -> "chain $cidx", FC.chain_indices(h.chn)))
    end
    title --> h.param.name
    bins --> 25
    normalize --> :pdf
    return x
end
