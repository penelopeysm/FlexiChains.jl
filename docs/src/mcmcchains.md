# [Converting to/from MCMCChains](@id integrations-mcmcchains)

You can convert to and from `MCMCChains.Chains` objects using the following functions:

```@docs
FlexiChains.from_mcmcchains
MCMCChains.Chains(::FlexiChains.FlexiChain)
```

Note that the constructor `FlexiChain{Symbol}(c::MCMCChains.Chains)` is deprecated.
In its place you can use `FlexiChains.from_mcmcchains(c)`, which has exactly the same behaviour.
