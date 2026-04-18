function _default_histogram_axis(k::FC.ParameterOrExtra)
    return (xlabel = "value", ylabel = "probability", title = string(k.name))
end

HIST_DOCSTRING = """
    Makie.hist(
        chn::FC.FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        kwargs...,
    )

Create a histogram for the specified parameters in the chain. If `param_or_params` is not
provided, plots all parameters in the chain.

$(MAKIE_KWARGS_DOCSTRING)
"""

STEPHIST_DOCSTRING = """
    Makie.stephist(
        chn::FC.FlexiChain[, param_or_params];
        pool_chains::Bool=false,
        kwargs...,
    )

Create a step histogram for the specified parameters in the chain. If`param_or_params` is
not provided, plots all parameters in the chain.

$(MAKIE_KWARGS_DOCSTRING)
"""

for f in (:hist, :stephist)
    f! = Symbol(f, '!')
    docstr = f === :hist ? HIST_DOCSTRING : STEPHIST_DOCSTRING

    expr = quote
        @doc $docstr
        function Makie.$f(
                chn::FC.FlexiChain,
                param_or_params = FC.Parameter.(FC.parameters(chn));
                pool_chains::Bool = false,
                layout::Union{Tuple{Int, Int}, Nothing} = nothing,
                legend_position::Symbol = :bottom,
                figure = (;),
                axis = (;),
                legend = (;),
                kwargs...,
            )
            chn = FC.PlotUtils.subset_and_split_chain(chn, param_or_params)
            keys_to_plot = keys(chn)
            isempty(keys_to_plot) && throw(ArgumentError("no parameters to plot"))
            nrows, ncols, figure = setup_figure_and_layout(length(keys_to_plot), 1, layout, figure)
            a, p = nothing, nothing
            # This order means that plots go from left to right before going to the next row
            indices = Iterators.product(1:ncols, 1:nrows)
            for ((col, row), k) in zip(indices, keys_to_plot)
                a, p = Makie.$f!(
                    Makie.Axis(figure[row, col]; _default_histogram_axis(k)..., axis...),
                    FC.PlotUtils.FlexiChainHistogram(chn, k, pool_chains);
                    kwargs...,
                )
            end
            if pool_chains
                # Extract the colors used in the last axis
                colors = map(p -> p.color[], a.scene.plots)
                maybe_add_legend(figure, chn, colors, legend_position; legend...)
            end
            return Makie.FigureAxisPlot(figure, a, p)
        end

        ########################
        # Single axis plotting #
        ########################
        function Makie.$f(grid::MakieGrids, chn::FC.FlexiChain, param; axis = (;), kwargs...)
            # TODO: Error if there is already something at the grid position?
            # See e.g. https://github.com/rafaqz/DimensionalData.jl/blob/6db30de4b2e1fc7f8611b7e1dc3f89dc02c78598/ext/DimensionalDataMakieExt.jl#L85-L96
            chn = FC.PlotUtils.subset_and_split_chain(chn, param)
            k = only(keys(chn))
            return Makie.$f!(
                Makie.Axis(grid; _default_histogram_axis(k)..., axis...),
                chn,
                param;
                kwargs...,
            )
        end
        function Makie.$f!(
                ax::Makie.Axis,
                chn::FC.FlexiChain,
                param;
                pool_chains::Bool = false,
                kwargs...,
            )
            chn = FC.PlotUtils.subset_and_split_chain(chn, param)
            k = only(keys(chn))
            a, p = Makie.$f!(
                ax, FC.PlotUtils.FlexiChainHistogram(chn, k, pool_chains); kwargs...
            )
            return Makie.AxisPlot(a, p)
        end
        function Makie.$f!(chn::FC.FlexiChain, param; kwargs...)
            return Makie.$f!(Makie.current_axis(), chn, param; kwargs...)
        end

        # For these two functions, they don't accept the `alpha` keyword argument. See
        # https://github.com/MakieOrg/Makie.jl/issues/3903.
        #
        # Ordinarily we could let this error just bubble up. However, the problem is that
        # `hist!` can be called via `mixeddensity!`, for which is it perfectly sensible to
        # specify `alpha`. So we need to explicitly handle it here.
        function Makie.$f!(
                ax::Makie.Axis,
                d::FC.PlotUtils.FlexiChainHistogram;
                alpha = nothing,
                kwargs...,
            )
            y = FC._get_raw_data(d.chn, d.param)
            FC.PlotUtils.check_eltype_is_real(y)
            p = nothing
            if d.pool_chains
                p = Makie.$f!(ax, vec(y); label = "pooled", kwargs...)
            else
                labels = permutedims(map(cidx -> "chain $cidx", FC.chain_indices(d.chn)))
                nchains = size(y, 2)
                color_kwargs = determine_color_kwargs(nchains, NamedTuple(kwargs))
                for (label, datacol, color_kwarg) in zip(labels, eachcol(y), color_kwargs)
                    p = Makie.$f!(
                        ax,
                        datacol;
                        normalization = :pdf,
                        label = label,
                        kwargs...,
                        color_kwarg...,
                    )
                end
            end
            return Makie.AxisPlot(ax, p)
        end
    end

    @eval $expr
end
