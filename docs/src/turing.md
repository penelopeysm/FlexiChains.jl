# Usage with Turing.jl

This page provides a fairly high-level overview of how to use FlexiChains with Turing.jl.

## Sampling

To obtain a `FlexiChain` from Turing.jl, you will need to specify a `chain_type` of `FlexiChains.VNChain` when performing MCMC sampling.

Let's use a non-trivial model so that we can illustrate some features of FlexiChains.

```@example 1
using Turing, FlexiChains

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

First, notice in the printout above that a `FlexiChain` stores 'parameters' and 'other keys' separately.
Parameters correspond to random variables of the model you sampled from, whereas other keys are extra data associated with the samples drawn (for example, the log-joint probability of each sample).
Each of these are accessed in a slightly different way.

### Parameters

To access parameters, the _most correct_ way is to use `VarName`s to index into the chain.
`VarName` is a data structure [defined in AbstractPPL.jl](https://turinglang.org/AbstractPPL.jl/stable/api/#AbstractPPL.VarName), and is what Turing.jl uses to represent the name of a random variable (appearing on the left-hand side of a tilde-statement).

`VarName`s are most easily constructed by applying the `@varname` macro to the name of the variable that you want to access.
For example, this directly gives us the value of `mu` in each iteration as a plain old vector of floats.

```@example 1
chain[@varname(mu)]
```

!!! note "DimMatrix"
    
    Indexing into a `FlexiChain` returns a [`DimensionalData.DimMatrix`](@extref DimensionalData DimArrays). This behaves exactly like a regular `Matrix`, but additionally carries extra information about its dimensions.
    
    This allows you to keep track of what each dimension means, and also allows for more advanced indexing operations, which are described in [the 'indexing' page](./indexing.md).

For vector-valued parameters like `theta`, this works in exactly the same way, except that you get a `DimMatrix` of vectors.

```@example 1
chain[@varname(theta)]
```

Note that the samples are stored _not_ as a 3D array, but rather a matrix of vectors.
**This is probably the biggest difference between FlexiChains and MCMCChains.**
MCMCChains by default will break vector-valued parameters into multiple scalar-valued parameters called `theta[1]`, `theta[2]`, etc., whereas FlexiChains keeps them together as they were defined in the model.

If you want to obtain only the first element of `theta`, you can index into it with the corresponding `VarName`:

```@example 1
chain[@varname(theta[1])]
```

In this way, you can 'break down', or access nested fields of, larger parameters.
That is, if your model has `x ~ dist`, FlexiChains will let you access some field or index of `x`.

!!! note "Heterogeneous data"
    
    If some samples of `x` have one element and others have two elements, attempting to access `x[2]` will return an array with `missing` values for the samples where `x` only has one element.

!!! note "Sub-variables"
    
    You can access _sub-variables_ of a model parameter, but not the other way around. If your model looks like
    
    ```julia
    @model function f()
        x[1] ~ dist
        return x[2] ~ dist
    end
    ```
    
    or alternatively
    
    ```julia
    @model function f()
        x = Vector{Float64}(undef, 2)
        return x .~ dist
    end
    ```
    
    you cannot 'reconstruct' `x` from its component elements, because `x` does not exist as a single parameter in the model.
    (Or at least, you can't do it with FlexiChains.
    You can still call `chain[@varname(x[1])]` and `chain[@varname(x[2])]` and then perform `hcat` or similar to put them together yourself.)

You can also use keyword arguments when indexing to specify which chains or iterations you are interested in.
Note that when using square brackets to index, keyword arguments must be separated by commas, not semicolons!

```@example 1
chain[@varname(mu), iter=2:4, chain=1]
```

The indexing behaviour of FlexiChains is described fully on [the next page](./indexing.md).

### Other keys

In general Turing.jl tries to package up some extra metadata into the chain that may be helpful.
For example, the log-joint probability of each sample is stored with the key `:logjoint`.
To access non-parameter information like this in an unambiguous fashion, you should use the `Extra` wrapper.

```@example 1
using FlexiChains: Extra

chain[Extra(:logjoint)]
```

!!! warning
    MCMCChains stores the log-joint probability as `:lp`. FlexiChains uses `:logjoint` instead, which is clearer. It is possible that MCMCChains may be changed to use `:logjoint` in the future, but for now this is another difference to be aware of.

If there is no ambiguity in the symbol `:logjoint`, then you can use a shortcut which is described in the next section.

### Indexing by `Symbol`: a shortcut

If you are used to MCMCChains.jl, you may find this more cumbersome than before.
So, FlexiChains provides some shortcuts for accessing data.
You can index into a `FlexiChain` with a single `Symbol`, and _as long as it is unambiguous_, it will return the corresponding data.

```@example 1
chain[:mu] # parameter
```

!!! note "What does unambiguous mean?"
    
    In this case, because the only parameter `p` for which `Symbol(p) == :mu` is `@varname(mu)`, we can safely identify `@varname(mu)` as the parameter that we want.

!!! note "No sub-varnames"
    
    You cannot use `chain[Symbol("theta[1]")]` as a replacement for `chain[@varname(theta[1])]`.

Likewise, we can omit wrapping `:logjoint` in `Extra(...)`:

```@example 1
chain[:logjoint] # other key
```

If there is any ambiguity present (for example if there is also a parameter named `@varname(logjoint)`), FlexiChains will throw an error.

## Splitting VarNames up

The way that FlexiChains keeps vector-valued parameters together can make it more difficult to perform subsequent analyses, such as summarising or plotting.
Therefore, to 'break up' parameters into their constituent sub-`VarName`s, you can use `FlexiChains.split_varnames`:

```@example 1
split_varnames(chain)
```

Do note that this is a lossy conversion.
There is no way to un-split the chain!
Furthermore, while functions like `predict` will still work with a split chain, there will be substantial performance regressions.
It is therefore strongly recommended that you only split a chain up only when necessary, and never earlier than that.

## Summary statistics

### Overall summaries

For a very quick summary of the chain, you can use `StatsBase.summarystats` (which FlexiChains reexports):

```@example 1
using FlexiChains: summarystats

