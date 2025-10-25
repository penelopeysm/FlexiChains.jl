const default_ci = [0.95, 0.90]

"""
    forestplot(chains)
    forestplot(chains, parameters)
    forestplot(vector_of_vectors)

Plots a summary of the samples in `chains` for each parameter by showing a `point_summary` and the central interval containing a specified `coverage`.

When passing a `vector_of_vectors`, each vector should contain the samples from all chains for one parameter.

Specific attributes to `forestplot` are:
- `ci = $default_ci`: The central intervals used to summarize the samples for each parameter.
- `point_summary = :median`: The function used to calculate the point summary; must return a single number.
- `min_width = 4`: The width of the lines showing the widest interval.
- `max_width = 8`: The width of the lines showing the narrowest interval.

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
forestplot(chains)
```
"""
@recipe(ForestPlot) do scene
    Attributes(;
        ci=default_ci,
        colormap=:viridis, # TODO allow passing a custom colormap and not just a symbol
        point_summary=median,
        min_width=4,
        max_width=8,
    )
end

# Convert a central interval to two-sided quantile boundaries
ci_to_quantiles(x) = 1 - (1 - x) / 2, (1 - x) / 2

# Wrapper for `get_colors` which reserves the last color for `point_summary`
forest_colors(n; kwargs...) = first(get_colors(n + 1; threshold=0, kwargs...), n)

function Makie.plot!(fp::ForestPlot{<:Tuple{<:AbstractVector{<:AbstractVector}}})
    samples = fp[1]
    r_samples = reverse(samples[]) # FIXME interactivity

    for ci in fp.ci[]
        0 < ci < 1 || error("Coverage must be between 0 and 1, got $ci.")
    end

    sorted_qs = map(ci_to_quantiles, sort(fp.ci[]; rev=true))

    qs = [[quantile.(Ref(s_i), qs_i) for s_i in r_samples] for qs_i in sorted_qs]

    colors = forest_colors(length(fp.ci[]); colormap=fp.colormap[])

    linewidths = range(fp.min_width[], fp.max_width[]; length=length(colors))

    for (q, color, linewidth) in zip(qs, colors, linewidths)
        lower = sdim(1)(q)
        upper = sdim(2)(q)
        for (i, xmin, xmax) in zip(eachindex(r_samples), lower, upper)
            lines!(fp, [xmin, xmax], fill(i, 2); color, linewidth)
        end
    end

    points = fp.point_summary[].(r_samples)
    if !(points isa Vector{<:Real})
        throw(error("Calling `point_summary` on a Vector must return a Float64."))
    end

    scatter!(
        fp,
        points,
        eachindex(r_samples);
        marker=:diamond,
        markersize=18,
        color=last(to_colormap(fp.colormap[])),
        strokecolor=:black,
        strokewidth=1.5,
    )

    return fp
end

function forestplot(
    chains::Chains,
    parameters;
    figure=nothing,
    ci=default_ci,
    colormap=:viridis,
    point_summary=median,
    min_width=4,
    max_width=8,
    legend_position=:bottom,
)
    samples = [vec(chains[:, parameter, :]) for parameter in parameters]

    if !(figure isa Figure)
        figure = Figure()
    end

    ax = Axis(figure[1, 1])
    ax.yticks = (eachindex(parameters), reverse(string.(parameters)))
    ax.xlabel = "Parameter estimate"
    forestplot!(samples; ci, point_summary, min_width, max_width, colormap)

    labels = @. string(round(Int, ci * 100)) * "%"
    colors = forest_colors(length(labels); colormap)
    elems = [PolyElement(; color) for color in colors]

    if legend_position == :bottom
        Legend(figure[1, 2], elems, labels, "Quantiles"; tellheight=false)
    elseif legend_position == :right
        Legend(figure[2, 1], elems, labels, "Quantiles"; tellheight=false)
    else
        error("Unsupported legend position: $legend_position, pick `:right` or `:bottom`.")
    end

    return figure
end

forestplot(chains::Chains; kwargs...) = forestplot(chains, names(chains); kwargs...)
