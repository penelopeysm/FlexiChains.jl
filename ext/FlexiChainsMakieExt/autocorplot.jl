"""
    autocorplot(chains)
    autocorplot(chains, parameters)
    autocorplot(matrix)

Plots the autocorrelations of the samples for each chain and parameter or for an iteration × chains matrix.

Specific attributes to `autocorplot` are:
- `lags = 0:20`: The lags at which autocorrelations should be calculated.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
autocorplot(chains)
```
"""
@recipe(AutocorPlot) do scene
    Attributes(
        color = :default,
        colormap = :default,
        lags = 0:20,
        linewidth = 1.5,
        alpha = 1.0,
    )
end

function Makie.plot!(ap::AutocorPlot{<:Tuple{<:AbstractMatrix}})
    mat = ap[1]
    color = get_colors(size(mat[], 2); color = ap.color[], colormap = ap.colormap[])

    autocormat = lift(mat, ap.lags) do mat, lags
        StatsBase.autocor(mat, lags)
    end

    for (i, ys) in enumerate(eachcol(autocormat[])) # FIXME interactivity?
        lines!(ap, ap.lags, ys; linewidth = ap.linewidth, color = (color[i], ap.alpha[]))
    end
    
    return ap
end

function autocorplot(chains::Chains, parameters; figure = nothing, color = :default,
    colormap = :default, lags = 0:20, linewidth = 1.5, alpha = 1.0, legend_position = :bottom)

    if !(figure isa Figure)
        figure = Figure(size = autosize(chains[:, parameters, :]))
    end

    for (i, parameter) in enumerate(parameters)
        ax1 = Axis(figure[i, 1], ylabel = string(parameter))
        ax2 = Axis(figure[i, 1], ylabel = "Autocorrelation", yaxisposition = :right)
        
        autocorplot!(chains[:, parameter, :]; lags, color, colormap, linewidth, alpha)
        
        hideydecorations!(ax1; label = false)
        hidexdecorations!(ax1)
        if i < length(parameters)
            hidexdecorations!(ax2; grid = false)
        else
            ax2.xlabel = "Lag"
        end    
    end

    colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
    chainslegend(figure, chains[:, parameters, :], colors; legend_position)
    
    return figure
end

autocorplot(chains::Chains; kwargs...) = autocorplot(chains, names(chains); kwargs...)
