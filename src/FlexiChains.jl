module FlexiChains

using AbstractPPL: AbstractPPL, VarName, @varname
using DocStringExtensions: TYPEDFIELDS

include("data_structures.jl")
include("interface.jl")

# For maximum ease of use with Turing...
const VNChain = FlexiChain{VarName}
export VarName, @varname, VNChain

# The public API
macro public(ex)
    # https://discourse.julialang.org/t/is-compat-jl-worth-it-for-the-public-keyword/119041/22
    if VERSION >= v"1.11.0-DEV.469"
        args = if ex isa Symbol
            (ex,)
        elseif Base.isexpr(ex, :tuple)
            ex.args
        else
            error("unexpected expression in @public")
        end
        esc(Expr(:public, args...))
    else
        nothing
    end
end

end # module FlexiChains
