module FlexiChainsInferenceObjectsExt

using FlexiChains: FlexiChains, FlexiChain, VarName
using InferenceObjects: InferenceObjects
using DimensionalData: DimensionalData as DD
using OrderedCollections: OrderedDict

# TODO: This is quite hacky, and has nothing to do with FlexiChains at all! This maps key
# names from Turing's samplers to the names used in ArviZ.
const STATS_KEY_MAP = Dict(
    :hamiltonian_energy => :energy,
    :hamiltonian_energy_error => :energy_error,
    :is_adapt => :tune,
    :max_hamiltonian_energy_error => :max_energy_error,
    :nom_step_size => :step_size_nom,
    :numerical_error => :diverging,
)

const POSTERIOR_GROUP = :posterior

"""
    InferenceObjects.convert_to_inference_data(
        chain::FlexiChain{<:TKey}; group::Symbol = $(POSTERIOR_GROUP), kwargs...
    ) where {TKey}

Convert a `FlexiChain` to an `InferenceObjects.InferenceData` object.

The `group` keyword argument specifies the group name for the chain's parameters. The
chain's extras are assigned to `:sample_stats` if `group` is `:posterior`, and to
`:sample_stats_<group>` otherwise.
        
Other keyword arguments are passed to `InferenceObjects.convert_to_dataset`.
"""
function InferenceObjects.convert_to_inference_data(
        chain::FlexiChain{<:TKey}; group::Symbol = POSTERIOR_GROUP, kwargs...
    ) where {TKey}
    # Handle parameters
    parameter_arrays = OrderedDict{Symbol, AbstractArray{<:Real}}()
    for param in FlexiChains.parameters(chain)
        arr_of_draws = _rename_iter_dim(chain[param])
        if !(eltype(arr_of_draws) <: Union{Real, AbstractArray{<:Real}})
            @warn "Variable $param is not a real-valued parameter, skipping."
            continue
        end
        parameter_arrays[Symbol(param)] = _stack_draws(arr_of_draws)
    end
    group_dataset = InferenceObjects.convert_to_dataset(parameter_arrays; kwargs...)

    isempty(FlexiChains.extras(chain)) &&
        return InferenceObjects.InferenceData(; group => group_dataset)

    # Handle extras
    sample_stats = OrderedDict{Symbol, AbstractArray{<:Real}}()
    for k in FlexiChains.extras(chain)
        arr_of_draws = _rename_iter_dim(chain[k])
        sym = Symbol(k)
        extra_name = get(STATS_KEY_MAP, sym, sym)
        sample_stats[extra_name] = _stack_draws(arr_of_draws)
    end
    group_sample_stats = if group === POSTERIOR_GROUP
        :sample_stats
    else
        Symbol("sample_stats_", group)
    end
    sample_stats_dataset = InferenceObjects.convert_to_dataset(sample_stats; kwargs...)

    return InferenceObjects.InferenceData(;
        group => group_dataset, group_sample_stats => sample_stats_dataset
    )
end

function _rename_iter_dim(arr::DD.AbstractDimArray)
    DD.hasdim(arr, FlexiChains.ITER_DIM_NAME) || return arr
    return DD.set(arr, FlexiChains.ITER_DIM_NAME => :draw)
end

_stack_draws(arr::AbstractArray{<:Real}) = arr
function _stack_draws(arr::AbstractMatrix{<:AbstractArray{<:Real, N}}) where {N}
    return permutedims(stack(arr), (N + 1, N + 2, ntuple(identity, N)...))
end

end # module
