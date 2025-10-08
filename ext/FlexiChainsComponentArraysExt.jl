module FlexiChainsComponentArraysExt

using FlexiChains: FlexiChains, FlexiChain, At
using ComponentArrays

function FlexiChains.values_at(
    chn::FlexiChain{TKey}, iter::Union{Int,At}, chain::Union{Int,At}, T::Type{TCA}
) where {TKey,TCA<:ComponentArray}
    return T(FlexiChains.values_at(chn, iter, chain, NamedTuple))
end
function FlexiChains.parameters_at(
    chn::FlexiChain{TKey}, iter::Union{Int,At}, chain::Union{Int,At}, T::Type{TCA}
) where {TKey,TCA<:ComponentArray}
    return T(FlexiChains.parameters_at(chn, iter, chain, NamedTuple))
end

end # module
