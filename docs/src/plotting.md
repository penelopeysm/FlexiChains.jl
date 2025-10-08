# Plotting

FlexiChains defines a few plot recipes which allows you to use [the Plots.jl ecosystem](@extref Plots :doc:`index`) to visualise chains.
In particular, you will want to import StatsPlots.jl.

!!! note "Other backends"
    Integration with (at least) Makie.jl is planned, but not yet implemented.

## Plot types

What kind of plot you get in when using Plots.jl is controlled mainly by the `seriestype` keyword argument.
For example, `plot(..., seriestype=:histogram)` will produce a histogram.
In fact, calling `histogram(...)` simply redirects to `plot(..., seriestype=:histogram)`.

The following series types are supported for `FlexiChain` objects.

| `seriestype=`            | Equivalent function                            | Description                                                                             |
| -------------            | ---------------------                          | -------------                                                                           |
| `:traceplot`             | `FlexiChains.traceplot()`                      | Trace plot of samples                                                                   |
| `:histogram`             | `Plots.histogram()`                            | Histogram of samples                                                                    |
| `:density`               | `Plots.density()`                              | Kernel density estimate of samples                                                      |
| `:mixeddensity`          | `FlexiChains.mixeddensity()`                   | Density plot or histogram, depending on whether the parameter is continuous or discrete |
| `:meanplot`              | `FlexiChains.meanplot()`                       | Running mean of samples                                                                 |
| `:traceplot_and_density` | `Plots.plot()` (with no `seriestype` argument) | Trace plot and mixed density side-by-side                                               |

!!! note "Feature parity with MCMCChains.jl"
    There are still substantially fewer options than in MCMCChains.jl. Other plot types will be added over time, but in the meantime if you need features from MCMCChains, you can convert a `FlexiChain` to an `MCMCChains.Chains` object using `MCMCChains.Chains(chn)`.

## Signature

The above plotting functions should be called with the following signature:

```julia
plotfunc(
    chn[, param_or_params];
    pool_chains::Bool=false,
    split_varnames::Bool=(chn isa FlexiChain{<:VarName}),
    kwargs...
)
```

**Positional arguments**

- `chn` is a `FlexiChain` object.
- `param_or_params` is optional, and can be [anything that is used to index into a chain](@ref "Indexing"). If not provided, all parameters in the chain will be plotted.

**Keyword arguments**

- If `pool_chains=true`, then samples from all chains are concatenated before plotting densities or histograms.
  Otherwise, each chain is plotted separately.

- `split_varnames` is only applicable if the chain key type is a VarName (as would be obtained from Turing).
  It controls whether vector-valued parameters are split into their individual components.
  For example, if `z` is a 2-dimensional parameter, then setting `split_varnames=true` will plot `z[1]` and `z[2]` separately.

  !!! note
      Plots.jl will error when attempting to plot vector-valued parameters, so there is no real reason to disable `split_varnames`, unless you are developing new plot types.

## Gallery

Here, we demonstrate the plotting features with a typical chain sampled from a Turing model.
However, the general principles are applicable to any `FlexiChain` object.

We'll make a model with different types of parameters (continuous, discrete, and vector-valued).

```@example 1
using FlexiChains, StatsPlots, Turing

@model function f()
    x ~ Normal()
    y ~ Poisson(3)
    z ~ MvNormal(zeros(2), I)
end

chn = sample(
    f(), MH(), MCMCThreads(), 1000, 3;
    discard_initial=100, chain_type=VNChain, progress=false
)
```

Notice that the chain has not split `z` up into `z[1]` and `z[2]`.
However, when plotting, it will be automatically split up for you:

```@example 1
plot(chn)
savefig("plot1.svg"); nothing # hide
```

![Trace and density plots of the sampled chain](plot1.svg)

Notice that `Extra` keys, like the log probabilities, are not plotted by default.
If you want to plot specific parameter(s), you can specify them as the second positional argument:

```@example 1
plot(chn, [@varname(x), :logjoint])
savefig("plot2.svg"); nothing # hide
```

![Trace and density plots of x and the logjoint](plot2.svg)

In general, the second argument can be _anything_ that you can index into a chain with.
This means a symbol, a parameter, a `FlexiChains.Extra`, a sub-VarName, or a vector thereof.

While the density plots above are useful for comparing whether the chains have mixed well, the overlapping histograms are harder to make sense of.
You can combine the histograms by setting `pool_chains=true`.
We'll also hide the legend to reduce clutter (keyword arguments like `legend` are simply passed through to Plots.jl):

```@example 1
plot(chn; pool_chains=true, legend=false)
savefig("plot3.svg"); nothing # hide
```

![Trace and pooled density plots of the sampled chain](plot3.svg)
