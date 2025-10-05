module FlexiChains

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

include("chain.jl")
include("summary.jl")
include("getindex.jl")
include("interface.jl")
include("varname.jl")

# Convenience re-exports.
using DimensionalData: At, Near, Contains, (..), Touches, Where, Not
export At, Near, Contains, (..), Touches, Where, Not
using Statistics: mean, median, std, var
export mean, median, std, var
using StatsBase: summarystats
export summarystats
using MCMCDiagnosticTools: ess
export ess, rhat, mcse
# For maximum ease of use with Turing...
const VNChain = FlexiChain{VarName}
export VarName, @varname, VNChain, split_varnames

# Attempt to precompile _some_ stuff, especially for VarName. This cuts the TTFX by about
# 2-3x.
@setup_workload begin
    d = Dict{ParameterOrExtra{<:VarName},Any}()
    d[Parameter(@varname(a))] = 1
    ds = fill(d, 10, 2)
    @compile_workload begin
        fc = VNChain(10, 2, ds)
        summarystats(fc)
    end
end

end # module FlexiChains
