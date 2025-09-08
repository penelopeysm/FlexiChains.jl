@public niters, nchains
@public subset, subset_parameters, subset_extras
@public parameters, extras, extras_grouped
@public get_dict_from_iter, get_parameter_dict_from_iter
@public to_varname_dict

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
    haskey(chain::FlexiChain{TKey}, key::ParameterOrExtra{TKey}) where {TKey}
    haskey(chain::FlexiChain{TKey}, key::TKey) where {TKey}

Returns `true` if the chain contains the given key.
"""
function Base.haskey(chain::FlexiChain{TKey}, key::ParameterOrExtra{TKey}) where {TKey}
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

Merge the contents of two `FlexiChain`s. If there are keys that are present in
both chains, the values from `c2` will overwrite those from `c1`.

If the key types are different, the resulting `FlexiChain` will have a promoted
key type, and a warning will be issued.

The two `FlexiChain`s being merged must have the same dimensions.

Note that this function does not perform a deepcopy of the underlying data.
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
    d1 = Dict{ParameterOrExtra{TKeyNew},SizedMatrix{NIter,NChain,<:TValNew}}(c1._data)
    d2 = Dict{ParameterOrExtra{TKeyNew},SizedMatrix{NIter,NChain,<:TValNew}}(c2._data)
    merged_data = merge(d1, d2)
    return FlexiChain{TKeyNew}(merged_data)
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
them.

Note that this function does not perform a deepcopy of the underlying data.
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
    return FlexiChain{TKey}(d)
end

"""
    subset_parameters(chain::FlexiChain{TKey,NIter,NChain})

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

function Base.show(
    io::IO, ::MIME"text/plain", chain::FlexiChain{TKey,niters,nchains}
) where {TKey,niters,nchains}
    printstyled(
        io,
        "FlexiChain ($niters iterations, $nchains chain$(nchains > 1 ? "s" : ""))\n\n";
        bold=true,
    )

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
    printstyled(io, "Other keys       "; bold=true)
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

"""
    Base.getindex(chain::FlexiChain{TKey}, key::ParameterOrExtra{TKey}) where {TKey}

Unambiguously access the data corresponding to the given `key` in the `chain`.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `Extra(:some_section, :x)`.
"""
function Base.getindex(chain::FlexiChain{TKey}, key::ParameterOrExtra{TKey}) where {TKey}
    return data(chain._data[key])  # errors if key not found
end
"""
    Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}

The most convenient method to index into a `FlexiChain` is using `Symbol`.

However, recall that the keys in a `FlexiChain{TKey}` are not stored as
`Symbol`s but rather as either `Parameter{TKey}` or `Extra`. Thus, to
access the data corresponding to a `Symbol`, we first convert all key names
(both parameters and other keys) to `Symbol`s, and then check if there is a
unique match.

If there is, then we can return that data. If there are no valid matches,
then we throw a `KeyError`.

If there are multiple matches: for example, if you have a `Parameter(:x)`
and also an `Extra(:some_section, :x)`, then this method will also
throw a `KeyError`. You will then have to index into it using the
actual key.
"""
function Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}
    # Convert all keys to symbols and see if there is a unique match
    potential_keys = ParameterOrExtra{TKey}[]
    for k in keys(chain._data)
        sym = if k isa Parameter{<:TKey}
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.name)
        elseif k isa Extra
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.key_name)
        end
        if sym == sym_key
            push!(potential_keys, k)
        end
    end
    if length(potential_keys) == 0
        throw(ArgumentError("no key corresponding to symbol $sym_key"))
    elseif length(potential_keys) > 1
        s = "multiple keys correspond to symbol :$sym_key.\n"
        s *= "Possible options are: \n"
        for k in potential_keys
            if k isa Parameter{<:TKey}
                s *= "  - Parameter($(k.name))\n"
            elseif k isa Extra
                s *= "  - Extra(:$(k.section_name), $(k.key_name))\n"
            end
        end
        throw(ArgumentError(s))
    else
        return data(chain._data[only(potential_keys)])
    end
end
"""
    Base.getindex(chain::FlexiChain{TKey}, section_name::Symbol, key_name::Any) where {TKey}

Convenience method for retrieving non-parameter keys. Equal to
`chain[Extra(section_name, key_name)]`.
"""
function Base.getindex(
    chain::FlexiChain{TKey}, section_name::Symbol, key_name::Any
) where {TKey}
    # This is a convenience method to access data in a section
    # using the section name and key name.
    return chain[Extra(section_name, key_name)]
