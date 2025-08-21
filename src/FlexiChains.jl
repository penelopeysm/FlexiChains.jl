module FlexiChains

using DocStringExtensions: TYPEDFIELDS

include("data_structures.jl")
include("interface.jl")
include("display.jl")

# For maximum ease of use with Turing...
using AbstractPPL: VarName, @varname
const VNFlexiChain = FlexiChain{VarName}
export VarName, @varname, VNFlexiChain

end # module FlexiChains
