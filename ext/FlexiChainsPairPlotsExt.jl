module FlexiChainsPairPlotsExt

import FlexiChains as FC
using PairPlots

function make_series(chn::FC.FlexiChain{TKey}, keys; label = nothing) where {TKey <: FC.VarName}
    all_data = NamedTuple(Symbol(FC.get_name(k)) => vec(chn[k]) for k in keys)
    return PairPlots.Series(all_data; label)
end

function PairPlots.pairplot(
        chn::FC.FlexiChain{TKey},
        param_or_params = FC.Parameter.(FC.parameters(chn));
        pool_chains::Bool = false,
    ) where {TKey <: FC.VarName}
    keys = FC.PlotUtils.get_keys_to_plot(chn, param_or_params)
    series = if pool_chains
        (make_series(chn, keys)...,)
    else
        Tuple(make_series(chn[chain = i], keys; label = "chain $i") for i in FC.chain_indices(chn))
    end
    return PairPlots.pairplot(series...)
end

end # module
