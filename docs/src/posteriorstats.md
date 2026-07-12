# [PosteriorStats.jl](@id integrations-posteriorstats)

[Documentation for PosteriorStats.jl](@extref PosteriorStats :doc:`index`)

PosteriorStats.jl provides the `hdi` and `eti` functions for computing highest density
intervals and equal-tailed intervals, respectively.
These are overloaded for `FlexiChain` objects in much the same way as `Statistics.mean`, `Statistics.std`, etc. (see [the Summarising page](@ref "Individual statistics") for more information).
Here is an example:

```@example posteriorstats
using FlexiChains, DynamicPPL, Distributions, PosteriorStats

@model function g(z)
    x ~ Normal()
    y ~ Normal(x)
    z ~ Normal(y)
end
model = g(1.0)

chn = FlexiChains._make_prior_chain(model, 100, 2)
PosteriorStats.hdi(chn; prob=0.95, split_interval=true)
```

`PosteriorStats.loo`, which computes Pareto-smoothed importance sampling leave-one-out cross-validation (PSIS-LOO), is also overloaded for `FlexiChain` objects.
You can either pass a chain of log-likelihood values, which can be computed via `DynamicPPL.pointwise_loglikelihoods(model, chain)`, or (perhaps more easily) a Turing model plus a posterior chain which just does that for you.
For example (although note that the chain above is sampled from the prior — so this is only meant to be a demonstration of the API):

```@example posteriorstats
PosteriorStats.loo(model, chn)
```

```@docs
PosteriorStats.hdi(::FlexiChains.FlexiChain; kwargs...)
PosteriorStats.eti(::FlexiChains.FlexiChain; kwargs...)
PosteriorStats.loo(::FlexiChains.FlexiChain; kwargs...)
PosteriorStats.loo(model::DynamicPPL.Model, posterior_chn::FlexiChains.FlexiChain; kwargs...)
```
