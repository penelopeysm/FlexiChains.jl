"""
    to_vnt_and_stats(transition)::Tuple{VarNamedTuple,NamedTuple}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler into a
`VarNamedTuple` mapping parameter names to their values, plus a `NamedTuple` of any
additional statistics.

The `VarNamedTuple` will be converted into `Parameter` keys, and the `NamedTuple` into
`Extra` keys.

If you are writing a custom AbstractMCMC sampler and want to allow users to collect the
samples as a `FlexiChain{VarName}`, i.e., 

    sample(...; chain_type=FlexiChain{VarName})

then you should ensure that your method of `AbstractMCMC.step` returns a transition that can
be passed to this method. (The other return value, the state, is not relevant.)

Note that this method is already implemented for `DynamicPPL.VarNamedTuple` (in which case
the stats are empty) as well as `DynamicPPL.ParamsWithStats`. Thus the easiest solution is
to just return one of those types.
"""
function to_vnt_and_stats end
# Note that `to_vnt_and_stats` has to be overloaded in DynamicPPLExt, not here.
@public to_vnt_and_stats

"""
    to_nt_and_stats(transition)::Tuple{NamedTuple,NamedTuple}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler into a
`NamedTuple` mapping parameter names to their values, plus a `NamedTuple` of any additional
statistics.

The first `NamedTuple` will be converted into `Parameter` keys, and the second `NamedTuple`
into `Extra` keys.

If you are writing a custom AbstractMCMC sampler and want to allow users to collect the
samples as a `FlexiChain{Symbol}`, i.e., 

    sample(...; chain_type=FlexiChain{Symbol})

then you should ensure that your method of `AbstractMCMC.step` returns a transition that can
be passed to this method. (The other return value, the state, is not relevant.)
"""
function to_nt_and_stats end
@public to_nt_and_stats
to_nt_and_stats(nt::NamedTuple) = (nt, (;))

function AbstractMCMC.bundle_samples(
        transitions::AbstractVector,
        @nospecialize(m::AbstractMCMC.AbstractModel),
        @nospecialize(s::AbstractMCMC.AbstractSampler),
        last_sampler_state::Any,
        chain_type::Type{FlexiChain{Symbol}};
        save_state = false,
        stats = missing,
        discard_initial::Int = 0,
        thinning::Int = 1,
        _kwargs...,
    )::FlexiChain{Symbol}
    niters = length(transitions)
    nts_and_stats = map(FlexiChains.to_nt_and_stats, transitions)
    dicts = map(nts_and_stats) do (nt, stat)
        d = OrderedDict{ParameterOrExtra{Symbol}, Any}(
            Parameter(sym) => val for (sym, val) in pairs(nt)
        )
        for (stat_name, stat_val) in pairs(stat)
            d[Extra(stat_name)] = stat_val
        end
        d
    end
    # timings
    tm = stats === missing ? missing : stats.stop - stats.start
    # last sampler state
    st = save_state ? last_sampler_state : missing
    # calculate iteration indices
    start = discard_initial + 1
    iter_indices = if thinning != 1
        range(start; step = thinning, length = niters)
    else
        # This returns UnitRange not StepRange -- a bit cleaner
        start:(start + niters - 1)
    end
    return FlexiChain{Symbol}(
        niters,
        1,
        dicts;
        iter_indices = iter_indices,
        # 1:1 gives nicer DimMatrix output than just [1]
        chain_indices = 1:1,
        sampling_time = [tm],
        last_sampler_state = [st],
    )
end

"""
    FlexiChains.from_parameter_array(
        arr::AbstractArray{T,3};
        parameters = @varname(x),
        iter_indices = 1:size(arr, 1),
        chain_indices = 1:size(arr, 2),
    )

Given a 3D array of parameter values (with dimensions `(iters, chains, params)`),
convert it into a `FlexiChain`. The `parameters` argument controls how columns in the
third dimension are mapped to parameter names:

- A single key (e.g. `@varname(x)` or `:x`): all columns are stored as a single
  vector-valued parameter.
- A tuple of `key => range` pairs: each pair maps a parameter name to a range of columns.

When `key => range` pairs are used, ranges of length 1 result in scalar-valued parameters,
while longer ranges result in vector-valued parameters. Ranges must cover all columns
`1:size(arr, 3)` exactly once, with no gaps or overlaps.

The key type of the resulting `FlexiChain` is inferred from the type(s) of the parameter
key(s).
"""
function from_parameter_array(
        arr::AbstractArray{T, 3};
        parameters = @varname(x),
        iter_indices = 1:size(arr, 1),
        chain_indices = 1:size(arr, 2),
    ) where {T}
    niters, nchains, nparams = size(arr)
    parameter_pairs = _normalize_parameters(parameters, nparams)
    _check_parameter_ranges(parameter_pairs, nparams)
    TKey = mapreduce(p -> typeof(first(p)), typejoin, parameter_pairs)
    dict = OrderedDict(
        map(parameter_pairs) do (key, range)
            if length(range) == 1
                Parameter(key) => arr[:, :, only(range)]
            else
                Parameter(key) => map(collect, eachslice(arr[:, :, range]; dims = (1, 2)))
            end
        end...,
    )
    return FlexiChain{TKey}(
        niters,
        nchains,
        dict;
        iter_indices = iter_indices,
        chain_indices = chain_indices,
    )
end

_normalize_parameters(key, nparams) = ((key => 1:nparams),)
_normalize_parameters(pairs::Tuple{Vararg{Pair}}, _) = pairs

function _check_parameter_ranges(pairs, nparams)
    all_indices = sort(mapreduce(p -> collect(last(p)), vcat, pairs))
    return if all_indices != 1:nparams
        throw(
            ArgumentError(
                "parameter ranges must cover all $nparams columns exactly once; " *
                    "expected indices 1:$nparams, got $all_indices",
            )
        )
    end
end
