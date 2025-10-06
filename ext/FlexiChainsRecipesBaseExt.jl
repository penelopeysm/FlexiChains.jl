module FlexiChainsRecipesBaseExt

using FlexiChains: FlexiChains as FC
using RecipesBase: @recipe

@recipe function _(chn::FC.FlexiChain)
    k = first(FC.parameters(chn))
    d = chn[k]
    ii = FC.iter_indices(chn)
    return ii, d
end

end # module
