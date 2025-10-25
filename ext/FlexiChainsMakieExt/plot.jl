# TODO Improve how the supported functions are tracked, hard to maintain as is
# On the other hand unlikely that new functions will be added frequently

# TODO Is it possible to allow passing kwargs to `plot` and then forward them to the right
# function in the Vararg version of `plot`?
# Outside the scope of my abilities, but it's definitely a bonus feature either way
"""
    plot(chains)
    plot(chains, parameters)
    plot(chains, functions...)
    plot(chains, parameters, functions...)

Plots a multi-column summary of all parameters, showing traceplots and densities.

When also passing a vector of `parameters` as either strings or symbols, only those parameters will be visualized.

The kinds and number of summary plots can be fully customized by splatting several mutating `functions...`. Currently supported functions are:

- `autocorplot!`
- `chainsdensity!`
- `chainshist!`
- `meanplot!`
- `traceplot!`
- `trankplot!`

## Attributes
WIP

## Example

```julia
using CairoMakie, ChainsMakie, MCMCChains
chains = Chains(randn(300, 3, 3), [:A, :B, :C])
plot(chains)
```
"""
function Makie.plot(
    chains::Chains,
    parameters;
    figure=nothing,
    link_x=false,
    color=:default,
    colormap=:default,
    legend_position=:bottom,
)
    sub_chains = chains[:, parameters, :]

    _, nparams, nchains = size(sub_chains)

    if !(figure isa Figure)
        figure = Figure(; size=autosize(sub_chains; ncols=2))
    end

    for i in 1:(nparams * 2)
        coord = fldmod1(i, 2)
        param_idx = first(coord)

        mat = sub_chains[:, param_idx, :]
        ax = Axis(figure[coord...])
        if iszero(i % 2)
            all(isinteger, mat) ? chainsbarplot!(mat; color) : chainsdensity!(mat; color)
        else
            traceplot!(mat; color)
            ax.ylabel = string(parameters[param_idx])
        end

        hideydecorations!(ax; label=false)

        if param_idx == nparams
            ax.xlabel = iszero(i % 2) ? "Parameter estimate" : "Iteration"
            continue
        end

        if link_x
            hidexdecorations!(ax; grid=false)
        else
            hidexdecorations!(ax; grid=false, ticklabels=false, ticks=false)
        end
    end

    colors = get_colors(nchains; color, colormap)
    chainslegend(figure, sub_chains, colors; legend_position)

    if link_x
        axes = [only(contents(figure[i, 2])) for i in 1:nparams]
        linkxaxes!(axes...)
    end

    return figure
end

Makie.plot(chains::Chains; kwargs...) = plot(chains, names(chains); kwargs...)

function Makie.plot(
    chains::Chains,
    parameters,
    funs::Vararg{Function,N};
    figure=nothing,
    link_x=false,
    legend_position=:bottom,
    kwargs...,
) where {N}
    for f_i in string.(funs)
        endswith(f_i, "!") ||
            error("All functions must be mutating. Got `$(f_i)`, pass `$(f_i)!` instead.")
    end

    sub_chains = chains[:, parameters, :]

    _, nparams, nchains = size(sub_chains[:, parameters, :])

    xlabels = _xlabel(funs)

    if !(figure isa Figure)
        figure = Figure(; size=autosize(sub_chains[:, parameters, :]; ncols=N))
    end

    for i in 1:(nparams * N)
        coord = fldmod1(i, N)
        param_idx = first(coord)

        mat = sub_chains[:, param_idx, :]
        ax = Axis(figure[coord...])

        if i % N == 1
            ax.ylabel = string(parameters[param_idx])
        end
        hideydecorations!(ax; label=false)

        if param_idx < nparams
            if link_x
                hidexdecorations!(ax; grid=false)
            else
                hidexdecorations!(ax; grid=false, ticklabels=false, ticks=false)
            end
        end

        # TODO automatically switch to barplot for integer parameters
        if i % N == 0
            last(funs)(mat; kwargs...)
            ax.xlabel = last(xlabels) # Hidden if param_idx < nparams
            continue
        end

        for j in eachindex(funs)
            if i % N == j
                funs[j](mat; kwargs...)
                ax.xlabel = xlabels[j] # Hidden if param_idx < nparams
            end
        end
    end

    per_bank = N > 2 ? 8 : 5
    color = get_colors(nchains; kwargs...)
    chainslegend(figure, sub_chains, color; per_bank, legend_position)

    if link_x
        axes = [only(contents(figure[i, 2])) for i in 1:nparams]
        linkxaxes!(axes...)
    end

    return figure
end

function Makie.plot(chains::Chains, funs::Vararg{Function,N}; kwargs...) where {N}
    return Makie.plot(chains, names(chains), funs...; kwargs...)
end
