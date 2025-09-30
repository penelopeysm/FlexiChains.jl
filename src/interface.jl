using DimensionalData: DimensionalData as DD

@public niters, nchains
@public subset, subset_parameters, subset_extras
@public parameters, extras, extras_grouped
@public get_dict_from_iter, get_parameter_dict_from_iter
@public to_varname_dict

using AbstractMCMC: AbstractMCMC

"""
    size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}

Returns `(niters, nchains)`.
"""
function Base.size(
    ::FlexiChain{TKey,NIter,NChains}
)::Tuple{Int,Int} where {TKey,NIter,NChains}
    return (NIter, NChains)
end
"""
    size(chain::FlexiChain{TKey,NIter,NChains}, 1)

Number of iterations in the `FlexiChain`. Equivalent to `niters(chain)`.

    size(chain::FlexiChain{TKey,NIter,NChains}, 2)

Number of chains in the `FlexiChain`. Equivalent to `nchains(chain)`.
"""
function Base.size(::FlexiChain{TKey,NIter,NChains}, dim::Int) where {TKey,NIter,NChains}
    return if dim == 1
        NIter
    elseif dim == 2
        NChains
    else
        throw(DimensionMismatch("Dimension $dim out of range for FlexiChain"))
    end
end

"""
    niters(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}

The number of iterations in the `FlexiChain`. Equivalent to `size(chain, 1)`.
"""
function niters(::FlexiChain{TKey,NIter,NChains})::Int where {TKey,NIter,NChains}
    return NIter
end

"""
    nchains(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}

The number of chains in the `FlexiChain`. Equivalent to `size(chain, 2)`.
"""
function nchains(::FlexiChain{TKey,NIter,NChains})::Int where {TKey,NIter,NChains}
    # Same as above but with isequal instead of ==
    return NChains
end

function Base.:(==)(
    c1::FlexiChain{TKey1,NIter1,NChain1}, c2::FlexiChain{TKey2,NIter2,NChain2}
) where {TKey1,TKey2,NIter1,NChain1,NIter2,NChain2}
    # Check if the type parameters are the same
    if TKey1 != TKey2 || NIter1 != NIter2 || NChain1 != NChain2
        return false
    end
    # Check if the data dictionaries are the same
    # Note: Because FlexiChains uses `Dict` for the underlying storage,
    # and Dicts do not check for ordering of keys, the ordering of keys is 
    # also immaterial for FlexiChain equality.
    return c1._data == c2._data
end

function Base.isequal(
    c1::FlexiChain{TKey1,NIter1,NChain1}, c2::FlexiChain{TKey2,NIter2,NChain2}
) where {TKey1,TKey2,NIter1,NChain1,NIter2,NChain2}
    # Same as above but with isequal instead of ==
    if TKey1 != TKey2 || NIter1 != NIter2 || NChain1 != NChain2
        return false
    end
    return isequal(c1._data, c2._data)
end

"""
    keys(chain::FlexiChain{TKey}) where {TKey}

Returns the keys of the `FlexiChain` as an iterable collection.
"""
function Base.keys(chain::FlexiChain{TKey}) where {TKey}
    return keys(chain._data)
end

"""
    haskey(chain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey}) where {TKey}
    haskey(chain::FlexiChain{TKey}, key::TKey) where {TKey}

Returns `true` if the `FlexiChain` contains the given key.
"""
function Base.haskey(chain::FlexiChain{TKey}, key::ParameterOrExtra{<:TKey}) where {TKey}
    return haskey(chain._data, key)
end
function Base.haskey(chain::FlexiChain{TKey}, key::TKey) where {TKey}
    return haskey(chain._data, Parameter(key))
end

