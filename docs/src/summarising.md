# Summarising

In general a `FlexiChain` contains data in matrices of size `(niters, nchains)`.
Often it is useful to summarise this data along one or both dimensions.

FlexiChains allows you to calculate one or more statistics for each variable stored in a `FlexiChain`.
The result is a `FlexiSummary` object, which can be indexed into in a very similar way to `FlexiChain`s: see [the Indexing page](./indexing.md) for full details, or the examples on this page.

## What happens with unsupported data types?

Before we launch into the available summary statistics, it is worth mentioning one point about data types.
Since FlexiChains allows for storage of completely arbitrary data types, it can contain data for which the mean (or other statistic) is not defined.
For example, the mean of `String` values is not defined.
In such cases, the key will be silently dropped from the result, and a warning issued (you can suppress the warning by passing the `warn=false` keyword argument).

If multiple summary statistics are requested (e.g. with [`summarystats`](@ref StatsBase.summarystats)), the key is only dropped if _all_ of them fail.
If at least one statistic is successfully computed for a key, that key will be included in the result, with `missing` values for the statistics that failed.

To give a flavour of how this works, here is an example:

```@example stats
using FlexiChains, Turing

@model function f()
    f ~ Normal()               # float
    v ~ MvNormal(zeros(2), I)  # vector
    s := "a string"            # string
end

chain = sample(f(), MH(), MCMCThreads(), 20, 3; chain_type=VNChain)
```

## Overall summary statistics

If you want a quick overview of what's in your chain, [`summarystats`](@ref StatsBase.summarystats) provides a handy selection of commonly used statistics:

```@docs
StatsBase.summarystats(::FlexiChains.FlexiChain)
```

!!! tip
    FlexiChains re-exports all the functions listed on this page.

```@example stats
summarystats(chain)
```

## Individual statistics

The following functions are all overloaded to accept `FlexiChain` objects.
In all cases, they can be called with `dims=:both`, `dims=:iter`, or `dims=:chain` to specify the dimension over which to compute the statistic; the default is `dims=:both`.

Importantly, all of these functions return a `FlexiSummary` where the `:stat` dimension has already been collapsed.
That means that if you want to access the mean of a variable `@varname(a)` you don't need to further use the `stat` dimension:

```julia
m = mean(chain)
# Not needed: mean_a = m[@varname(a), stat=:mean]
# Just do:
mean_a = m[@varname(a)]
```

```@docs
Statistics.mean(::FlexiChains.FlexiChain; kwargs...)
Statistics.median(::FlexiChains.FlexiChain; kwargs...)
Statistics.var(::FlexiChains.FlexiChain; kwargs...)
Statistics.std(::FlexiChains.FlexiChain; kwargs...)
Base.minimum(::FlexiChains.FlexiChain; kwargs...)
Base.maximum(::FlexiChains.FlexiChain; kwargs...)
Base.sum(::FlexiChains.FlexiChain; kwargs...)
Base.prod(::FlexiChains.FlexiChain; kwargs...)
Statistics.quantile(::FlexiChains.FlexiChain, p; kwargs...)
MCMCDiagnosticTools.ess(::FlexiChains.FlexiChain; kwargs...)
MCMCDiagnosticTools.rhat(::FlexiChains.FlexiChain; kwargs...)
MCMCDiagnosticTools.mcse(::FlexiChains.FlexiChain; kwargs...)
```

## Custom statistics

```@docs
FlexiChains.collapse
```
