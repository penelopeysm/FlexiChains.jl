using DimensionalData: DimensionalData as DD
using Statistics: Statistics

@public collapse_iter, collapse_chain, collapse

abstract type FlexiChainSummary{TKey,NIter,NChains} end

"""
    FlexiChainSummaryI{TKey,NIter,NChains,TCIdx<:DimensionalData.Lookup}

A summary where the iteration dimension has been collapsed. The type parameter `NIter`
refers to the original number of iterations (which have been collapsed).

If NChains > 1, indexing into this returns a (1 × NChains) matrix for each key; otherwise
it returns a scalar.
"""
struct FlexiChainSummaryI{TKey,NIter,NChains,TCIdx<:DD.Lookup} <:
       FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{ParameterOrExtra{<:TKey},<:SizedMatrix{1,NChains,<:Any}}
    _chain_indices::TCIdx

    # Constructor checks that `chain_indices` has the right length.
    # Ideally we'd use:
    # data::Dict{<:ParameterOrExtra{<:TKey},<:SizedMatrix{1,NChains,<:Any}},
    # as the argument. But that errors on Julia 1.10.
    function FlexiChainSummaryI{TKey,NIter,NChains}(
        data::Dict{<:Any,<:SizedMatrix{1,NChains,<:Any}}, chain_indices::TCIdx
    ) where {TKey,NIter,NChains,TCIdx<:DD.Lookup}
        # need to cast underlying dict to the right type
        data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{1,NChains,<:Any}}(data)
        if length(chain_indices) != NChains
            throw(DimensionMismatch("`chain_indices` must have length $NChains"))
        end
        return new{TKey,NIter,NChains,typeof(chain_indices)}(data, chain_indices)
    end
end
"""
    FlexiChains.chain_indices(
        summary::FlexiChainSummaryI{TKey,NIter,NChains,TCIdx}
    )::TCIdx where {TKey,NIter,NChains,TCIdx}

Return the chain indices of a `FlexiChainSummaryI`.
"""
function FlexiChains.chain_indices(
    fcsi::FlexiChainSummaryI{T,NI,NC,TCIdx}
)::TCIdx where {T,NI,NC,TCIdx}
    return fcsi._chain_indices
end

"""
    FlexiChainSummaryC{TKey,NIter,NChains,TIIdx<:DimensionalData.Lookup}

A summary where the chain dimension has been collapsed. The type parameter `NChain` refers to
the original number of chains (which have been collapsed).

If NChains > 1, indexing into this returns a (NIter × 1) matrix for each key; otherwise it
returns a vector.
"""
struct FlexiChainSummaryC{TKey,NIter,NChains,TIIdx<:DD.Lookup} <:
       FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{ParameterOrExtra{<:TKey},<:SizedMatrix{NIter,1,<:Any}}
    _iter_indices::TIIdx

    # Constructor checks that `iter_indices` has the right length.
    function FlexiChainSummaryC{TKey,NIter,NChains}(
        data::Dict{<:Any,<:SizedMatrix{NIter,1,<:Any}}, iter_indices::TIIdx
    ) where {TKey,NIter,NChains,TIIdx<:DD.Lookup}
        # need to cast underlying dict to the right type
        data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,1,<:Any}}(data)
        if length(iter_indices) != NIter
            throw(DimensionMismatch("`iter_indices` must have length $NIter"))
        end
        return new{TKey,NIter,NChains,typeof(iter_indices)}(data, iter_indices)
    end
end
"""
    FlexiChains.iter_indices(
        summary::FlexiChainSummaryC{TKey,NIter,NChains,TIIdx}
    )::TIIdx where {TKey,NIter,NChains,TIIdx}

Return the iteration indices of a `FlexiChainSummaryC`.
"""
function FlexiChains.iter_indices(
    fcsc::FlexiChainSummaryC{T,NI,NC,TIIdx}
)::TIIdx where {T,NI,NC,TIIdx}
    return fcsc._iter_indices
end

"""
    FlexiChainSummaryIC{TKey,NIter,NChains}

A summary where both the iteration and chain dimensions have been collapsed. The type
parameters `NIter` and `NChains` refer to the original number of iterations and chains
(which have been collapsed).

Indexing into this returns a scalar for each key.
"""
struct FlexiChainSummaryIC{TKey,NIter,NChains} <: FlexiChainSummary{TKey,NIter,NChains}
    _data::Dict{ParameterOrExtra{<:TKey},<:SizedMatrix{1,1,<:Any}}

    function FlexiChainSummaryIC{TKey,NIter,NChains}(
        data::Dict{<:Any,<:SizedMatrix{1,1,<:Any}}
    ) where {TKey,NIter,NChains}
        data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{1,1,<:Any}}(data)
        return new{TKey,NIter,NChains}(data)
    end
