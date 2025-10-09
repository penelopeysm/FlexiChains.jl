# FlexiChains.jl

Flexible Markov chains.

[**Documentation**](http://pysm.dev/FlexiChains.jl/)

## Usage

`FlexiChain{T}` represents a chain that stores data for parameters of type `T`.
`VNChain` is a alias for `FlexiChain{VarName}`, and is the appropriate type for storing Turing.jl's outputs.

To obtain a `VNChain` from MCMC sampling, pass the `chain_type` argument to the `sample` function.

```julia
using Turing
using FlexiChains

@model function f()
    x ~ Normal()
    y ~ Poisson(3.0)
    z ~ MvNormal(zeros(2), I)
end
chain = sample(f(), NUTS(), MCMCThreads(), 1000, 3; chain_type=VNChain)
```

You can index into a `VNChain` using `VarName`s.
Data is returned as a `DimMatrix` from the [`DimensionalData.jl` package](https://rafaqz.github.io/DimensionalData.jl/), which behaves exactly like an ordinary `Matrix` but additionally carries more information about its dimensions.

```julia
chain[@varname(x)]    # -> DimMatrix{Float64}
chain[@varname(y)]    # -> DimMatrix{Int}
chain[@varname(z)]    # -> DimMatrix{Vector{Float64}}
chain[@varname(z[1])] # -> DimMatrix{Float64}
chain[:logjoint]      # -> DimMatrix{Float64} NOTE: not `:lp`
```

Quick and dirty summary stats can be obtained with:

```julia
ss = summarystats(chain)         # mean, std, mcse, ess, rhat for all variables
ss[@varname(x), stat=At(:mean)]  # -> Float64 (the mean of x)
```

Or you can compute statistics directly with individual functions:

```julia
mean(chain)              # just the mean for all variables
mean(chain)[@varname(x)] # -> Float64
mean(chain; dims=:iter)  # take the mean over iterations only
```

Visualisation with Plots.jl is supported:

```julia
using StatsPlots
plot(chain)                    # trace + densities for all variables
plot(chain, [@varname(z)])     # trace + density for z[1] and z[2] only
plot(chain; pool_chains=true)  # combining samples from all chains
```

Finally, functions in Turing.jl which take chains as input, such as `returned`, `predict`, and `logjoint` should work out of the box with exactly the same behaviour as before.

## Why use FlexiChains?

Turing's default data type for Markov chains is [`MCMCChains.Chains`](https://turinglang.org/MCMCChains.jl/stable/).

This entire package essentially came about because I think `MCMCChains.Chains` is a bad data structure.

Consider the following model:

```julia
@model function f()
    x ~ Poisson(1.0)
    y ~ MvNormal(zeros(2), I)
end
```

The way that MCMCChains and FlexiChains stores the outputs of this model is illustrated here:

<div align="center">
<img width="450" alt="MCMCChains vs FlexiChains data structure comparison" src="https://github.com/user-attachments/assets/4fbbc925-d4c3-41c7-9d6a-e83503fdb349" />
</div>

Specifically, MCMCChains represents data as a mapping of _individual_ `Symbol`s to arrays of `Float64`s.
However, Turing.jl uses `VarName`s as keys in its models, and the values can be anything that is sampled from a distribution.
In this case, `x` is an integer-valued parameter, and `y` is a vector-valued parameter.

This leads to several problems:

1. **The conversion from `VarName` to `Symbol` is lossy.** See [here](https://github.com/TuringLang/MCMCChains.jl/issues/469) and [here](https://github.com/TuringLang/MCMCChains.jl/issues/470) for examples of how this can bite users. It also forces Turing.jl to store extra information in the chain which specifies how to retrieve the original `VarName`s.

1. **Array-valued parameters must be broken up in a chain.** This makes it very annoying to reconstruct the full arrays. It also causes [massive slowdowns for some operations](https://github.com/TuringLang/DynamicPPL.jl/issues/1019), and is also responsible for [some hacky code in AbstractPPL and DynamicPPL](https://github.com/TuringLang/AbstractPPL.jl/pull/125) that has no reason to exist beyond the limitations of MCMCChains.

1. **Inability to store generic information from MCMC sampling.** For example, a model containing a line such as `x := s::String` (see [here](https://turinglang.org/docs/usage/tracking-extra-quantities/) for the meaning of `:=`) will error.

1. **Overly aggressive casting to avoid abstract types.** If you have an integer-valued parameter, it will be cast to `Float64` when sampling using MCMCChains. See [this issue](https://github.com/TuringLang/Turing.jl/issues/2666) for details.

FlexiChains solves all of these by making the mapping of parameters to values much more flexible (hence the name).
Both keys and values can, in general, be of any type.
This makes for a less compact representation of the data, but means that information about the chain is preserved much more faithfully.
