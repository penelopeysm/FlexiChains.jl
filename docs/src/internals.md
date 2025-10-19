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

### `getindex`

```@docs
Base.getindex(::FlexiChains.FlexiSummary{TKey}, key::FlexiChains.ParameterOrExtra{TKey}) where {TKey}
```
