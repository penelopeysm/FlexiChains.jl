# [PairPlots.jl](@id integrations-pairplots)

[Documentation for PairPlots.jl](https://sefffal.github.io/PairPlots.jl/dev/)

FlexiChains provides two ways to interact with PairPlots.jl.

Firstly, you can directly call `pairplot(chn[, param_or_params])` on a `FlexiChain`.
This is a convenience method which includes extra functionality for e.g. highlighting divergent transitions.

```@docs
PairPlots.pairplot
```

```@example pairplots
using PairPlots, FlexiChains, Turing, CairoMakie

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
chn = sample(
    model,
    NUTS(),
    MCMCSerial(),
    2000,
    4;
    chain_type=VNChain,
    progress=false,
    verbose=false,
)

# Limit the parameters being plotted for readability
vns = [@varname(tau), @varname(theta[1]), @varname(theta[2])]

# For Turing.jl HMC/NUTS chains, the Boolean indicating whether or not the
# transition was divergent is stored in the `:numerical_error` key. If you
# have a different sampler you just need to specify the appropriate key.
pairplot(chn, vns; divergences=:numerical_error)
Makie.save("pairplot.png", ans); # hide
```

![Pair plot of the sampled chain](pairplot.png)

For more low-level control, you can also convert a `FlexiChain` into a `PairPlots.Series`, so that you can combine it with other data or fixed values in custom plots.

```@docs
PairPlots.Series
```
