using DimensionalData: DimensionalData as DD
using Statistics: Statistics
using MCMCDiagnosticTools: MCMCDiagnosticTools

@public FlexiSummary, collapse, summarize

const STAT_DIM_NAME = :stat
function _make_categorical(v::AbstractVector{Symbol})
    return DD.Categorical(v; order=DD.Unordered())
end

"""
    FlexiChains.FlexiSummary{
        TKey,
        TIIdx<:Union{DimensionalData.Lookup,Nothing},
        TCIdx<:Union{DimensionalData.Lookup,Nothing},
        TSIdx<:Union{DimensionalData.Categorical,Nothing},
    }

A data structure containing summary statistics of a [`FlexiChain`](@ref).

## Construction

Calling summary functions such as `mean` or `std` on a `FlexiChain` will return a `FlexiSummary`.
For more flexibility, you can use [`FlexiChains.collapse`](@ref) to apply one or more summary functions to a `FlexiChain`.

Users should not need to construct `FlexiSummary` objects directly.

## Indexing

A `FlexiSummary{TKey}` can be indexed into using exactly the same techniques as a
`FlexiChain{TKey}`. That is to say:

- with `Parameter{TKey}` or `Extra` to unambiguously get the summary statistics for that
  key
- with `TKey` for automatic conversion to `Parameter{TKey}`
- with `Symbol` to find unambiguous matches
- if `TKey<:VarName`, using `VarName` or sub-`VarName`s to additionally extract part of the
  data.

The returned value will be either a `DimensionalData.DimArray` (if there are one or more
non-collapsed dimensions), or a single value (if all dimensions are collapsed).

If a `DimArray` is returned, the dimensions that you will see are: `:$(ITER_DIM_NAME)` (if the
summary function was only applied over chains), `:$(CHAIN_DIM_NAME)` (same but for
iterations), and `:$(STAT_DIM_NAME)` (typically seen when multiple summary functions were
applied).

# Extended help

## Internal data layout

A `FlexiSummary`, much like a `FlexiChain`, contains a mapping of keys to arrays of data.
However, the dimensions of a `FlexiSummary` are substantially different. In particular:

- The `:$(ITER_DIM_NAME)` and/or `:$(CHAIN_DIM_NAME)` dimensions may have been collapsed via
  the act of calculating a summary over iterations or chains.
- There is an additional, third, dimension: the _statistic_ dimension, represented by
  `:$(STAT_DIM_NAME). This dimension records which statistic(s) have been calculated.
- The `:$(STAT_DIM_NAME)` dimension may *also* have been collapsed. This can happen if
  only one statistic was computed and `drop_stat_dim=true` was used when calling
  [`FlexiChains.collapse`](@ref). The purpose of this is to avoid making the user deal with
  a redundant singleton dimension when calling a function such as `mean(chain)`.

Regardless of which dimensions have been collapsed, the internal data of a `FlexiSummary`
**always** contains all three dimensions (some of which may have size 1).

Information about which dimensions are collapsed is therefore not stored in the arrays.
Instead, it is stored in the `_iter_indices`, `_chain_indices`, and `_stat_indices` fields
of the `FlexiSummary`, as well as their types. If any of these are `nothing`, then that
dimension has been collapsed.

This information is later used in the `_get_raw_data` and `_raw_to_user_data` functions.
"""
struct FlexiSummary{
    TKey,
    TIIdx<:Union{DD.Lookup,Nothing},
    TCIdx<:Union{DD.Lookup,Nothing},
    TSIdx<:Union{DD.Categorical,Nothing},
}
    _data::Dict{ParameterOrExtra{<:TKey},<:AbstractArray{<:Any,3}}
    _iter_indices::TIIdx
    _chain_indices::TCIdx
    _stat_indices::TSIdx

    function FlexiSummary{TKey}(
        data::Dict{<:Any,<:AbstractArray{<:Any,3}},
        # Note: These are NOT keyword arguments, they are mandatory positional arguments
        iter_indices::TIIdx,
        chain_indices::TCIdx,
        stat_indices::TSIdx,
    )::FlexiSummary{
        TKey,TIIdx,TCIdx,TSIdx
    } where {
        TKey,
        TIIdx<:Union{DD.Lookup,Nothing},
        TCIdx<:Union{DD.Lookup,Nothing},
        TSIdx<:Union{DD.Categorical,Nothing},
    }
        # Get expected size.
        expected_size = (
            TIIdx === Nothing ? 1 : length(iter_indices),
            TCIdx === Nothing ? 1 : length(chain_indices),
            TSIdx === Nothing ? 1 : length(stat_indices),
        )
        # Size verification (while marshalling into a Dict with the right type).
        d = Dict{ParameterOrExtra{<:TKey},Array{<:Any,3}}()
        for (k, v) in pairs(data)
            if size(v) != expected_size
                msg = "got size $(size(v)) for key $k, expected $expected_size"
                throw(DimensionMismatch(msg))
            end
            d[k] = collect(v)
        end
        return new{TKey,TIIdx,TCIdx,TSIdx}(d, iter_indices, chain_indices, stat_indices)
    end
