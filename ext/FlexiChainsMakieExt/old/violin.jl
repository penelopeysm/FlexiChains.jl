function Makie.convert_arguments(::Type{<:Violin}, m::MCMCChains.AxisMatrix)
    xs = repeat(axes(m, 2); inner=size(m, 1))
    ys = vec(m)
    return (xs, ys)
end

# Type piracy because ChainsMakie owns neither violin nor Chains
"""
    violin(chains)
    violin(chains, parameters)

Plots a violin plot of the distribution of samples for each of the `parameter` in `chains`.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie
import MCMCChains: Chains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
violin(chains)
```
"""
function Makie.violin(chains::Chains, parameters; kwargs...)
    fig = Figure(; size=autosize(chains[:, parameters, :]))
    violin!(chains, parameters; kwargs...)
    return fig
end

# TODO this currently does not work with the way colors are passed
# to all the other functions in ChainsMakie
# so there will be integration problems with `plot(chains, funs...)` (once that happens)
# The rest require a color vector which has length == size(chains, 1)
# Here it is size(chains, 1) * size(chains, 2)
function Makie.violin!(chains::Chains, parameters; color=:default, link_x=false, kwargs...)
    fig = current_figure()

    for (i, parameter) in enumerate(parameters)
        ax = Axis(fig[i, 1]; ylabel=string(parameter))
        ax2 = Axis(fig[i, 1]; ylabel="Parameter estimate", yaxisposition=:right)

        if color == :default
            color = get_colors(size(chains, 3); color)
        end

        color_per_value = repeat(first(color, size(chains, 3)); inner=size(chains, 1))

        plt = violin!(chains[:, parameter, :]; color=color_per_value, kwargs...)

        hideydecorations!(ax; label=false)
        hidexdecorations!(ax)

        orientation = to_value(Attributes(plt)[:orientation])

        if orientation == :horizontal
            ax2.ylabel = "Chain"
            hideydecorations!(ax2; label=false, ticklabels=false, ticks=false)

            if length(parameters) == i
                ax2.xlabel = "Parameter estimate"
                continue
            end

            if link_x
                [hidexdecorations!(a; grid=false) for a in [ax, ax2]]
            else
                hidexdecorations!(ax; grid=false, ticklabels=false, ticks=false)
            end

            continue
        end

        if length(parameters) == i
            hidexdecorations!(ax2; label=false, ticklabels=false, ticks=false)
            ax2.xlabel = "Chain"
        else
            hidexdecorations!(ax2)
        end
    end

    if link_x
        axes = [last(contents(fig[i, 1])) for i in eachindex(parameters)]
        linkxaxes!(axes...)
    end

    return fig
end

Makie.violin(chains::Chains; kwargs...) = violin(chains, names(chains); kwargs...)
Makie.violin!(chains::Chains; kwargs...) = violin!(chains, names(chains); kwargs...)
