sdim(i) = v -> map(x -> x[i], v)

function get_colors(n; color=:default, colormap=:default, threshold=7)
    all(!=(:default), [color, colormap]) &&
        error("Specify only one of `color` or `colormap`.")

    if colormap != :default
        cm = Makie.to_colormap(colormap)
        idx = round.(Int, collect(range(1, length(cm); length=n)))
        return cm[idx]
    end

    if n > threshold && color == :default
        cm =
            colormap == :default ? Makie.to_colormap(:viridis) : Makie.to_colormap(colormap)
        idx = round.(Int, collect(range(1, length(cm); length=n)))
        return cm[idx]
    end

    @show kwargs
    colors = first(color == :default ? Makie.wong_colors() : color, n)
    n > length(colors) && error("Specify at least as many colors as there are chains.")
    return colors
end

function get_colors_kwargs(chains, kwargs)
    if haskey(kwargs, :color) && haskey(kwargs, :colormap)
        error("Specify only one of `color` or `colormap`.")
    elseif haskey(kwargs, :color)
        return get_colors(size(chains, 3); color=kwargs[:color])
    elseif haskey(kwargs, :colormap)
        return get_colors(size(chains, 3); colormap=kwargs[:colormap])
    end
    return get_colors(size(chains, 3))
end

function chainslegend(fig, chains, colors; legend_position=:bottom, per_bank=5)
    nchains = size(chains, 3)
    nrows, ncols = size(fig.layout)
    banks = nbanks(chains; per_bank)

    elems = [PolyElement(; color) for color in colors]
    labels = string.(1:nchains)

    if legend_position == :bottom
        colpos = ncols > 1 ? range(1, ncols) : 1
        Legend(
            fig[nrows + 1, colpos],
            elems,
            labels,
            "Chain";
            orientation=:horizontal,
            nbanks=banks,
        )
    elseif legend_position == :right
        rowpos = nrows > 1 ? range(1, nrows) : 1
        Legend(fig[rowpos, ncols + 1], elems, labels, "Chain"; nbanks=banks)
    else
        error("Unsupported legend position: $legend_position, pick `:right` or `:bottom`.")
    end

    return nothing
end

function autosize(chains::Chains; ncols=1)
    axis_size = 200
    legend_size = 40 + nbanks(chains) * 20
    width = 200 + ncols * 200
    height = size(chains, 2) * axis_size + legend_size
    return (min(width, 1800), min(height, 8000))
end

nbanks(chains; per_bank=5)::Int64 = ceil(size(chains, 3) / per_bank)

# Set xlabel based on the function passed, this is for `plot(chains, f...)`
function _xlabel(f)
    f_string = map(s -> replace(s, "!" => ""), string.(f))

    label_dict = Dict(
        "chainsdensity" => "Parameter estimate",
        "chainshist" => "Parameter estimate",
        "traceplot" => "Iteration",
        "trankplot" => "Iteration",
        "meanplot" => "Iteration",
        "autocorplot" => "Lag",
    )

    out = String[]
    for f_i in f_string
        if haskey(label_dict, f_i)
            push!(out, label_dict[f_i])
            continue
        end
        error("Unsupported function $f_i for composite plot.")
    end

    return out
end

function setaxisdecorations!(ax, islast, xlabel, link_x)
    hideydecorations!(ax; label=false)

    if islast
        ax.xlabel = xlabel
        return nothing
    end

    if link_x
        hidexdecorations!(ax; grid=false)
    else
        hidexdecorations!(ax; grid=false, ticklabels=false, ticks=false)
    end
end
