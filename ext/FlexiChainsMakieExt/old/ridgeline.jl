"""
    ridgeline(chains)
    ridgeline(chains, parameters)
    ridgeline(vector_of_vectors)

Plots the densities of the samples for each parameter in a single axis by stacking them vertically.

When passing a `vector_of_vectors`, each vector should contain the samples from all chains for one parameter.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
ridgeline(chains)
```
"""
@recipe(RidgeLine) do scene
    Attributes(;
        color=first(Makie.wong_colors()),
        strokewidth=1.0,
        strokecolor=first(Makie.wong_colors()),
        alpha=0.4,
    )
end

function Makie.plot!(rl::RidgeLine{<:Tuple{<:AbstractVector{<:AbstractVector}}})
    vectors = rl[1]
    for (i, vector) in enumerate(reverse(vectors[]))
        density!(
            rl,
            vector;
            offset=i / 2,
            color=(rl.color[], rl.alpha[]),
            strokecolor=rl.strokecolor[],
            strokewidth=rl.strokewidth,
        )
    end
    return rl
end

function ridgeline(
    chn::Chains,
    parameters;
    figure=nothing,
    color=first(Makie.wong_colors()),
    strokewidth=1,
    strokecolor=first(Makie.wong_colors()),
    alpha=0.4,
)
    samples = [vec(chn[:, parameter, :]) for parameter in parameters]

    if !(figure isa Figure)
        figure = Figure(; size=(400, min(150 * length(parameters), 2000)))
    end

    ax = Axis(figure[1, 1])
    ax.yticks = (eachindex(parameters) ./ 2, reverse(string.(parameters)))
    ax.xlabel = "Parameter estimate"
    ridgeline!(samples; color, strokewidth, strokecolor, alpha)

    return figure
end

ridgeline(chains::Chains; kwargs...) = ridgeline(chains, names(chains); kwargs...)
