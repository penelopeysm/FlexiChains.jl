module FlexiChainsMakieExt

import FlexiChains as FC
using Makie

function Makie.plot!(plot::Makie.Density{<:Tuple{<:FC.PlotUtils.FlexiChainDensity}})
    valid_attributes = Makie.shared_attributes(plot, Makie.Density)
    return density!(plot, valid_attributes, plot[1])
end

function Makie.convert_arguments(
    P::Type{<:Makie.Density}, fcd::FC.PlotUtils.FlexiChainDensity; kwargs...
)
    @show kwargs
    y = vec(FC._get_raw_data(fcd.chn, fcd.param))
    return Makie.convert_arguments(P, y; kwargs...)
end

function Makie.density(
    chn::FC.FlexiChain,
    param_or_params=FC.Parameter.(FC.parameters(chn));
    figure=nothing,
    kwargs...,
)
    keys_to_plot = FC.PlotUtils.get_keys_to_plot(chn, param_or_params)

    if !(figure isa Makie.Figure)
        figure = Makie.Figure(;
            size=(
                FC.PlotUtils.DEFAULT_WIDTH,
                FC.PlotUtils.DEFAULT_HEIGHT * length(keys_to_plot),
            ),
        )
    end

    for (i, k) in enumerate(keys_to_plot)
        Makie.density!(
            Makie.Axis(figure[i, 1]), FC.PlotUtils.FlexiChainDensity(chn, k); kwargs...
        )
        # islast = length(parameters) == i
        # setaxisdecorations!(ax, islast, "Parameter estimate", link_x)
    end

    return figure
end

# function Makie.density(
#     chains::FC.FlexiChain,
#     parameters;
#     figure=nothing,
#     color=:default,
#     colormap=:default,
#     strokewidth=1.0,
#     alpha=0.4,
#     link_x=false,
#     legend_position=:bottom,
# )
#     if !(figure isa Figure)
#         figure = Figure(; size=autosize(chains[:, parameters, :]))
#     end
#
#     for (i, parameter) in enumerate(parameters)
#         ax = Axis(figure[i, 1]; ylabel=string(parameter))
#         chainsdensity!(chains[:, parameter, :]; color, colormap, strokewidth, alpha)
#         islast = length(parameters) == i
#         setaxisdecorations!(ax, islast, "Parameter estimate", link_x)
#     end
#
#     colors = get_colors(size(chains[:, parameters, :], 3); color, colormap)
#     chainslegend(figure, chains[:, parameters, :], colors; legend_position)
#
#     return figure
# end

# include("FlexiChainsMakieExt/utils.jl")
# include("FlexiChainsMakieExt/density.jl")
# include("FlexiChainsMakieExt/barplot.jl")
# include("FlexiChainsMakieExt/hist.jl")
# include("FlexiChainsMakieExt/traceplot.jl")
# include("FlexiChainsMakieExt/trankplot.jl")
# include("FlexiChainsMakieExt/ridgeline.jl")
# include("FlexiChainsMakieExt/forestplot.jl")
# include("FlexiChainsMakieExt/autocorplot.jl")
# include("FlexiChainsMakieExt/meanplot.jl")
# include("FlexiChainsMakieExt/violin.jl")
# include("FlexiChainsMakieExt/plot.jl")

end
