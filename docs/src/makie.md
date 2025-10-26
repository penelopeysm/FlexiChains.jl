# Plotting: Makie.jl

Plotting functionality with Makie.jl is currently in a very early stage of development, so features are quite limited (for now).

## General interface

For each function `plotfunc` shown below, you can use the following invocations:

1. Generate an entire `Makie.Figure`. This automatically generates a complete plot for you, including a legend.

   There are special keyword arguments:

    - The `figure`, `axis`, and `legend` arguments (which can be, e.g., `NamedTuple`s) allow you to pass extra options to the `Figure`, `Axis`, and `Legend` constructors.

    - You can pass `legend_position` to specify where the legend should be placed (default is `:bottom`; `:right` is also supported, and `:none` disables the legend).

    - To control the colours used for separate chains, you can pass either (but not both) of the `color` or `colormap` keyword arguments. `color` can be anything usually passed to Makie; but you can also specify a vector of colours, one per chain. For `colormap`, it is expected that you will pass a categorical colormap such as `:tab10`. Continuous colormaps like `:viridis` will not give you the desired result since it will use the first `n` colours of the colormap, which are all very similar!

    - The layout of the plot is usually fixed to a single column. You can change this by passing a tuple of `(nrows, ncols)` as the `layout` keyword argument. This mimics Plots.jl's `layout` argument.

   Other keyword arguments (`kwargs...`) are passed to the plotting function used internally (e.g., `lines!`, `scatter!`, etc.).

   ```julia
   plotfunc(
       chn[, param_or_params];
       figure=(;), axis=(;), legend=(;),
       legend_position=:bottom,
       kwargs...
   )
   ```

2. Plot a single parameter onto an existing `Makie.Axis` object. If `ax` is not specified, uses the current axis.

   Colours are handled the same way as above.

   ```julia
   plotfunc!([ax, ]chn, param; kwargs...)
   ```

3. Plot a single parameter onto a Makie grid position. This constructs a `Makie.Axis` for you, and as before you can pass options via the `axis` keyword argument.

   Colours are handled the same way as above.

   ```julia
   f = Figure()
   gp = f[1, 1]
   plotfunc!(gp, chn, param; axis=(;), kwargs...)
   ```

When plotting multiple parameters (invocation (1)), `param_or_params` can be anything used to index into a chain (single parameters are also accepted).
If not specified, all parameters in the chain will be plotted.

When plotting single parameters, `param` must be a single parameter.

## Gallery

Here, we create a model with different types of parameters (continuous, discrete, and vector-valued).

This is the same model as used on the Plots.jl documentation page, so we will not repeat the explanations.

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

Plot density estimates of all parameters:

```@example 1
Makie.density(chn; layout=(2, 2), alpha=0.7)
```

Trace plots (with a rather ugly colour scheme):

```@example 1
FlexiChains.mtraceplot(chn; layout=(2, 2), colors=[(:red, 0.6), (:blue, 0.6), (:green, 0.6)])
```

## Docstrings

Under construction.
