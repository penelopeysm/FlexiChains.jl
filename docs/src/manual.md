# Behind the scenes

This section is intended for readers who may have to work on the package itself or its Turing.jl compatibility.
This will require you to have some understanding of the internal workings of a FlexiChain.

## The `FlexiChain` type

Fundamentally, a `FlexiChain{T}` is a mapping of keys to arrays of values.
Indeed, a `FlexiChain` contains a `_data` field which is just a dictionary.

```@docs
FlexiChain
```

The keys must be one of two types:

  - `Parameter(::T)`: a parameter of the Markov chain itself
  - `Extra(::Symbol, ::Any)`: a key that is not a parameter, such as metadata. The `Symbol` argument identifies a _section_ which the key belongs to, thus allowing for multiple keys to be grouped together in meaningful ways.

```@docs
Parameter
Extra
FlexiChainKey
```

The values must be matrices or vectors that all have the same size.
This is represented by a `FlexiChains.SizedMatrix`, which carries its size as a type parameter (although the underlying storage still uses `Base.Array`).

```@docs
FlexiChains.SizedMatrix
```

The element type of these arrays is unconstrained.

Bearing this in mind, there are two ways to construct a `FlexiChain`.
One is to pass an array of dictionaries (i.e., one dictionary per iteration); the other is to pass a dictionary of arrays (i.e., the values for each key are already grouped together).

```@docs
FlexiChain{TKey}(data)
```

Note that, although the dictionaries themselves may have loose types, the key type of the `FlexiChain` must be specified (and the keys of the dictionaries will be checked against this).

## Accessing data

The most unambiguous way to index into a `FlexiChain` is to use either `Parameter` or `Extra`.

```@docs
Base.getindex(::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}
```

This can be slightly verbose, so the following two methods are provided as a 'quick' way of accessing parameters and other keys respectively:

```@docs
Base.getindex(::FlexiChain{TKey}, parameter_name::TKey) where {TKey}
Base.getindex(::FlexiChain{TKey}, section_name::Symbol, key_name::Any) where {TKey}
```

Finally, to preserve some semblance of backwards compatibility with MCMCChains.jl, FlexiChains can also be indexed by `Symbol`s.
It does so by looking for a unique `Parameter` or `Extra` which can be converted to that `Symbol`.

```@docs
Base.getindex(::FlexiChain, key::Symbol)
```
