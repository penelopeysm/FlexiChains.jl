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

$(FC._PARAM_DOCSTRING("cornerplot"))

$(FC._PLOTS_KWARGS_DOCSTRING)
"""
function StatsPlots.cornerplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        kwargs...
    )
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    keys_to_plot = keys(chn)
    data = DimArray(chn) # iters x chains x params
    label = map(vn -> String(Symbol(vn)), lookup(data, FC.PARAM_DIM_NAME))
    # Plots expects iters + chains to be pooled.
    # Weird bugs happen if we don't force concretisation. Just don't ask.
    data = Float64.(reshape(data, size(data, 1) * size(data, 2), size(data, 3)))
    return StatsPlots.cornerplot(data; size = (600, 600), label = label, compact = true, kwargs...)
end

end # module
