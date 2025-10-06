using FlexiChains: FlexiChains as FC
using AbstractPPL: VarName
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

const DEFAULT_WIDTH = 400
const DEFAULT_HEIGHT = 250

#########################
# Convenience functions #
#########################

# These have the same effect as doing `@userplot Trace`, but avoid cluttering the namespace
# with an extra struct, plus macro obfuscation.
# Note that these are later exported from FlexiChains.
trace(chn::FC.FlexiChain; kw...) = plot(chn; kw..., seriestype=:trace)
trace!(chn::FC.FlexiChain; kw...) = plot!(chn; kw..., seriestype=:trace)
trace(chn::FC.FlexiChain, params; kw...) = plot(chn, params; kw..., seriestype=:trace)
trace!(chn::FC.FlexiChain, params; kw...) = plot!(chn, params; kw..., seriestype=:trace)

###############################
# The actual plotting recipes #
###############################

"""
Entry point for single-parameter plotting; simply wraps and sends it to the multi-parameter
method.
"""
@recipe function _(chn::FC.FlexiChain, param)
    return chn, [param]
end
"""
Main entry point for multiple-parameter plotting.

If parameters are unspecified, all parameters in the chain will be plotted. Note that
this excludes non-parameter, `Extra` keys.

`VarName` chains are additionally split up into constituent real-valued parameters by
default, unless the `split_varnames=false` keyword argument is passed.
"""
@recipe function _(
    chn::FC.FlexiChain{TKey},
    params::Union{AbstractVector,Colon,Nothing}=nothing;
    split_varnames=(TKey <: VarName),
) where {TKey}
    # Extract parameters.
    keys_to_plot = if isnothing(params)
        FC.Parameter.(FC.parameters(chn))
    else
        FC._get_multi_keys(TKey, keys(chn), params)
    end
    # Subset the chain to just those parameters. Ordinarily we wouldn't need to do this; we
    # would just iterate over `keys_to_plot`. However, there are some subtle considerations
    # when using VarName chains. See below for a full explanation.
    chn = chn[keys_to_plot]
    # Now, we split VarNames into real-valued parameters if requested.
    if split_varnames
        TKey <: VarName || throw(
            ArgumentError(
                "`split_varnames=true` is only supported for chains with `TKey<:VarName`",
            ),
        )
        chn = FC.split_varnames(chn)
    end
    # Re-calculate which keys need to be plotted. Now, in the general case, `keys_to_plot`
    # will _already_ be the same as `keys(chn)` because of the subsetting above. However, if
    # it's a VarName chain and a VarName has been split up, it's possible that they may be
    # different. For example, consider a chain with `@varname(x)` being a length-2 vector.
    # If the user calls `plot(chn, [@varname(x)])`, then `keys_to_plot` will initially be
    # `[@varname(x)]`. BUT this line is what allows us to reassign the value of
    # `keys_to_plot` to be `[@varname(x[1]), @varname(x[2])]` after the split. If we didn't
    # do this, it would error in mystifying ways.
    keys_to_plot = collect(keys(chn))
    # When the user calls `plot(chn[, params])` without specifying a `seriestype`, we
    # default to showing a side-by-side trace and density/histogram for each parameter.
    # Otherwise, if the user calls `trace`, `density`, `histogram`, etc. then there will be
    # a `seriestype` set for us. In either case, we can then use `seriestype` to set up the
    # layout, and dispatch to the appropriate recipe.
    seriestype = get(plotattributes, :seriestype, :trace_and_density)
    ncols = seriestype === :trace_and_density ? 2 : 1
    nrows = length(keys_to_plot)
    layout := (nrows, ncols)
    size := (DEFAULT_WIDTH * ncols, DEFAULT_HEIGHT * nrows)
    for (i, k) in enumerate(keys_to_plot)
        if seriestype === :trace_and_density
            left_margin := (5, :mm)
            bottom_margin := (5, :mm)
            @series begin
                subplot := 2i - 1
                FlexiChainTrace(chn, k)
            end
            @series begin
                subplot := 2i
                FlexiChainAutoDensity(chn, k)
            end
        else
            @series begin
                subplot := i
                if seriestype === :trace
                    return FlexiChainTrace(chn, k)
                elseif seriestype === :density
                    return FlexiChainDensity(chn, k)
                elseif seriestype === :hiseriestypeogram
                    return FlexiChainHistogram(chn, k)
                else
                    return (chn, k, seriestype)
                end
            end
        end
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
