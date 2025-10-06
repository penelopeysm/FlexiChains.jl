# Integrations with other packages

FlexiChains is most obviously tied to the Turing.jl ecosystem, as described on the previous pages.
However, it also contains some integrations with other packages.

## PosteriorDB.jl

[Documentation for PosteriorDB.jl](@extref PosteriorDB PosteriorDB.jl)

If you have loaded a `PosteriorDB.ReferencePosterior`, you can transform it into a `FlexiChain` using [`FlexiChains.from_posteriordb_ref`](@ref):

```@example 1
using PosteriorDB, FlexiChains

pdb = PosteriorDB.database()
post = PosteriorDB.posterior(pdb, "eight_schools-eight_schools_centered")
ref = PosteriorDB.reference_posterior(post)

chn = FlexiChains.from_posteriordb_ref(ref)
```

You can then use all the functionality of FlexiChains on `chn`:

```@example 1
summarystats(chn)
```

```@docs
FlexiChains.from_posteriordb_ref
```
