# Integrations with other packages

FlexiChains is most obviously tied to the Turing.jl ecosystem, as described on the previous pages.
However, it also contains some integrations with other packages.

## PosteriorDB.jl

[Documentation for PosteriorDB.jl](@extref PosteriorDB :doc:`index`)

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

```@docs
FlexiChains.from_posteriordb_ref
```

## Serialization.jl

Calling this an 'integration' is a bit of a stretch, because it simply works out of the box (no extra code needed), but it had to be documented somewhere...

You can serialise and deserialise `FlexiChain` and `FlexiSummary` objects using the [Serialization.jl standard library](@extref Julia Serialization).

```@example serialization
using FlexiChains, Turing, Serialization

@model f() = x ~ Normal()
chn = sample(f(), NUTS(), MCMCThreads(), 100, 3; chain_type=VNChain, progress=false)
fname = "mychain"
serialize(fname, chn)
```

```@example serialization
chn2 = deserialize(fname)
isequal(chn, chn2)
```

Note two things:

1. If the serialisation and deserialisation steps are performed in different Julia sessions, you need to make sure that you have all necessary packages loaded in the second session.
In particular, if you use `save_state=true`, then you should load Turing.jl before deserialising, because Turing provides the sampler state types.

2. If you are testing the integrity of (de)serialisation, you may find that `isequal()` on sampler state types may not return `true` even when the sampler states are the same. This is because Julia's default definition of equality for structs is based on object identity, not on field values. For example, the following returns `false` because `[1] !== [1]`.

   ```@example serialization
   struct Foo{T}
       t::T
   end
   
   Foo([1]) == Foo([1])
   ```
