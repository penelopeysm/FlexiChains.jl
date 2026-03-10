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
mchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=MCMCChains.Chains);
fchain = sample(Xoshiro(468), f(), MH(), 50; chain_type=FlexiChains.VNChain);

(eltype(mchain[:y]), eltype(fchain[:y]))
```

Now, Distributions.jl kindly allows you to call `logpdf(::Poisson, x::Float64)` and returns the correct value if `isinteger(x)`.
So, if your model is simple enough, you can still use functions such as `returned` and `predict` without running into errors, even with MCMCChains.

However, if you attempt to use the value of `x` somewhere where it needs to be an integer, such as...

```@example types
@model function f2()
    # A more realistic scenario is `n ~ Poisson(...)`.
    # That errors with MCMCChains for a *different* reason;
    # we'll come to that in a while.
    n ~ DiscreteUniform(2, 2)
    x ~ MvNormal(zeros(n), I)
    return sum(x)
end

mchain = sample(Xoshiro(468), f2(), MH(), 50; chain_type=MCMCChains.Chains)
nothing # hide
```

you will find that it errors, because `n` is stored as `2.0` in the chain:

```@example types
try #hide
returned(f2(), mchain)
catch e; showerror(stdout, e); end # hide
```

Now, you *could* work around this with `zeros(Int(n))`, but that's deeply unsatisfying, because `n` really *should* be an integer.
Good news: FlexiChains will store it as an integer for you!

```@example types
fchain = sample(Xoshiro(468), f2(), MH(), 50; chain_type=FlexiChains.VNChain)
returned(f2(), fchain)
```

## Missing data

As a variant on the above bug with proper type representation, consider the case where some data is missing:

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

## Variable-length parameters

Above we used an example with `DiscreteUniform(2, 2)` to demonstrate what happens when `Int`-valued parameters get converted to `Float`s.
This is of course a bit pointless since sampling from that always gives `2`.
Let's see now what happens when we have a truly variable-length parameter:

```@example varlen
using Random, Turing, FlexiChains, MCMCChains

@model function varlen()
    n ~ Poisson(3.5)
    x ~ MvNormal(zeros(n), I)
    y ~ Normal(sum(x))
end

model = varlen()
cond_model = varlen() | (; y = 2.0)

mchain = sample(Xoshiro(468), cond_model, MH(), 50; chain_type=MCMCChains.Chains);
fchain = sample(Xoshiro(468), cond_model, MH(), 50; chain_type=FlexiChains.VNChain);
nothing # hide
```

So far, so good; we can sample from everything just fine.
The trouble comes when you want to use something like `predict` or `returned` which involves feeding the samples from the chain back into the model.

```@example varlen
try #hide
predict(model, mchain)
catch e; showerror(stdout, e); end # hide
```

!!! warning
    The above will *probably* fail, but it *can* actually run successfully, if you are lucky enough to get a sample where `n` is larger than or equal to that in all the other samples.
    If the built docs don't show an error, try running it in the REPL, and you'll find that it will almost always fail.

The reason why MCMCChains fails here is because it does two things:

1. It stores `x` as a series of elements `x[1]`, `x[2]`, and so on.
2. When reconstructing the value of `x` for use in the model, it doesn't know how long `x` is *supposed* to be.
   It determines this by running the model once, and taking the value of `x` from *that specific* run of the model.

This of course ignores the fact that `x` can have different lengths.

In contrast, FlexiChains does two things:

1. Where possible, it will store `x` as a single parameter.
2. As a guard against situations where this isn't possible (e.g. if not all values of `x` are filled in), it *also* stores the structure of `x` as part of the chain, so that it can always reconstruct it correctly.

This means that regardless of what value `n` takes in the samples, `predict` and `returned` will always work correctly with FlexiChains.

```@example varlen
predict(model, fchain)
```

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
mchain = sample(Xoshiro(468), hasstring(), MH(), 50; chain_type=MCMCChains.Chains)
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
setprogress!(false)

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

If you have `x` stored as a full vector, you can also do fancy things like indexing into `x[end]`, which will give you the last element of `x` regardless of how long it is in that particular sample.

```@example reconstruct
@model function varlen_again()
    n ~ Poisson(3.5)
    x ~ MvNormal(zeros(n), I)
