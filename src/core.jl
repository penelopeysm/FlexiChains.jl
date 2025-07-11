# Note that this file isn't in a module. Hence, all the imports / exports are
# global.

using AbstractMCMC: AbstractMCMC
using StaticArrays: SMatrix

export FlexiChain

const NTOf{T} = NamedTuple{<:Any,<:NTuple{<:Any,<:T}} where {T}

"""
    to_smatrix_with_size_check(key_name::String, mat::AbstractMatrix, niter::Int, nchains::Int)

Convert an AbstractMatrix to an `SMatrix{niter,nchains}`. Error if the size is wrong.
"""
function to_smatrix_with_size_check(
    key_name::String, mat::AbstractMatrix{T}, niter::Int, nchains::Int
)::SMatrix{niter,nchains,T} where {T}
    if size(mat) != (niter, nchains)
        msg = "The data for $key_name had an inconsistent size: expected ($(niter), $(nchains)), got $(size(mat))."
        throw(ArgumentError(msg))
    end
    return SMatrix{niter,nchains}(mat)
end

"""
    FlexiChain{TKey,NIter,NChains,Sections}

TODO: Document further.

StaticArrays.jl is used not for performance but rather for type-level storage
of the number of iterations and chains. This allows us to have compile-time
guarantees that the sizes of the arrays are constant across all parameters
(which must necessarily be true for a Markov chain).
"""
struct FlexiChain{TKey,NIter,NChains,Sections} <: AbstractMCMC.AbstractChains
    # all parameters must share a common type; their values must be real numbers
    parameters::Dict{TKey,SMatrix{NIter,NChains,<:Real}}
    # section names are always Symbol; but the underlying keys (and values) can
    # be anything
    other_sections::NTOf{Dict{<:Any,<:SMatrix{NIter,NChains}}}

    function FlexiChain{TKey}(
        parameters::AbstractDict{TKey,<:AbstractMatrix{<:Real}},
        other_sections::NTOf{AbstractDict{<:Any,<:AbstractMatrix}},
    ) where {TKey}
        # Extract the number of iterations and chains from any of the data matrices
        first_matrix = if isempty(parameters)
            if isempty(other_sections) || all(isempty, values(other_sections))
                # If they're all empty we can return early
                return FlexiChain{TKey,0,0}(
                    Dict{TKey,SMatrix{0,0,float(Real)}}(),
                    Dict{Tuple{Symbol,Any},SMatrix{0,0}},
                )
            else
                # Get the first non-empty matrix from `other`
                first(merge(values(other_sections)...))
            end
        else
            first(parameters).second
        end
        niter, nchains = size(first_matrix)

        # Check that all matrices have the same size
        params_checked = Dict(
            (k, to_smatrix_with_size_check("parameter $k", v, niter, nchains)) for
            (k, v) in pairs(parameters)
        )
        other_checked = NamedTuple([
            s => Dict(
                (k, to_smatrix_with_size_check("key $k in section $s", v, niter, nchains)) for (k, v) in pairs(d)
            ) for (s, d) in pairs(other_sections)
        ])
        section_names = tuple(keys(other_checked)...)
        return new{TKey,niter,nchains,section_names}(params_checked, other_checked)
    end
end

function Base.size(chain::FlexiChain{TKey,NIter,NChains}) where {TKey,NIter,NChains}
    num_objects = length(chain.parameters) + length(chain.other_sections)
    return (NIter, num_objects, NChains)
end

function get_parameter(chain::FlexiChain{TKey}, key::TKey) where {TKey}
    return get(chain.parameters, key, nothing)
end

function get_other(chain::FlexiChain, section_name::Symbol, key::Any)
    section = get(chain.other_sections, section_name, nothing)
    section === nothing && return nothing
    return get(section, key, nothing)
end
