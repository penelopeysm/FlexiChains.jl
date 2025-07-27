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

Indexing into a `FlexiChain` can be done in two ways:

- using `Symbol`, which is a lossy operation but more convenient;
- directly using `Parameter` or `OtherKey`, which is most faithful to the underlying data structure;

```@docs
Base.getindex(::FlexiChain, key::Symbol)
Base.getindex(::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}
```

For convenience when accessing non-parameter keys, you can also use:

```@docs
Base.getindex(::FlexiChain{TKey}, section_name::Symbol, key_name::Any) where {TKey}
```
