# [PairPlots.jl](@id integrations-pairplots)

[Documentation for PairPlots.jl ↗](https://sefffal.github.io/PairPlots.jl/dev/)

FlexiChains provides two ways to interact with PairPlots.jl.

## `pairplot()`

Firstly, you can directly call `pairplot(chn[, param_or_params])` on a `FlexiChain`.
This is a convenience method which includes extra functionality for e.g. highlighting divergent transitions.

```@example pairplots
using DynamicPPL, Distributions, LinearAlgebra, FlexiChains

J = 8
y = [28, 8, -3, 7, -1, 1, 18, 12]
sigma = [15, 10, 16, 11, 9, 11, 10, 18]
@model function eightsch(J, y, sigma)
    mu ~ Normal(0, 5)
    tau ~ truncated(Cauchy(0, 5); lower=0)
    theta ~ MvNormal(fill(mu, J), tau^2 * I)
    for i in 1:J
        y[i] ~ Normal(theta[i], sigma[i])
    end
end
model = eightsch(J, y, sigma)

chn = FlexiChains._make_posterior_chain(model, 1000, 4)
```

When sampling with Turing's HMC or NUTS, the resulting chain will contain an `Extra(:numerical_error)` key, which is a Boolean indicating whether or not the transition was divergent.
Because in this docs page we aren't actually sampling with Turing.jl, the chain above doesn't have this, so we'll add it in ourselves.

The following says: 'transform each sample of `mu` into a random Boolean, and store it in the `Extra(:numerical_error)` key'.
(See the [Modifying data section](@ref modifying-values) for more details on `transform_values`.)

```@example pairplots
# Make approximately 5% of the samples 'divergent'.
chn = FlexiChains.transform_values(
    chn,
    @varname(mu) => (_ -> rand() < 0.05) => FlexiChains.Extra(:numerical_error),
)
```

Carrying on with our plotting:

```@example pairplots
# Limit the parameters being plotted for readability
vns = [@varname(tau), @varname(theta[1]), @varname(theta[2])]

using PairPlots, CairoMakie
pairplot(chn, vns; divergences=:numerical_error)
Makie.save("pairplot.png", ans); # hide
```

![Pair plot of the sampled chain](pairplot.png)

## Conversion to Series

For more low-level control, you can also convert a `FlexiChain` into a `PairPlots.Series`, so that you can combine it with other data or fixed values in custom plots.

```@example pairplots
# Just some random values.
expected_means = (tau=0.0, var"theta[1]"=2.5, var"theta[2]"=5.0)

pairplot(PairPlots.Series(chn[vns]), PairPlots.Truth(expected_means, label="True"))
```

Notice that `Series(chn)` will pool the samples in all four chains together.
If you want to plot each chain separately, split them up into separate `Series` objects:

```@example pairplots
pairplot(
    (
        PairPlots.Series(chn[vns, chain=i], label="Chain $i") for
        i in FlexiChains.chain_indices(chn)
    )...,
    PairPlots.Truth(expected_means, label="True"),
)
```

## Docstrings

```@docs
PairPlots.pairplot
PairPlots.Series
```
