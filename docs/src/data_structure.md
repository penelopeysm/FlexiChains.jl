# Core data structure

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
