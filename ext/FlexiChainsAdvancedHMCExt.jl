module FlexiChainsAdvancedHMCExt

using FlexiChains: FlexiChains
using DimensionalData: DimArray, Dim
using AdvancedHMC: AdvancedHMC

function FlexiChains.to_nt_and_stats(t::AdvancedHMC.Transition)
    da = DimArray(t.z.θ, Dim{:param}(axes(t.z.θ, 1)))
    return (; params = da), t.stat
end

end # module FlexiChainsTuringExt
