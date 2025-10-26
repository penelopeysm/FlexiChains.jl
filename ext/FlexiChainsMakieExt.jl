module FlexiChainsMakieExt

using FlexiChains: FlexiChains
using Makie
using Makie: ColorTypes

const FC = FlexiChains
const MakieGrids = Union{Makie.GridPosition,Makie.GridSubposition}

"""
Adds a legend to the given `fig` for the chains in `chn` using the provided `colors`.

`legend_position` specifies where to place the legend: either `:right`, `:bottom` or `:none`.
If `legend_position` is `:none`, no legend is added.

Keyword arguments are forwarded to `Makie.Legend`.

Returns the created `Makie.Legend`, or `nothing` if no legend was added.
"""
function maybe_add_legend(
    fig::Makie.Figure,
    chn::FC.FlexiChain,
    colors::AbstractVector,
    legend_position::Symbol;
    kwargs...,
)
    legend_position == :none && return nothing
    nrows, ncols = size(fig.layout)
    labels = map(string, FC.chain_indices(chn))
    elems = map(color -> Makie.PolyElement(; color=color), colors)
    l = if legend_position == :bottom
        colpos = ncols > 1 ? range(1, ncols) : 1
        Makie.Legend(
            fig[nrows + 1, colpos],
            elems,
            labels,
            "Chain";
            orientation=:horizontal,
            kwargs...,
        )
    elseif legend_position == :right
        rowpos = nrows > 1 ? range(1, nrows) : 1
        Makie.Legend(fig[rowpos, ncols + 1], elems, labels, "Chain"; kwargs...)
    else
        error(
            "unsupported value for `legend_position`: permitted values are `:right`, `:bottom` or `:none`",
        )
    end
    return l
end

"""
Determines the color keyword arguments for each chain based on the provided values for the
`color` and `colormap` arguments.

`kwargs` are all the keyword arguments that were passed into the plotting function (minus
things such as `pool_chains` which are pulled out at a higher level).

This returns a vector of NamedTuples, one for each chain, each containing the appropriate
keyword arguments for specifying the color of that chain.
"""
function determine_color_kwargs(nchains::Int, kwargs::NamedTuple)::Vector{NamedTuple}
    color = get(kwargs, :color, nothing)
    # TODO: Use this
    colormap = get(kwargs, :colormap, nothing)

    if (!isnothing(colormap) && !isnothing(color))
        error("cannot specify both `color` and `colormap` arguments")
    end

    color_kwargs = if isnothing(colormap)
        # No colormap, so we need to handle `color`.
        if isnothing(color)
            # Just stick to the default.
            fill((;), nchains)
        elseif color isa AbstractVector
            # Assume it's a manually specified vector of colours, e.g. `color=[:red, :blue,
            # :green]`
            length(color) < nchains && error(
                "not enough colors specified for each chain: got $(length(color)), need $nchains",
            )
            map(c -> (; color=c), color)
        else
            # Assume it's a single colour, e.g. `color=:purple`
            fill((; color=color), nchains)
        end
    else
        # Colormap was provided. We should probably assume it's categorical
        cm = Makie.to_colormap(colormap)
        map(i -> (; color=cm[i]), 1:nchains)
    end
    return color_kwargs
end

include("FlexiChainsMakieExt/density.jl")
include("FlexiChainsMakieExt/traceplot.jl")

end
