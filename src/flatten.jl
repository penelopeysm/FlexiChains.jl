# Utilities for 'flattening' chains.
import Tables

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

## Tables.jl interface

function _prepare_chain(chn::FlexiChain; split_varnames::Bool = true, parameters_only::Bool = true)
    if parameters_only
        chn = FlexiChains.subset_parameters(chn)
    end
    if split_varnames
        chn = FlexiChains._split_varnames(chn)
    end
    return chn
end

function _check_duplicate_keys(ks)
    seen = Set{eltype(ks)}()
    duplicates = eltype(ks)[]
    for k in ks
        if k in seen
            push!(duplicates, k)
        else
            push!(seen, k)
        end
    end
    return if !isempty(duplicates)
        throw(
            ArgumentError(
                "duplicate column names after converting keys to Symbols: " *
                    join(unique(duplicates), ", "),
            )
        )
    end
end

const WIDE_LONG_KWARGS_DOC = """
## Keyword arguments

- `split_varnames`: whether to split array-valued parameters into scalar leaves. If `true`
  (the default), then array-valued parameters are split into scalar leaves, e.g. a
  vector-valued parameter `x` would be split into `x[1]`, `x[2]`, etc.

- `parameters_only`: whether to include only parameters (and skip extras) in the resulting
  table. Defaults to `true`.
"""

"""
    FlexiChains.Wide(
        chn::FlexiChain;
        split_varnames::Bool=true,
        parameters_only::Bool=true
    )

A wrapper struct indicating that a `FlexiChain` should be converted to a 'wide' table
format, where each parameter is a separate column.

## Example

```julia
using Turing, FlexiChains, DataFrames

@model function f()
    x ~ Normal()
    b ~ Bernoulli()
end
chn = sample(f(), Prior(), MCMCThreads(), 10, 2; chain_type=VNChain)

df = DataFrame(Wide(chn))
```

returns a DataFrame that looks like the following. Each parameter is a different column, and
the `iter` and `chain` dimensions are represented as separate columns as well; `iter` varies
faster than `chain`.

!!! note
    Because all parameter names must be converted to `Symbol` for column names, this
    may lead to clashes between e.g. parameters and extras which convert to the same
    `Symbol`. FlexiChains will error in such a situation.

```
20×4 DataFrame
 Row │ iter   chain  x          b
     │ Int64  Int64  Float64    Bool
─────┼────────────────────────────────
   1 │     1      1  -1.38809   false
   2 │     2      1  -0.511805   true
   3 │     3      1  -1.37277   false
  ⋮  │   ⋮      ⋮        ⋮        ⋮
  18 │     8      2   2.31312   false
  19 │     9      2   1.58254    true
  20 │    10      2  -1.14516   false
```

$(WIDE_LONG_KWARGS_DOC)
"""
struct Wide{F <: FlexiChain, N <: NamedTuple}
    chn::F
    # A precomputed mapping from Symbol(k) => k for all keys in `chn`.
    symbol_to_keys::N

    function Wide(chn::FlexiChain; split_varnames::Bool = true, parameters_only::Bool = true)
        chn = _prepare_chain(chn; split_varnames, parameters_only)
        # Strip parameter/extra wrappers and convert to Symbol for column names.
        ks = Tuple(FlexiChains.get_name.(keys(chn)))
        sym_ks = Symbol.(ks)
        _check_duplicate_keys(sym_ks)
        symbol_to_keys = NamedTuple{sym_ks}(ks)
        return new{typeof(chn), typeof(symbol_to_keys)}(chn, symbol_to_keys)
    end
end

