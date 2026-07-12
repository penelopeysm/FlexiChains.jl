# Plotting: AlgebraOfGraphics.jl

FlexiChains does not provide any direct functionality to work with AlgebraOfGraphics.jl.
However, it is easy to convert a `FlexiChain` to an intermediate `DataFrame` and then feed that into AlgebraOfGraphics.jl for plotting.
This page provides a handful of examples.

We begin by sampling our familiar eight-schools model.

```@example aog
using FlexiChains, Turing

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
chain = sample(model, NUTS(), MCMCSerial(), 100, 3; progress=false)
```

Because AoG mainly works with long-form data, we need to specify this when converting the `FlexiChain` to a `DataFrame`.
We also subset the chain to only include the `theta` parameters.

```@example aog
using FlexiChains: Long
using DataFrames

df = DataFrame(Long(chain[[@varname(theta)]]))
```

When faceting by parameter, it is necessary to specify the `presorted` function, because `VarName`s do not have a natural ordering.
The `presorted` function makes sure that the facets retain the order in the chain.

```@example aog
using AlgebraOfGraphics, CairoMakie

m = mapping(:value, layout=:param => presorted)
v = AlgebraOfGraphics.density()

draw(df * m * v)
```

To avoid pooling all chains into a single plot, we can also split the chains into separate colours:

```@example aog
m = mapping(:value, layout=:param => presorted, color=:chain => nonnumeric)
v = visual(Density; alpha=0.4)
draw(df * m * v)
```

And here is a violin plot:

```@example aog
m = mapping(:param => presorted, :value)
v = visual(Violin; orientation=:horizontal)
draw(df * m * v)
```
