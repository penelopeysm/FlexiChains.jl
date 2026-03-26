module FlexiChainsComponentArraysExt

using FlexiChains: FlexiChains, FlexiChain, At
using ComponentArrays

function FlexiChains._values_at_single(
        chn::FlexiChain{TKey}, iter::Union{Int, At}, chain::Union{Int, At}, T::Type{TCA}
    ) where {TKey, TCA <: ComponentArray}
    return T(FlexiChains._values_at_single(chn, iter, chain, NamedTuple))
end
function FlexiChains._parameters_at_single(
        chn::FlexiChain{TKey}, iter::Union{Int, At}, chain::Union{Int, At}, T::Type{TCA}
    ) where {TKey, TCA <: ComponentArray}
    return T(FlexiChains._parameters_at_single(chn, iter, chain, NamedTuple))
end

end # module
