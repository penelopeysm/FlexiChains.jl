# [PosteriorDB.jl](@id integrations-posteriordb)

[Documentation for PosteriorDB.jl ↗](@extref PosteriorDB :doc:`index`)

If you have loaded a `PosteriorDB.ReferencePosterior`, you can transform it into a `FlexiChain` using [`FlexiChains.from_posteriordb_ref`](@ref):

```@example posteriordb
using PosteriorDB, FlexiChains

pdb = PosteriorDB.database()
post = PosteriorDB.posterior(pdb, "eight_schools-eight_schools_centered")
ref = PosteriorDB.reference_posterior(post)

chn = FlexiChains.from_posteriordb_ref(ref)
```

You can then use all the functionality of FlexiChains on `chn`:

```@example posteriordb
summarystats(chn)
```

## Docstrings

```@docs
FlexiChains.from_posteriordb_ref
```
