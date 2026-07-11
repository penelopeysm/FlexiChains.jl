# Overview

FlexiChains.jl provides a rich data structure for storing and analysing Markov chain Monte Carlo (MCMC) output.

```@example splash
using Turing, FlexiChains
@model function f()
    x ~ Normal()
    y ~ Poisson(3.0)
    z ~ MvNormal(zeros(2), I)
end
chain = sample(f(), MH(), MCMCThreads(), 1000, 3; progress=false)
```

## Feature overview

### Type and structure fidelity

FlexiChains preserves the original shapes of your samples: all Julia types are faithfully stored without modification.
The example Turing.jl model above yields a `FlexiChain` where each `x` is a Float64, each `y` is an Int, and each `z` is a `Vector{Float64}`.

This is in contrast to many other representations which flatten all samples into a single `Array{Float64}`.

### Diverse input sources

FlexiChains is the default chain type for [Turing.jl](https://turinglang.org) since v0.45 of Turing.

With older versions of Turing, you can obtain a FlexiChain by calling `sample(model, ...; chain_type=FlexiChains.VNChain)`.

You can also construct a FlexiChain from a variety of other sources, including
[ParallelMCMC.jl](https://github.com/rsenne/ParallelMCMC.jl),
[Pigeons.jl](https://pysm.dev/FlexiChains.jl/stable/integrations/#integrations-pigeons),
[Stan CSV files](https://pysm.dev/FlexiChains.jl/stable/integrations/#Stan), or
[PosteriorDB.jl](https://pysm.dev/FlexiChains.jl/stable/integrations/#PosteriorDB.jl).

### Expressive indexing

You can [access data stored in chains](@ref indexing) in a variety of ways, using the full power of DimensionalData.jl selectors.

```@example splash
chain[@varname(x), iter=101:End, chain=2]
```

### Downstream analysis

FlexiChains provides a number of [statistical analysis tools](@ref summarising), including:

  - simple statistics (mean, variance, quantiles, etc.)
  - MCMC diagnostics and statistics via [MCMCDiagnosticTools.jl](https://turinglang.org/MCMCDiagnosticTools.jl) and [PosteriorStats.jl](https://julia.arviz.org/PosteriorStats/stable/)
  - Pareto-smoothed importance sampling (PSIS) via [PSIS.jl](https://arviz-devs.github.io/PSIS.jl/stable/)

```@example splash
ss = summarystats(chain)
```

```@example splash
ss[@varname(x), stat=At(:mean)]
```

For added versatility you can also [convert a FlexiChain into a `DimArray` or a `DataFrame`](@ref api-flatten).

### Built-in plotting

[Visualisation with both Makie.jl and Plots.jl is supported](@ref plotting), along with a PairPlots.jl extension.

```@example splash
using PairPlots, CairoMakie
pairplot(chain)
Makie.save("index-pairplot.png", ans); # hide
```

![Pair plot of the sampled chain](index-pairplot.png)

```
```