end
function iter_indices(fs::FlexiSummary{TKey,TIIdx})::TIIdx where {TKey,TIIdx}
    return fs._iter_indices
end
function chain_indices(fs::FlexiSummary{TKey,TIIdx,TCIdx})::TCIdx where {TKey,TIIdx,TCIdx}
    return fs._chain_indices
end
function stat_indices(
    fs::FlexiSummary{TKey,TIIdx,TCIdx,TSIdx}
)::TSIdx where {TKey,TIIdx,TCIdx,TSIdx}
    return fs._stat_indices
end

function Base.show(io::IO, ::MIME"text/plain", summary::FlexiSummary{TKey}) where {TKey}
    maybe_s(x) = x == 1 ? "" : "s"
    printstyled(io, "FlexiSummary"; bold=true)
    ii = iter_indices(summary)
    color_counter = 1
    if !isnothing(ii)
        printstyled(io, " | $(length(ii)) iterations ("; bold=true)
        printstyled(io, "$(_show_range(ii))"; color=DD.dimcolor(color_counter), bold=true)
        color_counter += 1
        printstyled(io, ")"; bold=true)
    end
    ci = chain_indices(summary)
    if !isnothing(ci)
        printstyled(io, " | $(length(ci)) iterations ("; bold=true)
        printstyled(io, "$(_show_range(ci))"; color=DD.dimcolor(color_counter), bold=true)
        color_counter += 1
        printstyled(io, ")"; bold=true)
    end
    si = summary._stat_indices
    if !isnothing(si)
        printstyled(io, " | $(length(si)) statistic$(maybe_s(length(si))) ("; bold=true)
        printstyled(
            io, "$(join(parent(si), ", "))"; color=DD.dimcolor(color_counter), bold=true
        )
        printstyled(io, ")"; bold=true)
    end
    println(io)
    println(io)

    # Print parameter names
    parameter_names = parameters(summary)
    printstyled(io, "Parameter type   "; bold=true)
    println(io, "$TKey")
    printstyled(io, "Parameters       "; bold=true)
    if isempty(parameter_names)
        println(io, "(none)")
    else
        println(io, join(parameter_names, ", "))
    end

    # Print extras
    extra_names = extras(summary)
    printstyled(io, "Extra keys       "; bold=true)
    if isempty(extra_names)
        println(io, "(none)")
    else
        println(io, join(map(e -> repr(e.name), extra_names), ", "))
    end

    # TODO: Dataframe-like printing
    return nothing
end

"""
    _get_raw_data(summary::FlexiSummary{<:TKey}, key::ParameterOrExtra{<:TKey})

Extract the raw data (i.e. an Array of samples) corresponding to a given key in the summary.
The returned data is always a 3D array with dimensions (NIter, NChain, NStat).

!!! important
    This function does not check if the key exists.
"""
function _get_raw_data(
    summary::FlexiSummary{<:TKey}, key::ParameterOrExtra{<:TKey}
) where {TKey}
    return summary._data[key]
end

"""
    _raw_to_user_data(summary::FlexiSummary, data::AbstractArray)

Convert `data`, which is a raw 3D array of samples, to either:

- a `DimensionalData.DimArray` using the indices stored in in the `FlexiSummary`, if there
  are one or more non-collapsed dimensions; or
- a single value, if all dimensions are collapsed.

!!! important
    This function performs no checks to make sure that the lengths of the indices stored in
the chain line up with the size of the matrix.
"""
function _raw_to_user_data(
    fs::FlexiSummary{TKey,TIIdx,TCIdx,TSIdx}, arr::Array{T,3}
) where {TKey,TIIdx,TCIdx,TSIdx,T}
    lookups = []
    dims_to_keep = []
    if TIIdx !== Nothing
        push!(dims_to_keep, 1)
        push!(lookups, DD.Dim{ITER_DIM_NAME}(iter_indices(fs)))
    end
    if TCIdx !== Nothing
        push!(dims_to_keep, 2)
        push!(lookups, DD.Dim{CHAIN_DIM_NAME}(chain_indices(fs)))
    end
    if TSIdx !== Nothing
        push!(dims_to_keep, 3)
        push!(lookups, DD.Dim{STAT_DIM_NAME}(stat_indices(fs)))
    end
    dims_to_drop = tuple(setdiff(1:3, dims_to_keep)...)
    dropped_arr = dropdims(arr; dims=dims_to_drop)
    return if isempty(lookups)
        dropped_arr[]
    else
        return DD.DimArray(dropped_arr, tuple(lookups...))
    end
