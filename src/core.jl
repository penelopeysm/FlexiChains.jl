using AbstractMCMC: AbstractMCMC

export FlexiChain, Parameter, OtherKey

"""
    SizedMatrix{NIter,NChains,T}

A matrix type that is used to store the data in a `FlexiChain`. It is similar
to `StaticArrays.SMatrix` in terms of its type behaviour, but under the hood
uses plain `Array`s for storage. This allows us to have type-level guarantees
about the size of the matrix, without having to opt into the performance
characteristics and data structures of `StaticArrays`.

`T` is the element type.

The underlying data in a SizedMatrix can be accessed using
`collect(::SizedMatrix)`. If the matrix has only one chain, it will be
returned as a vector. If it has multiple chains, it will be returned as a
matrix.

$(TYPEDFIELDS)
"""
struct SizedMatrix{NIter,NChains,T}
    """
    Internal data. Do not access this directly! Use `collect(::SizedMatrix)` instead.
    """
    _data::AbstractMatrix{T}

    function SizedMatrix{NIter,NChains}(data::AbstractMatrix{T}) where {NIter,NChains,T}
        if size(data) != (NIter, NChains)
            msg = "expected matrix of size ($(NIter), $(NChains)), got $(size(data))."
            throw(DimensionMismatch(msg))
        end
        return new{NIter,NChains,T}(data)
    end
    function SizedMatrix{NIter,1}(data::AbstractVector{T}) where {NIter,T}
        if length(data) != (NIter)
            msg = "expected vector of length $(NIter), got $(length(data))."
            throw(DimensionMismatch(msg))
        end
        return new{NIter,1,T}(reshape(data, NIter, 1)) # convert vector to matrix.
    end
end
function Base.collect(s::SizedMatrix{NIter,1,T}) where {NIter,T}
    return vec(s._data)
end
function Base.collect(s::SizedMatrix{NIter,NChains,T}) where {NIter,NChains,T}
    return s._data
end

"""
    Parameter(name)

A named parameter in a `FlexiChain`. The name can be of any type, but all
parameters in a `FlexiChain` must have the same type for their names.

Specifically, if you have a `FlexiChain{TKey}`, then all parameters must be of
type `Parameter{TKey}`.
"""
struct Parameter{T}
    name::T
end

"""
    OtherKey(section_name::Symbol, key_name::Any)

A key in a `FlexiChain` that is not a parameter. FlexiChain allows for
such informations to be grouped into _sections_, which are identified by
`Symbol`s. The name of the key itself can be of any type and is not
constrained by the type of the `FlexiChain`.
"""
struct OtherKey{T}
    section_name::Symbol
    key_name::T
end

"""
    FlexiChainKey{T}

Either a `Parameter{T}`, or an `OtherKey`.

All keys in a `FlexiChain{T}` must be a `FlexiChainKey{T}`.
"""
const FlexiChainKey{T} = Union{Parameter{<:T},OtherKey{<:Any}}

