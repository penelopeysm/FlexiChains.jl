module FlexiChainsStatsPlotsExt

using FlexiChains: FlexiChains as FC
using DimensionalData: DimArray, lookup
using StatsPlots: StatsPlots

# Have to manually overload because cornerplot is marked as `@userplot` in StatsPlots, which
# doesn't dispatch via the usual recipe mechanism.

"""
    StatsPlots.cornerplot(
        chn::FlexiChain[, param_or_params];
        kwargs...
    )

Make a corner plot of `chn` using Plots.jl.

$(FC.PlotUtils._PARAM_DOCSTRING("cornerplot"))

$(FC.Plots._PLOTS_KWARGS_DOCSTRING)
"""
function StatsPlots.cornerplot(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    kwargs...,
)
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    data = DimArray(chn) # iters x chains x params
    label = map(vn -> String(Symbol(vn)), lookup(data, FC.PARAM_DIM_NAME))
    # Plots expects iters + chains to be pooled.
    # Weird bugs happen if we don't force concretisation. Just don't ask.
    data = Float64.(reshape(data, size(data, 1) * size(data, 2), size(data, 3)))
    return StatsPlots.cornerplot(
        data;
        size=(600, 600),
        label=label,
        compact=true,
        kwargs...,
    )
end

####################################################################################
# Everything below this is just docstrings which we need to attach to functions in
# Plots/StatsPlots.
####################################################################################

"""
    Plots.density(
        chn::FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        kwargs...
    )

Make a density plot of the parameter values in `chn` using Plots.jl.

$(FC.PlotUtils._PARAM_DOCSTRING("density"))

$(FC.PlotUtils._POOL_CHAINS_DOCSTRING)

$(FC.Plots._PLOTS_KWARGS_DOCSTRING)
"""
StatsPlots.density

"""
    Plots.histogram(
        chn::FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        kwargs...
    )

Make a histogram of the parameter values in `chn` using Plots.jl.

$(FC.PlotUtils._PARAM_DOCSTRING("histogram"))

$(FC.PlotUtils._POOL_CHAINS_DOCSTRING)

$(FC.Plots._PLOTS_KWARGS_DOCSTRING)
"""
StatsPlots.histogram

"""
    Plots.violin(
        chn::FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        with_box::Bool=false,
        kwargs...
    )

Make a violin plot of `chn` using Plots.jl.

$(FC.PlotUtils._PARAM_DOCSTRING("violin"))

$(FC.PlotUtils._POOL_CHAINS_DOCSTRING)

If `with_box=true`, a box plot will additionally be overlaid on the violin plot.

$(FC.Plots._PLOTS_KWARGS_DOCSTRING) (For `with_box=true`, keyword arguments are passed to
both the violin and box plot components.)
"""
StatsPlots.violin

end # module
