module FlexiChainsMCMCChainsExt

using FlexiChains: FlexiChains, FlexiChain, VarName, AbstractPPL
using MCMCChains: MCMCChains
using OrderedCollections: OrderedDict, OrderedSet

############################
# Conversion to MCMCChains #
############################

"""
    MCMCChains.Chains(chain::FlexiChain{<:VarName})

Convert a `FlexiChain{<:VarName}` to an `MCMCChains.Chains` object.

Array-valued VarNames are split up into their individual real-valued elements, much like the
output that you get directly from sampling with Turing + MCMCChains.

!!! note "Splitting VarNames"

    If your only aim is to split VarNames, you can use [`FlexiChains.split_varnames`](@ref)
    instead. The conversion to MCMCChains is only useful if you specifically want to use
    functionality that is only available in MCMCChains.
"""
function MCMCChains.Chains(vnchain::FlexiChain{<:VarName})
    ni, nc = size(vnchain)
    array_of_dicts = [FlexiChains.parameters_at(vnchain, i, j) for i in 1:ni, j in 1:nc]
    # Construct array of parameter names and array of values.
    # Most of this functionality is copied from _params_to_array in
    # Turing's src/mcmc/Inference.jl.
    names_set = OrderedSet{VarName}()
    # Extract the parameter names and values from each transition.
    split_dicts = map(array_of_dicts) do d
        nms_and_vs = if isempty(d)
            Tuple{VarName,Any}[]
        else
            iters = map(AbstractPPL.varname_and_value_leaves, Base.keys(d), Base.values(d))
            mapreduce(collect, vcat, iters)
        end
        nms = map(first, nms_and_vs)
        vs = map(last, nms_and_vs)
        for nm in nms
            push!(names_set, nm)
        end
        # Convert the names and values to a single dictionary.
        return OrderedDict(zip(nms, vs))
    end
    varnames = collect(names_set)
    values = [
        get(split_dicts[i, j], key, missing) for i in 1:ni, key in varnames, j in 1:nc
    ]
    varname_symbols = map(Symbol, varnames)

    # Handle non-parameter keys
    internal_keys = Symbol[]
    internal_values = Array{Real,3}(undef, ni, 0, nc)
    for k in FlexiChains.extras(vnchain)
        v = map(identity, vnchain[k])
        if eltype(v) <: Real
            # special-case logjoint ...
            mcmcc_key = k.name == :logjoint ? :lp : Symbol(k.name)
            push!(internal_keys, mcmcc_key)
            internal_values = hcat(internal_values, reshape(v, ni, 1, nc))
        else
            @warn "key $k skipped in MCMCChains conversion as it is not Real-valued"
        end
    end

    all_symbols = vcat(varname_symbols, internal_keys)
    all_values = hcat(values, internal_values)
    # The following 'concretisation' (in reality, casting everything to Float64) is overly
    # aggressive. It's only included to match what Turing.jl does. See
    # https://github.com/TuringLang/Turing.jl/issues/2666 for details.
    all_values = MCMCChains.concretize(all_values)

    info = (varname_to_symbol=OrderedDict(zip(varnames, varname_symbols)),)
    # See comment above for the use of 'internals' as the only section.
    return MCMCChains.Chains(
        all_values,
        all_symbols,
        # Note that Turing.jl stores all other keys in the 'internals' section.
        (; internals=internal_keys);
        info=info,
        iterations=FlexiChains.iter_indices(vnchain),
    )
end

end # module
