# Utilities for 'flattening' chains.

"""
    FlexiChains._split_varnames(cs::ChainOrSummary{<:VarName})

Split up a chain, which in general may contain array- or other-valued parameters, into a
chain containing only scalar-valued parameters. This is done by replacing the original
`VarName` keys with appropriate _leaves_. For example, if `x` is a vector-valued parameter,
then it is replaced by `x[1]`, `x[2]`, etc.

This function is only used for summarising and plotting: note that calling this on an
original chain, and subsequently using that chain for functions such as `returned` or
`predict`, **will** lead to errors!
"""
function _split_varnames(cs::ChainOrSummary{<:VarName})
    vns = OrderedSet{VarName}()
    for vn in FlexiChains.parameters(cs)
        d = _get_raw_data(cs, Parameter(vn))
        for i in eachindex(d)
            for vn_leaf in AbstractPPL.varname_leaves(vn, d[i])
                push!(vns, vn_leaf)
            end
        end
    end
    return cs[[collect(vns)..., FlexiChains.extras(cs)...]]
end

"""
    FlexiChains._split_varnames(cs::ChainOrSummary{Union{Symbol,<:AbstractString}})

For `Symbol`-keyed chains, convert keys to `VarName`, split array-valued parameters into
scalar leaves, then convert the keys back to `Symbol`.

Likewise for `AbstractString`-keyed chains; the keys are converted back to standard
`String`.
"""
function _split_varnames(cs::ChainOrSummary{Symbol})
    N = cs isa FlexiChain ? 2 : 3
    new_data = OrderedDict{ParameterOrExtra{<:VarName}, Array{<:Any, N}}()
    for (k, v) in cs._data
        new_key = k isa Parameter ? Parameter(VarName{k.name}()) : k
        new_data[new_key] = v
    end
    vn_cs = FlexiChains._replace_data(cs, VarName, new_data)
    split_cs = _split_varnames(vn_cs)
    return FlexiChains.map_parameters(k -> Symbol(k), split_cs)
end
function _split_varnames(cs::ChainOrSummary{<:AbstractString})
    N = cs isa FlexiChain ? 2 : 3
    new_data = OrderedDict{ParameterOrExtra{<:VarName}, Array{<:Any, N}}()
    for (k, v) in cs._data
        new_key = k isa Parameter ? Parameter(VarName{Symbol(k.name)}()) : k
        new_data[new_key] = v
    end
    vn_cs = FlexiChains._replace_data(cs, VarName, new_data)
    split_cs = _split_varnames(vn_cs)
    return FlexiChains.map_parameters(k -> String(Symbol(k)), split_cs)
end

"""
    FlexiChains._split_varnames(cs::ChainOrSummary)

For all other chains that are not keyed by `VarName` or `Symbol`, we check if all keys are
real-valued anyway. If they are, then we can just return the original chain. If not, this
throws an error.
"""
function _split_varnames(cs::ChainOrSummary)
    for (k, v) in cs._data
        if eltype(v) <: Real
            continue
        else
            throw(ArgumentError("key $(k) in the chain has data of type $(eltype(v)), which is not scalar-valued; variable names cannot be split for this chain. Please use a chain with key type VarName or Symbol if you want to use variable name splitting."))
        end
    end
    return cs
end

"""
    DimensionalData.DimArray(
        chain::FlexiChain{TKey};
        warn::Bool=true,
        eltype_filter=Any,
        parameters_only::Bool=true,
    ) where {TKey}

Convert a FlexiChain into a 3-dimensional `DimArray` with dimensions `(:iter, :chain,
:param)`.

This proceeds by first splitting array-valued parameters into scalar leaves, then extracting
all scalar parameters whose element type subtypes `eltype_filter` and stacking them into a
3D array.

Keys whose values do not subtype `eltype_filter` after splitting are skipped (with a warning
if `warn=true`).

If `parameters_only=true` (the default), then two things happen:

- Only parameters (not extras) are included in the `DimArray`. Otherwise, both
  parameters and extras are included.

- The keys in the `:param` dimension of the resulting `DimArray` are just
  `TKey`, i.e., the `Parameter` wrapper is removed. Otherwise, the keys will
  be `Union{Parameter{<:TKey},Extra}`.
"""
function DD.DimArray(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        eltype_filter::Type{T} = Any,
        parameters_only::Bool = true,
    ) where {TKey, T}
    chain = FlexiChains._split_varnames(chain)
    kept_keys = if parameters_only
        TKey[]
    else
        ParameterOrExtra{<:TKey}[]
    end
    ni, nc = size(chain)
    kept_matrices = Matrix[]
    skipped_keys = ParameterOrExtra{<:TKey}[]
    for (k, v) in chain._data
        if eltype(v) <: T && (!parameters_only || k isa Parameter)
            k = if parameters_only && k isa Parameter
                FlexiChains.get_name(k)
            else
                k
            end
            push!(kept_keys, k)
            push!(kept_matrices, v)
        else
            if !(parameters_only && k isa Extra)
                push!(skipped_keys, k)
            end
        end
    end
    if warn && !isempty(skipped_keys)
        skipped_str = join(("`$k`" for k in skipped_keys), ", ")
        @warn "skipping keys $skipped_str as their values do not subtype $T"
    end
    np = length(kept_matrices)
    np == 0 && @warn "no keys with values subtyping $T found"
    # Here we could call `stack(kept_matrices)` to do mostly the same thing. Unfortunately
    # `stack` aggressively promotes element types, so if there are e.g. continuous
    # and discrete parameters it will promote everything to `Float64`. We work
    # around that by manually filling in an array.
    kept_data = Array{eltype_filter}(undef, ni, nc, np)
    for (i, m) in enumerate(kept_matrices)
        kept_data[:, :, i] = m
    end
    # Concretise as far as possible.
    kept_data = [x for x in kept_data]
    dims = (
        DD.Dim{ITER_DIM_NAME}(iter_indices(chain)),
        DD.Dim{CHAIN_DIM_NAME}(chain_indices(chain)),
        DD.Dim{PARAM_DIM_NAME}(kept_keys),
    )
    return DD.DimArray(kept_data, dims)
end

"""
    Base.Array(
        chain::FlexiChain;
        kwargs...
    )

Convert a `FlexiChain` into a standard `Array` with dimensions `(iter, chain, param)`. This
is the same as the conversion to [`DimensionalData.DimArray`](@ref), except that the
dimension metadata is discarded.

See [`DimensionalData.DimArray`](@ref) for more details on the conversion process and
available keyword arguments.
"""
function Base.Array(
        chain::FlexiChain{TKey};
        warn::Bool = true,
        eltype_filter::Type{T} = Any,
        parameters_only::Bool = true,
    ) where {TKey, T}
    da = DD.DimArray(chain; warn, eltype_filter, parameters_only)
    return parent(da)
end
