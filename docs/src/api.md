# Public API

!!! danger
    This page is still a work in progress. Please check back later for updates.

The types and functions documented on this page form part of FlexiChains's public API.

On Julia 1.11 and later, these are marked with the `public` keyword (or are extensions of other packages' APIs).

FlexiChains also guarantees that any changes to these APIs will be reflected with a breaking version bump.

## The `FlexiChain` and `FlexiSummary` types

The `FlexiChain` and `FlexiSummary` types are technically marked as public, but you should not handle them or their fields directly.
For dispatch purposes, it is guaranteed that the first type parameter is always the key type; this should typically be all you need.
Both types have extra type parameters, but they are considered internal and may change at any time.

You can also use `Base.keytype`:

```@docs
Base.keytype(::FlexiChains.ChainOrSummary)
```

## Equality

```@docs
Base.:(==)(::FlexiChains.FlexiChain, ::FlexiChains.FlexiChain)
Base.isequal(::FlexiChains.FlexiChain, ::FlexiChains.FlexiChain)
FlexiChains.has_same_data(::FlexiChains.FlexiChain, ::FlexiChains.FlexiChain)
```

## Sizes

```@docs
Base.size(::FlexiChains.FlexiChain)
Base.size(::FlexiChains.FlexiSummary)
FlexiChains.niters
FlexiChains.nchains
FlexiChains.nstats
```

## Indices

```@docs
FlexiChains.iter_indices
FlexiChains.chain_indices
FlexiChains.stat_indices
FlexiChains.renumber_iters
FlexiChains.renumber_chains
```

## Key types

```@docs
FlexiChains.Parameter
FlexiChains.Extra
FlexiChains.ParameterOrExtra
```

## Accessing key-value pairs

```@docs
Base.keys(::FlexiChains.ChainOrSummary)
Base.haskey(::FlexiChains.ChainOrSummary{TKey}, key::TKey) where {TKey}
Base.haskey(::FlexiChains.ChainOrSummary{TKey}, key::FlexiChains.ParameterOrExtra{<:TKey}) where TKey
FlexiChains.parameters(::FlexiChains.ChainOrSummary)
FlexiChains.extras(::FlexiChains.ChainOrSummary)
Base.values(::FlexiChains.ChainOrSummary)
Base.pairs(::FlexiChains.ChainOrSummary)
```

## Indexing by key

For the public interface of `getindex`, please see [the Indexing page](@ref Indexing).

## Accessing metadata

Chains additionally store some metadata:

```@docs
FlexiChains.sampling_time
FlexiChains.last_sampler_state
```

## Combining chains

```@docs
Base.vcat(::FlexiChains.FlexiChain{T}, ::FlexiChains.FlexiChain{T}) where {T}
Base.hcat(::FlexiChains.FlexiChain{T}, ::FlexiChains.FlexiChain{T}) where {T}
Base.merge(::FlexiChains.FlexiChain{T}, ::FlexiChains.FlexiChain{T}) where {T}
```

## Subsetting chains

You can do these with `getindex` too, but these functions are sometimes more convenient.

```@docs
FlexiChains.subset_parameters
FlexiChains.subset_extras
```

## Extracting per-iteration samples

```@docs
FlexiChains.values_at
FlexiChains.parameters_at
```

## Splitting up VarNames

```@docs
FlexiChains.split_varnames
```

TODO: Summaries, plotting.