"""
    Base.merge(
        c1::FlexiChain{TKey1,NIter,NChain},
        c2::FlexiChain{TKey2,NIter,NChain}
    ) where {TKey1,TKey2,NIter,NChain}

Merge the contents of two `FlexiChain`s. If there are keys that are present in both chains,
the values from `c2` will overwrite those from `c1`.

If the key types are different, the resulting `FlexiChain` will have a promoted key type,
and a warning will be issued.

The two `FlexiChain`s being merged must have the same dimensions.

The chain indices and metadata are taken from the second chain. Those in the first chain are
silently ignored.
"""
function Base.merge(
    c1::FlexiChain{TKey1,NIter,NChain}, c2::FlexiChain{TKey2,NIter,NChain}
) where {TKey1,TKey2,NIter,NChain}
    # Promote key type if necessary and warn
    TKeyNew = if TKey1 != TKey2
        new = Base.promote_type(TKey1, TKey2)
        @warn "Merging FlexiChains with different key types: $(TKey1) and $(TKey2). The resulting chain will have $(new) as the key type."
        new
    else
        TKey1
    end
    # Figure out value type
    # TODO: This function has to access internal data, urk
    TValNew = Base.promote_type(eltype(valtype(c1._data)), eltype(valtype(c2._data)))
    # Merge the data dictionaries
    d1 = Dict{ParameterOrExtra{<:TKeyNew},SizedMatrix{NIter,NChain,<:TValNew}}(c1._data)
    d2 = Dict{ParameterOrExtra{<:TKeyNew},SizedMatrix{NIter,NChain,<:TValNew}}(c2._data)
    merged_data = merge(d1, d2)
    return FlexiChain{TKeyNew,NIter,NChain}(
        merged_data;
        iter_indices=FlexiChains.iter_indices(c2),
        chain_indices=FlexiChains.chain_indices(c2),
        sampling_time=FlexiChains.sampling_time(c2),
        last_sampler_state=FlexiChains.last_sampler_state(c2),
    )
end
function Base.merge(
    ::FlexiChain{TKey1,NIter1,NChain1}, ::FlexiChain{TKey2,NIter2,NChain2}
) where {TKey1,TKey2,NIter1,NChain1,NIter2,NChain2}
    # Fallback if niter and nchains are different
    throw(
        DimensionMismatch(
            "cannot merge FlexiChains with different sizes $(NIter1)×$(NChain1) and $(NIter2)×$(NChain2).",
        ),
    )
end

"""
    subset(
        chain::FlexiChain{TKey,NIter,NChain},
        keys::AbstractVector{<:ParameterOrExtra{<:TKey}}
    )::FlexiChain{TKey,NIter,NChain} where {TKey,NIter,NChain}

Create a new `FlexiChain` containing only the specified keys and the data corresponding to
them. All metadata is preserved.
"""
function subset(
    chain::FlexiChain{TKey,NIter,NChain}, keys::AbstractVector{<:ParameterOrExtra{<:TKey}}
)::FlexiChain{TKey,NIter,NChain} where {TKey,NIter,NChain}
    d = empty(chain._data)
    for k in keys
        if haskey(chain._data, k)
            d[k] = chain._data[k]
        else
            throw(KeyError(k))
        end
    end
    return FlexiChain{TKey,NIter,NChain}(
        d;
        iter_indices=FlexiChains.iter_indices(chain),
        chain_indices=FlexiChains.chain_indices(chain),
        sampling_time=FlexiChains.sampling_time(chain),
        last_sampler_state=FlexiChains.last_sampler_state(chain),
    )
end

"""
    subset_parameters(chain::FlexiChain)

Subset a chain, retaining only the `Parameter` keys.
"""
function subset_parameters(
    chain::FlexiChain{TKey,NIter,NChain}
)::FlexiChain{TKey,NIter,NChain} where {TKey,NIter,NChain}
    return subset(chain, Parameter.(parameters(chain)))
end

"""
    subset_parameters(chain::FlexiChain{TKey,NIter,NChain})

Subset a chain, retaining only the keys that are `Extra`s (i.e. not parameters).
"""
function subset_extras(
    chain::FlexiChain{TKey,NIter,NChain}
)::FlexiChain{TKey,NIter,NChain} where {TKey,NIter,NChain}
    v = Extra[]
    for k in keys(chain)
        if !(k isa Parameter)
            push!(v, k)
        end
    end
    return subset(chain, v)
