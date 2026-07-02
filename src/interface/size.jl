@public niters, nchains

"""
    Base.size(chain::FlexiChain[, dim::Int])

Returns `(niters, nchains)`, or `niters` or `nchains` if `dim=1` or `dim=2` is specified.

!!! note "MCMCChains difference"
    
    MCMCChains returns a 3-tuple of `(niters, nkeys, nchains)` where `nkeys` is the total number of parameters. FlexiChains does not do this because the keys are not considered an axis of their own. If you want the total number of keys in a `FlexiChain`, you can use `length(keys(chain))`.
"""
function Base.size(chain::FlexiChain)::Tuple{Int,Int}
    return (niters(chain), nchains(chain))
end
function Base.size(chain::FlexiChain, dim::Int)::Int
    return if dim == 1
        niters(chain)
    elseif dim == 2
        nchains(chain)
    else
        throw(DimensionMismatch("Dimension $dim out of range for FlexiChain"))
    end
end
"""
    Base.size(summary::FlexiSummary[, dim::Int])

Returns `(niters, nchains, nstats)`, or `niters`, `nchains`, or `nstats` if `dim=1`,
`dim=2`, or `dim=3` is specified. If any of the dimensions have been collapsed, the
corresponding value will be 0.
"""
function Base.size(summary::FlexiSummary)::Tuple{Int,Int,Int}
    return (niters(summary), nchains(summary), nstats(summary))
end
function Base.size(summary::FlexiSummary, dim::Int)::Int
    return if dim == 1
        niters(summary)
    elseif dim == 2
        nchains(summary)
    elseif dim == 3
        nstats(summary)
    else
        throw(DimensionMismatch("Dimension $dim out of range for FlexiSummary"))
    end
end

"""
    FlexiChains.niters(chain::FlexiChain)

The number of iterations in the `FlexiChain`. Equivalent to `size(chain, 1)`.
"""
function niters(chain::FlexiChain)::Int
    return length(iter_indices(chain))
end
"""
    FlexiChains.niters(summary::FlexiSummary)

The number of iterations in the `FlexiSummary`. Equivalent to `size(summary, 1)`. Returns 0
if the iteration dimension has been collapsed.
"""
function niters(summary::FlexiSummary)::Int
    return if isnothing(iter_indices(summary))
        0
    else
        length(iter_indices(summary))
    end
end

"""
    FlexiChains.nchains(chain::FlexiChain)

The number of chains in the `FlexiChain`. Equivalent to `size(chain, 2)`.
"""
function nchains(chain::FlexiChain)::Int
    return length(chain_indices(chain))
end
"""
    FlexiChains.nchains(summary::FlexiSummary)

The number of chains in the `FlexiSummary`. Equivalent to `size(summary, 2)`. Returns 0 if
the chain dimension has been collapsed.
"""
function nchains(summary::FlexiSummary)::Int
    return if isnothing(chain_indices(summary))
        0
    else
        length(chain_indices(summary))
    end
end

"""
    FlexiChains.nstats(summary::FlexiSummary)

The number of statistics in the `FlexiSummary`. Equivalent to `size(summary, 3)`. Returns 0
if the statistics dimension has been collapsed (this means that there is a single statistic,
but its name is not stored or displayed to the user).
"""
function nstats(summary::FlexiSummary)::Int
    return if isnothing(stat_indices(summary))
        0
    else
        length(stat_indices(summary))
    end
end
