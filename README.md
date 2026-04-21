# FlexiChains.jl

Flexible Markov chains.

[**Documentation**](http://pysm.dev/FlexiChains.jl/)

## Quickstart

`FlexiChain{T}` represents a chain that stores data for parameters of type `T`.
`VNChain` is a alias for `FlexiChain{VarName}`, and is the appropriate type for storing Turing.jl's outputs.

To obtain a `VNChain` from Turing's MCMC sampling, pass the `chain_type` argument to the `sample` function.

```julia
using Turing
using FlexiChains

@model function f()
    x ~ Normal()
    y ~ Poisson(3.0)
    z ~ MvNormal(zeros(2), I)
end
model = f()
chain = sample(model, MH(), MCMCThreads(), 1000, 3; chain_type=VNChain)
```

Alternatively, you can construct a `VNChain` from a matrix of `VarNamedTuple`s:

```julia
import AbstractMCMC
vnts = [rand(model) for _ in 1:1000, _ in 1:3]  # (1000 x 3) draw from the prior
chain = AbstractMCMC.from_samples(VNChain, vnts)
```

You can index into a `VNChain` using `VarName`s.
Data is returned as a `DimMatrix` from the [`DimensionalData.jl` package](https://rafaqz.github.io/DimensionalData.jl/), which behaves exactly like an ordinary `Matrix` but additionally carries more information about its dimensions.

```julia
chain[@varname(x)]    # -> DimMatrix{Float64}
chain[@varname(y)]    # -> DimMatrix{Int}
chain[@varname(z)]    # -> DimMatrix{Vector{Float64}}; but see also DimensionalDistributions.jl
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

Visualisation with Plots.jl and Makie.jl is supported, as well as PairPlots.jl which is Makie-based:

```julia
using StatsPlots               # or CairoMakie
plot(chain)                    # trace + densities for all variables
plot(chain, [@varname(z)])     # trace + density for z[1] and z[2] only
plot(chain; pool_chains=true)  # combining samples from all chains

using PairPlots, CairoMakie
pairplot(chain)                # pair/corner plot
```

Finally, functions in Turing.jl which take chains as input work out of the box, with exactly the same behaviour as with MCMCChains but significantly better performance on top of that:

```julia
returned(model, chain)                 # model's return value for each iteration
predict(model, chain)                  # posterior predictions
logjoint(model, chain)                 # log joint probability
pointwise_logdensities(model, chain)   # log densities for each tilde-statement
```


The [online documentation](https://pysm.dev/FlexiChains.jl) contains much more detail about FlexiChains and its interface.
Please do check it out!