end
_get(fcsic::FlexiChainSummaryIC, key) = only(collect(fcsic._data[key])) # scalar

function _warn_non_numerics(non_numerics)
    if !isempty(non_numerics)
        @warn "The following non-numeric keys were skipped: $(non_numerics)"
    end
end

"""
    collapse_iter(
        chain::FlexiChain{TKey,NIter,NChains},
        func::Function;
        skip_nonnumeric::Bool=true,
        warn::Bool=false
        kwargs...
    )::FlexiChainSummaryI{TKey,NIter,NChains} where {TKey,NIter,NChains}

Collapse the iteration dimension of `chain` by applying `func` to each key in the chain with
numeric values.

The function `func` must map an (NIter × NChains) matrix to a (1 × NChains) matrix.

If `skip_nonnumeric` is true, non-numeric keys are skipped (with a warning if `warn` is true).

Other keyword arguments passed to `collapse_iter` are forwarded to `func`.

## Example

```julia
using FlexiChains, Statistics
# This function maps an (NIter × NChains) matrix to a (1 × NChains) matrix.
dim1_mean(x::AbstractMatrix) = mean(x; dims=1)
# This means we can use it with `collapse_iter`.
FlexiChains.collapse_iter(chain, dim1_mean)
# (Note that the above is also aliased to `mean(chain; dims=:iter)`.)
```
"""
function collapse_iter(
    chain::FlexiChain{TKey,NIter,NChains},
    func::Function;
    skip_nonnumeric::Bool=true,
    warn::Bool=false,
    kwargs...,
)::FlexiChainSummaryI{TKey,NIter,NChains} where {TKey,NIter,NChains}
    data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{1,NChains,<:Any}}()
    non_numerics = ParameterOrExtra{TKey}[]
    for (k, v) in chain._data
        if (!skip_nonnumeric) || eltype(v) <: Number
            # We use chain._data[k] instead of chain[k] here to guarantee that the input to
            # `k` is always a matrix (if NChains=1, chain[k] would return a vector).
            collapsed = func(chain._data[k]; kwargs...)
            data[k] = SizedMatrix{1,NChains}(collapsed)
        else
            warn && push!(non_numerics, k)
        end
    end
    warn && _warn_non_numerics(non_numerics)
    return FlexiChainSummaryI{TKey,NIter,NChains}(data, FlexiChains.chain_indices(chain))
end

"""
    collapse_chain(
        chain::FlexiChain{TKey,NIter,NChains},
        func::Function;
        skip_nonnumeric::Bool=true,
        warn::Bool=false
        kwargs...
    )::FlexiChainSummaryC{TKey,NIter,NChains} where {TKey,NIter,NChains}

Collapse the chain dimension of `chain` by applying `func` to each key in the chain with
numeric values.

The function `func` must map an (NIter × NChains) matrix to an (NIter × 1) matrix (_not_ a
vector).

If `skip_nonnumeric` is true, non-numeric keys are skipped (with a warning if `warn` is
true).

Other keyword arguments passed to `collapse_chain` are forwarded to `func`.

## Example

```julia
using FlexiChains, Statistics
# This function maps an (NIter × NChains) matrix to an (NIter × 1) matrix.
dim2_mean(x::AbstractMatrix) = mean(x; dims=2)
# This means we can use it with `collapse_chain`.
FlexiChains.collapse_chain(chain, dim2_mean)
# (Note that the above is also aliased to `mean(chain; dims=:chain)`.)
```
"""
function collapse_chain(
    chain::FlexiChain{TKey,NIter,NChains},
    func::Function;
    skip_nonnumeric::Bool=true,
    warn::Bool=false,
    kwargs...,
)::FlexiChainSummaryC{TKey,NIter,NChains} where {TKey,NIter,NChains}
    data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{NIter,1,<:Any}}()
    non_numerics = ParameterOrExtra{TKey}[]
    for (k, v) in chain._data
        if (!skip_nonnumeric) || eltype(v) <: Number
            collapsed = func(chain._data[k]; kwargs...)
            data[k] = SizedMatrix{NIter,1}(collapsed)
        else
            warn && push!(non_numerics, k)
        end
    end
    warn && _warn_non_numerics(non_numerics)
    return FlexiChainSummaryC{TKey,NIter,NChains}(data, FlexiChains.iter_indices(chain))