end

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

function Base.show(
    io::IO, ::MIME"text/plain", chain::FlexiChain{TKey,niters,nchains}
) where {TKey,niters,nchains}
    maybe_s(x) = x == 1 ? "" : "s"
    printstyled(io, "FlexiChain | $niters iteration$(maybe_s(niters)) ("; bold=true)
    printstyled(
        io,
        "$(_show_range(FlexiChains.iter_indices(chain)))";
        color=DD.dimcolor(1),
        bold=true,
    )
    printstyled(io, ") | $nchains chain$(maybe_s(nchains)) ("; bold=true)
    printstyled(
        io,
        "$(_show_range(FlexiChains.chain_indices(chain)))";
        color=DD.dimcolor(2),
        bold=true,
    )
    printstyled(io, ")\n"; bold=true)
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
    extras = extras_grouped(chain)
    printstyled(io, "Extra keys       "; bold=true)
    if isempty(extras)
        println(io, "(none)")
    else
        print_space = false
        for (section, keys) in pairs(extras)
            print_space && print(io, "\n                 ")
            print(io, "{:$section} ", join(keys, ", "))
            print_space = true
        end
    end

    # TODO: Summary statistics?
    return nothing
end

function _get(chain::FlexiChain{TKey}, key::ParameterOrExtra{TKey}) where {TKey}
    return data(chain._data[key])  # errors if key not found
end

"""
    parameters(chain::FlexiChain{TKey}) where {TKey}

Returns a vector of parameter names in the `FlexiChain`.
"""
function parameters(chain::FlexiChain{TKey})::Vector{TKey} where {TKey}
    parameter_names = TKey[]
    for k in keys(chain._data)
        if k isa Parameter{<:TKey}
            push!(parameter_names, k.name)
        end
    end
    return parameter_names
end

"""
    extras(chain::FlexiChain)

Returns a vector of non-parameter names in the `FlexiChain`.
"""
function extras(chain::FlexiChain)::Vector{Extra}
    other_key_names = Extra[]
    for k in keys(chain._data)
        if k isa Extra
            push!(other_key_names, k)
        end
    end
    return other_key_names
end

"""
    extras_grouped(chain::FlexiChain)

Returns a NamedTuple of `Extra` names, grouped by their section.
"""
function extras_grouped(chain::FlexiChain)::NamedTuple
    other_keys = Dict{Symbol,Any}()
    # Build up the dictionary of section name => key name
    for k in keys(chain._data)
        if k isa Extra
            section = k.section_name
            key_name = k.key_name
            if !haskey(other_keys, section)
                other_keys[section] = Any[]
            end
            push!(other_keys[section], key_name)
        end
    end
    # concretise
    for (section, keys) in pairs(other_keys)
        other_keys[section] = Set(map(identity, keys))
    end
    return NamedTuple(other_keys)
end

# Overloaded in TuringExt.
"""
    to_varname_dict(transition)::Dict{VarName,Any}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler
into a dictionary mapping `VarName`s to their corresponding values.

If you are writing a custom sampler for Turing.jl and your sampler's
implementation of `AbstractMCMC.step` returns anything _but_ a
`Turing.Inference.Transition` as its first return value, then to use FlexiChains
with your sampler, you will have to overload this function.
"""
function to_varname_dict end

