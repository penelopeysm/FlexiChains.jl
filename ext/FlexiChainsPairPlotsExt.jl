module FlexiChainsPairPlotsExt

import FlexiChains as FC
using PairPlots
using Makie: wong_colors

"""
    PairPlots.Series(chn::FlexiChain; split_varnames=true, kwargs...)

Create a `PairPlots.Series` from the given `FlexiChain`. The series data will contain one
column for each key in the chain.

Note that this function will include *all* keys in the chain, including `Extra` keys. If you
only want to include a subset of keys, you should first subset the chain, for example with
`chn[[key1, key2, ...]]`, and then pass that subsetted chain in.

If `split_varnames` is `true`, then parameters in the chain will be split into their
constituent real-valued elements. This is necessary for plotting. In practice there should
never be any reason to set this to `false`, unless you already know that your chain contains
only scalar variables and you want to avoid the cost of splitting the variable names again.
"""
function PairPlots.Series(
        chn::FC.FlexiChain; split_varnames = true, kwargs...
    )
    split_chn = if split_varnames
        FC._split_varnames(chn)
    else
        chn
    end
    all_data = NamedTuple(Symbol(FC.get_name(k)) => vec(split_chn[k]) for k in keys(split_chn))
    return PairPlots.Series(all_data; kwargs...)
end

"""
    PairPlots.pairplot(
        chn::FlexiChain[, param_or_params];
        args=(),
        pool_chains::Bool=false,
        divergences=nothing,
        divergences_kwargs=(; markersize=3, color=:red),
        kwargs...
    )

Create a pair plot for the given chain. Note that PairPlots.jl uses Makie.jl as its plotting
backend, so you will additionally need to load a Makie backend (e.g. with `using GLMakie` or
`using CairoMakie`) before calling this function.

$(FC._PARAM_DOCSTRING("pairplot"))

## Keyword arguments

- `args`: a tuple of additional arguments to pass to `PairPlots.pairplot`. This can be used
  to specify additional series to plot, for example.

- `pool_chains`: controls whether to pool all chains together into a single series, or to
  plot each chain separately.

- `divergences`: specifies a key name in the chain that contains a boolean array indicating
  which samples are divergences. If provided, divergent samples will be highlighted in the
  plot. Note that for HMC/NUTS chains sampled with Turing.jl, the key name for divergences
  is (as of Turing v0.43) `:numerical_error`. By default this is `nothing`, which disables
  plotting of divergences (because not all chains will have this information).

- `divergences_kwargs`: a `NamedTuple` of keyword arguments which is eventually passed to
  `Makie.scatter`, which can be used to control the appearance of the points.
  Defaults to `(; markersize=3, color=:red)`.

Other keyword arguments are passed to `PairPlots.pairplot`.
"""
function PairPlots.pairplot(
        chn::FC.FlexiChain,
        param_or_params = FC.Parameter.(FC.parameters(chn));
        args = (),
        pool_chains::Bool = false,
        divergences = nothing,
        divergences_kwargs = (; markersize = 3, color = :red),
        kwargs...
    )
    # Get the divergences first, before we subset the chain
    divergence_mask = if divergences !== nothing
        m = chn[divergences]
        if !isa(m, AbstractMatrix{Bool})
            throw(ArgumentError("The `divergences` key must correspond to a boolean array."))
        end
        m
    else
        nothing
    end
    chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
    series = if pool_chains
        # already split above, so don't need to split again here
        (PairPlots.Series(chn; split_varnames = false),)
    else
        # Need to manually specify colours here because PairPlots
        # doesn't add them when directly plotting Series objects
        # https://github.com/sefffal/PairPlots.jl/pull/78
        wc = wong_colors()
        color(i) = wc[mod1(i, length(wc))]
        Tuple(
            PairPlots.Series(
                    chn[chain = ci];
                    split_varnames = false,  # already split above
                    label = "chain $ci", color = color(i), strokecolor = color(i),
                ) for (i, ci) in enumerate(FC.chain_indices(chn))
        )
    end
    # Identify divergent samples
    divergence_arg = if divergence_mask !== nothing
        samples = NamedTuple(Symbol(FC.get_name(k)) => chn[k][divergence_mask] for k in keys(chn))
        # Can't plot Series => (Scatter,): see
        # https://github.com/sefffal/PairPlots.jl/issues/80
        # (PairPlots.Series(samples; label="divergences", color=:red, strokecolor=:red) => (PairPlots.Scatter(; divergences_kwargs...),),)
        (samples => (PairPlots.Scatter(; divergences_kwargs...),),)
    else
        ()
    end
    return PairPlots.pairplot(series..., divergence_arg..., args...; kwargs...)
end

end # module