end

"""
    collapse(
        chain::FlexiChain{TKey,NIter,NChains},
        func::Function;
        skip_nonnumeric::Bool=true,
        warn::Bool=false
        kwargs...
    )::FlexiChainSummaryIC{TKey,NIter,NChains} where {TKey,NIter,NChains}

Collapse both the iteration and chain dimensions of `chain` by applying `func` to each key in the chain with numeric values.

The function `func` must map an (NIter × NChains) matrix to a scalar.

If `skip_nonnumeric` is true, non-numeric keys are skipped (with a warning if `warn` is true).

Other keyword arguments are forwarded to `func`.

## Example

```julia
using FlexiChains, Statistics
FlexiChains.collapse(chain, mean)
# (Note that the above is also aliased to `mean(chain)`.)
```
"""
function collapse(
    chain::FlexiChain{TKey,NIter,NChains},
    func::Function;
    skip_nonnumeric::Bool=true,
    warn::Bool=false,
    kwargs...,
)::FlexiChainSummaryIC{TKey,NIter,NChains} where {TKey,NIter,NChains}
    data = Dict{ParameterOrExtra{<:TKey},SizedMatrix{1,1,<:Any}}()
    non_numerics = ParameterOrExtra{TKey}[]
    for (k, v) in chain._data
        if (!skip_nonnumeric) || eltype(v) <: Number
            # We use chain._data[k] instead of chain[k] here to guarantee that the input to
            # `k` is always a matrix (if NChains=1, chain[k] would return a vector).
            collapsed = func(chain._data[k]; kwargs...)
            data[k] = SizedMatrix{1,1}(reshape([collapsed], 1, 1))
        else
            warn && push!(non_numerics, k)
        end
    end
    warn && _warn_non_numerics(non_numerics)
    return FlexiChainSummaryIC{TKey,NIter,NChains}(data)
end

macro enable_collapse(skip_nonnumeric, func)
    # TODO: This is type unstable. I don't see a way to fix this now though since we use
    # different output types for different keyword arguments.
    quote
        function $(esc(func))(
            chain::FlexiChain{TKey,NIter,NChains};
            dims::Symbol=:both,
            warn::Bool=false,
            kwargs...,
        )::FlexiChainSummary{TKey,NIter,NChains} where {TKey,NIter,NChains}
            if dims == :both
                return collapse(
                    chain,
                    $(esc(func));
                    skip_nonnumeric=$(esc(skip_nonnumeric)),
                    warn=warn,
                    kwargs...,
                )
            elseif dims == :iter
                return collapse_iter(
                    chain,
                    function (x; kwargs...)
                        return $(esc(func))(x; dims=1, kwargs...)
                    end;
                    skip_nonnumeric=$(esc(skip_nonnumeric)),
                    warn=warn,
                    kwargs...,
                )
            elseif dims == :chain
                return collapse_chain(
                    chain,
                    function (x; kwargs...)
                        return $(esc(func))(x; dims=2, kwargs...)
                    end;
                    skip_nonnumeric=$(esc(skip_nonnumeric)),
                    warn=warn,
                    kwargs...,
                )
            else
                throw(ArgumentError("`dims` must be `:iter`, `:chain`, or `:both`"))
            end
        end
    end
end

function _stat_docstring(func_name, long_name)
    return """
    $(func_name)(chain::FlexiChain; dims::Symbol=:both, warn::Bool=false)

Calculate the $(long_name) across all iterations and chains for each numeric key in `chain`. If
 `warn=true`, issues a warning for all non-numeric keys encountered.

The `dims` keyword argument specifies which dimensions to collapse.
- `:iter`: collapse the iteration dimension only
- `:chain`: collapse the chain dimension only
- `:both`: collapse both the iteration and chain dimensions (default)

Other keyword arguments are forwarded to `$(func_name)`.
"""
end

"""
$(_stat_docstring("mean", "mean"))
"""
@enable_collapse true Statistics.mean
"""
$(_stat_docstring("median", "median"))
"""
@enable_collapse true Statistics.median
"""
$(_stat_docstring("minimum", "minimum"))
"""
@enable_collapse true Base.minimum
"""
$(_stat_docstring("maximum", "maximum"))
"""
@enable_collapse true Base.maximum
"""
$(_stat_docstring("var", "variance"))
"""
@enable_collapse true Statistics.var
"""
$(_stat_docstring("std", "standard deviation"))
"""
@enable_collapse true Statistics.std
