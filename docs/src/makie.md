# Plotting: Makie.jl

Plotting functionality with Makie.jl is currently in a very early stage of development, so features are quite limited (for now).

## General interface

For each function `plotfunc` shown below, you can use the following invocations:

1. Generate an entire `Makie.Figure`. The `figure` and `axis` arguments (which can be, e.g., `NamedTuple`s) allow you to pass extra options to the `Figure` and `Axis` constructors.

   ```julia
   plotfunc(chn[, param_or_params]; figure=(;), axis=(;), kwargs...)
   ```

2. Plot a single parameter onto an existing `Makie.Axis` object. If `ax` is not specified, uses the current axis.

   ```julia
   plotfunc!([ax, ]chn, param; kwargs...)
   ```

3. Plot a single parameter onto a Makie grid position.

    ```julia
    f = Figure()
    gp = f[1, 1]
    plotfunc!(gp, chn, param; kwargs...)
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
Makie.density(chn)
```

## Docstrings

Under construction.
