using MCMCDiagnosticTools: MCMCDiagnosticTools

"""
    _to_3darray(chain::FlexiChain{TKey}; warn=true, eltype_filter=Real) where {TKey}

Split array-valued parameters into scalar leaves, then extract all scalar parameters whose
element type subtypes `eltype_filter` and return them as a `DimArray` with dimensions
`(:iter, :chain, :param)`.

Parameters whose values do not subtype `eltype_filter` after splitting are skipped (with a
warning if `warn=true`).
"""
function _to_3darray(
        chain::FlexiChain{TKey}; warn::Bool = true, eltype_filter::Type{T} = Real,
    ) where {TKey, T}
    chain = FlexiChains._split_varnames(chain)
    kept_keys = ParameterOrExtra{<:TKey}[]
    kept_data = Matrix{<:Real}[]
    skipped_keys = ParameterOrExtra{<:TKey}[]
    for (k, v) in chain._data
        if eltype(v) <: T
            push!(kept_keys, k)
            push!(kept_data, v)
        else
            push!(skipped_keys, k)
        end
    end
    if warn && !isempty(skipped_keys)
        skipped_str = join(("`$k`" for k in skipped_keys), ", ")
        @warn "skipping keys $skipped_str as their values do not subtype $T"
    end
    if isempty(kept_keys)
        throw(ArgumentError("no parameters with values subtyping $T found"))
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
    MCMCDiagnosticTools.gelmandiag(
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
function MCMCDiagnosticTools.gelmandiag(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        kwargs...,
    ) where {TKey}
    dimarr = _to_3darray(chain; warn = warn)
    result = MCMCDiagnosticTools.gelmandiag(parent(dimarr); kwargs...)
    return _gelmandiag_summary(TKey, DD.lookup(dimarr, :param), result.psrf, result.psrfci)
end

"""
    MCMCDiagnosticTools.gelmandiag_multivariate(
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
function MCMCDiagnosticTools.gelmandiag_multivariate(
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

"""
    MCMCDiagnosticTools.discretediag(
        chain::FlexiChain{TKey};
        warn::Bool=true,
        kwargs...
    ) where {TKey}

Compute the discrete diagnostic for each parameter in the chain. This diagnostic is designed
for discrete (categorical) MCMC samples.

Returns a `NamedTuple` with two fields:
- `between`: a [`FlexiSummary`](@ref) with between-chain diagnostics (`:stat`, `:df`,
  `:pvalue`) per parameter
- `within`: a [`FlexiSummary`](@ref) with within-chain diagnostics (`:stat`, `:df`,
  `:pvalue`) per parameter and per chain

The `FlexiChain` must contain at least 2 chains. Array-valued parameters are automatically
split into their constituent scalars. Non-`Integer`-valued keys are skipped with a warning
(which can be suppressed via `warn=false`).

Other keyword arguments are forwarded to
[`MCMCDiagnosticTools.discretediag`](@extref).
"""
function MCMCDiagnosticTools.discretediag(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        kwargs...,
    ) where {TKey}
    dimarr = _to_3darray(chain; warn = warn, eltype_filter = Integer)
    between_vals, within_vals = MCMCDiagnosticTools.discretediag(
        parent(dimarr); kwargs...
    )
    kept_keys = DD.lookup(dimarr, :param)
    stat_names = _make_categorical([:stat, :df, :pvalue])

    # Between-chain summary: both iter and chain dimensions collapsed
    between_data = OrderedDict{ParameterOrExtra{<:TKey}, Array{Float64, 3}}()
    for (i, k) in enumerate(kept_keys)
        between_data[k] = reshape(
            Float64[between_vals.stat[i], between_vals.df[i], between_vals.pvalue[i]],
            1, 1, 3,
        )
    end
    between = FlexiSummary{TKey}(between_data, nothing, nothing, stat_names)

    # Within-chain summary: iter dimension collapsed, chain dimension kept
    num_chains = length(FlexiChains.chain_indices(chain))
    within_data = OrderedDict{ParameterOrExtra{<:TKey}, Array{Float64, 3}}()
    for (i, k) in enumerate(kept_keys)
        vals = Array{Float64, 3}(undef, 1, num_chains, 3)
        vals[1, :, 1] = within_vals.stat[i, :]
        vals[1, :, 2] = within_vals.df[i, :]
        vals[1, :, 3] = within_vals.pvalue[i, :]
        within_data[k] = vals
    end
    within = FlexiSummary{TKey}(
        within_data, nothing, FlexiChains.chain_indices(chain), stat_names,
    )

    return (; between, within)
end

"""
    MCMCDiagnosticTools.bfmi(
        chain::FlexiChain,
        energy_key
    )

Calculate the Bayesian fraction of missing information (BFMI) from the given chain, using
the specified `energy_key` to identify the key in the chain that corresponds to the
Hamiltonian energy. Returns a `DimVector` of BFMI values, one per chain (note that even if
there is only one chain, the result will still be a vector of length 1).

For chains sampled with Turing.jl's HMC/NUTS, the energy key is `:hamiltonian_energy`.
"""
function MCMCDiagnosticTools.bfmi(chain::FlexiChain, energy_key)
    return MCMCDiagnosticTools.bfmi(chain[energy_key])
end
