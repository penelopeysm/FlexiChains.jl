# Migrating from MCMCChains.jl

FlexiChains.jl has been designed from the ground up to address existing limitations of [MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl).

This page describes some key differences from MCMCChains.jl and how you can migrate your code to use FlexiChains.jl.

## The fundamental difference

Under the hood, MCMCChains.jl uses [`AxisArrays.AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl/) as its data structure.
Specifically, this allows it to store data in a compact 3-dimensional matrix, and index into the matrix using `Symbol`s.

The downside of this is that it enforces a key type of `Symbol` and a value type of `Tval<:Real`.
This means that, for example, if you have a model with vector-valued parameters (like `x` above), the vectors will be split up into their individual elements before being stored in the chain.

This is _the_ core of how MCMCChains and FlexiChains differ, and all of the behaviour shown below stems from this.

To illustrate this, let's sample from a typical Turing model and store the results in both `MCMCChains.Chains` and `FlexiChains.FlexiChain`.

```julia
# using Turing, MCMCChains, FlexiChains, Random
# 
# @model function f(x)
#     chol ~ LKJCholesky(3, 1.0)
#     corr := PDMats.PDMat(chol)
#     mu ~ MvNormal(zeros(3), I)
#     x ~ MvNormal(mu, corr)
# end
#
# model = f(randn(Xoshiro(468), 3))
# mcmc = sample(Xoshiro(468), model, NUTS(), 100; chain_type=MCMCChains.Chains)
# flexi = sample(Xoshiro(468), model, NUTS(), 100; chain_type=FlexiChains.FlexiChain)
```

## Accessing vector-valued parameters

Blah

## Accessing individual elements

Blah

## Accessing 'generated quantities' (using `:=`)

Blah

## No need to avoid reserved names

When sampling from a Turing model with MCMCChains as the output format, some metadata (non-parameter keys) such as `lp` are added to the chain.
If your model contains a variable called `lp`, sampling will still work but [odd things will happen](https://github.com/TuringLang/MCMCChains.jl/issues/469).
HMC samplers further include extra metadata such as `hamiltonian_energy`, and in general **any sampler** can include any kind of extra metadata it wants.
As a user, you have no way of knowing what these names are, and you have to avoid using them in your model, which is quite unfair.

(demo)

FlexiChains circumvents this entirely since it stores these separately as `Parameter(@varname(lp))` and `OtherKey(:stats, :lp)`.
Again, you will run into ambiguities if you simply attempt to index the chain with `[:lp]`:

(demo)

but you can still access the value using the original `Parameter`:

(demo)

and this difference is also respected when pretty-printing the chain (MCMCChains simply hides the `lp` parameter from you because it thinks that it's an internal name).

## For DynamicPPL developers

Blah

## Design goals

My main design goals for FlexiChains.jl were twofold:

1. To provide a rich data structure that can more faithfully represent the outputs from sampling with Turing.jl.

   The restriction of MCMCChains.jl to `Symbol` keys and `Real` values means that round-trip conversion is a lossy operation.
   Consider, e.g., the `predict(::Model, ::MCMCChains.Chains)` function, which is used to sample from the posterior predictive distribution.
   This requires one to extract the values from the chain and insert them back into the model (or technically the `VarInfo`).

   However, in general one cannot reconstruct a vector `x` from its constituent elements `x[1]`, `x[2]`, ... as we do not know the appropriate length of the vector!
   The current implementation of this function in DynamicPPL.jl thus has to, essentially, insert all the elements it can find and hope for the best.

   Essentially, MCMCChains' data structure forces packages like Turing.jl and DynamicPPL.jl to include workarounds to deal with the limitations of the chains package.

1. To create a robust and readable codebase.

   Much Julia code is written with the intention of efficiency or versatility, often sacrificing clarity in the process.
   This is usually acceptable when creating simple scripts.
   However, I believe that library code should be held to a (much) higher standard.

   In particular, I consider the overuse of multiple dispatch to be a major source of confusion in Julia code.
   Types cannot be fully inferred at compile time (and even when they can, it requires packages such as JET.jl, which do not (yet) have convenient language server integrations).
   This means that when reading code, one cannot easily determine which method is being called.

   A prime example is the `Chains` constructor in MCMCChains.jl.
   `methods(Chains)` returns 11 methods, and each time you see a call to `Chains(...)` you need to figure out which of these 11 it is.
   In writing FlexiChains I have made a conscious choice to create only two inner constructors for `FlexiChain`.

In particular, notice that *performance* is not one of my considerations.
In my opinion, performance is only a minor concern for FlexiChains.jl, because the main bottleneck in Bayesian inference is the sampling, not how fast one can construct or index into a chain.
I have not performed any benchmarks but I would expect that most operations on `MCMCChains.Chains` will be faster than on `FlexiChains.FlexiChain`.
