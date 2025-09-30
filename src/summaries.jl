using DimensionalData: DimensionalData as DD
using Statistics: Statistics

@public FlexiSummary, collapse

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

A `FlexiSummary{TKey}` can be indexed into using exactly the same techniques as a
`FlexiChain{TKey}`. That is to say:

- with `Parameter{TKey}` or `Extra` to unambiguously get the summary statistics for that
  key
- with `TKey` for automatic conversion to `Parameter{TKey}`
- with `Symbol` to find unambiguous matches
- if `TKey<:VarName`, using `VarName` or sub-`VarName`s to additionally extract part of the
  data.
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
        # Note: These are NOT keyword arguments, they are mandatory
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
        d = Dict{ParameterOrExtra{<:TKey},AbstractArray{<:Any,3}}()
        for (k, v) in pairs(data)
            if size(v) != expected_size
                msg = "got size $(size(v)) for key $k, expected $expected_size"
                throw(DimensionMismatch(msg))
            end
            d[k] = v
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
    printstyled(io, "FlexiSummary "; bold=true)
    ii = iter_indices(summary)
    if !isnothing(ii)
        printstyled(io, " | $(length(ii)) iterations ("; bold=true)
        printstyled(io, "$(_show_range(ii))"; color=DD.dimcolor(1), bold=true)
        printstyled(io, ")"; bold=true)
    end
    ci = chain_indices(summary)
    if !isnothing(ci)
        printstyled(io, " | $(length(ci)) iterations ("; bold=true)
        printstyled(io, "$(_show_range(ci))"; color=DD.dimcolor(2), bold=true)
        printstyled(io, ")"; bold=true)
    end
    si = summary._stat_indices
    if !isnothing(si)
        printstyled(io, " | $(length(si)) statistic$(maybe_s(length(si))) ("; bold=true)
        printstyled(io, "$(join(parent(si), ", "))"; color=DD.dimcolor(3), bold=true)
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

const STAT_DIM_NAME = :stat
function _get_data(
    fs::FlexiSummary{TKey,TIIdx,TCIdx,TSIdx}, key::ParameterOrExtra{<:TKey}
) where {TKey,TIIdx,TCIdx,TSIdx}
    dim_indices = []
    dims = []
    if TIIdx !== Nothing
        push!(dim_indices, 1)
        push!(dims, DD.Dim{ITER_DIM_NAME}(iter_indices(fs)))
    end
    if TCIdx !== Nothing
        push!(dim_indices, 2)
        push!(dims, DD.Dim{CHAIN_DIM_NAME}(chain_indices(fs)))
    end
    if TSIdx !== Nothing
        push!(dim_indices, 3)
        push!(dims, DD.Dim{STAT_DIM_NAME}(stat_indices(fs)))
    end
    dropped_dim_indices = tuple(setdiff(1:3, dim_indices)...)
    array = dropdims(fs._data[key]; dims=dropped_dim_indices)
    return if isempty(dims)
        array[]
    else
        return DD.DimArray(array, tuple(dims...))
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

If the `drop_stat_dim` keyword argument is `true` and only one function is provided in
`funcs`, then the resulting `FlexiSummary` will have the `stat` dimension dropped. This allows
for easier indexing into the result when only one statistic is computed. It is an error to set
`drop_stat_dim=true` when more than one function is provided.

The return type is a [`FlexiSummary`](@ref).
"""
function collapse(
    chain::FlexiChain{TKey,NIter,NChains},
    funcs::AbstractVector;
    dims::Symbol=:both,
    drop_stat_dim::Bool=false,
) where {TKey,NIter,NChains}
    data = Dict{ParameterOrExtra{<:TKey},AbstractArray{<:Any,3}}()
    names, funcs = _get_names_and_funcs(funcs)
    expected_size = _get_expected_size(NIter, NChains, dims)
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
                @warn "skipping key `$(e.key)` as applying the function `$(e.fname)` to it encountered an error: $(e.exception)"
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

macro forward_stat_function(func, func_name, short_name)
    docstring = """
                $(func_name)(chain::FlexiChain; dims::Symbol=:both, warn::Bool=false)

                Calculate the $(short_name) across all iterations and chains for each numeric
                key in `chain`. If `warn=true`, issues a warning for all non-numeric keys
                encountered.

                The `dims` keyword argument specifies which dimensions to collapse.
                - `:iter`: collapse the iteration dimension only
                - `:chain`: collapse the chain dimension only
                - `:both`: collapse both the iteration and chain dimensions (default)

                Other keyword arguments are forwarded to `$(func_name)`.
                """
    quote
        @doc $docstring function $(esc(func))(
            chn::FlexiChain; dims::Symbol=:both, kwargs...
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
            return collapse(chn, funcs; dims=dims, drop_stat_dim=true)
        end
    end
end

@forward_stat_function Statistics.mean "Statistics.mean" "mean"
@forward_stat_function Statistics.median "Statistics.median" "median"
@forward_stat_function Statistics.std "Statistics.std" "standard deviation"
@forward_stat_function Statistics.var "Statistics.var" "variance"
@forward_stat_function Base.minimum "Base.minimum" "minimum"
@forward_stat_function Base.maximum "Base.maximum" "maximum"
@forward_stat_function Base.sum "Base.sum" "sum"
@forward_stat_function Base.prod "Base.prod" "product"

# Convenience re-exports.
using Statistics: mean, median, std, var
export mean, median, std, var
