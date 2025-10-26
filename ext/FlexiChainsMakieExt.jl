module FlexiChainsMakieExt

import FlexiChains as FC
using Makie

const MakieGrids = Union{Makie.GridPosition,Makie.GridSubposition}

include("FlexiChainsMakieExt/density.jl")

function _default_density_axis(k::FC.ParameterOrExtra)
    return (xlabel="value", ylabel="density", title=string(k.name))
end

end
