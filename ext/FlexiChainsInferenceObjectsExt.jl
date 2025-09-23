module FlexiChainsInferenceObjectsExt

using FlexiChains: FlexiChains, FlexiChain, VarName
using InferenceObjects: InferenceObjects
using DimensionalData: DimensionalData as DD
using OrderedCollections: OrderedDict

const stats_key_map = Dict(
    :hamiltonian_energy => :energy,
    :hamiltonian_energy_error => :energy_error,
    :is_adapt => :tune,
    :max_hamiltonian_energy_error => :max_energy_error,
    :nom_step_size => :step_size_nom,
    :numerical_error => :diverging,
)

function InferenceObjects.convert_to_inference_data(
    chain::FlexiChain{<:VarName}; group::Symbol=:posterior, kwargs...
)
    # all extras stored in :sample_stats (or :prior_sample_stats)
    parameter_arrays = OrderedDict{Symbol,AbstractArray{<:Real}}()
    for var_name in FlexiChains.parameters(chain)
        arr_of_draws = chain[var_name]
        if !(eltype(arr_of_draws) <: Union{Real,AbstractArray{<:Real}})
            @warn "Variable $var_name is not a real-valued parameter, skipping."
            continue
        end
        parameter_arrays[Symbol(var_name)] = _cat_draws(_rename_iter_dim(arr_of_draws))
    end
    group_dataset = InferenceObjects.convert_to_dataset(parameter_arrays; kwargs...)

    isempty(FlexiChains.extras(chain)) &&
        return InferenceObjects.InferenceData(; group => group_dataset)

    sample_stats = OrderedDict{Symbol,AbstractArray{<:Real}}()
    for k in FlexiChains.extras(chain)
        arr_of_draws = _rename_iter_dim(chain[k])
        sym = Symbol(k.key_name)
        extra_name = get(stats_key_map, sym, sym)
        sample_stats[extra_name] = _cat_draws(arr_of_draws)
    end
    group_sample_stats = if group === :posterior
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

_cat_draws(arr::AbstractMatrix{<:Real}) = arr
function _cat_draws(arr::AbstractMatrix{<:AbstractArray{<:Real,N}}) where {N}
    return permutedims(stack(arr), (N + 1, N + 2, ntuple(identity, N)...))
end

end # module