"""
    Base.vcat(cs...::FlexiChain{TKey}) where {TKey}

Concatenate one or more `FlexiChain`s along the iteration dimension. Both `c1` and `c2` must
have the same number of chains and the same key type.

The resulting chain's keys are the union of both input chains' keys. Any keys that only have
data in one of the arguments will be assigned `missing` data in the other chain during
concatenation.

The resulting chain's sampling time is the sum of the input chains' sampling times, and
the last sampler state is taken from the second chain.
"""
function Base.vcat(
    c1::FlexiChain{TKey,NIter1,NChains}, c2::FlexiChain{TKey,NIter2,NChains}
)::FlexiChain{TKey,NIter1 + NIter2,NChains} where {TKey,NIter1,NIter2,NChains}
    # Warn if the chains don't line up in terms of chain indices
    ci1, ci2 = FlexiChains.chain_indices(c1), FlexiChains.chain_indices(c2)
    if ci1 != ci2
        @warn "concatenating FlexiChains with different chain indices: got $(ci1) and $(ci2). The resulting chain will have the chain indices of the first chain."
    end
    d = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter1 + NIter2,NChains}}()
    for k in union(keys(c1), keys(c2))
        c1_data = haskey(c1, k) ? c1._data[k] : fill(missing, NIter1, NChains)
        c2_data = haskey(c2, k) ? c2._data[k] : fill(missing, NIter2, NChains)
        d[k] = SizedMatrix{NIter1 + NIter2,NChains}(vcat(c1_data, c2_data))
    end
    return FlexiChain{TKey,NIter1 + NIter2,NChains}(
        d;
        iter_indices=vcat(FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2)),
        chain_indices=FlexiChains.chain_indices(c1),
        sampling_time=FlexiChains.sampling_time(c1) .+ FlexiChains.sampling_time(c2),
        last_sampler_state=FlexiChains.last_sampler_state(c2),
    )
end
function Base.vcat(c1::FlexiChain{TKey}, c2::FlexiChain{TKey}) where {TKey}
    throw(
        DimensionMismatch(
            "cannot vcat FlexiChains with different number of chains: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
end
function Base.vcat(::FlexiChain{TKey1}, ::FlexiChain{TKey2}) where {TKey1,TKey2}
    throw(
        ArgumentError(
            "cannot vcat FlexiChains with different key types $(TKey1) and $(TKey2)"
        ),
    )
end
Base.vcat(c1::FlexiChain) = c1
function Base.vcat(
    c1::FlexiChain{TKey,NIter1,NChains},
    c2::FlexiChain{TKey,NIter2,NChains},
    cs::FlexiChain{TKey}...,
) where {TKey,NIter1,NIter2,NChains}
    return Base.vcat(Base.vcat(c1, c2), cs...)
end

"""
    Base.hcat(cs...::FlexiChain{TKey}) where {TKey}

Concatenate one or more `FlexiChain`s along the chain dimension. Both `c1` and `c2` must
have the same number of iterations and the same key type.

The resulting chain's keys are the union of both input chains' keys. Any keys that only have
data in one of the arguments will be assigned `missing` data in the other chain during
concatenation.

The resulting chain's sampling times and last sampler states are obtained by concatenating
those of the input chains.
"""
function Base.hcat(
    c1::FlexiChain{TKey,NIter,NChains1}, c2::FlexiChain{TKey,NIter,NChains2}
)::FlexiChain{TKey,NIter,NChains1 + NChains2} where {TKey,NIter,NChains1,NChains2}
    # Warn if the chains don't line up in terms of iteration indices
    ii1, ii2 = FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2)
    if ii1 != ii2
        @warn "concatenating FlexiChains with different iteration indices: got $(ii1) and $(ii2). The resulting chain will have the iteration indices of the first chain."
    end
    # Build up the new data dictionary
    d = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,NChains1 + NChains2}}()
    for k in union(keys(c1), keys(c2))
        c1_data = haskey(c1, k) ? c1._data[k] : fill(missing, NIter, NChains1)
        c2_data = haskey(c2, k) ? c2._data[k] : fill(missing, NIter, NChains2)
        d[k] = SizedMatrix{NIter,NChains1 + NChains2}(hcat(c1_data, c2_data))
    end
    # TODO: Do we want to use the chain indices passed in?
    return FlexiChain{TKey,NIter,NChains1 + NChains2}(
        d;
        iter_indices=FlexiChains.iter_indices(c1),
        chain_indices=1:(NChains1 + NChains2),
        sampling_time=vcat(FlexiChains.sampling_time(c1), FlexiChains.sampling_time(c2)),
        last_sampler_state=vcat(
            FlexiChains.last_sampler_state(c1), FlexiChains.last_sampler_state(c2)
        ),
    )
