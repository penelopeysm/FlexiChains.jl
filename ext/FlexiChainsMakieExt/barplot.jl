"""
    chainsbarplot(matrix)

Plots a barplot of the distribution of parameter samples given an integer-valued iteration × chain matrix.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
samples = reshape(repeat(1:4, 300 ÷ 4 * 3 * 3), (300, 3, 3))
chains = Chains(samples, [:A, :B, :C])
chainsbarplot(chains[:, :B, :])
```
"""
@recipe(ChainsBarPlot) do scene
    Attributes(
        color = :default,
        colormap = :default,
        bins = 15,
    )
end

function Makie.plot!(bp::ChainsBarPlot{<:Tuple{<:AbstractMatrix}})
    mat = bp[1]
    color = get_colors(size(mat[], 2); color = bp.color[], colormap = bp.colormap[])

    all(isinteger, mat[]) || error("Use `hist` for continuous parameters.")
    
    for (i, ys) in enumerate(eachcol(to_value(mat)))
        count_dict = countmap(ys)
        xs = collect(keys(count_dict))
        ys = collect(values(count_dict))
        barplot!(bp, xs, ys; color = color[i])
    end
    
    return bp
end

# Type piracy, I own neither `barplot` nor `Chains`?
"""
    barplot(chains)
    barplot(chains, parameters)

Plots integer-valued samples for each chain and parameter in `chains`.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
samples = reshape(repeat(1:4, 300 ÷ 4 * 3 * 3), (300, 3, 3))
chains = Chains(samples, [:A, :B, :C])
barplot(chains)
```
"""
function Makie.barplot(chains::Chains, parameters; figure = nothing, color = :default,
    colormap = :default, bins = 15)
    
    if !(figure isa Figure)
        figure = Figure(size = autosize(chains[:, parameters, :]))
    end

    for (i, parameter) in enumerate(parameters)
        ax = Axis(figure[i, 1])
        
        hideydecorations!(ax; label=false)
        if i < length(parameters)
            hidexdecorations!(ax; grid=false)
        else
            ax.xlabel = "Parameter estimate"
        end

        chainsbarplot!(chains[:, parameter, :]; color, colormap, bins)
    end

    colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
    chainslegend(figure, chains[:, parameters, :], colors)

    return figure
end

Makie.barplot(chains::Chains; kwargs...) = barplot(chains, names(chains); kwargs...)
