"""
    meanplot(chains)
    meanplot(chains, parameters)
    meanplot(matrix)

Plots the running average of the samples for each chain and parameter or for an iteration × chains matrix.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
meanplot(chains)
```
"""
@recipe(MeanPlot) do scene
    Attributes(
        color = :default,
        colormap = :default,
        linewidth = 1.5,
        alpha = 1.0,
    )
end

function Makie.plot!(mp::MeanPlot{<:Tuple{<:AbstractMatrix}})
    mat = mp[1]
    color = get_colors(size(mat[], 2); color = mp.color[], colormap = mp.colormap[])
    
    for (i, vals) in enumerate(eachcol(to_value(mat)))
        ys = MCMCChains.cummean(vals)
        lines!(mp, ys; color = (color[i], mp.alpha[]))
    end
    
    return mp
end

function meanplot(chains::Chains, parameters; figure = nothing, color = :default,
    colormap = :default, linewidth = 1.5, alpha = 1.0, legend_position = :bottom)

    if !(figure isa Figure)
        figure = Figure(size = autosize(chains[:, parameters, :]))
    end
    
    for (i, parameter) in enumerate(parameters)
        ax1 = Axis(figure[i, 1], ylabel = string(parameter))
        ax2 = Axis(figure[i, 1], ylabel = "Mean", yaxisposition = :right)

        meanplot!(chains[:, parameter, :]; color, colormap, linewidth, alpha)

        hideydecorations!(ax1; label=false)
        hidexdecorations!(ax1)
        if i < length(parameters)
            hidexdecorations!(ax2; grid=false)
        else
            ax2.xlabel = "Iteration"
        end
    end

    colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
    chainslegend(figure, chains[:, parameters, :], colors; legend_position)

    return figure
end

meanplot(chains::Chains; kwargs...) = meanplot(chains, names(chains); kwargs...)
