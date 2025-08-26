# Overview

FlexiChains.jl provides an information-rich data structure for Markov chains.
It is intended as a drop-in (but better) replacement for MCMCChains.jl.

## Basic usage

To obtain a `FlexiChain` from Turing.jl, you will need to pass the `chain_type` keyword argument to `sample`.

```@example 1
using Turing
using FlexiChains: VNChain

@model f() = x ~ Normal()
chain = sample(f(), NUTS(), 1000; chain_type=VNChain)
```

Right now FlexiChains only provides a data structure.
It does not yet provide any functionality for calculating statistics or plotting.

If you want that, you can convert a `FlexiChain` to an `MCMCChains.Chains` object using the `MCMCChains.Chains` constructor.

```@example 1
using MCMCChains
mcmc = MCMCChains.Chains(chain)
```

## What is exported?

FlexiChains.jl only _exports_ three things, all for convenience when using this with Turing.jl.

- `VNChains`, an alias for `FlexiChain{VarName}`
- The `VarName` type and `@varname` macro

For semantic versioning purposes, a number of other types and functions are marked as _public_.
However, they are not exported: you will have to explicitly import them.

## The `FlexiChain` type

Fundamentally, a `FlexiChain{T}` is a mapping of keys to values.

```@docs
FlexiChain
```

The values must be matrices or vectors that all have the same size.
The element type is unconstrained.

The keys must be one of two types:
- `Parameter(::T)`: a parameter of the Markov chain itself
- `OtherKey(::Symbol, ::Any)`: a key that is not a parameter, such as metadata. The `Symbol` argument identifies a _section_ which the key belongs to, thus allowing for multiple keys to be grouped together in meaningful ways.

```@docs
Parameter
OtherKey
FlexiChainKey
```

Bearing this in mind, there are two ways to construct a `FlexiChain`.
One is to pass an array of dictionaries (i.e., one dictionary per iteration); the other is to pass a dictionary of arrays (i.e., the values for each key are already grouped together).

```@docs
FlexiChain{TKey}(data)
```

Note that, although the dictionaries themselves may have loose types, the key type of the `FlexiChain` must be specified (and the keys of the dictionaries will be checked against this).

## Accessing values

Indexing into a `FlexiChain` can be done in several ways.

The most correct way is to directly use `Parameter`s or `OtherKey`s:

```@docs
Base.getindex(::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}
```

This can be slightly verbose, so the following two methods are provided as a 'quick' way of accessing parameters and other keys respectively:

```@docs
Base.getindex(::FlexiChain{TKey}, parameter_name::TKey) where {TKey}
Base.getindex(::FlexiChain{TKey}, section_name::Symbol, key_name::Any) where {TKey}
```

Finally, to preserve some semblance of backwards compatibility with MCMCChains.jl, FlexiChains can also be indexed by `Symbol`s.
It does so by looking for a unique `Parameter` or `OtherKey` which can be converted to that `Symbol`.

```@docs
Base.getindex(::FlexiChain, key::Symbol)
```
