module FlexiChainsMCMCChainsExt

using FlexiChains: FlexiChains, FlexiChain, VarName, AbstractPPL
using MCMCChains: MCMCChains
using OrderedCollections: OrderedDict, OrderedSet

# Magic constants. Such is life when MCMCChains allows you to bundle arbitrary info into a
# NamedTuple. Refer to DynamicPPLMCMCChainsExt for where these get set
const MCStartTimeKey = :start_time
const MCStopTimeKey = :stop_time
const MCSamplerStateKey = :samplerstate

##############################
# Conversion from MCMCChains #
##############################

"""
    FlexiChain{Symbol}(chains::MCMCChains.Chains)

Convert an `MCMCChains.Chains` object to a `FlexiChain{Symbol}`.

Parameters in the `:parameters` section of the `Chains` are stored as `Parameter{Symbol}`
keys, while parameters in all other sections (e.g. `:internals`) are stored as `Extra` keys.

Iteration indices, chain indices, and per-chain sampling times are preserved where possible.
"""
function FlexiChains.FlexiChain{Symbol}(chains::MCMCChains.Chains)
    ni, _, nc = size(chains)
    iter_indices = Base.range(chains)
    chain_indices = MCMCChains.chains(chains) # bizarre function name, yeah

    data = OrderedDict{FlexiChains.ParameterOrExtra{Symbol}, Matrix}()

    # Parameters section
    param_names = if haskey(chains.name_map, :parameters)
        chains.name_map[:parameters]
    else
        Symbol[]
    end
    for name in param_names
        var_idx = findfirst(==(name), Base.names(chains))
        var_idx === nothing && continue
        data[FlexiChains.Parameter(name)] = chains.value.data[:, var_idx, :]
    end

    # All other sections become Extras.
    for section in keys(chains.name_map)
        section === :parameters && continue
        for name in chains.name_map[section]
            var_idx = findfirst(==(name), Base.names(chains))
            var_idx === nothing && continue
            data[FlexiChains.Extra(name)] = chains.value.data[:, var_idx, :]
        end
    end

    # Attempt to determine whether the chain was constructed with `sample(model, spl, N)` or
    # `sample(model, spl, MCMCThreads(), N, M)`. This affects whether the metadata is
    # recorded as scalars or vectors.
    has_vector_metadata = (
        # trivially true if there are multiple chains
        nc > 1 ||
            # attempt to infer from start/stop time
            (hasproperty(chains.info, MCStartTimeKey) && chains.info.start_time isa AbstractVector) ||
            (hasproperty(chains.info, MCStopTimeKey) && chains.info.stop_time isa AbstractVector)
    )

    sampling_time = if hasproperty(chains.info, MCStartTimeKey) &&
            hasproperty(chains.info, MCStopTimeKey)
        start_time = getfield(chains.info, MCStartTimeKey)
        stop_time = getfield(chains.info, MCStopTimeKey)
        starts = has_vector_metadata ? start_time : [start_time]
        stops = has_vector_metadata ? stop_time : [stop_time]
        Float64.(stops .- starts)
    else
        fill(missing, nc)
    end

    last_sampler_state = if hasproperty(chains.info, MCSamplerStateKey)
        st = getfield(chains.info, MCSamplerStateKey)
        has_vector_metadata ? st : [st]
    else
        fill(missing, nc)
    end

    return FlexiChains.FlexiChain{Symbol}(
        ni, nc, data;
        iter_indices = iter_indices,
        chain_indices = chain_indices,
        sampling_time = sampling_time,
        last_sampler_state = last_sampler_state,
    )
end

############################
# Conversion to MCMCChains #
############################

"""
    MCMCChains.Chains(chain::FlexiChain{<:VarName})

Convert a `FlexiChain{<:VarName}` to an `MCMCChains.Chains` object.

Array-valued VarNames are split up into their individual real-valued elements, much like the
output that you get directly from sampling with Turing + MCMCChains.
"""
function MCMCChains.Chains(vnchain::FlexiChain{<:VarName})
    ni, nc = size(vnchain)
    array_of_dicts = [
        FlexiChains.parameters_at(vnchain; iter = i, chain = j) for i in 1:ni, j in 1:nc
    ]
    # Construct array of parameter names and array of values.
    # Most of this functionality is copied from _params_to_array in
    # Turing's src/mcmc/Inference.jl.
    names_set = OrderedSet{VarName}()
    # Extract the parameter names and values from each transition.
    split_dicts = map(array_of_dicts) do d
        nms_and_vs = if isempty(d)
            Tuple{VarName, Any}[]
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
    internal_values = Array{Real, 3}(undef, ni, 0, nc)
    for k in FlexiChains.extras(vnchain)
        v = map(identity, vnchain[k])
        if eltype(v) <: Real
            push!(internal_keys, Symbol(k.name))
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

    info = (varname_to_symbol = OrderedDict(zip(varnames, varname_symbols)),)

    # Preserve sampling time as start_time/stop_time if available.
    # MCMCChains stores these as absolute timestamps. FlexiChains only stores durations, so
    # we use 0-based start times...
    st = FlexiChains.sampling_time(vnchain)
    if !all(ismissing, st)
        starts = zeros(Float64, nc)
        stops = Float64.(coalesce.(st, 0.0))
        info = merge(
            info, (;
                MCStartTimeKey => starts,
                MCStopTimeKey => stops,
            )
        )
    end

    # Preserve last sampler state if available.
    lss = FlexiChains.last_sampler_state(vnchain)
    if !all(ismissing, lss)
        info = merge(info, (; MCSamplerStateKey => collect(lss)))
    end

    # See comment above for the use of 'internals' as the only section.
    return MCMCChains.Chains(
        all_values,
        all_symbols,
        # Note that Turing.jl stores all other keys in the 'internals' section.
        (; internals = internal_keys);
        info = info,
        iterations = FlexiChains.iter_indices(vnchain),
    )
end

end # module
