# Pretty-printing.
function Base.show(
    io::IO, ::MIME"text/plain", chain::FlexiChain{TKey,niters,nchains}
) where {TKey,niters,nchains}
    printstyled(io, "FlexiChain ($niters iterations, $nchains chain$(nchains > 1 ? "s" : ""))\n\n"; bold=true)

    # Print parameter names
    parameter_names = get_parameter_names(chain)
    printstyled(io, "Parameter type   "; bold=true)
    println(io, "$TKey")
    printstyled(io, "Parameters       "; bold=true)
    if isempty(parameter_names)
        println(io, "(none)")
    else
        println(io, join(parameter_names, ", "))
    end

    # Print other keys
    other_key_names = get_other_key_names(chain)
    printstyled(io, "Other keys       "; bold=true)
    if isempty(other_key_names)
        println(io, "(none)")
    else
        print_space = false
        for (section, keys) in pairs(other_key_names)
            print_space && print(io, "\n                 ")
            print(io, "{:$section} ", join(keys, ", "))
            print_space = true
        end
    end

    # TODO: Summary statistics?

    return nothing
end
