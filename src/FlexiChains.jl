module FlexiChains

using AbstractPPL: AbstractPPL, VarName, @varname
using DocStringExtensions: TYPEDFIELDS

# For use when marking the public API.
# On 1.11+ it just uses the `public` keyword, otherwise it does nothing.
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

include("data_structures.jl")
include("summary.jl")
include("getindex.jl")
include("interface.jl")

# For maximum ease of use with Turing...
const VNChain = FlexiChain{VarName}
export VarName, @varname, VNChain
@public VNChain, var"@varname", VarName

end # module FlexiChains
