# Why a new package?

FlexiChains.jl has been designed from the ground up to address existing limitations of [MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl).

## The fundamental difference

Under the hood, MCMCChains.jl uses [`AxisArrays.AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl/) as its data structure.
Specifically, this allows it to store data in a compact 3-dimensional matrix, and index into the matrix using `Symbol`s.

The downside of this is that it enforces a key type of `Symbol` and a value type of `Tval<:Real`.
This means that, for example, if you have a model with vector-valued parameters (like `x` above), the vectors will be split up into their individual elements before being stored in the chain.

This is _the_ core of how MCMCChains and FlexiChains differ, and all of the behaviour shown below stems from this.

To illustrate this, let's sample from a Turing model and store the results in both `MCMCChains.Chains` and `FlexiChains.VNChain`.

```@example 1
using Turing
using MCMCChains: Chains
using FlexiChains: VNChain, VarName, @varname
using Random: Xoshiro
using PDMats: PDMats

Turing.setprogress!(false)

@model function f(x)
    sigma ~ truncated(Normal(0, 1); lower=0)
    chol ~ LKJCholesky(3, 1.0)
    corr := PDMats.PDMat(chol)
    mu ~ MvNormal(zeros(3), sigma^2 * I)
    return x ~ MvNormal(mu, corr)
end

model = f(randn(Xoshiro(468), 3))
```

The default chain type for Turing's `sample` is still `MCMCChains.Chains`; we just specify it here for clarity.

```@example 1
mcmc = sample(Xoshiro(468), model, NUTS(), 100; chain_type=Chains)
```

Because FlexiChains does not enforce a key type, you are technically required to specify the key type of the chain as a type parameter.
You could, for example, write `FlexiChains.FlexiChain{DynamicPPL.VarName}`.
But since this is really the main use case of FlexiChains, we provide a convenient alias for this, `FlexiChains.VNChain`.

```@example 1
flexi = sample(Xoshiro(468), model, NUTS(), 100; chain_type=VNChain)
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

## Other types of data

Let's say we define a weird new discrete distribution which samples from the two structs `Duck()` and `Goose()`.

(Why would you want to do this?
Well, why _shouldn't_ you be able to do it?
Turing's docs [tell you how to define your own distributions](https://turinglang.org/docs/usage/custom-distribution/), but it doesn't say that you have to use numbers.
The point is that FlexiChains doesn't _force_ you to stick only to distributions over numbers.)

```@example 1
using Distributions, Random

abstract type Bird end
struct Duck <: Bird end
struct Goose <: Bird end

struct BirdDist <: Distributions.DiscreteUnivariateDistribution end
Distributions.rand(rng::Random.AbstractRNG, ::BirdDist) = rand(rng) < 0.3 ? Duck() : Goose()
Distributions.logpdf(::BirdDist, x::Duck) = log(0.3)
Distributions.logpdf(::BirdDist, x::Goose) = log(0.7)

@model function f()
    return x ~ BirdDist()
end

# A bit more boilerplate is needed here to actually make it work with Turing.
using Bijectors, DynamicPPL
DynamicPPL.tovec(b::Bird) = [b]
Bijectors.logabsdetjac(::typeof(identity), ::Bird) = 0.0

# mcmc = sample(f(), MH(), 100; chain_type=VNChain)
```

TODO: Fix the example above, it fails with typed VarInfo because typed VarInfo expects Real things to put into Metadata. SimpleVarInfo would work. See https://github.com/TuringLang/DynamicPPL.jl/pull/1003

Well, that worked quite nicely with FlexiChains.

MCMCChains on the other hand would completely error here because it requires all its values to be `Real`.
(To be precise, it requires all its values to be _convertable_ to `Real`.
So a distribution over `Char` works, even though `Char <: Real` is false, because `Char`s can be converted to `Real`.)

## No need to avoid reserved names

When sampling from a Turing model with MCMCChains as the output format, some metadata (non-parameter keys) such as `lp` are added to the chain.
If your model contains a variable called `lp`, sampling will still work but [odd things will happen](https://github.com/TuringLang/MCMCChains.jl/issues/469).
For example, it will look as if your chain does not actually have any variables:

```@example 1
@model function lp_model()
    return lp ~ Normal()
end

mchain = sample(Xoshiro(468), lp_model(), NUTS(), 100; chain_type=Chains)
describe(mchain)
```

When you index into `mchain[:lp]`, how do you know whether it refers to the `lp` variable in your model or the `lp` metadata key?

```@example 1
any(mchain[:lp] .> 0)
```

Well, since there are some positive values, it has to be the parameter, because the metadata `lp = logpdf(Normal(), value_of_lp_parameter)` is always negative.
But you didn't know that when you tried to index into it, you had to reverse engineer it.

Besides, if you actually want the log-density, it's now gone.
Tough luck.
(You can get it back with `logjoint(lp_model(), mchain)` if you want.)

HMC samplers further include extra metadata such as `hamiltonian_energy`, and in general **any sampler** can include any kind of extra metadata it wants.
As a user, you have no way of knowing what these names are, and you have to avoid using them in your model, which is quite unfair.

FlexiChains circumvents this entirely since it stores these separately as `Parameter(@varname(lp))` and `OtherKey(:logprobs, :lp)`.

```@example 1
fchain = sample(Xoshiro(468), lp_model(), NUTS(), 100; chain_type=VNChain)
```

You will of course run into ambiguities if you simply attempt to index the chain with `[:lp]`, because both the `Parameter(@varname(lp))` and the `OtherKey(:logprobs, :lp)` exist.

```julia
fchain[:lp]
# This code block isn't run because it would throw the following error:
# ArgumentError: multiple keys correspond to symbol :lp.
```

but you can still access the value using the original value of the `Parameter`:

```@example 1
fchain[@varname(lp)]
```

and the corresponding metadata:

```@example 1
fchain[:logprobs, :lp]
```

and indeed we can check that these do align:

```@example 1
logpdf.(Normal(), fchain[@varname(lp)]) ≈ fchain[:logprobs, :lp]
```

TODO pretty-printing / summary stats

## For DynamicPPL developers

TODO Write about how this makes life a lot easier for things like `predict`.

## Design goals

My main design goals for FlexiChains.jl were twofold:

 1. To provide a rich data structure that can more faithfully represent the outputs from sampling with Turing.jl.
    
    The restriction of MCMCChains.jl to `Symbol` keys and `Real` values means that round-trip conversion is a lossy operation.
    Consider, e.g., the `predict(::Model, ::MCMCChains.Chains)` function, which is used to sample from the posterior predictive distribution.
    This requires one to extract the values from the chain and insert them back into the model (or technically the `VarInfo`).
    
    However, in general one cannot reconstruct a vector `x` from its constituent elements `x[1]`, `x[2]`, ... as we do not know the appropriate length of the vector!
    The current implementation of this function in DynamicPPL.jl thus has to, essentially, insert all the elements it can find and hope for the best.
    
    Essentially, MCMCChains' data structure forces packages like Turing.jl and DynamicPPL.jl to include workarounds to deal with the limitations of the chains package.

 2. To create a robust and readable codebase.
    
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
