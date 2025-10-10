# Why FlexiChains?

If you are a Turing user (or developer!), you may well be asking why you should consider using FlexiChains.jl.

In one sentence: **FlexiChains is a more faithful representation of data.**
MCMCChains.jl places extremely strong restrictions on its data structure, which leads to an irrevocable loss of information.

Of course, on its own this doesn't mean much (unless you are a software engineering purist!).
So this page will demonstrate a few concrete scenarios where FlexiChains has a practical advantage.

## Documentation

This package is much better documented.
In my opinion.
(To be fair, I did put a lot of work into it, and if I spent the same amount of time on MCMCChains, I suppose its docs would also look better.)

## Heterogeneous parameter types

```@example types
using Random, Turing, FlexiChains, MCMCChains

@model function f()
    x ~ Normal()
    y ~ Poisson(3.0)
end
```

When sampling from this model, one should expect that the samples of `x` are stored as floats, whereas the samples of `y` are stored as integers, because that is what these distributions produce.

Under the hood, MCMCChains stores the values of all parameters in a single array, which means that all samples get converted into the same type.

```@example types
mchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=MCMCChains.Chains)
fchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=FlexiChains.VNChain)
(eltype(mchain[:y]), eltype(fchain[:y]))
```

In general, this doesn't cause problems with functions like `predict` because Distributions.jl kindly allows you to call `logpdf(::Poisson, x::Float64)` and returns the correct value if `isinteger(x)`.
In fact, this is true of all discrete univariate distributions in Distributions.jl.
But if you were to define your own discrete distribution, you would have to remember to implement this method, or else you would get an error when trying to use things like `predict`.

## Missing data

Okay, maybe the above is still quite abstract.
(For us, it's not: we actually ran into a bug with Turing's test suite once because of this very issue.)
But after all, if it works for everything in Distributions, surely we're fine?

Consider the case where some data is missing:

```@example missing
using Random, Turing, FlexiChains, MCMCChains

@model function f()
    x ~ Normal()
    if x > 0
        y ~ Normal(x)
    end
end

mchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=MCMCChains.Chains)
fchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=FlexiChains.VNChain)
```

In some samples, `y` will be present and not in others.
Because MCMCChains forces all parameters to be in the same array, this means that the entire array must have an element type of `Union{Missing, Float64}`.
With MCMCChains this gets propagated to all parameters, even those that are never missing, such as `x`.

```@example missing
(eltype(mchain[:x]), eltype(fchain[:x]))
```

Okay, maybe you don't ever have such weird models.
It turns out though that you can still run into this.
In Turing's MCMC sampling, the first step is not an actual MCMC step, but rather just the initial parameters (either sampled or provided by the user).
Thus, there are no 'sampler statistics' for the first step, and these are stored as `missing` in MCMCChains.
That means that all the parameters become `Union{Missing, Float64}`!

## Arbitrary types

