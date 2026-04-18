# Plotting: Makie.jl

Plotting functionality with Makie.jl is currently in a very early stage of development, so there are fewer plots.
However, there is some custom code to generate (e.g.) shared legends, which leads to perhaps slightly nicer plots than for Plots.jl.
Many parts of the Makie integration in FlexiChains are heavily lifted from [the (unreleased) ChainsMakie.jl package](https://simonsteiger.github.io/ChainsMakie.jl/dev/).

!!! note
    You can also use Makie as a backend to make pair plots! This requires loading a Makie
    backend as well as PairPlots.jl. Please see the [PairPlots.jl integration section](@ref
    integrations-pairplots) for more details.

## [General interface](@id makie-interface)

For all functions `plotfunc` shown in the table of [the plotting page](./plotting.md), you can use the following invocation:

1. Generate an entire `Makie.Figure`. This automatically generates a complete plot for you, including a legend.

   ```julia
   plotfunc(
       chn[, param_or_params];
       figure=(;), axis=(;), legend=(;),
       legend_position=:bottom,
       kwargs...
   )
   ```

   `param_or_params` can be anything used to index into a chain (single parameters are also accepted).
   If not specified, all parameters in the chain will be plotted.

   Most keyword arguments are passed to the underlying Makie plotting functions, but there are some special ones which are handled by FlexiChains.
   For more information about these, see the [customisation section below](@ref makie-customisation).

For functions which create only a single plot per parameter (e.g. `density`, or `mtraceplot`), the following options are also available.
The intention is to allow you to build more complex figures using these as building blocks:

2. Plot a single parameter onto an existing `Makie.Axis` object: this uses the 'mutating' version with an exclamation mark.

   If `ax` is not specified, uses the current axis. Colours are handled the same way as above. `param` must be a single parameter.

   ```julia
   plotfunc!([ax, ]chn, param; kwargs...)
   ```

3. Plot a single parameter onto a Makie grid position. This constructs a `Makie.Axis` for you, and as before you can pass options via the `axis` keyword argument. Colours are handled the same way as above. `param` must be a single parameter.

   ```julia
   f = Figure()
   gp = f[1, 1]
   plotfunc!(gp, chn, param; axis=(;), kwargs...)
   ```

## Setup

Here, we create a model with different types of parameters (continuous, discrete, and vector-valued).
This is the same model as used on the Plots.jl documentation page.

```@example 1
using FlexiChains, CairoMakie, Turing

@model function f()
    x ~ Normal()
    y ~ Poisson(3)
    z ~ MvNormal(zeros(2), I)
end

chn = sample(
    f(), MH(), MCMCThreads(), 1000, 3;
    discard_initial=100, chain_type=VNChain, progress=false
)
```

## Default plot

Calling `Makie.plot(chn)` produces a trace plot and mixed density side-by-side for each parameter.

```@docs
Makie.plot
```

```@example 1
Makie.plot(chn)
Makie.save("plot_makie.png", ans.figure); # hide
```

![Default trace and density plots of the sampled chain](plot_makie.png)

## Trace plots

```@docs
FlexiChains.mtraceplot
```

```@example 1
FlexiChains.mtraceplot(chn)
Makie.save("traceplot_makie.png", ans.figure); # hide
```

![Trace plots of the sampled chain](traceplot_makie.png)

## Density plots

```@docs
Makie.density
```

```@example 1
Makie.density(chn)
Makie.save("density_makie.png", ans.figure); # hide
```

![Density plots of the sampled chain](density_makie.png)

## Histograms

```@docs
Makie.hist
Makie.stephist
```

```@example 1
Makie.hist(chn)
Makie.save("hist_makie.png", ans.figure); # hide
```

![Histograms of the sampled chain](hist_makie.png)

## Mixed density plots

```@docs
FlexiChains.mmixeddensity
```

```@example 1
FlexiChains.mmixeddensity(chn)
Makie.save("mixeddensity_makie.png", ans.figure); # hide
```

![Mixed density plots of the sampled chain](mixeddensity_makie.png)

## Rank plots

```@docs
FlexiChains.mrankplot
```

```@example 1
FlexiChains.mrankplot(chn)
Makie.save("rankplot_makie.png", ans.figure); # hide
```

![Rank plots of the sampled chain](rankplot_makie.png)

## [Customisation](@id makie-customisation)

As described in the [general interface section above](@ref makie-interface), all of the above functions accept keyword arguments to control the appearance of the plot.

The `figure`, `axis`, and `legend` arguments (which can be, e.g., `NamedTuple`s) allow you to pass extra keyword arguments to the `Figure`, `Axis`, and `Legend` constructors.
Then, most other keyword arguments are forwarded to the underlying Makie plotting functions; please refer to the Makie documentation for more details on these.

Finally, there are also some special keyword arguments which are handled by FlexiChains.
Here are some examples of these in action.

### Custom layout

By default, plots are arranged with one parameter per row.
You can pass a tuple of `(nrows, ncols)` as the `layout` keyword argument to change this:

```@example 1
Makie.density(chn; layout=(2, 2))
Makie.save("custom_layout_makie.png", ans.figure); # hide
```

![Density plots with a 2x2 layout](custom_layout_makie.png)

### Custom colours

Pass a vector of colours (one per chain) via the `color` keyword, or a categorical colormap via `colormap`:

```@example 1
FlexiChains.mtraceplot(chn, [@varname(x), @varname(y)];
    color=[(:red, 0.6), (:blue, 0.6), (:green, 0.6)],
    # or e.g. colormap=:tab10
)
Makie.save("custom_colors_makie.png", ans.figure); # hide
```

![Trace plots with custom colours](custom_colors_makie.png)

!!! note
    To get the best effects with `colormap`, you should pass a categorical colormap such as `:tab10`.
    Continuous colormaps like `:viridis` will give poor results since it will use the first `n` colours of the colormap, which are all very similar!

### Legend position

Use `legend_position` to move the legend (`:bottom`, `:right`, or `:none`):

```@example 1
FlexiChains.mtraceplot(chn; legend_position=:right)
Makie.save("custom_legend_makie.png", ans.figure); # hide
```

![Trace plots with the legend on the right](custom_legend_makie.png)
