# FlexiChains in more detail

On this page we go into more detail about how FlexiChains is designed, and the ways to manipulate and extract data from a `FlexiChain`.

## The `FlexiChain` type

We begin by looking at the `FlexiChain` type itself.
Fundamentally, a `FlexiChain{T}` is a mapping of keys to arrays of values.
Indeed, a `FlexiChain` contains a `_data` field which is just a dictionary that maps keys to fixed-size arrays.

```@docs
FlexiChains.FlexiChain
```

Each chain also stores information about which iterations and chains it contains.
The iteration indices are typically provided by the MCMC sampler (e.g. in Turing.jl); the chain indices on the other hand will usually just `1:nchains`.

```@docs
FlexiChains.iter_indices
FlexiChains.chain_indices
```

To renumber these indices you can use:

```@docs
FlexiChains.renumber_iters
FlexiChains.renumber_chains
```

## Metadata

Before we discuss the actual _data_ stored in a `FlexiChain`, we note that it also contains a `_metadata` field.
This field stores miscellaneous information that is pertinent to the chain as a whole, rather than information that is per-iteration.
However, it should not be accessed manually as its fields are considered internal and subject to change.
Instead if you need to access this you can use:

```@docs
FlexiChains.sampling_time
FlexiChains.last_sampler_state
```

## Key types

The keys of a `FlexiChain{T}` must be one of two types:

  - `Parameter(::T)`: a parameter of the Markov chain itself
  - `Extra(::Any)`: a key that is not a parameter, such as metadata.

```@docs
FlexiChains.Parameter
FlexiChains.Extra
FlexiChains.ParameterOrExtra
```

## Dimensions and sizes

`size()` when called on a FlexiChain returns a 2-tuple of `(niters, nchains)`.

!!! note "MCMCChains difference"
    
    MCMCChains returns a 3-tuple of `(niters, nkeys, nchains)` where `nkeys` is the total number of parameters. FlexiChains does not do this because the keys do not form a regular grid. If you want the total number of keys in a `FlexiChain`, you can use `length(keys(chain))`.

```@docs
Base.size(::FlexiChains.FlexiChain)
Base.size(::FlexiChains.FlexiChain, ::Int)
FlexiChains.niters
FlexiChains.nchains
```

## Listing keys

`keys()` will return all the keys in an unspecified order.

```@docs
Base.keys(::FlexiChains.FlexiChain)
```

If you only want `Parameter`s, or only `Extra`s you can use the following:

```@docs
FlexiChains.parameters
FlexiChains.extras
```

## Subsetting and merging parameters

To restrict a `FlexiChain` to a subset of its keys, you can use `FlexiChains.subset`.

```@docs
FlexiChains.subset
```

Two common use cases are subsetting to only parameters and only extra keys:

```@docs
FlexiChains.subset_parameters
FlexiChains.subset_extras
```

The reverse of subsetting is merging.
This can only be done when the chains being merged have the same size.

```@docs
Base.merge(::FlexiChains.FlexiChain{TKey1,NIter,NChain}, ::FlexiChains.FlexiChain{TKey2,NIter,NChain}) where {TKey1,TKey2,NIter,NChain}
```

## Indexing via parameters

This was covered in a more accessible manner on [the previous page](./turing.md), but we provide the full docstrings here for completeness.

The most unambiguous way to index into a `FlexiChain` is to use either `Parameter` or `Extra`.

```@docs
Base.getindex(::FlexiChains.FlexiChain{TKey}, key::FlexiChains.ParameterOrExtra{TKey}) where {TKey}
```

This can be slightly verbose, so the following two methods are provided as a 'quick' way of accessing parameters and other keys respectively:

```@docs
Base.getindex(::FlexiChains.FlexiChain{TKey}, parameter_name::TKey) where {TKey}
```

Finally, to preserve some semblance of backwards compatibility with MCMCChains.jl, FlexiChains can also be indexed by `Symbol`s.
It does so by looking for a unique `Parameter` or `Extra` which can be converted to that `Symbol`.

```@docs
Base.getindex(::FlexiChains.FlexiChain, key::Symbol)
```

## Concatenation along the other dimensions

If you have two chains and want to concatenate them along the iteration or chain dimension, you can use `vcat` and `hcat` respectively.
The chains must have the same size along the other dimension (that is not being concatenated).

If there are parameters that are present in one chain but not the other, they will be assigned `missing` values in the concatenated chain.

```@docs
Base.vcat(::FlexiChains.FlexiChain{TKey,NIter1,NChains}, ::FlexiChains.FlexiChain{TKey,NIter2,NChains}) where {TKey,NIter1,NIter2,NChains}
Base.hcat(::FlexiChains.FlexiChain{TKey,NIter,NChains1}, ::FlexiChains.FlexiChain{TKey,NIter,NChains2}) where {TKey,NIter,NChains1,NChains2}
```

The rather little-known `AbstractMCMC.chainscat` and `AbstractMCMC.chainsstack` methods (see [AbstractMCMC.jl docs](https://turinglang.org/AbstractMCMC.jl/stable/api/#Chains)) are also defined on FlexiChains; they both make use of `hcat`.

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
```

### Indexing

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