end
Base.hcat(c1::FlexiChain) = c1
function Base.hcat(c1::FlexiChain{TKey}, c2::FlexiChain{TKey}) where {TKey}
    throw(
        DimensionMismatch(
            "cannot hcat FlexiChains with different number of iterations: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
end
function Base.hcat(::FlexiChain{TKey1}, ::FlexiChain{TKey2}) where {TKey1,TKey2}
    throw(
        ArgumentError(
            "cannot hcat FlexiChains with different key types $(TKey1) and $(TKey2)"
        ),
    )
end
function Base.hcat(
    c1::FlexiChain{TKey,NIter,NChains1},
    c2::FlexiChain{TKey,NIter,NChains2},
    cs::FlexiChain{TKey,NIter}...,
) where {TKey,NIter,NChains1,NChains2}
    return Base.hcat(Base.hcat(c1, c2), cs...)
end

"""
    AbstractMCMC.chainscat(chains...)

Concatenate `FlexiChain`s along the chain dimension.
"""
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey,NIter,NChains1}, c2::FlexiChain{TKey,NIter,NChains2}
)::FlexiChain{TKey,NIter,NChains1 + NChains2} where {TKey,NIter,NChains1,NChains2}
    return Base.hcat(c1, c2)
end
AbstractMCMC.chainscat(c1::FlexiChain) = c1
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey,NIter,NChains1},
    c2::FlexiChain{TKey,NIter,NChains2},
    cs::FlexiChain{TKey,NIter}...,
) where {TKey,NIter,NChains1,NChains2}
    return AbstractMCMC.chainscat(AbstractMCMC.chainscat(c1, c2), cs...)
end

"""
    get_dict_from_iter(
        chain::FlexiChain{TKey},
        iteration_number::Int,
        chain_number::Union{Int,Nothing}=nothing
    )::Dict{ParameterOrExtra{TKey},Any}

Extract the dictionary mapping keys to their values in a single MCMC iteration.

If `chain` only contains a single chain, then `chain_number` does not need to be
specified.

The order of keys in the returned dictionary is not guaranteed.

To get only the parameter keys, use `get_parameter_dict_from_iter`.
"""
function get_dict_from_iter(
    chain::FlexiChain{TKey}, iteration_number::Int, chain_number::Union{Int,Nothing}=nothing
)::Dict{ParameterOrExtra{TKey},Any} where {TKey}
    d = Dict{ParameterOrExtra{TKey},Any}()
    for k in keys(chain)
        if chain_number === nothing
            d[k] = chain[k][iteration_number]
        else
            d[k] = chain[k][iteration_number, chain_number]
        end
    end
    return d
end

"""
    get_parameter_dict_from_iter(
        chain::FlexiChain{TKey},
        iteration_number::Int,
        chain_number::Union{Int,Nothing}=nothing
    )::Dict{TKey,Any} where {TKey}

Extract the dictionary corresponding to a single MCMC iteration, but with only
the parameters.

To get all other non-parameter keys as well, use `get_dict_from_iter`.

The order of keys in the returned dictionary is not guaranteed.
"""
function get_parameter_dict_from_iter(
    chain::FlexiChain{TKey}, iteration_number::Int, chain_number::Union{Int,Nothing}=nothing
)::Dict{TKey,Any} where {TKey}
    d = Dict{TKey,Any}()
    for k in parameters(chain)
        if chain_number === nothing
            d[k] = chain[k][iteration_number]
        else
            d[k] = chain[k][iteration_number, chain_number]
        end
    end
    return d
end
