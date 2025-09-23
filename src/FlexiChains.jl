module FlexiChains

using AbstractPPL: AbstractPPL, VarName, @varname
using DocStringExtensions: TYPEDFIELDS
using PrecompileTools: @setup_workload, @compile_workload

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

include("sizedmatrix.jl")
include("chain.jl")
include("summaries.jl")
include("getindex.jl")
include("interface.jl")

# For maximum ease of use with Turing...
const VNChain = FlexiChain{VarName}
export VarName, @varname, VNChain
@public VNChain, var"@varname", VarName

# Attempt to precompile _some_ stuff, especially for VarName. This cuts the TTFX by about
# 2-3x.
@setup_workload begin
    d = Dict{ParameterOrExtra{<:VarName},Any}()
    d[Parameter(@varname(a))] = 1
    ds = fill(d, 10, 2)
    @compile_workload begin
        fc = VNChain{10,2}(ds)
        Statistics.mean(fc)
    end
end

end # module FlexiChains
