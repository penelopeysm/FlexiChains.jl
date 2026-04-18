# Plotting overview

FlexiChains contains some support for visualising chains with Plots.jl and Makie.jl.

## Available functions

Here is a rough overview of the current status:

| Type of plot                     | Plots.jl                              | Makie.jl                                                |
| :------------------------------- | :------------------------------------ | :------------------------------------------------------ |
| Trace + mixed density (default)  | ✅ [`Plots.plot`](@ref plot)          | ✅ [`Makie.plot`](@ref)                                 |
| Pair / corner plots              | 🐌                                    | ✅ [`PairPlots.pairplot`](@ref integrations-pairplots)  |
| Trace plots                      | ✅ [`FlexiChains.traceplot`](@ref)    | ✅ [`FlexiChains.mtraceplot`](@ref)                     |
| Density plots                    | ✅ `Plots.density`                    | ✅ [`Makie.density`](@ref)                              |
| Histograms                       | ✅ `Plots.histogram`                  | ✅ [`Makie.hist`](@ref) and [`Makie.stephist`](@ref)    |
| Mixed density plots              | ✅ [`FlexiChains.mixeddensity`](@ref) | ✅ [`FlexiChains.mmixeddensity`](@ref)                  |
| Running mean plots               | ✅ [`FlexiChains.meanplot`](@ref)     | 🐌                                                      |
| Autocorrelation plots            | ✅ [`FlexiChains.autocorplot`](@ref)  | 🐌                                                      |
| Rank plots                       | ✅ [`FlexiChains.rankplot`](@ref)     | ✅ [`FlexiChains.mrankplot`](@ref)                      |
| Violin plots                     | 🐌                                    | 🐌                                                      |
| Energy plots                     | 🐌                                    | 🐌                                                      |
| Forest plots                     | 🐌                                    | 🐌                                                      |
| Predictive check plots           | 🐌                                    | 🐌                                                      |

All of the above functions have 'mutating' versions with a `!` suffix.

Notice that for the functions provided by FlexiChains, the corresponding Makie.jl version is prefixed with `m`.
This is necessary for disambiguation, much like how `Plots.plot()` and `Makie.plot()` are different functions.

## Compositionality

In general, the plotting interfaces in FlexiChains try to stay as close as possible to the way the original plotting libraries work.
That means that you should be able to construct your own plots, insert a FlexiChains plot into a larger figure, and so on, using the interface provided by the original plotting library.

For example, with Plots.jl you can do things like this:

```julia
chn = ...
# These functions provided / extended by FlexiChains
p1 = FlexiChains.traceplot(chn, param1)
p2 = Plots.density(chn, param2)
# This is some completely external Plots.jl plot
p3 = Plots.plot(randn(10, 10))
# Compose them with Plots.jl
plot([p1, p2, p3], layout=(3, 1))
```

and with Makie, a workflow like this should also work:

```julia
chn = ...
# Set up a Makie figure
f = Makie.Figure()
# These functions provided / extended by FlexiChains
FlexiChains.mtraceplot!(f[1, 1], chn, param1)
Makie.density!(f[1, 2], chn, param2)
# This is some completely external Makie.jl plot
Makie.plot!(f[1, 3], randn(10, 10))
# Show the figure
f
```

However, I'm not the most experienced user of either Plots.jl or Makie.jl, so some inconsistencies will no doubt exist.
This may especially be so with Makie.jl because it is quite a bit more difficult to write extensions for Makie than it is for Plots (which has a very powerful recipe system).

Please do feel free to open issues or pull requests to improve the plotting functionality!
