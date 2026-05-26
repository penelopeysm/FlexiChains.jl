# [Plotting overview](@id plotting)

FlexiChains contains some support for visualising chains with Plots.jl and Makie.jl.

## Available functions

Here is a rough overview of the current status:

| Type of plot                     | Plots.jl                                    | Makie.jl                                                |
| :------------------------------- | :------------------------------------       | :------------------------------------------------------ |
| Trace + mixed density (default)  | ✅ [`Plots.plot`](@ref)                     | ✅ [`Makie.plot`](@ref)                                 |
| Trace plots                      | ✅ [`FlexiChains.Plots.traceplot`](@ref)    | ✅ [`FlexiChains.Makie.traceplot`](@ref)                |
| Density plots                    | ✅ [`Plots.density`](@ref)                  | ✅ [`Makie.density`](@ref)                              |
| Histograms                       | ✅ [`Plots.histogram`](@ref)                | ✅ [`Makie.hist`](@ref) and [`Makie.stephist`](@ref)    |
| Mixed density plots              | ✅ [`FlexiChains.Plots.mixeddensity`](@ref) | ✅ [`FlexiChains.Makie.mixeddensity`](@ref)             |
| Running mean plots               | ✅ [`FlexiChains.Plots.meanplot`](@ref)     | ✅ [`FlexiChains.Makie.meanplot`](@ref)                 |
| Autocorrelation plots            | ✅ [`FlexiChains.Plots.autocorplot`](@ref)  | ✅ [`FlexiChains.Makie.autocorplot`](@ref)              |
| Rank plots                       | ✅ [`FlexiChains.Plots.rankplot`](@ref)     | ✅ [`FlexiChains.Makie.rankplot`](@ref)                 |
| Corner plots                     | ✅ [`StatsPlots.cornerplot`](@ref)          | ✅ [`PairPlots.pairplot`](@ref)                         |
| Violin plots                     | ✅ [`StatsPlots.violin`](@ref)              | 🐌                                                      |
| Energy plots                     | 🐌                                          | 🐌                                                      |
| Forest plots                     | 🐌                                          | 🐌                                                      |
| Predictive check plots           | 🐌                                          | 🐌                                                      |

All of the above functions have 'mutating' versions with a `!` suffix.

Notice that FlexiChains provides separate functions for Plots.jl and Makie.jl backends, which are namespaced within the `FlexiChains.Plots` and `FlexiChains.Makie` modules, respectively.
This is necessary for disambiguation, much like how `Plots.plot()` and `Makie.plot()` are different functions.

## Compositionality

In general, the plotting interfaces in FlexiChains try to stay as close as possible to the way the original plotting libraries work.
That means that you should be able to construct your own plots, insert a FlexiChains plot into a larger figure, and so on, using the interface provided by the original plotting library.

For example, with Plots.jl you can do things like this:

```julia
chn = ...
# These functions provided / extended by FlexiChains
p1 = FlexiChains.Plots.traceplot(chn, param1)
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
FlexiChains.Makie.traceplot!(f[1, 1], chn, param1)
Makie.density!(f[1, 2], chn, param2)
# This is some completely external Makie.jl plot
Makie.plot!(f[1, 3], randn(10, 10))
# Show the figure
f
```

However, I'm not the most experienced user of either Plots.jl or Makie.jl, so some inconsistencies will no doubt exist.
This may especially be so with Makie.jl because it is quite a bit more difficult to write extensions for Makie than it is for Plots (which has a very powerful recipe system).

Please do feel free to open issues or pull requests to improve the plotting functionality!
