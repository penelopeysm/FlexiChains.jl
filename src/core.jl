# Note that this file isn't in a module. Hence, all the imports / exports are
# global.

using AbstractMCMC: AbstractMCMC
using StaticArrays: SMatrix

export FlexiChain

function to_smatrix_with_check(
    key, mat::AbstractMatrix, niter::Int, nchains::Int
)
    if size(mat) != (niter, nchains)
        msg = "The data for key $key had an inconsistent size: expected ($(niter), $(nchains)), got $(size(mat))."
        throw(ArgumentError(msg))
    end
    return SMatrix{niter,nchains}(mat)
end

"""
    FlexiChain{TKey,NIter,NChains}

TODO: Document further.

StaticArrays.jl is used not for performance but rather for type-level storage
of the number of iterations and chains. This allows us to have compile-time
guarantees that the sizes of the arrays are constant across all parameters
(which must necessarily be true for a Markov chain).
"""
struct FlexiChain{TKey,NIter,NChains} <: AbstractMCMC.AbstractChains
    params::Dict{TKey,SMatrix{NIter,NChains,<:AbstractFloat}}
    core::Dict{TKey,SMatrix{NIter,NChains}}
    other::Dict{Tuple{TKey,Symbol},SMatrix{NIter,NChains}}

    # Constructor that doesn't require StaticArrays.
    function FlexiChain{TKey}(
        params::AbstractDict{<:Any,<:AbstractMatrix{<:AbstractFloat}},
        core::AbstractDict{<:Any,<:AbstractMatrix},
        other::AbstractDict{<:Any,<:AbstractMatrix},
    ) where {TKey}
        # Check if they're all empty
        if isempty(params) && isempty(core) && isempty(other)
            return FlexiChain{TKey,0,0}(
                Dict{TKey,SMatrix{0,0,<:AbstractFloat}}(),
                Dict{TKey,SMatrix{0,0}}(),
                Dict{Tuple{TKey,Symbol},SMatrix{0,0}},
            )
        end

        # Extract the number of iterations and chains from any of the data matrices
        first_matrix = if isempty(params)
            if isempty(core)
                first(other).second
            else
                first(core).second
            end
        else
            first(params).second
        end
        niter, nchains = size(first_matrix)

        # Check that all matrices have the same size
        params_sdict = Dict(
            (k, to_smatrix_with_check(k, v, niter, nchains)) for (k, v) in pairs(params)
        )
        core_sdict = Dict(
            (k, to_smatrix_with_check(k, v, niter, nchains)) for (k, v) in pairs(core)
        )
        other_sdict = Dict(
            (k, to_smatrix_with_check(k, v, niter, nchains)) for (k, v) in pairs(other)
        )
        return new{TKey,niter,nchains}(params_sdict, core_sdict, other_sdict)
    end
end

function Base.size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}
    num_objects = length(chain.params) + length(chain.core) + length(chain.other)
    return (NIter, num_objects, NChains)
end

function get_parameter(chain::FlexiChain{TKey}, key::TKey) where {TKey}
    return get(chain.params, key, nothing)
end

function get_core(chain::FlexiChain{TKey}, key::TKey) where {TKey}
    return get(chain.core, key, nothing)
end

function get_other(chain::FlexiChain{TKey}, key::TKey, section_name::Symbol) where {TKey}
    return get(chain.other, (key, section_name), nothing)
end
