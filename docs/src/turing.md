# Usage with Turing.jl

This page describes how to use FlexiChains from the perspective of a Turing.jl user.

In particular, it does not explain 'under the hood' how FlexiChains works.
Rather, it focuses on the usage of FlexiChains within a typical Bayesian inference workflow.
For more detailed information about the inner workings of FlexiChains, please see [Behind the scenes](@ref).

## Sampling

To obtain a `FlexiChain` from Turing.jl, you will need to specify a `chain_type` of `FlexiChains.VNChain` when performing MCMC sampling.

Let's use a non-trivial model so that we can illustrate some features of FlexiChains.

```@example 1
using Turing
using FlexiChains: VNChain

y = [28, 8, -3, 7, -1, 1, 18, 12]
sigma = [15, 10, 16, 11, 9, 11, 10, 18]
@model function eight_schools(y, sigma)
    mu ~ Normal(0, 5)
    tau ~ truncated(Cauchy(0, 5); lower=0)
    theta ~ MvNormal(fill(mu, length(y)), tau^2 * I)
    for i in eachindex(y)
        y[i] ~ Normal(theta[i], sigma[i])
    end
    return (mu=mu, tau=tau)
end
model = eight_schools(y, sigma)
chain = sample(model, NUTS(), 5; chain_type=VNChain)
```

!!! note
    
    We only run 5 MCMC iterations here to keep the output in the following sections small.

## Accessing data

First, notice in the printout above that a `FlexiChain` stores parameters and 'other keys' separately.
The way to access these differs slightly.

### Parameters

To access parameters, the _most correct_ way is to use `VarName`s to index into the chain.
`VarName` is a data structure [defined in AbstractPPL.jl](https://turinglang.org/AbstractPPL.jl/stable/api/#AbstractPPL.VarName), and is what Turing.jl uses to represent the name of a random variable (appearing on the left-hand side of a tilde-statement).

For example, this directly gives us the value of `mu` in each iteration as a plain old vector of floats.

```@example 1
chain[@varname(mu)]
```

!!! note "Multiple chains"
    
    If you sample multiple chains, e.g. with `sample(model, NUTS(), MCMCThreads(), 1000, 3; chain_type=VNChain)`, then indexing into the `FlexiChain` will give you a matrix of floats instead.

For vector-valued parameters like `theta`, this works in exactly the same way, except that you get a vector of vectors (note: not a matrix).

```@example 1
chain[@varname(theta)]
```

This is probably the most major difference between FlexiChains and MCMCChains.
MCMCChains by default will break vector-valued parameters into multiple scalar-valued parameters called `theta[1]`, `theta[2]`, etc., whereas FlexiChains keeps them together as they were defined in the model.

If you want to obtain the first element of `theta`, you can index into it with the corresponding `VarName`:

```@example 1
chain[@varname(theta[1])]
```

Note that this can only be used to 'break down', or access nested fields of, larger parameters.
That is, if your model has `x ~ dist`, FlexiChains will let you access some field or index of `x`.

However, you cannot go the other way: if your model has `x[1] ~ dist` you cannot 'reconstruct' `x` from its component elements.
(Or at least, you can't do it with FlexiChains.
You can still call `chain[@varname(x[1])]` and `chain[@varname(x[2])]` and then perform `hcat` or similar to put them together yourself.)

### Other information in the chain

In general Turing.jl tries to package up some extra metadata into the chain that may be helpful.
For example, the log-joint probability of each sample is stored with the key `:lp`.
Notice in the `FlexiChain` output displayed above, this is associated with a _section_, labelled `:logprobs`.
In `FlexiChain`s, all non-parameter keys are grouped into _sections_.

To access these, you need to specify both the section name and the key name.

```@example 1
chain[:logprobs, :lp]
```

### Shortcuts

If you are used to MCMCChains.jl, you may find this more cumbersome than before.
So, FlexiChains provides some shortcuts for accessing data.
You can index into a `FlexiChain` with a single `Symbol`, and _as long as it is unambiguous_, it will return the corresponding data.

```@example 1
chain[:mu] # parameter
```

!!! note "What does unambiguous mean?"
    
    In this case, because the only parameter `p` for which `Symbol(p) == :mu` is `@varname(mu)`, we can safely identify `@varname(mu)` as the parameter that we want.

Likewise, we can omit the section symbol for the `:lp` data.

```@example 1
chain[:lp] # other key
```

If there is any ambiguity present (for example if there is a parameter named `lp` as well), FlexiChains will throw an error.

## Posterior predictions and friends

The functions `predict`, `returned`, `logjoint`, `loglikelihood`, and `logprior` all work 'as expected' using FlexiChains with exactly the same signatures that you are used to.
Please consult [the Turing.jl documentation](https://turinglang.org/Turing.jl/stable/api/#Predictions) for more details.

```@example 1
returned(model, chain)
```

The `pointwise_logdensity` family of functions is not yet implemented.

## Statistics and plotting

Right now FlexiChains does not (yet) provide any functionality for calculating statistics or plotting, although these are planned for the future.

In the meantime, you can convert a `FlexiChain` to an `MCMCChains.Chains` object using the `MCMCChains.Chains` constructor.

```@example 1
using MCMCChains
mcmc = MCMCChains.Chains(chain)
```