end

function _get_names_and_funcs(names_or_funcs::AbstractVector)
    names = Symbol[]
    funcs = Function[]
    for nf in names_or_funcs
        if nf isa Function
            push!(names, Symbol(nf))
            push!(funcs, nf)
        elseif nf isa Tuple{Symbol,Function}
            push!(names, nf[1])
            push!(funcs, nf[2])
        else
            throw(
                ArgumentError(
                    "each element of `funcs` must be a Function or a (Symbol, Function) tuple",
                ),
            )
        end
    end
    # check that there are no repeats
    if length(names) != length(unique(names))
        throw(ArgumentError("function names must be unique"))
    end
    return names, funcs
end
function _get_expected_size(niters::Int, nchains::Int, collapsed_dims::Symbol)
    return if collapsed_dims == :iter
        (1, nchains)
    elseif collapsed_dims == :chain
        (niters, 1)
    elseif collapsed_dims == :both
        (1, 1)
    else
        throw(ArgumentError("`dims` must be `:iter`, `:chain`, or `:both`"))
    end
end
function _size_matches(collapsed::Any, expected_size::Tuple{Int,Int}, dims::Symbol)
    return (dims == :both) || size(collapsed) == expected_size
end

struct CollapseFailedError{T,E<:Exception} <: Exception
    key::T
    fname::Symbol
    exception::E
end

"""
    FlexiChains.collapse(
        chain::FlexiChain,
        funcs::AbstractVector;
        dims::Symbol=:both,
        warn::Bool=true,
        drop_stat_dim::Bool=false,
    )

Low-level function to collapse one or both dimensions of a `FlexiChain` by applying a list
of summary functions.

The `funcs` argument must be a vector which contains either:
 - tuples of the form `(statistic_name::Symbol, func::Function)`; or
 - just functions, in which case the statistic name is obtained from the function name.

The `dims` keyword argument specifies which dimensions to collapse. By default, `dims` is `:both`, which
collapses both the iteration and chain dimensions. Other valid values are `:iter` or `:chain`, which 
respectively collapse only the iteration or chain dimension.

The functions in `funcs` **must** map an (NIter × NChains) matrix to:
 - a single item if `dims=:both`;
 - a (1 × NChains) matrix if `dims=:iter`;
 - an (NIter × 1) matrix if `dims=:chain`.

This means that the exact function used will differ depending on the value of `dims`. For
example, suppose that `chn` is a FlexiChain. Then the following are all valid:

```julia
using FlexiChains: collapse
using Statistics: mean, std

collapse(chn, [mean, std]; dims=:both)
collapse(chn, [x -> mean(x; dims=1), x -> std(x; dims=1)]; dims=:iter)
collapse(chn, [x -> mean(x; dims=2), x -> std(x; dims=2)]; dims=:chain)
```

Note that, in the latter two cases, the inferred statistic name will _not_ be `mean` or
`std` but rather some unintelligible name of an anonymous function. This is why it is
recommended to use the `(statistic_name::Symbol, func::Function)` tuple form in these cases,
such as in the following:

```julia
collapse(chn, [
    (:mean, x -> mean(x; dims=1)),
    (:std, x -> std(x; dims=1))
]; dims=:iter)
```

If a statistic function errors when applied to a key, that key is skipped and a warning
is issued. The warning can be suppressed by setting `warn=false`.

If the `drop_stat_dim` keyword argument is `true` and only one function is provided in
`funcs`, then the resulting `FlexiSummary` will have the `stat` dimension dropped. This allows
for easier indexing into the result when only one statistic is computed. It is an error to set
`drop_stat_dim=true` when more than one function is provided.

The return type is a [`FlexiSummary`](@ref).
"""
function collapse(
    chain::FlexiChain{TKey},
    funcs::AbstractVector;
    dims::Symbol=:both,
    warn::Bool=true,
    drop_stat_dim::Bool=false,
) where {TKey}
    data = Dict{ParameterOrExtra{<:TKey},AbstractArray{<:Any,3}}()
    names, funcs = _get_names_and_funcs(funcs)
    expected_size = _get_expected_size(niters(chain), nchains(chain), dims)
    # Not proud of this function, but it does what it needs to do... sigh.
    for (k, v) in chain._data
        try
            output = Array{Any,3}(undef, (expected_size..., length(funcs)))
            for (i, f) in enumerate(funcs)
                try
                    collapsed = f(v)
                    if !_size_matches(collapsed, expected_size, dims)
                        msg = "function $f returned size $(size(collapsed)) for key $k, expected $(expected_size)"
                        throw(DimensionMismatch(msg))
                    end
                    if dims == :both
                        collapsed = reshape([collapsed], 1, 1)
                    end
                    output[:, :, i] = collapsed
                catch e
                    throw(CollapseFailedError(k, names[i], e))
                end
            end
            data[k] = map(identity, output)
        catch e
            if e isa CollapseFailedError
                # TODO: Print e.exception; but the problem is that that can be very long! If
                # there's a nice way to truncate it, then we could add that to the info.
                warn &&
                    @warn "skipping key `$(e.key)` as applying the function `$(e.fname)` to it encountered an error"
            else
                rethrow()
            end
        end
    end
    iter_idxs = dims == :chain ? FlexiChains.iter_indices(chain) : nothing
    chain_idxs = dims == :iter ? FlexiChains.chain_indices(chain) : nothing
    stat_lookup = if drop_stat_dim
        if length(funcs) != 1
            throw(
                ArgumentError(
                    "`drop_stat_dim=true` only allowed when one function is provided"
                ),
            )
        else
            nothing
        end
    else
        _make_categorical(names)
    end
    return FlexiSummary{TKey}(data, iter_idxs, chain_idxs, stat_lookup)
