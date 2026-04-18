module FlexiChainsPosteriorStatsExt

using PosteriorStats
using FlexiChains: FlexiChains, FlexiChain
import DimensionalData as DD

"""
$(FlexiChains._stat_docstring("PosteriorStats.hdi", "highest density interval"))
"""
FlexiChains.@_forward_stat PosteriorStats.hdi

"""
$(FlexiChains._stat_docstring("PosteriorStats.eti", "equal-tailed interval"))
"""
FlexiChains.@_forward_stat PosteriorStats.eti

struct NamesAndLOOResult{V <: AbstractVector, P <: PosteriorStats.PSISLOOResult}
    param_names::V
    loo::P
end
function Base.show(io::IO, m::MIME"text/plain", x::NamesAndLOOResult)
    printstyled(io, "NamesAndLOOResult"; bold = true)
    println(io)
    print(io, "├─ param_names: $(x.param_names)")
    println(io)
    print(io, "└─ loo: ")
    return show(io, m, x.loo)
end

"""
    PosteriorStats.loo(chn::FlexiChains; kwargs...)

Calculates the leave-one-out cross-validation (LOO) statistic for a `FlexiChain` object. The
chain must contain only log-likelihood values, and they must all be stored as parameters
(not extras). Parameters that map to arrays of log-likelihood values are supported: they
will be flattened before being passed to `PosteriorStats.loo`.

Returns a struct with the following fields:

- `param_names::Vector`: A vector of parameter names whose log-likelihood values were used.

- `loo::PosteriorStats.PSISLOOResult`: The return value of `PosteriorStats.loo` applied to
  the log-likelihood values extracted from the `FlexiChain`. This contains the statistics
  of interest.

Additional keyword arguments are forwarded to [`PosteriorStats.loo`](@extref).
"""
function PosteriorStats.loo(chn::FlexiChain; kwargs...)
    da = DD.DimArray(chn; eltype_filter = Real, parameters_only = true)
    param_names = DD.val(DD.dims(da, FlexiChains.PARAM_DIM_NAME))
    return NamesAndLOOResult(param_names, PosteriorStats.loo(da; kwargs...))
end

end # module