end
"""
    Base.getindex(chain::FlexiChain{TKey}, parameter_name::TKey) where {TKey}

Convenience method for retrieving parameters. Equal to
`chain[Parameter(parameter_name)]`.
"""
function Base.getindex(chain::FlexiChain{TKey}, parameter_name::TKey) where {TKey}
    return chain[Parameter(parameter_name)]
end

"""
Helper function for `getindex` with `VarName`. Accesses the VarName `vn` in the chain (if it
is a parameter) and applies the `optic` function to the data before returning it.

`orig_vn` is the VarName that the user attempted to access. It is used only for error
reporting.
"""
function _getindex_vn_with_map(
    chain::FlexiChain{<:VarName}, vn::VarName{sym}, optic::Function, orig_vn::VarName{sym}
) where {sym}
    if haskey(chain, vn)
        # Found
        if optic === identity
            return data(chain._data[Parameter(vn)])
        else
            # TODO: Nicer error if the optic is incompatible with the data shape?
            # Or do we just let it error naturally?
            return map(optic, data(chain._data[Parameter(vn)]))
        end
    else
        # Not found -- attempt to reduce.
        # TODO: This depends on AbstractPPL internals and is prone to breaking.
        # These should be exported from AbstractPPL.
        o = AbstractPPL.getoptic(vn)
        i, l = AbstractPPL._init(o), AbstractPPL._last(o)
        if l === identity
            # Cannot reduce further
            throw(KeyError(orig_vn))
        else
            new_vn = VarName{sym}(i)
            new_optic = optic ∘ l
            return _getindex_vn_with_map(chain, new_vn, new_optic, orig_vn)
        end
    end
end
"""
    Base.getindex(chain::FlexiChain{<:VarName}, vn::VarName)

An additional specialisation for `VarName`, meant for convenience when working with
Turing.jl models.

`chn[vn]` first checks if the VarName `vn` itself is stored in the chain. If not, it will
attempt to check if the 'parent' of `vn` is in the chain, and so on, until all possibilities
have been exhausted.

For example, the parent of `@varname(x[1])` is `@varname(x)`. If `@varname(x[1])` itself is
in the chain, then that will be returned. If not, then `@varname(x)` will be checked next,
and if that is a vector-valued parameter then all of its first entries will be returned.
"""
function Base.getindex(chain::FlexiChain{<:VarName}, vn::VarName)
    return _getindex_vn_with_map(chain, vn, identity, vn)
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
"""
function Base.vcat(
    c1::FlexiChain{TKey,NIter1,NChains}, c2::FlexiChain{TKey,NIter2,NChains}
)::FlexiChain{TKey,NIter1 + NIter2,NChains} where {TKey,NIter1,NIter2,NChains}
    d = Dict{ParameterOrExtra{TKey},SizedMatrix{NIter1 + NIter2,NChains}}()
    for k in union(keys(c1), keys(c2))
        c1_data = if haskey(c1, k)
            c1[k]
        else
            SizedMatrix{NIter1,NChains}(fill(missing, NIter1, NChains))
        end
        c2_data = if haskey(c2, k)
            c2[k]
        else
            SizedMatrix{NIter2,NChains}(fill(missing, NIter2, NChains))
        end
        d[k] = SizedMatrix{NIter1 + NIter2,NChains}(vcat(c1_data, c2_data))
    end
    return FlexiChain{TKey}(d)
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
"""
function Base.hcat(
    c1::FlexiChain{TKey,NIter,NChains1}, c2::FlexiChain{TKey,NIter,NChains2}
)::FlexiChain{TKey,NIter,NChains1 + NChains2} where {TKey,NIter,NChains1,NChains2}
    d = Dict{ParameterOrExtra{TKey},SizedMatrix{NIter,NChains1 + NChains2}}()
    for k in union(keys(c1), keys(c2))
        c1_data = if haskey(c1, k)
            c1[k]
        else
            SizedMatrix{NIter,NChains1}(fill(missing, NIter, NChains1))
        end
        c2_data = if haskey(c2, k)
            c2[k]
        else
            SizedMatrix{NIter,NChains2}(fill(missing, NIter, NChains2))
        end
        d[k] = SizedMatrix{NIter,NChains1 + NChains2}(hcat(c1_data, c2_data))
    end
    # concatenate metadata
    sampling_times = vcat(FlexiChains.sampling_time(c1), FlexiChains.sampling_time(c2))
    last_sampler_states = vcat(
        FlexiChains.last_sampler_state(c1), FlexiChains.last_sampler_state(c2)
    )
    return FlexiChain{TKey}(
        d; sampling_time=sampling_times, last_sampler_state=last_sampler_states
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