[Turing provides this very nice operator `:=`](https://turinglang.org/docs/usage/tracking-extra-quantities/), which lets you store arbitrary values in the chain during an MCMC run.

The problem with MCMCChains is, as ever, you can only store things that are `Real` or some array thereof.
Even a simple string will fail:

```@example extraquantities
using Random, Turing, FlexiChains, MCMCChains

@model function hasstring()
    x ~ Normal()
    y := "$x"
end
try #hide
mchain = sample(Xoshiro(468), hasstring(), MH(), 50; chain_type=MCMCChains.Chains, progress=false)
catch e; showerror(stdout, e); end # hide
```

FlexiChains will let you store anything you like.
String? No problem.
ODE solver output? No problem.

```@example extraquantities
fchain = sample(Xoshiro(468), hasstring(), MH(), 50; chain_type=FlexiChains.VNChain)
```

## Reconstructing parameters

Suppose you have some array-valued parameter.

```@example reconstruct
using Random, Turing, FlexiChains, MCMCChains

@model lkj() = x ~ LKJCholesky(3, 2.0)

mchain = sample(Xoshiro(468), lkj(), NUTS(), 50; chain_type=MCMCChains.Chains);
fchain = sample(Xoshiro(468), lkj(), NUTS(), 50; chain_type=FlexiChains.VNChain);
```

With FlexiChains the Cholesky samples are kept together:

```@example reconstruct
fchain[@varname(x)][iter=1, chain=1]
```

Because MCMCChains stores _all_ its data in a single array, it has to flatten this parameter, so good luck trying to reconstruct it.

```@example reconstruct
(mchain[Symbol("x.L[1, 1]")][1, 1], mchain[Symbol("x.L[2, 1]")][1, 1]) # ...
```

Of course, if you really wanted to flatten a chain, FlexiChains lets you do that with [`FlexiChains.split_varnames`](@ref).

## VarNames as keys

Did you notice in that last line we had to write something like `Symbol("x.L[1, 1]")`?
And since it's a `Symbol`, we _have_ to get the name exactly right, we couldn't do (for example) `x.L[1,1]` without the space after the comma?

That's because MCMCChains uses AxisArrays.jl under the hood, which allows you to index into the chain using `Symbol`s — but _only_ `Symbol`s.
FlexiChains retains the original `VarName`s used by Turing, which is a far richer type and allows you to use keys that actually carry meaning, rather than just being strings that _have_ to match exactly.

```@example reconstruct
fchain[@varname(x.L[1,1])][iter=1, chain=1] # No space!
```

```@example reconstruct
fchain[@varname(x.L[:, 1])][iter=1, chain=1] # Index into `x` any way you like
```

## Performance (on important things)

In the following model, `y` is a single parameter that is a vector of length `N`.
That means that when you use functions like `returned` or `predict` on a chain, MCMCChains has to _somehow_ reconstruct the vector `y` from its components which are all stored separately.

```@example perf
using Turing, FlexiChains, MCMCChains, Random

@model function longvec(N)
    m ~ Normal(0)
    y ~ filldist(Normal(m), N)
end
```

It turns out that if `N` is small, MCMCChains does just fine, and is in fact even faster than FlexiChains (because constructing a FlexiChain has more overhead).

```@example perf
using Chairmarks: @be

function benchmark(N)
    model = (longvec(N) | (y = rand(Xoshiro(468), Normal(2.0), N),))
    mchain = sample(Xoshiro(468), model, NUTS(), 500; chain_type=MCMCChains.Chains);
    fchain = sample(Xoshiro(468), model, NUTS(), 500; chain_type=FlexiChains.VNChain);
    mt = @be predict(longvec(N), mchain)
    ft = @be predict(longvec(N), fchain)
    return (N=N, mcmcchains=median(mt).time, flexichains=median(ft).time)
end

benchmark(2) # The results are in seconds
```

But MCMCChains scales really poorly with `N`.

```@example perf
benchmark(1000)
```

## Avoiding name clashes

All of Turing.jl's samplers include some 'sampler statistics' in the output chain.
These are pretty useful things like the step size, whether a transition was accepted, the log-probabilities, and so on.

But if you have a parameter that _just happens_ to share a name with these, then MCMCChains will make it pretty hard for you to get one of them.

```@example clash
using Random, Turing, FlexiChains, MCMCChains

# Oops! This will clash with the actual log prior.
@model pr() = logprior ~ Normal()

mchain = sample(Xoshiro(468), pr(), MH(), 50; chain_type=MCMCChains.Chains);
collect(keys(mchain))
```

There are two columns labelled `:logprior`.
Of course, one is your parameter, the other is the actual log prior probability.
It's a mystery which one is which, and which you get when you do `mchain[:logprior]`!
You could avoid this if you knew exactly which keys the sampler returns, but in general this isn't documented anywhere.
(It _should_ be, of course.)

FlexiChains avoids clashes by completely separating `Parameter` and `Extra` keys, meaning that you can use any name you like without worrying about a rogue sampler breaking your workflow.

## DimensionalData.jl indexing

As you will have noticed, FlexiChains uses DimensionalData.jl to return information-rich matrices.
That means that you can [use all the selectors from DimensionalData.jl](./indexing.md) to extract exactly what you want.
Don't want to use those?
No problem; good old 1-based indices work fine too.