end

fchain = sample(Xoshiro(468), varlen_again(), MH(), 5; chain_type=FlexiChains.VNChain);
fchain[@varname(x)]
```

```@example reconstruct
fchain[@varname(x[end])]
```

## Interoperability with the rest of Turing

Suppose you have sampled a chain, and you want to use something from it as the starting point for a new chain, or a new optimisation, or something.

```@example interop
using Random, Turing, FlexiChains, MCMCChains

@model function twonorm()
    x ~ Normal()
    y ~ Normal()
    return x + y
end

mchain = sample(Xoshiro(468), twonorm(), MH(), 50; chain_type=MCMCChains.Chains);
fchain = sample(Xoshiro(468), twonorm(), MH(), 50; chain_type=FlexiChains.VNChain);
```

Let's say you want to use the last sample of `x` as the starting point for another sampler.

```@example interop
Array(mchain)[50, :, :]
```

Even at this early point, it is already quite ugly: you have to know that the samples are stored in a 3D array, and that the first dimension corresponds to iterations, the second to parameters, and the third to chains.
Secondly, it gives you a *vector* of parameters, and it's nontrivial to figure out from this how these map to the original variables in the model.
You *can* use

```@example interop
names(MCMCChains.get_sections(mchain, :parameters))
```

and for this trivial model it's very clear that the first one is `x` and the second is `y`.
However, this generalises to complex samples very poorly (consider e.g. matrices and Cholesky samples again), and is *very* difficult to write in a programmatic way!

In contrast, with FlexiChains, you can just do

```@example interop
vnt = FlexiChains.parameters_at(fchain, 50, 1)
```

which directly gives you a `VarNamedTuple` that will 'just work' with the rest of Turing.
For example, you can use it as the starting point for a new sampler:

```@example interop
init = InitFromParams(vnt)
sample(twonorm(), NUTS(), 50; initial_params=init, chain_type=FlexiChains.VNChain)
```

or use it to begin an optimisation (a bit pointless for our trivial model, but you get the idea!):

```@example interop
maximum_a_posteriori(twonorm(); initial_params=init)
```

or pass it to a function like `returned`:

```@example interop
returned(twonorm(), vnt)
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

## If you're a Turing developer...

I suppose I am somewhat qualified to comment on this...
There are a number of places in TuringLang where the unfaithful data structure of MCMCChains leads to hacky workarounds.
Most of them centre around the difficulty of reconstructing vectors `x` from its flattened components `x[1]`, `x[2]`, and so on.

For example, [AbstractPPLDistributionsExt](https://github.com/TuringLang/AbstractPPL.jl/blob/v0.13.5/ext/AbstractPPLDistributionsExt.jl) exists _solely_ for this reason.
(None of us are particularly happy about this: see [this PR](https://github.com/TuringLang/AbstractPPL.jl/pull/125).)
The methods defined here allow you to check whether a dictionary like `Dict(@varname(x[1]) => 1.0, @varname(x[2]) => 2.0)` can be reconstructed into a vector-valued parameter `x`, _given_ that `x` is drawn from `MvNormal(zeros(2), I)`.
This is precisely because we can only obtain the former dictionary from MCMCChains, but when evaluating a model we need the latter.

On top of that, MCMCChains doesn't store the keys as `VarName`s: it stores them as `Symbol`s.
That means that any time we need to retrieve the original `VarName`s, we need to use a secret dictionary that is stored inside `chain.info`.
This is [automatically included when sampling using Turing](https://github.com/TuringLang/Turing.jl/blob/cabe73fd07b3ddb37b51f6c0c9db66891e179f3c/src/mcmc/Inference.jl#L351-L353), but it makes it somewhat frustrating to test MCMCChains-related functionality in isolation.
In general, though, this is a very fragile solution and relies on Turing 'just happening' to do the right thing.
