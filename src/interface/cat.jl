"""
    _smartcat(v1, v2)

Attempt to 'cleverly' concatenate two vectors of integers, returning a vector of integers.
This is used to concatenate the iteration indices of two `FlexiChain`s during `vcat`.

Essentially, if the concatenation of the two vectors can be represented as a single
`UnitRange` or `StepRange`, then we try to do so. Otherwise we will just fall back to
returning a boring `Vector{Int}`.

But most importantly, if `v1` and `v2` are each in ascending order, this function will
guarantee that `_smartcat(v1, v2)` is also in ascending order.
"""
function _smartcat(v1::DDL.Sampled, v2::DDL.Sampled)
    return _make_lookup(_smartcat(parent(v1), parent(v2)))
end
function _smartcat(v1::UnitRange, v2::StepRange)
    return if v2.step == 1
        _smartcat(v1, (v2.start):(v2.stop))
    else
        vcat(v1, maximum(v1) .+ v2)
    end
end
function _smartcat(v1::StepRange, v2::UnitRange)
    return if v1.step == 1
        _smartcat((v1.start):(v1.stop), v2)
    else
        vcat(v1, maximum(v1) .+ v2)
    end
end
function _smartcat(v1::StepRange, v2::StepRange)
    return if v1.step == v2.step && v1.stop + v1.step == v2.start
        (v1.start):(v1.step):(v2.stop)
    else
        vcat(v1, maximum(v1) .+ v2)
    end
end
function _smartcat(v1::UnitRange, v2::UnitRange)
    return if v1.stop + 1 == v2.start
        (v1.start):(v2.stop)
    else
        vcat(v1, maximum(v1) .+ v2)
    end
end
function _smartcat(v1::AbstractVector{<:Integer}, v2::AbstractVector{<:Integer})
    # default
    return vcat(v1, maximum(v1) .+ v2)
end

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
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    # Check sizes are compatible
    nchains(c1) == nchains(c2) || throw(
        DimensionMismatch(
            "cannot vcat FlexiChains with different number of chains: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
    # Warn if the chains don't line up in terms of chain indices
    ci1, ci2 = FlexiChains.chain_indices(c1), FlexiChains.chain_indices(c2)
    if ci1 != ci2
        @warn "concatenating FlexiChains with different chain indices: got $(ci1) and $(ci2). The resulting chain will have the chain indices of the first chain."
    end
    d = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
    allkeys = OrderedSet{ParameterOrExtra{<:TKey}}(keys(c1))
    union!(allkeys, keys(c2))
    for k in allkeys
        c1_data = if haskey(c1, k)
            _get_raw_data(c1, k)
        else
            fill(missing, size(c1)...)
        end
        c2_data = if haskey(c2, k)
            _get_raw_data(c2, k)
        else
            fill(missing, size(c2)...)
        end
        d[k] = vcat(c1_data, c2_data)
    end
    new_iter_indices = _smartcat(FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2))
    return FlexiChain{TKey}(
        niters(c1) + niters(c2),
        nchains(c1),
        d;
        iter_indices=new_iter_indices,
        chain_indices=FlexiChains.chain_indices(c1),
        sampling_time=FlexiChains.sampling_time(c1) .+ FlexiChains.sampling_time(c2),
        last_sampler_state=FlexiChains.last_sampler_state(c2),
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
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
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
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    # Check sizes are compatible
    niters(c1) == niters(c2) || throw(
        DimensionMismatch(
            "cannot hcat FlexiChains with different number of iterations: got sizes $(size(c1)) and $(size(c2))",
        ),
    )
    # Warn if the chains don't line up in terms of iteration indices
    ii1, ii2 = FlexiChains.iter_indices(c1), FlexiChains.iter_indices(c2)
    if ii1 != ii2
        @warn "concatenating FlexiChains with different iteration indices: got $(ii1) and $(ii2). The resulting chain will have the iteration indices of the first chain."
    end
    # Build up the new data dictionary
    d = OrderedDict{ParameterOrExtra{<:TKey},Matrix}()
    allkeys = OrderedSet{ParameterOrExtra{<:TKey}}(keys(c1))
    union!(allkeys, keys(c2))
    for k in allkeys
        c1_data = if haskey(c1, k)
            _get_raw_data(c1, k)
        else
            fill(missing, size(c1)...)
        end
        c2_data = if haskey(c2, k)
            _get_raw_data(c2, k)
        else
            fill(missing, size(c2)...)
        end
        d[k] = hcat(c1_data, c2_data)
    end
    # TODO: Do we want to use the chain indices passed in?
    return FlexiChain{TKey}(
        niters(c1),
        nchains(c1) + nchains(c2),
        d;
        iter_indices=FlexiChains.iter_indices(c1),
        chain_indices=1:(nchains(c1) + nchains(c2)),
        sampling_time=vcat(FlexiChains.sampling_time(c1), FlexiChains.sampling_time(c2)),
        last_sampler_state=vcat(
            FlexiChains.last_sampler_state(c1), FlexiChains.last_sampler_state(c2)
        ),
    )
end
Base.hcat(c1::FlexiChain) = c1
function Base.hcat(::FlexiChain{TKey1}, ::FlexiChain{TKey2}) where {TKey1,TKey2}
    throw(
        ArgumentError(
            "cannot hcat FlexiChains with different key types $(TKey1) and $(TKey2)"
        ),
    )
end
function Base.hcat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
    return Base.hcat(Base.hcat(c1, c2), cs...)
end

"""
    AbstractMCMC.chainscat(chains...)

Concatenate `FlexiChain`s along the chain dimension.
"""
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}
)::FlexiChain{TKey} where {TKey}
    return Base.hcat(c1, c2)
end
AbstractMCMC.chainscat(c1::FlexiChain) = c1
function AbstractMCMC.chainscat(
    c1::FlexiChain{TKey}, c2::FlexiChain{TKey}, cs::FlexiChain{TKey}...
) where {TKey}
    return AbstractMCMC.chainscat(AbstractMCMC.chainscat(c1, c2), cs...)
end
