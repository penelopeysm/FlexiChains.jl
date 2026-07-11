<div align="center">
  <img src="docs/src/assets/logo.svg" alt="FlexiChains.jl logo" width="230">
  <h1>FlexiChains.jl</h1>
  <a href="https://pysm.dev/FlexiChains.jl/stable"><img src="https://img.shields.io/badge/docs-stable-blue.svg" alt="Docs (stable release)" /></a>
  <p>Type- and structure-preserving Markov chains.</p>
</div>

## Installation

```julia
import Pkg;
Pkg.add("FlexiChains")
```

## Documentation

The README contains a quickstart guide below, and the [online documentation](https://pysm.dev/FlexiChains.jl/stable/) contains much more detail on how to use FlexiChains.
Please do check it out!

## Contributing

**Issues and requests for new functionality are more than welcome!**
Please don't hesitate to [open an issue](https://github.com/penelopeysm/FlexiChains.jl/issues) if you have any questions or suggestions.

In particular, I'm very interested in integrating FlexiChains with other packages, which can either be input sources (i.e., packages that generate MCMC samples) or output sinks (i.e., visualisation or analysis packages).
This allows improvements to be shared across the entire ecosystem.
If you know of a package that would benefit from FlexiChains integration, do get in touch!

# Quickstart

## Obtaining a chain

MCMC sampling with [Turing.jl](https://turinglang.org/) or [ParallelMCMC.jl](https://github.com/rsenne/ParallelMCMC.jl) returns a FlexiChain by default:

```julia
using Turing, FlexiChains
@model function f()
    x ~ Normal()
    y ~ Poisson(3.0)
    z ~ MvNormal(zeros(2), I)
end
model = f()
chain = sample(model, MH(), MCMCThreads(), 1000, 3)
```

```
╭─FlexiChain (1000 iterations, 3 chains) ───────────────────────────────╮
│ ↓ iter  = 1:1000                                                      │
│ → chain = 1:3                                                         │
│                                                                       │
│ Parameters (3) ── VarName                                             │
│  Float64          x                                                   │
│  Int64            y                                                   │
│  Vector{Float64}  z (2,)                                              │
│                                                                       │
│ Extras (4)                                                            │
│  Bool     accepted                                                    │
│  Float64  logprior, loglikelihood, logjoint                           │
╰───────────────────────────────────────────────────────────────────────╯
```

You can also construct a FlexiChain from a variety of other sources, including
[Pigeons.jl](https://pysm.dev/FlexiChains.jl/stable/integrations/#integrations-pigeons),
[Stan CSV files](https://pysm.dev/FlexiChains.jl/stable/integrations/#Stan),
[PosteriorDB.jl](https://pysm.dev/FlexiChains.jl/stable/integrations/#PosteriorDB.jl),
an `MCMCChains.Chains` object,
or [a matrix of `DynamicPPL.VarNamedTuple`s or `DynamicPPL.ParamsWithStats`](https://pysm.dev/FlexiChains.jl/stable/api/#AbstractMCMC.from_samples).

## A quick primer on the data structure

A `FlexiChain{T}` stores data for *parameters* of type `T`, along with *extras* of any type which represent per-iteration metadata such as log densities.

Broadly speaking, a `FlexiChain` can be thought of as a dictionary mapping `Union{Parameter{<:T},Extra}` to `niters x nchains` matrices of samples.
Each matrix can have a different element type, which allows FlexiChains to store samples as their original types (e.g. Int or Vector) rather than flattening and converting everything to Float64.

The most common types `T` are `Symbol` and [`AbstractPPL.VarName`](https://turinglang.org/AbstractPPL.jl/stable/varname/).
The respective chain types are aliased to `SymChain` and `VNChain`.

## Indexing

Indexing into a `FlexiChain` returns a `DimMatrix` from the [`DimensionalData.jl` package](https://rafaqz.github.io/DimensionalData.jl/), which behaves exactly like an ordinary `Matrix` but additionally carries more information about its dimensions.

```julia
chain[@varname(x)]              # -> (niters x nchains)     DimMatrix{Float64}
chain[@varname(y)]              # -> (niters x nchains)     DimMatrix{Int}
chain[@varname(z)]              # -> (niters x nchains)     DimMatrix{Vector{Float64}}
chain[@varname(z); stack=true]  # -> (niters x nchains x 2) DimArray{Float64} 
```

If you have a `VNChain`, you can access sub-components of parameters by specifying the appropriate `VarName`.
Here `z` is a 2-dimensional vector, so accessing either `z[1]` or `z[2]` gives us scalars:

```julia
chain[@varname(z[1])] # -> (niters x nchains) DimMatrix{Float64}
```

You can index with `Symbol`s, as long as it can be unambiguously resolved to a parameter or extra:

```julia
chain[:y]         # -> (niters x nchains) DimMatrix{Int}
chain[:logjoint]  # -> (niters x nchains) DimMatrix{Float64}
```

You can additionally subset iterations / chains using `iter` or `chain` keyword arguments:

```julia
chain[@varname(x), iter=101:End, chain=2]
```

(note that with keyword arguments you have to use `End` instead of `end`).

See the [full guide to indexing](https://pysm.dev/FlexiChains.jl/stable/indexing) for more.

## Statistics

Quick and dirty summary stats can be obtained with:

```julia
ss = summarystats(chain)
```

This produces a `FlexiSummary` object with mean, standard deviation, Monte Carlo standard error, effective sample size, R-hat, and quantiles for each key:

```
╭─FlexiSummary (9 statistics) ──────────────────────────────────────────╮
│   iter    collapsed                                                   │
│   chain   collapsed                                                   │
│ ↓ stat  = [mean, std, mcse, ess_bulk, ess_tail, rhat, q5, q50, q95]   │
│                                                                       │
│ Parameters (4) ── VarName                                             │
│  Float64  x, y, z[1], z[2]                                            │
│                                                                       │
│ Extras (4)                                                            │
│  Float64  accepted, logprior, loglikelihood, logjoint                 │
│                                                                       │
│ Summary                                                               │
│   param     mean     std    mcse   ess_bulk   ess_tail    rhat  …     │
│       x  -0.0033  1.0190  0.0189  2888.7897  2657.3833  0.9998  …     │
│       y   2.9520  1.7255  0.0323  2869.7379  2988.1386  1.0002  …     │
│    z[1]  -0.0345  0.9956  0.0186  2863.4554  2624.3254  1.0000  …     │
│    z[2]   0.0267  1.0054  0.0181  3071.3115  2977.7340  1.0005  …     │
╰───────────────────────────────────────────────────────────────────────╯
```

You can index into this much like a `FlexiChain`:

```julia
ss[@varname(x), stat=At(:mean)]  # -> 0.0173 (mean of `x`)
```

Or you can compute statistics directly with individual functions:

```julia
mean(chain)              # just the mean for all variables
mean(chain)[@varname(x)] # -> Float64
mean(chain; dims=:iter)  # take the mean over iterations only
```

See the [full guide to summarising](https://pysm.dev/FlexiChains.jl/stable/summarising) for more.

## Plotting

FlexiChains contains extensive functionality for visualising chains with Makie.jl and Plots.jl.
Most of the effort has been focused on the Makie backend, and we recommend using this first.

```julia
using CairoMakie
plot(chain)                    # trace + densities for all parameters
plot(chain; pool_chains=true)  # combine samples from all chains
plot(chain, [@varname(z)])     # z[1] and z[2] only
```

<div align="center">
<img src="https://raw.githubusercontent.com/penelopeysm/FlexiChains.jl/refs/heads/img/readme-default-plot.png" width="500" alt="Trace/density plot of z in the FlexiChain sampled above"></img>
</div>

Specialised MCMC plots are namespaced under the `FlexiChains.Makie` module:

```julia
import FlexiChains.Makie as FM
FM.meanplot(chain; layout=(2, 2)) # Running mean plot, with custom grid layout
```

<div align="center">
<img src="https://raw.githubusercontent.com/penelopeysm/FlexiChains.jl/refs/heads/img/readme-meanplot.png" width="500" alt="Running mean plot of the FlexiChain sampled above"></img>
</div>

Pair plots can be generated with the [PairPlots.jl extension](https://pysm.dev/FlexiChains.jl/stable/integrations/#integrations-pairplots):

```julia
using PairPlots;
pairplot(chain)
```

<div align="center">
<img src="https://raw.githubusercontent.com/penelopeysm/FlexiChains.jl/refs/heads/img/readme-pairplot.png" width="500" alt="Pair plot of the FlexiChain sampled above"></img>
</div>

The interface to Plots.jl is similar:

```julia
using StatsPlots;
plot(chain)
import FlexiChains.Plots as FP;
FP.meanplot(chain; layout=(2, 2))
StatsPlots.corner(chain)
```

See the [full guide to plotting](https://pysm.dev/FlexiChains.jl/stable/plotting) for more.
