# Avoid printing the entire `Sampled` object if it's been constructed
_show_range(s::DD.Dimensions.Lookups.Lookup) = _show_range(parent(s))
_show_range(s::AbstractRange) = string(s)
function _show_range(s::AbstractVector)
    if length(s) > 5
        return "[$(first(s)) … $(last(s))]"
    else
        return string(s)
    end
end
function _show_range(s::AbstractVector{<:Symbol})
    return "[" * join(string.(s), ", ") * "]"
end

function Base.show(io::IO, ::MIME"text/plain", chain::FlexiChain{TKey}) where {TKey}
    maybe_s(x) = x == 1 ? "" : "s"
    ni, nc = size(chain)
    printstyled(
        io, "FlexiChain ($ni iteration$(maybe_s(ni)), $nc chain$(maybe_s(nc)))\n"; bold=true
    )
    printstyled(
        io,
        "$(DD.dimsymbol(1)) iter=$(_show_range(FlexiChains.iter_indices(chain)))";
        color=DD.dimcolor(1),
    )
    print(io, " | ")
    printstyled(
        io,
        "$(DD.dimsymbol(2)) chain=$(_show_range(FlexiChains.chain_indices(chain)))";
        color=DD.dimcolor(2),
    )
    println(io, "\n")
    # Print parameter names
    parameter_names = parameters(chain)
    printstyled(io, "Parameter type   "; bold=true)
    println(io, "$TKey")
    printstyled(io, "Parameters       "; bold=true)
    if isempty(parameter_names)
        println(io, "(none)")
    else
        println(io, join(parameter_names, ", "))
    end

    # Print extras
    extra_names = extras(chain)
    printstyled(io, "Extra keys       "; bold=true)
    if isempty(extra_names)
        println(io, "(none)")
    else
        println(io, join(map(e -> repr(e.name), extra_names), ", "))
    end

    # TODO: Summary statistics?
    return nothing
end
