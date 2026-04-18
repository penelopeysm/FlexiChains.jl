# Plotting: Plots.jl

FlexiChains defines a few plot recipes which allows you to use [the Plots.jl ecosystem](@extref Plots :doc:`index`) to visualise chains.
In particular, you will want to import StatsPlots.jl.

## Plot types

What kind of plot you get in when using Plots.jl is controlled mainly by the `seriestype` keyword argument.
For example, `plot(..., seriestype=:histogram)` will produce a histogram.
In fact, calling `histogram(...)` simply redirects to `plot(..., seriestype=:histogram)`.

The following series types are supported for `FlexiChain` objects.

| `seriestype=`            | Equivalent function                                                     | Description                                                                             |
| -------------            | ---------------------                                                   | -------------                                                                           |
| `:traceplot`             | `FlexiChains.traceplot()`                                               | Trace plot of samples                                                                   |
| `:histogram`             | `Plots.histogram()`                                                     | Histogram of samples                                                                    |
| `:density`               | `Plots.density()`                                                       | Kernel density estimate of samples                                                      |
| `:mixeddensity`          | [`FlexiChains.mixeddensity()`](@ref)                                    | Density plot or histogram, depending on whether the parameter is continuous or discrete |
| `:meanplot`              | [`FlexiChains.meanplot()`](@ref)                                        | Running mean of samples                                                                 |
| `:autocorplot`           | [`FlexiChains.autocorplot()`](@ref)                                     | Autocorrelation of samples                                                              |
| `:traceplot_and_density` | `Plots.plot()` (with no `seriestype` argument)                          | Trace plot and mixed density side-by-side                                               |
| `:rankplot`              | [`FlexiChains.rankplot(...; overlay=false)`](@ref FlexiChains.rankplot) | Rank plot with separate histograms per chain                                            |
| `:rankplot_overlay`      | [`FlexiChains.rankplot(...; overlay=true)`](@ref FlexiChains.rankplot)  | Rank plot with all chains' data overlaid                                                |

!!! warning "Identifier conflicts"
    Please note that the identifiers `traceplot`, `meanplot`, `mixeddensity`, and `autocorplot` are also exported by MCMCChains.jl and [also currently re-exported by Turing.jl](https://github.com/TuringLang/Turing.jl/issues/2681). For this reason, FlexiChains does not export them, although they are part of the public API. To make sure you are using the FlexiChains versions, you must prefix them with the module name: `FlexiChains.traceplot(...)`. Otherwise, you may run into unexpected errors. 

!!! note "Feature parity with MCMCChains.jl"
    There are still somewhat fewer options than in MCMCChains.jl. Other plot types will be added over time, but in the meantime if you need features from MCMCChains, you can convert a `FlexiChain` to an `MCMCChains.Chains` object using `MCMCChains.Chains(chn)`. Help with adding new plots is very much welcome!

## General interface

The above plotting functions should be called with the following signature:

```julia
plotfunc(
    chn[, param_or_params];
    pool_chains::Bool=false,
    kwargs...
)
```

**Positional arguments**

- `chn` is a `FlexiChain` object.
- `param_or_params` is optional, and can be [anything that is used to index into a chain](@ref "Indexing"). If not provided, all parameters in the chain will be plotted.

**Keyword arguments**

- If `pool_chains=true`, then samples from all chains are concatenated before plotting densities or histograms.
  Otherwise, each chain is plotted separately.

- Some plotting functions like `autocorplot` and `rankplot` have additional keyword arguments which control the details of the plot; please see the docstrings for those functions for more details.

- Other keyword arguments are passed through to the underlying Plots.jl functions which allow you to, for example, control the appearance of the plot.

## Setup

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

## Default plot

Calling `plot(chn)` produces a trace plot and mixed density side-by-side for each parameter.

Notice that the chain has not split `z` up into `z[1]` and `z[2]`.
However, when plotting, it will be automatically split up for you.
Also notice that `Extra` keys, like the log probabilities, are not plotted by default.

```@example 1
plot(chn)
savefig("plot1.svg"); nothing # hide
```

![Trace and density plots of the sampled chain](plot1.svg)

If you want to plot specific parameter(s), you can specify them as the second positional argument.
In general, the second argument can be _anything_ that you can index into a chain with.
This means a symbol, a parameter, a `FlexiChains.Extra`, a sub-VarName, or a vector thereof:

```@example 1
plot(chn, [@varname(x), :logjoint])
savefig("plot2.svg"); nothing # hide
```

![Trace and density plots of x and the logjoint](plot2.svg)

## Trace plots

```@docs
FlexiChains.traceplot
```

```@example 1
FlexiChains.traceplot(chn)
savefig("traceplot.svg"); nothing # hide
```

![Trace plots of the sampled chain](traceplot.svg)

## Running mean plots

```@docs
FlexiChains.meanplot
```

```@example 1
FlexiChains.meanplot(chn)
savefig("meanplot.svg"); nothing # hide
```

![Running mean plots of the sampled chain](meanplot.svg)

## Rank plots

```@docs
FlexiChains.rankplot
```

```@example 1
FlexiChains.rankplot(chn)
savefig("rankplot.svg"); nothing # hide
```

![Rank plots of the sampled chain](rankplot.svg)

## Autocorrelation plots

```@docs
FlexiChains.autocorplot
```

```@example 1
FlexiChains.autocorplot(chn)
savefig("autocorplot.svg"); nothing # hide
```

![Autocorrelation plots of the sampled chain](autocorplot.svg)

## Mixed density plots

```@docs
FlexiChains.mixeddensity
```

```@example 1
FlexiChains.mixeddensity(chn)
savefig("mixeddensity.svg"); nothing # hide
```

![Mixed density plots of the sampled chain](mixeddensity.svg)