"""
    FlexiChains.Long(
        chn::FlexiChain;
        split_varnames::Bool=true,
        parameters_only::Bool=true
    )

A wrapper struct indicating that a `FlexiChain` should be converted to a 'long' table
format, where all values are stacked into a single column, and there is an additional column
indicating the parameter name.

!!! note
    Because all parameter values are stacked into a single column, note that the resulting
    element type of the `value` column will be the common supertype of all parameter values.
    This can cause data to be promoted to a type that is not the same as its original type.
    For example, the `b` parameter below is converted to `Float64`.

## Example

```julia
using Turing, FlexiChains, DataFrames

@model function f()
    x ~ Normal()
    b ~ Bernoulli()
end
chn = sample(f(), Prior(), MCMCThreads(), 10, 2; chain_type=VNChain)

df = DataFrame(Long(chn))
```

returns a DataFrame that looks like the following. The `iter` and `chain` dimensions are
represented as separate columns as before, but now the parameter names are stacked into a
single `param` column, and the values are stacked into a single `value` column.

The `iter` column varies faster than the `chain` column, which in turn varies faster than
the `param` column.

```
40×4 DataFrame
 Row │ iter   chain  param     value
     │ Int64  Int64  VarName…  Float64
─────┼─────────────────────────────────
   1 │     1      1  x         -1.38809
   2 │     2      1  x         -0.511805
   3 │     3      1  x         -1.37277
  ⋮  │   ⋮      ⋮      ⋮         ⋮
  38 │     8      2  b          0.0
  39 │     9      2  b          1.0
  40 │    10      2  b          0.0
```

$(WIDE_LONG_KWARGS_DOC)

Additionally, when `parameters_only=true` (the default), the `Parameter` wrapper is stripped
from keys. Otherwise, the `Parameter`/`Extra` wrappers are retained. If you want to unwrap
them, you can use [`FlexiChains.get_name`](@ref) on the `param` column of the resulting
table.
"""
struct Long{F <: FlexiChain, K <: Tuple}
    chn::F
    # The keys for the param column: unwrapped if parameters_only, wrapped otherwise.
    original_keys::K

    function Long(chn::FlexiChain; split_varnames::Bool = true, parameters_only::Bool = true)
        chn = _prepare_chain(chn; split_varnames, parameters_only)
        original_keys = if parameters_only
            Tuple(FlexiChains.get_name.(keys(chn)))
        else
            Tuple(keys(chn))
        end
        _check_duplicate_keys(original_keys)
        return new{typeof(chn), typeof(original_keys)}(chn, original_keys)
    end
end

Tables.istable(::Type{<:Wide}) = true
Tables.istable(::Type{<:Long}) = true
Tables.columnaccess(::Type{<:Wide}) = true
Tables.columnaccess(::Type{<:Long}) = true

# Default Tables.jl implementation for FlexiChain itself
Tables.columns(chn::FlexiChain) = Wide(chn; split_varnames = true, parameters_only = true)

# Wide
Tables.columnnames(s::Wide) = [FlexiChains.ITER_DIM_NAME, FlexiChains.CHAIN_DIM_NAME, keys(s.symbol_to_keys)...]
function Tables.getcolumn(s::Wide, col::Symbol)
    return if col === FlexiChains.ITER_DIM_NAME
        repeat(iter_indices(s.chn); outer = FlexiChains.nchains(s.chn))
    elseif col === FlexiChains.CHAIN_DIM_NAME
        repeat(chain_indices(s.chn); inner = FlexiChains.niters(s.chn))
    else
        vec(s.chn[s.symbol_to_keys[col]])
    end
end
Tables.getcolumn(s::Wide, col::Int) = Tables.getcolumn(s, Tables.columnnames(s)[col])
Tables.columns(s::Wide) = s

# Long
const VALUE_COL_NAME = :value
Tables.columnnames(::Long) = [FlexiChains.ITER_DIM_NAME, FlexiChains.CHAIN_DIM_NAME, FlexiChains.PARAM_DIM_NAME, VALUE_COL_NAME]
function Tables.getcolumn(s::Long, col::Symbol)
    nkeys = length(s.original_keys)
    return if col === FlexiChains.ITER_DIM_NAME
        repeat(iter_indices(s.chn); outer = FlexiChains.nchains(s.chn) * nkeys)
    elseif col === FlexiChains.CHAIN_DIM_NAME
        repeat(chain_indices(s.chn); inner = FlexiChains.niters(s.chn), outer = nkeys)
    elseif col === FlexiChains.PARAM_DIM_NAME
        repeat(collect(s.original_keys); inner = FlexiChains.niters(s.chn) * FlexiChains.nchains(s.chn))
    elseif col === VALUE_COL_NAME
        mapreduce(vcat, s.original_keys) do k
            vec(s.chn[k])
        end
    else
        throw(ArgumentError("unknown column name: $col"))
    end
end
function Tables.getcolumn(s::Long, col::Int)
    return Tables.getcolumn(s, Tables.columnnames(s)[col])
end
Tables.columns(s::Long) = s