"""
    FlexiChain{TKey,NIter,NChains,Sections}

TODO: Document further.
"""
struct FlexiChain{TKey,NIter,NChains} <: AbstractMCMC.AbstractChains
    data::Dict{<:FlexiChainKey{TKey},<:SizedMatrix{NIter,NChains,<:Any}}

    """
        FlexiChain{TKey}(
            array_of_dicts::AbstractArray{<:AbstractDict}
        ) where {TKey}

    Construct a `FlexiChain` from a vector or matrix of dictionaries. Each
    dictionary corresponds to one iteration.

    Each dictionary must be a mapping from a `FlexiChainKey{TKey}` (i.e.,
    either a `Parameter{TKey}` or an `OtherKey`) to its value at that
    iteration.

    If `dicts` is a vector, then `niter` is the length of the vector and
    `nchains` is 1. If `dicts` is a matrix, then `(niter, nchains) =
    size(dicts)`.
    """
    function FlexiChain{TKey}(
        array_of_dicts::AbstractArray{<:AbstractDict,N}
    ) where {TKey,N}
        # Determine size
        niter, nchains = if N == 1
            length(array_of_dicts), 1
        elseif N == 2
            size(array_of_dicts)
        else
            throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
        end

        # Extract all unique keys from the dictionaries
        keys_set = Set{FlexiChainKey{TKey}}()
        for d in array_of_dicts
            for k in keys(d)
                if !(k isa FlexiChainKey{TKey})
                    msg = "all keys should either be `Parameter{<:$TKey}` or `OtherKey`; got `$(typeof(k))`."
                    throw(ArgumentError(msg))
                end
                push!(keys_set, k)
            end
        end

        # We have data as matrices-of-dict; we want to convert to dict-of-matrices.
        data = Dict{FlexiChainKey{TKey},SizedMatrix{niter,nchains}}()
        for key in keys_set
            # Extract the values for this key from all dictionaries
            values = map(d -> get(d, key, missing), array_of_dicts)
            # Convert to SizedMatrix
            values_smat = SizedMatrix{niter,nchains}(values)
            # Store in the data dictionary
            data[key] = values_smat
        end

        return new{TKey,niter,nchains}(data)
    end

    """
        FlexiChain{TKey}(
            dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
        ) where {TKey,N}
    """
    function FlexiChain{TKey}(
        dict_of_arrays::AbstractDict{<:Any,<:AbstractArray{<:Any,N}}
    ) where {TKey,N}
        # If no data, assume 0 iters and 0 chains.
        if isempty(dict_of_arrays)
            return FlexiChain{TKey,0,0}(Dict{FlexiChainKey{TKey},SizedMatrix{0,0}}())
        end

        # dict_of_arrays is already in the correct form, but we need to do some
        # upfront work to check the keys are consistent, and also ensure that
        # the sizes are consistent (and convert to SMatrix).
        niter, nchains = if N == 1
            length(first(values(dict_of_arrays))), 1
        elseif N == 2
            size(first(values(dict_of_arrays)))
        else
            throw(DimensionMismatch("expected vector or matrix, got $(N)-dimensional array."))
        end

        data = Dict{FlexiChainKey{TKey},SizedMatrix{niter,nchains}}()
        for (key, array) in pairs(dict_of_arrays)
            # Check key type
            if !(key isa FlexiChainKey{TKey})
                msg = "all keys should either be `Parameter{<:$TKey}` or `OtherKey`; got `$(typeof(key))`."
                throw(ArgumentError(msg))
            end
            # Check size
            if array isa AbstractVector
                if length(array) != niter
                    msg = "data for key $key has an inconsistent size: expected $(niter), got $(length(array))."
                    throw(DimensionMismatch(msg))
                end
            elseif array isa AbstractMatrix
                if size(array) != (niter, nchains)
                    msg = "data for key $key has an inconsistent size: expected ($(niter), $(nchains)), got $(size(array))."
                    throw(DimensionMismatch(msg))
                end
            end
            # Convert to SMatrix
            mat = SizedMatrix{niter,nchains}(array)
            data[key] = mat
        end

        return new{TKey,niter,nchains}(data)
    end
end

"""
    size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}

Returns the size of the `FlexiChain` as a tuple `(NIter, num_objects, NChains)`,
where `num_objects` is the number of unique keys in the chain (both `Parameter`s
and `OtherKey`s).
"""
function Base.size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}
    num_objects = length(chain.data)
    return (NIter, num_objects, NChains)
end

function Base.keys(chain::FlexiChain{TKey}) where {TKey}
    return keys(chain.data)
end

function Base.values(chain::FlexiChain{TKey}) where {TKey}
    return values(chain.data)
end

function Base.pairs(chain::FlexiChain{TKey}) where {TKey}
    return pairs(chain.data)
end

"""
    Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}

The most convenient method to index into a `FlexiChain` is using `Symbol`.

However, recall that the keys in a `FlexiChain{TKey}` are not stored as
`Symbol`s but rather as either `Parameter{TKey}` or `OtherKey`. Thus, to
access the data corresponding to a `Symbol`, we first convert all keys
(both parameters and other keys) to `Symbol`s and then check if there is a
unique match.

If there is, then we can return that data. If there are no valid matches,
then we throw a `KeyError` as expected.

If there are multiple matches: for example, if you have a `Parameter(:x)`
and also an `OtherKey(:some_section, :x)`, then this method will also
throw a `KeyError`. You will then have to index into it using the
actual key.

    Base.getindex(chain::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}

Unambiguously access the data corresponding to the given `key` in the `chain`.

You will need to use this method if you have multiple keys that convert to the
same `Symbol`, such as a `Parameter(:x)` and an `OtherKey(:some_section, :x)`.
"""
function Base.getindex(chain::FlexiChain{TKey}, key::FlexiChainKey{TKey}) where {TKey}
    return collect(chain.data[key])  # errors if key not found
end
function Base.getindex(chain::FlexiChain{TKey}, sym_key::Symbol) where {TKey}
    # Convert all keys to symbols and see if there is a unique match
    potential_keys = FlexiChainKey{TKey}[]
    for k in keys(chain.data)
        sym = if k isa Parameter{TKey}
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.name)
        elseif k isa OtherKey
            # TODO: What happens if Symbol(...) fails on some weird type?
            Symbol(k.key_name)
        end
        if sym == sym_key
            push!(potential_keys, k)
        end
    end
    if length(potential_keys) == 0
        throw(KeyError("no key corresponding to symbol $sym_key"))
    elseif length(potential_keys) > 1
        throw(KeyError("multiple keys correspond to symbol $sym_key: $(potential_keys)"))
    else
        return collect(chain.data[only(potential_keys)])
    end
end
