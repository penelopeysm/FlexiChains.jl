# Internals

!!! danger
    This page contains discussion of internal implementation details of FlexiChains. It is also not always completely up-to-date, due to the rapid development that is going on right now. You should not need to read this unless you are actively developing FlexiChains or a package that interacts with it.

On this page we go into more detail about how FlexiChains is designed, and the ways to manipulate and extract data from a `FlexiChain`.

## Manually constructing a `FlexiChain`

If you ever need to construct a `FlexiChain` from scratch, there are exactly two ways to do so.
One is to pass an array of dictionaries (i.e., one dictionary per iteration); the other is to pass a dictionary of arrays (i.e., the values for each key are already grouped together).

```@docs
FlexiChains.FlexiChain{TKey}(data)
```

Note that, although the dictionaries themselves may have loose types, the key type of the `FlexiChain` must be specified (and the keys of the dictionaries will be checked against this).

## Deconstructing a `FlexiChain`

Sometimes you may want to retrieve the mapping of keys to values for a particular iteration.
This is useful especially for DynamicPPL developers.
To this end, the following functions are provided:

```@docs
FlexiChains.get_dict_from_iter
FlexiChains.get_parameter_dict_from_iter
```

## Summaries

### A basic overview

In general a `FlexiChain` contains data in matrices of size `(niters, nchains)`.
Often it is useful to summarise this data along one or both dimensions.

For ease of use, a number of pre-existing functions are extended to work with FlexiChains in this manner.
For these functions, you can use `f(chain; dims=:iter)` to collapse over the iteration dimension only, or `f(chain; dims=:chain)` to collapse over the chain dimension only.

Keyword arguments are automatically forwarded to the underlying function.

!!! note "Errors"
    
    Since FlexiChains is _really_ general in its data types, functions like `Statistics.mean` may not work on all values that are present in the chain.
    For example, the mean of `String` values is not defined.
    In such cases, a warning is emitted and the key is dropped from the returned summary object.

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

To calculate all of `mean`, `std`, `mcse`, bulk `ess`, tail `ess`, and `rhat` at once:

```@docs
StatsBase.summarystats
```

### `getindex`

```@docs
Base.getindex(::FlexiChains.FlexiSummary{TKey}, key::FlexiChains.ParameterOrExtra{TKey}) where {TKey}
```

### Multiple functions at once

TODO: we don't have a nice API for this. There is `collapse` but that's a bit clunky.

### Summaries in more depth

All of the above functions dispatch to a more general function, called `collapse`.

```@docs
FlexiChains.collapse
```

For example, you can pass the functions `x -> mean(x; dims=1)`, `x -> mean(x; dims=2)`, and `mean`.

The return type of `collapse` is `FlexiSummary`, which has very similar indexing behaviour to `FlexiChain`.

```@docs
FlexiChains.FlexiSummary
```
