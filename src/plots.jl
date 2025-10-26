function _PLOTS_DOCSTRING_SUPPLEMENTARY(funcname)
    return """
If no parameters are specified, this will plot all parameters in the chain. Note that
non-parameter, i.e. `Extra`, keys are excluded by default. If you want to plot _all_ keys,
you can explicitly pass all keys with `$(funcname)(chn, :)`.

Keyword arguments are forwarded to Plots.jl's functions.
"""
end

"""
    FlexiChains.traceplot(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Create a trace plot of the specified parameter(s) in the given `FlexiChain`.

$(_PLOTS_DOCSTRING_SUPPLEMENTARY("traceplot"))
"""
function traceplot end

"""
    FlexiChains.traceplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.traceplot`, but uses `plot!` instead of `plot`.
"""
function traceplot! end

"""
    FlexiChains.mixeddensity(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Create either a density plot, or a histogram, of the specified parameter(s) in the given
`FlexiChain`. Continuous-valued parameters are plotted using density plots, discrete-valued
parameters with histograms.

$(_PLOTS_DOCSTRING_SUPPLEMENTARY("mixeddensity"))
"""
function mixeddensity end

"""
    FlexiChains.mixeddensity!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.mixeddensity`, but uses `plot!` instead of `plot`.
"""
function mixeddensity! end

"""
    FlexiChains.meanplot(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Plot the running mean of the specified parameter(s) in the given `FlexiChain`.

$(_PLOTS_DOCSTRING_SUPPLEMENTARY("meanplot"))
"""
function meanplot end

"""
    FlexiChains.meanplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.meanplot`, but uses `plot!` instead of `plot`.
"""
function meanplot! end

"""
    FlexiChains.autocorplot(
        chn::FlexiChain{TKey}[, param_or_params];
        lags=1:min(niters(chn)-1, round(Int,10*log10(niters(chn)))),
        demean=true,
        kwargs...
    )

Plot the autocorrelation of the specified parameter(s) in the given `FlexiChain`.

The `lags` keyword argument can be used to specify which lags to plot. If `nothing` is
passed (the default), this is set to the integers from 1 to `min(niters-1,
round(Int,10*log10(niters)))` where `niters` is the number of iterations in the chain. This
mimics the default behaviour of [`StatsBase.autocor`](@extref).

The `demean` keyword argument specifies whether to subtract the mean of the parameter before
computing the autocorrelation, and is passed to [`StatsBase.autocor`](@extref).

$(_PLOTS_DOCSTRING_SUPPLEMENTARY("autocorplot"))
"""
function autocorplot end

"""
    FlexiChains.autocorplot!(
        chn::FlexiChain{TKey}[, param_or_params];
        kwargs...
    )

Same as `FlexiChains.autocorplot`, but uses `plot!` instead of `plot`.
"""
function autocorplot! end

###########################################################
# Utility functions for plotting (shared across backends) #
###########################################################
#
# We stick these in a module to avoid cluttering the main FlexiChains namespace.

module PlotUtils

const DEFAULT_WIDTH = 400
const DEFAULT_HEIGHT = 250

using ..FlexiChains:
    FlexiChain,
    ParameterOrExtra,
    VarName,
    split_varnames,
    niters,
    _get_multi_keys,
    _get_multi_key

"""
Figure out which keys to plot. Most of the heavy lifting here is done by `_get_multi_keys`
which is the same as for indexing. However, this function is also responsible for splitting
VarName chains up into constituent leaf VarNames before plotting.
"""
function get_keys_to_plot(chn::FlexiChain{TKey}, param_or_params) where {TKey}
    parameters_to_plot = if param_or_params isa AbstractVector
        _get_multi_keys(TKey, keys(chn), param_or_params)
    else
        # Assume it's a single key. No, don't ask what happens if the key type is an
        # AbstractVector...
        [_get_multi_key(TKey, keys(chn), param_or_params)]
    end
    # Subset the chain to just those parameters. Ordinarily we wouldn't need to do this; we
    # would just directly return `keys_to_plot`. However, there are some subtle
    # considerations when using VarName chains. See below for a full explanation.
    chn = chn[parameters_to_plot]
    # Now, we split VarNames into real-valued parameters if requested.
    if TKey <: VarName
        chn = split_varnames(chn)
    end
    # Re-calculate which keys need to be plotted. Now, in the general case, `keys_to_plot`
    # will _already_ be the same as `keys(chn)` because of the subsetting above. However, if
    # it's a VarName chain and a VarName has been split up, it's possible that they may be
    # different. For example, consider a chain with `@varname(x)` being a length-2 vector.
    # If the user calls `plot(chn, [@varname(x)])`, then `keys_to_plot` will initially be
    # `[@varname(x)]`. BUT this line is what allows us to reassign the value of
    # `keys_to_plot` to be `[@varname(x[1]), @varname(x[2])]` after the split. If we didn't
    # do this, it would error in mystifying ways.
    return collect(keys(chn))
end

"""
Check that the element type of the array is a subtype of `Real`.
"""
function check_eltype_is_real(::AbstractArray{T}) where {T}
    if !(T <: Real)
        throw(
            ArgumentError(
                "plotting functions only support real-valued data; got data of type $T"
            ),
        )
    end
end

struct FlexiChainTrace{TKey,Tp<:ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
end

struct FlexiChainHistogram{TKey,Tp<:ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

function runningmean(v::AbstractVector{<:Union{Real,Missing}})
    y = similar(v, Float64)
    n = 0
    sum = zero(eltype(v))
    for i in eachindex(v)
        if !ismissing(v[i])
            n += 1
            sum += v[i]
        end
        y[i] = sum / n
    end
    return y
end
struct FlexiChainMean{TKey,Tp<:ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
end

"""
Calculate default lags for autocorrelation plots. This is directly taken from StatsBase.jl.
"""
function default_lags(chn::FlexiChain)
    return 1:min(niters(chn) - 1, round(Int, 10 * log10(niters(chn))))
end
struct FlexiChainAutoCor{TKey,Tp<:ParameterOrExtra{<:TKey},Tl<:AbstractVector{Int}}
    chn::FlexiChain{TKey}
    param::Tp
    lags::Tl
    demean::Bool
end

struct FlexiChainMixedDensity{TKey,Tp<:ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

struct FlexiChainDensity{TKey,Tp<:ParameterOrExtra{<:TKey}}
    chn::FlexiChain{TKey}
    param::Tp
    pool_chains::Bool
end

end # module PlotUtils
