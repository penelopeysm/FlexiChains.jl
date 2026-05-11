# [Converting to/from 3D arrays](@id arrays)

Many MCMC libraries return samples in the form of 3D arrays.
...

## [API: converting from arrays](@id api-fromarray)

```@docs
FlexiChains.FlexiChain(::AbstractArray{T, 3}) where T
```

## [API: converting to arrays](@id api-flatten)

```@docs
DimensionalData.DimArray(::FlexiChains.FlexiChain)
DimensionalData.DimArray(::FlexiChains.FlexiSummary)
Base.Array(::FlexiChains.FlexiChain)
Base.Array(::FlexiChains.FlexiSummary)
Wide
Long
```
