# Integrations with other packages

FlexiChains is most obviously tied to the Turing.jl ecosystem, as described on the previous pages.
However, it also contains some useful links to other packages (listed here in alphabetical order).

## DimensionalDistributions.jl

[Documentation for DimensionalDistributions.jl](https://github.com/sethaxen/DimensionalDistributions.jl)

!!! note
    DimensionalDistributions.jl is not yet registered in the Julia package registry; at present you will need to install it from GitHub using `]add https://github.com/sethaxen/DimensionalDistributions.jl`.
    Furthermore, it is not yet compatible with the latest release of DynamicPPL; hence the code blocks here have been disabled.

In the quickstart guide we saw that FlexiChains, by default, stores vector-valued parameters together.
For example, `chn[@varname(x)]` here returns a `DimArray` of `Vector`s:

```julia
using FlexiChains, Turing

@model f() = x ~ MvNormal(zeros(3), I)
chn = sample(f(), MH(), MCMCThreads(), 5, 2; chain_type=VNChain, progress=false)

chn[@varname(x)]
```

One might like to stack these vectors together, such that `chn[@varname(x)]` returns a three-dimensional `DimArray` instead.
You can do this manually, for example:

```julia
using DimensionalData
school_dim = Dim{:school}([:a, :b, :c])
permutedims(stack(map(v -> DimVector(v, school_dim), chn[@varname(x)])), (2, 3, 1))
```

This is of course a bit tedious.
Unfortunately, there is not much that FlexiChains can do because `MvNormal()` itself returns plain `Vector`s that do not carry any dimensional information.

But, if you can use the `withdims` wrapper from DimensionalDistributions.jl, you will get a distribution that returns `DimVector`s:

```julia
using DimensionalDistributions
dim_mvnormal = withdims(MvNormal(zeros(3), I), school_dim)
rand(dim_mvnormal)
```

And if you use this in a Turing model, then this information will be carried through all the way to FlexiChains, and indexing into this parameter will automatically give you a stacked `DimArray`:

```julia
@model f2() = x ~ dim_mvnormal
chn2 = sample(f2(), MH(), MCMCThreads(), 5, 2; chain_type=VNChain, progress=false)
chn2[@varname(x)]
```

Sub-VarName indexing also works, although you can't use DimensionalData selectors inside a VarName, so only one-based indexing:

```julia
chn2[@varname(x[1])]
```

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

## PosteriorStats.jl

[Documentation for PosteriorStats.jl](@extref PosteriorStats :doc:`index`)

PosteriorStats.jl provides the `hdi` and `eti` functions for computing highest density
intervals and equal-tailed intervals, respectively.
These are overloaded for `FlexiChain` objects in much the same way as `Statistics.mean`, `Statistics.std`, etc. (see [the Summarising page](@ref "Individual statistics") for more information).

Note however that you will need to import PosteriorStats.jl explicitly to use these functions (as they are implemented in an extension rather than the main package).

```@docs
PosteriorStats.hdi(::FlexiChains.FlexiChain; kwargs...)
PosteriorStats.eti(::FlexiChains.FlexiChain; kwargs...)
```

## Serialization.jl

Calling this an 'integration' is a bit of a stretch, because it simply works out of the box (no extra code needed), but it had to be documented somewhere...

You can serialise and deserialise `FlexiChain` and `FlexiSummary` objects using the [Serialization.jl standard library](@extref Julia Serialization).

```@example serialization
using FlexiChains, Turing, Serialization

@model f() = x ~ Normal()
chn = sample(f(), NUTS(), 100; chain_type=VNChain, progress=false)
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

2. If you are testing the integrity of (de)serialisation, you may find that `isequal()` on sampler state types may not return `true` even when the sampler states are the same.
   This is because Julia's default definition of equality for structs is based on object identity, not on field values.
   For example, the following returns `false` because `[1] !== [1]`.

   ```@example serialization
   struct Foo{T}
       t::T
   end
   
   Foo([1]) == Foo([1])
   ```
