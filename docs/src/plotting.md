# Plotting

FlexiChains contains some support for visualising chains with Plots.jl and Makie.jl.

## Status

In general, the plotting interfaces in FlexiChains try to stay as close as possible to the way the original plotting libraries work.
That means that you should be able to construct your own plots, insert a FlexiChains plot into a larger figure, and so on, using the interface provided by the original plotting library.
However, I'm not the most experienced user of either Plots.jl or Makie.jl, so some inconsistencies may exist.
Please do feel free to open issues or pull requests to improve the plotting functionality!

Here is a rough overview of the current status:

| Type of plot                    | Plots.jl                   | Makie.jl                 |
| --------------                  | ----------                 | ----------               |
| Trace + mixed density (default) | `Plots.plot`               | `Makie.plot`             |
| Trace plots                     | `FlexiChains.traceplot`    | `FlexiChains.mtraceplot` |
| Density plots                   | `Plots.density`            | `Makie.density`          |
| Histograms                      | `Plots.histogram`          | not yet implemented      |
| Mixed density plots             | `FlexiChains.mixeddensity` | not yet implemented      |
| Running mean plots              | `FlexiChains.meanplot`     | not yet implemented      |
| Autocorrelation plots           | `FlexiChains.autocorplot`  | not yet implemented      |
| Corner plots                    | not yet implemented        | not yet implemented      |
| Violin plots                    | not yet implemented        | not yet implemented      |
| Energy plots                    | not yet implemented        | not yet implemented      |
| Forest plots                    | not yet implemented        | not yet implemented      |
| Predictive check plots          | not yet implemented        | not yet implemented      |

Notice that for the functions provided by FlexiChains, the corresponding Makie.jl version is prefixed with `m`.
This is necessary for disambiguation, much like how `Plots.plot()` and `Makie.plot()` are different functions.

Feature parity with MCMCChains.jl is not yet complete, but is planned for the near future.