end

function _stat_docstring(func_name, short_name)
    return """
    $(func_name)(chain::FlexiChain; dims::Symbol=:both, warn::Bool=true, kwargs...)

Calculate the $(short_name) across all iterations and chains for each key in
the `chain`. If the statistic cannot be computed for a key, that key is
skipped and a warning is issued (which can be suppressed by setting
`warn=false`).

The `dims` keyword argument specifies which dimensions to collapse.
- `:iter`: collapse the iteration dimension only
- `:chain`: collapse the chain dimension only
- `:both`: collapse both the iteration and chain dimensions (default)

Other keyword arguments are forwarded to `$(func_name)`.
"""
end

"""
    @forward_stat_function_dims(func)

Helper macro to define the functions `func(chain; dims, warn, kwargs...)`. This macro
assumes that `func` has the following behaviour:

- `func` maps a Matrix to a single value;
- `x -> func(x; dims=1) maps a (m × n) matrix to a (1 × n) matrix; and
- `x -> func(x; dims=2) maps a (m × n) matrix to a (m × 1) matrix.

This is true of e.g. `Statistics.mean`, `Statistics.std`, `Base.sum`, etc.
"""
macro forward_stat_function_dims(func)
    quote
        function $(esc(func))(
            chn::FlexiChain; dims::Symbol=:both, warn::Bool=true, kwargs...
        )
            funcs = if dims == :both
                [(Symbol($(esc(func))), x -> $(esc(func))(x; kwargs...))]
            elseif dims == :iter
                [(Symbol($(esc(func))), x -> $(esc(func))(x; dims=1, kwargs...))]
            elseif dims == :chain
                [(Symbol($(esc(func))), x -> $(esc(func))(x; dims=2, kwargs...))]
            else
                throw(ArgumentError("`dims` must be `:iter`, `:chain`, or `:both`"))
            end
            return collapse(chn, funcs; dims=dims, warn=warn, drop_stat_dim=true)
        end
    end
end
"""
    @forward_stat_function_each(func)

Helper macro to define the functions `func(chain; dims, warn, kwargs...)`. This macro
assumes that `func` has the following behaviour:

- `func` maps a Matrix to a single value; and
- `func` maps a Vector to a single value;

In other words, `func` does not accept the `dims` keyword argument. This is true of e.g.
`MCMCDiagnosticTools.ess`. In its place this function manually maps `func` over each
row/column where necessary.
"""
macro forward_stat_function_each(func)
    quote
        function $(esc(func))(
            chn::FlexiChain; dims::Symbol=:both, warn::Bool=true, kwargs...
        )
            funcs = if dims == :both
                [(Symbol($(esc(func))), x -> $(esc(func))(x; kwargs...))]
            elseif dims == :iter
                [(
                    Symbol($(esc(func))),
                    x -> reshape(
                        map(c -> $(esc(func))(c; kwargs...), eachcol(x)),
                        1,
                        size(x, 2),
                    ),
                )]
            elseif dims == :chain
                [(
                    Symbol($(esc(func))),
                    x -> reshape(
                        map(r -> $(esc(func))(r; kwargs...), eachrow(x)),
                        size(x, 1),
                        1,
                    ),
                )]
            else
                throw(ArgumentError("`dims` must be `:iter`, `:chain`, or `:both`"))
            end
            return collapse(chn, funcs; dims=dims, warn=warn, drop_stat_dim=true)
        end
    end
