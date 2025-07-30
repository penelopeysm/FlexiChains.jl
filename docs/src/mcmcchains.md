# Migrating from MCMCChains.jl

FlexiChains.jl has been designed from the ground up to address existing limitations of [MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl).

This page describes some key differences from MCMCChains.jl and how you can migrate your code to use FlexiChains.jl.

## The fundamental difference

Under the hood, MCMCChains.jl uses [`AxisArrays.AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl/) as its data structure.
Specifically, this allows it to store data in a compact 3-dimensional matrix, and index into the matrix using `Symbol`s.

The downside of this is that it enforces a key type of `Symbol` and a value type of `Tval<:Real`.
This means that, for example, if you have a model with vector-valued parameters (like `x` above), the vectors will be split up into their individual elements before being stored in the chain.

This is _the_ core of how MCMCChains and FlexiChains differ, and all of the behaviour shown below stems from this.

To illustrate this, let's sample from a Turing model and store the results in both `MCMCChains.Chains` and `FlexiChains.FlexiChain`.

```@example 1
using Turing
using MCMCChains: MCMCChains
using FlexiChains: FlexiChains
using Random: Xoshiro
using PDMats: PDMats
using DynamicPPL: VarName

Turing.setprogress!(false)

@model function f(x)
    sigma ~ truncated(Normal(0, 1); lower = 0)
    chol ~ LKJCholesky(3, 1.0)
    corr := PDMats.PDMat(chol)
    mu ~ MvNormal(zeros(3), sigma^2 * I)
    x ~ MvNormal(mu, corr)
end

model = f(randn(Xoshiro(468), 3))
```

The default chain type for Turing's `sample` is still `MCMCChains.Chains`; we just specify it here for clarity.

```@example 1
mcmc = sample(Xoshiro(468), model, NUTS(), 100; chain_type=MCMCChains.Chains)
```

When using FlexiChains, you have to specify the key type of the chain.
In this case, it is `VarName`.

```@example 1
flexi = sample(Xoshiro(468), model, NUTS(), 100; chain_type=FlexiChains.FlexiChain{VarName})
```

Here, we expect the following parameters to be present in the chain:

- `sigma` is a scalar;
- `chol` is a Cholesky factor which contains a 3×3 lower triangular matrix;
- `corr` is a 3×3 correlation matrix, which is a positive-definite matrix;
- `mu` is a length-3 vector.

Let's test first that both chains contain the same values for `sigma`.
(Some fiddling is required because `mcmc[:sigma]` returns an AxisArray with a 100×1 matrix, while `flexi[:sigma]` returns a 100-element vector.)

```@example 1
vec(mcmc[:sigma].data) == flexi[@varname(sigma)]
```

## Indexing keys

There is already one difference here: when indexing into MCMCChains you need to use a `Symbol` or `String`, whereas with FlexiChains you can use the original `VarName`.

If you think this is too verbose, fret not!
FlexiChains also lets you use `Symbol`s (mainly for compatibility with MCMCChains):

```@example 1
flexi[:sigma] == flexi[@varname(sigma)]
```

The rest of this page uses `VarName`s, but you can mentally replace them with `Symbol`s if you prefer.

## Accessing vector-valued parameters

Suppose you want to access the value of `mu` in the first iteration.

With FlexiChains, you can do this directly as:

```@example 1
flexi[:mu][1]
```

With MCMCChains, because `mu` has been split up into its constituent elements, you need to do:

```@example 1
[mu[1] for mu in (mcmc["mu[1]"], mcmc["mu[2]"], mcmc["mu[3]"])]
```

## Accessing parameters with even more special types

Now suppose you want to extract the sampled values of `chol` and `corr`, and check that

```julia
# This code block isn't executed because we haven't defined `chols` and `corrs`
for (chol, corr) in zip(chols, corrs)
    chol == cholesky(corr) || error("oops")
end
```

The question is of course how one can obtain the vectors `chols` and `corrs` from the chain.
With FlexiChains, you can do this directly as:

```@example 1
chols = flexi[:chol]
```

and likewise for `:corr`.

On the other hand, with MCMCChains, reconstructing the `chol`s becomes a non-trivial task:

```@example 1
using LinearAlgebra

chols = map(1:length(mcmc)) do i
    c = Cholesky(LowerTriangular(zeros(3, 3)))
    for j in 1:3
        for k in 1:j
            c.L[j, k] = mcmc["chol.L[$j, $k]"][i]
        end
    end
    c
end
```

and similarly for the `corr`s (which we won't demonstrate here).

In general the point is that in any situation where you want to work with the actual types of the parameters, rather than their individual elements, FlexiChains makes this much easier.

## Accessing individual elements

Sometimes maybe you really want to access just `mu[2]` without any reference to `mu[1]` or `mu[3]`.

Because FlexiChains stores the entire vector `mu`, you will then need to index into it:

```@example 1
[mu_sample[2] for mu_sample in flexi[:mu]]
```

In MCMCChains you can of course do

```@example 1
mcmc["mu[2]"]
```

Note, though, that MCMCChains requires you to pass a _string_ `"2"` to get the second variable.
Of course, if you have an integer `2` this is quite easily done with interpolation, but I would argue from a readability perspective it's much clearer to index with an integer `2` rather than a string.

## Accessing 'generated quantities' (using `:=`)

TODO

## Convergence checks

'Ah,' you say, 'but when I plot my chains I want to see the individual elements of `mu` as separate lines!'

## No need to avoid reserved names

When sampling from a Turing model with MCMCChains as the output format, some metadata (non-parameter keys) such as `lp` are added to the chain.
If your model contains a variable called `lp`, sampling will still work but [odd things will happen](https://github.com/TuringLang/MCMCChains.jl/issues/469).
For example, it will look as if your chain does not actually have any variables:

```@example 1
@model function lp_model()
    lp ~ Normal()
end

chain = sample(Xoshiro(468), lp_model(), NUTS(), 100; chain_type=MCMCChains.Chains)
describe(chain)
```

When you index `chain[:lp]`, how do you know whether it refers to the `lp` variable in your model or the `lp` metadata key?

```@example 1
any(chain[:lp] .> 0)
```

Well, since there are some positive values, it has to be the parameter, because the metadata `lp = logpdf(Normal(), value_of_lp_parameter)` is always negative.
But you didn't know that when you tried to index into it, you had to reverse engineer it.

Besides, if you actually want the log-density, it's now gone.
Tough luck.
(You can get it back with `logjoint(lp_model(), chain)` if you want.)

HMC samplers further include extra metadata such as `hamiltonian_energy`, and in general **any sampler** can include any kind of extra metadata it wants.
As a user, you have no way of knowing what these names are, and you have to avoid using them in your model, which is quite unfair.

FlexiChains circumvents this entirely since it stores these separately as `Parameter(@varname(lp))` and `OtherKey(:stats, :lp)`.

```@example 1
chain = sample(Xoshiro(468), lp_model(), NUTS(), 100; chain_type=FlexiChains.FlexiChain{VarName})
```

You will of course run into ambiguities if you simply attempt to index the chain with `[:lp]`, because both the `Parameter(@varname(lp))` and the `OtherKey(:stats, :lp)` exist.

```julia
chain[:lp]
# This code block isn't run because it would throw the following error:
# ArgumentError: multiple keys correspond to symbol :lp.
```

but you can still access the value using the original value of the `Parameter`:

```@example 1
chain[@varname(lp)]
```

and the corresponding metadata:

```@example 1
chain[:stats, :lp]
```

and indeed we can check that these do align:

```@example 1
logpdf.(Normal(), chain[@varname(lp)]) ≈ chain[:stats, :lp]
```

TODO pretty-printing / summary stats

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
