"""
    traceplot(chains)
    traceplot(chains, parameters)
    traceplot(matrix)

Plots the sampled values per iteration for each chain and parameter or for an iteration × chains matrix.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
traceplot(chains)
```
"""
@recipe(TracePlot) do scene
    Attributes(
        color = :default,
        colormap = :default,
        linewidth = 1.5,
        alpha = 0.8
    )
end

function Makie.plot!(tp::TracePlot{<:Tuple{<:AbstractMatrix}})
    mat = tp[1]
    xs = lift(m -> 1:size(m, 1), mat)
    color = get_colors(size(mat[], 2); color = tp.color[], colormap = tp.colormap[])

    for (i, ys) in enumerate(eachcol(to_value(mat))) # FIXME interactivity?
        lines!(tp, xs, ys; linewidth = tp.linewidth, color = (color[i], tp.alpha[]))
    end
    
    return tp
end

function traceplot(chains::Chains, parameters; figure = nothing, color = :default,
    colormap = :default, linewidth = 1.5, alpha = 0.8)

    if !(figure isa Figure)
        figure = Figure(size = autosize(chains[:, parameters, :]))
    end

    for (i, parameter) in enumerate(parameters)
        ax = Axis(figure[i, 1], ylabel = string(parameter))
        
        traceplot!(chains[:, parameter, :]; color, colormap, linewidth, alpha)
        
        hideydecorations!(ax; label=false)
        if i < length(parameters)
            hidexdecorations!(ax; grid=false)
        else
            ax.xlabel = "Iteration"
        end    
    end

    colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
    chainslegend(figure, chains[:, parameters, :], colors)
    
    return figure
end

traceplot(chains::Chains; kwargs...) = traceplot(chains, names(chains); kwargs...)