summarystats(chain)
```

By default, `summarystats` will split `VarName`s up.
This is done because summary statistics often only make sense for scalar-valued parameters, and users are unlikely to use a `FlexiSummary` to a performance-critical task.
If you want to avoid this, you can set `split_varnames=false`:

```@example 1
summarystats(chain; split_varnames=false)
```

### Individual summaries

You can obtain, for example, the mean of each key in the chain using `Statistics.mean`.
This returns a `FlexiSummary` object:

```@example 1
using Statistics: mean

mn = mean(chain)
```

You can index into a `FlexiSummary` in exactly the same ways as a `FlexiChain`.

```@example 1
mn[@varname(mu)]
```

Out of the box, FlexiChains provides:

  - `Statistics.mean`
  - `Statistics.median`
  - `Statistics.std`
  - `Statistics.var`
  - `Statistics.quantile`
  - `Base.minimum`
  - `Base.maximum`
  - `Base.sum`
  - `Base.prod`
  - `MCMCDiagnosticTools.ess`
  - `MCMCDiagnosticTools.rhat`
  - `MCMCDiagnosticTools.mcse`

These functions can all be applied to a `FlexiChain` with their usual signatures (for example, `quantile` will require a second argument).
Keyword arguments of the original functions are also supported, for example `ess(chain; kind=:tail)` returns the tail ESS.

!!! note "Other summary functions"
    
    If you want to apply a summary function that isn't listed above, you can manually use [`FlexiChains.collapse`](@ref). If it is something that is worth appearing in FlexiChains proper, please do open an issue!

### Collapsed dimensions

By default, applying summary functions will collapse the data in both the iteration and chain dimensions (the latter is only relevant if multiple chains are present).

To only collapse over one dimension you can use

```@example 1
mean(chain; dims=:iter)[@varname(mu)]
```

or `dims=:chain` (although that is probably less useful).

## Saving and resuming MCMC sampling progress

If you want to sample a fewer number of iterations first and then resume it later, you can use the following:

```@example 1
chn1 = sample(model, NUTS(), 10; chain_type=VNChain, save_state=true)
chn2 = sample(model, NUTS(), 10; chain_type=VNChain, resume_from=chn1)
```

The chains can be combined using `vcat`:

```@example 1
chn = vcat(chn1, chn2)
```

!!! note "Multiple-chain sampling"
    
    In general, the `resume_from` argument only works automatically if both the original and resumed sampling use the same number of chains.
    That is, `chn1` and `chn2` must either both be invoked as `sample(model, spl, N)`, or both invoked as `sample(model, spl, MCMCThreads(), N, C)` with the same `C`.
    
    If you need more flexibility than this, then the `initial_state` keyword argument is recommended instead.
    When performing **single-chain sampling** with `sample(model, spl, N; initial_state=state)`, `initial_state` should be either `nothing` (to start a new chain) or the state to resume from.
    For **multiple-chain sampling** with `sample(model, spl, MCMCThreads(), N, C)`, `initial_state` should be a vector of length `C`, where `initial_state[i]` is the state to resume the `i`-th chain from (or `nothing` to start a new chain).
    
    To obtain the saved final state of a chain, you can use [`FlexiChains.last_sampler_state`](@ref).
    This always returns a vector of states with length equal to the number of chains.
    Note that this applies also if you only sampled a single chain, in which case the returned value is a vector of length 1: you will therefore have to use `only()` to extract the state itself.
    
    The above applies equally to `MCMCSerial()` and `MCMCDistributed()`.

## Posterior predictions and friends

The functions `predict`, `returned`, `logjoint`, `loglikelihood`, and `logprior` all work 'as expected' using FlexiChains with exactly the same signatures that you are used to.
Please consult [the Turing.jl documentation](https://turinglang.org/Turing.jl/stable/api/#Predictions) for more details.

```@example 1
returned(model, chain)
```

The `pointwise_logdensity` family of functions is not yet implemented.

## Plotting

FlexiChains contains a few recipes for plotting with StatsPlots.jl; please see [the Plotting page](./plotting.md) for full details.

```@example 1
# Or omit the second argument to plot all parameters.
plot(chn, [@varname(mu), @varname(tau), @varname(theta[1])])
savefig("plot_ex.svg"); nothing # hide
```

![Trace and density plots for mu, tau, and theta1](plot_ex.svg)
