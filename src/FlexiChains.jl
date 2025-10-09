module FlexiChains

using AbstractMCMC: AbstractMCMC
using DimensionalData: DimensionalData as DD
using DimensionalData.Dimensions.Lookups: Lookups as DDL
using OrderedCollections: OrderedDict, OrderedSet
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
include("interface/equal.jl")
include("interface/size.jl")
include("interface/dict.jl")
include("interface/show.jl")
include("interface/cat.jl")
include("interface/mergesubset.jl")
include("interface/decomp.jl")
include("varname.jl")

# These denote the 'special' keys that we use for Turing.jl return values
const _LOGJOINT_KEY = Extra(:logjoint)
const _LOGPRIOR_KEY = Extra(:logprior)
const _LOGLIKELIHOOD_KEY = Extra(:loglikelihood)
# Overloaded in TuringExt.
"""
    to_varname_dict(transition)::AbstractDict{VarName,Any}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler
into a dictionary mapping `VarName`s to their corresponding values.

If you are writing a custom sampler for Turing.jl and your sampler's
implementation of `AbstractMCMC.step` returns anything _but_ a
`Turing.Inference.Transition` as its first return value, then to use FlexiChains
with your sampler, you will have to overload this function.
"""
function to_varname_dict end
@public to_varname_dict
# Extended in PosteriorDB extension (but not exported)
function from_posteriordb_ref end
@public from_posteriordb_ref
# Extended in RecipesBase extension
include("plots.jl")
@public traceplot, traceplot!
@public mixeddensity, mixeddensity!
@public meanplot, meanplot!
@public autocorplot, autocorplot!

# Convenience re-exports.
using DimensionalData: At, Near, Contains, (..), Touches, Where, Not
export At, Near, Contains, (..), Touches, Where, Not
using Statistics: mean, median, std, var
export mean, median, std, var
using StatsBase: summarystats
export summarystats
using MCMCDiagnosticTools: ess, rhat, mcse
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
