module FlexiChains

using DocStringExtensions: TYPEDFIELDS

include("data_structures.jl")
include("interface.jl")

# For maximum ease of use with Turing...
using AbstractPPL: VarName, @varname
const VNChain = FlexiChain{VarName}
export VarName, @varname, VNChain

end # module FlexiChains