end

"""
$(_stat_docstring("Statistics.mean", "mean"))
"""
@forward_stat_function_dims Statistics.mean
"""
$(_stat_docstring("Statistics.median", "median"))
"""
@forward_stat_function_dims Statistics.median
"""
$(_stat_docstring("Statistics.std", "standard deviation"))
"""
@forward_stat_function_dims Statistics.std
"""
$(_stat_docstring("Statistics.var", "variance"))
"""
@forward_stat_function_dims Statistics.var
"""
$(_stat_docstring("Base.minimum", "minimum"))
"""
@forward_stat_function_dims Base.minimum
"""
$(_stat_docstring("Base.maximum", "maximum"))
"""
@forward_stat_function_dims Base.maximum
"""
$(_stat_docstring("Base.sum", "sum"))
"""
@forward_stat_function_dims Base.sum
"""
$(_stat_docstring("Base.prod", "product"))
"""
@forward_stat_function_dims Base.prod

# Quantile is just different! Grr.
"""
    Statistics.quantile(chain::FlexiChain, p; dims::Symbol=:both, warn::Bool=true, kwargs...)

Calculate the quantile across all iterations and chains for each key in the `chain`. If it
cannot be computed for a key, that key is skipped and a warning is issued (which can be
suppressed by setting `warn=false`).

The `dims` keyword argument specifies which dimensions to collapse.
- `:iter`: collapse the iteration dimension only
- `:chain`: collapse the chain dimension only
- `:both`: collapse both the iteration and chain dimensions (default)

The argument `p` specifies the quantile to compute, and is forwarded to
`Statistics.quantile`, along with any other keyword arguments.
"""
function Statistics.quantile(
    chn::FlexiChain, p; dims::Symbol=:both, warn::Bool=true, kwargs...
)
    funcs = if dims == :both
        # quantile only acts on a vector so we have to linearise the matrix x
        [(:quantile, x -> Statistics.quantile(x[:], p; kwargs...))]
    elseif dims == :iter
        [(
            :quantile,
            x -> reshape(
                map(c -> Statistics.quantile(c, p; kwargs...), eachcol(x)),
                1,
                size(x, 2),
            ),
        )]
    elseif dims == :chain
        [(
            :quantile,
            x -> reshape(
                map(r -> Statistics.quantile(r, p; kwargs...), eachrow(x)),
                size(x, 1),
                1,
            ),
        )]
    else
        throw(ArgumentError("`dims` must be `:iter`, `:chain`, or `:both`"))
    end
    return collapse(chn, funcs; dims=dims, warn=warn, drop_stat_dim=true)
end

"""
$(_stat_docstring("MCMCDiagnosticTools.ess", "effective sample size"))

For a full list of keyword arguments, please see the documentation for
[`MCMCDiagnosticTools.ess`](@extref).
"""
@forward_stat_function_each MCMCDiagnosticTools.ess
"""
$(_stat_docstring("MCMCDiagnosticTools.rhat", "R-hat diagnostic"))

For a full list of keyword arguments, please see the documentation for
[`MCMCDiagnosticTools.rhat`](@extref).
"""
@forward_stat_function_each MCMCDiagnosticTools.rhat
"""
$(_stat_docstring("MCMCDiagnosticTools.mcse", "Monte Carlo standard error"))

For a full list of keyword arguments, please see the documentation for
[`MCMCDiagnosticTools.mcse`](@extref).
"""
@forward_stat_function_each MCMCDiagnosticTools.mcse

"""
    summarize(chain::FlexiChain)

Compute a standard set of summary statistics for each key in the `chain`. The statistics include:

- mean
- standard deviation
- Monte Carlo standard error
- bulk effective sample size
- tail effective sample size
- R-hat diagnostic
"""
function summarize(chain::FlexiChain)
    return collapse(
        chain,
        [
            (:mean, Statistics.mean),
            (:std, Statistics.std),
            (:mcse, MCMCDiagnosticTools.mcse),
            (:ess_bulk, x -> MCMCDiagnosticTools.ess(x; kind=:bulk)),
            (:ess_tail, x -> MCMCDiagnosticTools.ess(x; kind=:tail)),
            (:rhat, MCMCDiagnosticTools.rhat),
        ];
        dims=:both,
        warn=false,
    )
end
