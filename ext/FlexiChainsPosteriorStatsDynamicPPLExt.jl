module FlexiChainsPosteriorStatsDynamicPPLExt

using PosteriorStats: PosteriorStats
using FlexiChains: FlexiChain
using DynamicPPL: DynamicPPL

"""
    PosteriorStats.loo(
        model::DynamicPPL.Model,
        posterior_chn::FlexiChains;
        kwargs...
    )

Calculates the leave-one-out cross-validation (LOO) statistic, given a model plus a
posterior chain. This first uses the model and posterior chain to calculate pointwise
log-likelihoods, and then uses those to calculate the LOO statistic.

Returns a struct with the following fields:

- `param_names::Vector`: A vector of parameter names whose log-likelihood values were used.

- `loo::PosteriorStats.PSISLOOResult`: The return value of `PosteriorStats.loo` applied to
  the log-likelihood values extracted from the `FlexiChain`. This contains the statistics
  of interest.

Additional keyword arguments are forwarded to [`PosteriorStats.loo`](@extref).
"""
function PosteriorStats.loo(model::DynamicPPL.Model, posterior_chn::FlexiChain; kwargs...)
    lls_chn = DynamicPPL.pointwise_loglikelihoods(model, posterior_chn)
    return PosteriorStats.loo(lls_chn; kwargs...)
end

end
