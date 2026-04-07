"""
    _to_3darray(chain::FlexiChain{TKey}; warn) where {TKey}

Split array-valued parameters into scalar leaves, then extract all scalar Real-valued
parameters from a `FlexiChain` and return them as a `DimArray` with dimensions
`(:iter, :chain, :param)`.

Parameters whose values are not `<:Real` after splitting are skipped (with a warning if
`warn=true`).
"""
function _to_3darray(chain::FlexiChain{TKey}; warn::Bool = true) where {TKey}
    chain = FlexiChains._split_varnames(chain)
    kept_keys = ParameterOrExtra{<:TKey}[]
    kept_data = Matrix{<:Real}[]
    for (k, v) in chain._data
        if eltype(v) <: Real
            push!(kept_keys, k)
            push!(kept_data, v)
        elseif warn
            @warn "skipping key `$k` as its values are not Real-valued"
        end
    end
    if isempty(kept_keys)
        throw(ArgumentError("no Real-valued parameters found"))
    end
    arr = stack(kept_data)
    dims = (
        DD.Dim{ITER_DIM_NAME}(iter_indices(chain)),
        DD.Dim{CHAIN_DIM_NAME}(chain_indices(chain)),
        DD.Dim{:param}(kept_keys),
    )
    return DD.DimArray(arr, dims)
end

# Convert the output of `MCMCDiagnosticTools.gelmandiag` into a FlexiSummary
function _gelmandiag_summary(
        ::Type{TKey}, kept_keys, psrf, psrfci
    ) where {TKey}
    data = OrderedDict{ParameterOrExtra{<:TKey}, Array{Float64, 3}}()
    for (i, k) in enumerate(kept_keys)
        data[k] = reshape([psrf[i], psrfci[i]], 1, 1, 2)
    end
    return FlexiSummary{TKey}(
        data, nothing, nothing, _make_categorical([:psrf, :psrfci])
    )
end

"""
    gelmandiag(
        chain::FlexiChain{TKey};
        warn::Bool=true,
        kwargs...
    ) where {TKey}

Compute the Gelman–Rubin–Brooks diagnostic (Potential Scale Reduction Factor, PSRF) for each
parameter in the chain.

Returns a [`FlexiSummary`](@ref) with two statistics per parameter: `:psrf` (the point
estimate) and `:psrfci` (the upper confidence limit).

The `FlexiChain` must contain at least 2 chains. Array-valued parameters are automatically
split into their constituent scalars. Non-`Real`-valued keys are skipped with a warning
(which can be suppressed via `warn=false`).

Other keyword arguments are forwarded to
[`MCMCDiagnosticTools.gelmandiag`](@extref).
"""
function gelmandiag(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        kwargs...,
    ) where {TKey}
    dimarr = _to_3darray(chain; warn = warn)
    result = MCMCDiagnosticTools.gelmandiag(parent(dimarr); kwargs...)
    return _gelmandiag_summary(TKey, DD.lookup(dimarr, :param), result.psrf, result.psrfci)
end

"""
    gelmandiag_multivariate(
        chain::FlexiChain{TKey};
        warn::Bool=true,
        kwargs...
    ) where {TKey}

Compute the multivariate Gelman–Rubin–Brooks diagnostic for the chain. This requires at
least 2 parameters and at least 2 chains.

Returns a `NamedTuple` with two fields:
- `summary`: a [`FlexiSummary`](@ref) with `:psrf` and `:psrfci` statistics (same as
  what [`gelmandiag`](@ref) returns)
- `psrf_multivariate`: the multivariate potential scale reduction factor (`Float64`)

Array-valued parameters are automatically split into their constituent scalars.
Non-`Real`-valued keys are skipped with a warning (which can be suppressed via
`warn=false`).

Other keyword arguments are forwarded to
[`MCMCDiagnosticTools.gelmandiag_multivariate`](@extref).
"""
function gelmandiag_multivariate(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        kwargs...,
    ) where {TKey}
    dimarr = _to_3darray(chain; warn = warn)
    result = MCMCDiagnosticTools.gelmandiag_multivariate(parent(dimarr); kwargs...)
    summary = _gelmandiag_summary(
        TKey, DD.lookup(dimarr, :param), result.psrf, result.psrfci
    )
    return (; summary, psrf_multivariate = result.psrfmultivariate)
end
