module FlexiChainsMCMCChainsExt

using FlexiChains: FlexiChains, FlexiChain, VarName, AbstractPPL
using MCMCChains: MCMCChains
using OrderedCollections: OrderedDict, OrderedSet

############################
# Conversion to MCMCChains #
############################

function MCMCChains.Chains(vnchain::FlexiChain{<:VarName,NIter,NChain}) where {NIter,NChain}
    array_of_dicts = [
        FlexiChains.get_parameter_dict_from_iter(vnchain, i, j) for i in 1:NIter,
        j in 1:NChain
    ]
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
        get(split_dicts[i, j], key, missing) for i in 1:NIter, key in varnames,
        j in 1:NChain
    ]
    varname_symbols = map(Symbol, varnames)

    # Handle non-parameter keys
    internal_keys = Symbol[]
    internal_values = Array{Real,3}(undef, NIter, 0, NChain)
    name_map = Dict{Symbol,Vector{Symbol}}()
    for k in FlexiChains.get_other_key_names(vnchain)
        v = map(identity, vnchain[k])
        if eltype(v) <: Real
            push!(internal_keys, Symbol(k.key_name))
            if haskey(name_map, k.section_name)
                push!(name_map[k.section_name], Symbol(k.key_name))
            else
                name_map[k.section_name] = [Symbol(k.key_name)]
            end
            internal_values = hcat(internal_values, reshape(v, NIter, 1, NChain))
        else
            @warn "key $k skipped in MCMCChains conversion as it is not Real-valued"
        end
    end

    all_symbols = vcat(varname_symbols, internal_keys)
    all_values = hcat(values, internal_values)

    info = (varname_to_symbol=OrderedDict(zip(varnames, varname_symbols)),)
    return MCMCChains.Chains(all_values, all_symbols, NamedTuple(name_map); info=info)
end

end # module
