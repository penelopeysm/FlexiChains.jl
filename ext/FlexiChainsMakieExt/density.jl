"""
    chainsdensity(matrix)

Plots the density of the samples for an iteration × chain `matrix`.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
chainsdensity(chains[:, :B, :])
```
"""
@recipe(ChainsDensity) do scene
    Attributes(; color=:default, colormap=:default, strokewidth=1.0, alpha=0.4)
end

function Makie.plot!(cd::ChainsDensity{<:Tuple{<:AbstractMatrix}})
    mat = cd[1]
    color = get_colors(size(mat[], 2); color=cd.color[], colormap=cd.colormap[])

    for (i, ys) in enumerate(eachcol(mat[]))
        density!(
            cd,
            ys;
            color=(color[i], cd.alpha[]),
            strokecolor=color[i],
            strokewidth=cd.strokewidth[],
        )
    end

    return cd
end

function Makie.density(
    chains::FC.FlexiChain,
    parameters;
    figure=nothing,
    color=:default,
    colormap=:default,
    strokewidth=1.0,
    alpha=0.4,
    link_x=false,
    legend_position=:bottom,
)
    @show parameters
    if !(figure isa Figure)
        figure = Figure(; size=autosize(chains[:, parameters, :]))
    end

    for (i, parameter) in enumerate(parameters)
        ax = Axis(figure[i, 1]; ylabel=string(parameter))
        chainsdensity!(chains[:, parameter, :]; color, colormap, strokewidth, alpha)
        islast = length(parameters) == i
        setaxisdecorations!(ax, islast, "Parameter estimate", link_x)
    end

    colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
    chainslegend(figure, chains[:, parameters, :], colors; legend_position)

    return figure
end

Makie.density(chains::Chains; kwargs...) = density(chains, names(chains); kwargs...)
