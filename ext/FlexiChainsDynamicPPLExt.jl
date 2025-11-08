module FlexiChainsDynamicPPLExt

using FlexiChains:
    FlexiChains, FlexiChain, VarName, Parameter, Extra, ParameterOrExtra, VNChain
using DimensionalData: DimensionalData as DD
using DynamicPPL: DynamicPPL, AbstractPPL, AbstractMCMC, Distributions
using OrderedCollections: OrderedDict
using Random: Random

##################################################
# AbstractMCMC.{to,from}_samples implementations #
##################################################

"""
    AbstractMCMC.from_samples(
        ::Type{<:VNChain},
        params_and_stats::AbstractMatrix{<:DynamicPPL.ParamsWithStats}
    )::VNChain

Convert a matrix of [`DynamicPPL.ParamsWithStats`](@extref) to a `VNChain`.
"""
function AbstractMCMC.from_samples(
    ::Type{<:VNChain}, params_and_stats::AbstractMatrix{<:DynamicPPL.ParamsWithStats}
)::VNChain
    # Just need to convert the `ParamsWithStats` to Dicts of ParameterOrExtra.
    dicts = map(params_and_stats) do ps
        # Parameters
        d = OrderedDict{ParameterOrExtra{<:VarName},Any}(
            Parameter(vn) => val for (vn, val) in ps.params
        )
        # Stats
        for (stat_vn, stat_val) in pairs(ps.stats)
            d[Extra(stat_vn)] = stat_val
        end
        d
    end
    return VNChain(size(params_and_stats, 1), size(params_and_stats, 2), dicts)
end

"""
    AbstractMCMC.to_samples(
        ::Type{DynamicPPL.ParamsWithStats},
        chain::VNChain
    )::DimensionalData.DimMatrix{DynamicPPL.ParamsWithStats}

Convert a `VNChain` to a `DimMatrix` of [`DynamicPPL.ParamsWithStats`](@extref).

The axes of the `DimMatrix` are the same as those of the input `VNChain`.
"""
function AbstractMCMC.to_samples(
    ::Type{DynamicPPL.ParamsWithStats}, chain::FlexiChain{T}
)::DD.DimMatrix{<:DynamicPPL.ParamsWithStats} where {T<:VarName}
    dicts = FlexiChains.values_at(chain, :, :)
    return map(dicts) do d
        # Need to separate parameters and stats.
        param_dict = OrderedDict{T,Any}(
            vn_param.name => val for (vn_param, val) in d if vn_param isa Parameter{<:T}
        )
        stats_nt = NamedTuple(
            Symbol(extra_param.name) => val for
            (extra_param, val) in d if extra_param isa Extra
        )
        DynamicPPL.ParamsWithStats(param_dict, stats_nt)
    end
end

############################
# InitFromParams extension #
############################
"""
    DynamicPPL.InitFromParams(
        chn::FlexiChain{<:VarName},
        iter::Union{Int,DD.At},
        chain::Union{Int,DD.At},
        fallback::Union{AbstractInitStrategy,Nothing}=InitFromPrior()
    )::DynamicPPL.InitFromParams

Use the parameters stored in a FlexiChain as an initialisation strategy.
"""
function DynamicPPL.InitFromParams(
    chn::FlexiChain{<:VarName},
    iter::Union{Int,DD.At},
    chain::Union{Int,DD.At},
    fallback::Union{DynamicPPL.AbstractInitStrategy,Nothing}=DynamicPPL.InitFromPrior(),
)
    # Note that this is functionally the same as `InitFromFlexiChainUnsafe` but it is more
    # flexible because it allows `DD.At` indices, and it also allows for split-VarNames
    # (although that's an unlikely situation). I think conceptually, the difference is that
    # `InitFromParams` isn't meant to be used in tight loops / performance-sensitive code,
    # and can thus give more guarantees about flexibility, whereas
    # `InitFromFlexiChainUnsafe` is really meant for internal use only.
    return DynamicPPL.InitFromParams(FlexiChains.parameters_at(chn, iter, chain), fallback)
end

##################################
# Optimisation for parameters_at #
##################################
struct InitFromFlexiChain{C<:FlexiChains.VNChain} <: DynamicPPL.AbstractInitStrategy
    chain::C
    iter_index::Int
    chain_index::Int
end
function DynamicPPL.init(
    ::Random.AbstractRNG,
    vn::VarName,
    ::Distributions.Distribution,
    strategy::InitFromFlexiChain,
)
    return strategy.chain._data[FlexiChains.Parameter(vn)][
        strategy.iter_index, strategy.chain_index
    ]
end

###########################################
# DynamicPPL: predict, returned, logjoint #
###########################################

function _default_reevaluate_accs()
    return (
        DynamicPPL.LogPriorAccumulator(),
        DynamicPPL.LogJacobianAccumulator(),
        DynamicPPL.LogLikelihoodAccumulator(),
        DynamicPPL.ValuesAsInModelAccumulator(true),
    )
end

"""
Returns a tuple of (retval, varinfo) for each iteration in the chain.
"""
function reevaluate(
    rng::Random.AbstractRNG,
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName},
    accs::NTuple{N,DynamicPPL.AbstractAccumulator}=_default_reevaluate_accs(),
)::DD.DimMatrix{<:Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    niters, nchains = size(chain)
    tuples = Iterators.product(1:niters, 1:nchains)
    retvals_and_varinfos = map(tuples) do (i, j)
        vi = DynamicPPL.Experimental.OnlyAccsVarInfo(DynamicPPL.AccumulatorTuple(accs))
        DynamicPPL.init!!(rng, model, vi, InitFromFlexiChain(chain, i, j))
    end
    return FlexiChains._raw_to_user_data(chain, retvals_and_varinfos)
end
function reevaluate(
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName},
    accs::NTuple{N,DynamicPPL.AbstractAccumulator}=_default_reevaluate_accs(),
)::DD.DimMatrix{<:Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    return reevaluate(Random.default_rng(), model, chain, accs)
end

"""
    DynamicPPL.returned(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})

Returns a `DimMatrix` of the model's return values, re-evaluated using the parameters in
each iteration of the chain.
"""
function DynamicPPL.returned(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::DD.DimMatrix
    return map(first, reevaluate(model, chain))
end

"""
    DynamicPPL.logjoint(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})

Returns a `DimMatrix` of the log-joint probabilities, re-evaluated using the parameters at
each iteration of the chain.
"""
function DynamicPPL.logjoint(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::DD.DimMatrix
    accs = (DynamicPPL.LogPriorAccumulator(), DynamicPPL.LogLikelihoodAccumulator())
    return map(DynamicPPL.getlogjoint ∘ last, reevaluate(model, chain, accs))
end

"""
    DynamicPPL.loglikelihood(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})

Returns a `DimMatrix` of the log-likelihoods, re-evaluated using the parameters at each
iteration of the chain.
"""
function DynamicPPL.loglikelihood(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::DD.DimMatrix
    accs = (DynamicPPL.LogLikelihoodAccumulator(),)
    return map(DynamicPPL.getloglikelihood ∘ last, reevaluate(model, chain, accs))
end

"""
    DynamicPPL.logprior(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})

Returns a `DimMatrix` of the log-prior probabilities, re-evaluated using the parameters at
each iteration of the chain.
"""
function DynamicPPL.logprior(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::DD.DimMatrix
    accs = (DynamicPPL.LogPriorAccumulator(),)
    return map(DynamicPPL.getlogprior ∘ last, reevaluate(model, chain, accs))
end

"""
    DynamicPPL.predict(
        [rng::Random.AbstractRNG,]
        model::DynamicPPL.Model,
        chain::FlexiChain{<:VarName};
        include_all::Bool=true,
    )

Returns a new `FlexiChain` containing predictions for variables in the model, conditioned on
the parameters in each iteration of the input `chain`.

The returned `FlexiChain` by default will contain all the predicted variables, as well as the
variables already present in the input `chain`. If you only want the predicted variables,
set `include_all=false`.

The returned chain will also contain log-probabilities corresponding to the re-evaluation of
the model. In particular, the log probability for the newly predicted variables are
now considered as prior terms. However, note that the log-prior of the returned chain will
also contain the log-prior terms of the parameters already present in the input `chain`.
Thus, if you want to obtain the log-probability of the predicted variables only, you can
subtract the two log-prior terms. The `include_all` keyword argument has no effect on the
log-probability fields.
"""
function DynamicPPL.predict(
    rng::Random.AbstractRNG,
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName};
    include_all::Bool=true,
)::FlexiChain{VarName}
    existing_parameters = Set(FlexiChains.parameters(chain))
    param_dicts = map(reevaluate(rng, model, chain)) do (_, vi)
        vn_dict = DynamicPPL.getacc(vi, Val(:ValuesAsInModel)).values
        # ^ that is OrderedDict{VarName}
        p_dict = OrderedDict{ParameterOrExtra{<:VarName},Any}(
            Parameter(vn) => val for
            (vn, val) in vn_dict if (include_all || !(vn in existing_parameters))
        )
        # Tack on the probabilities
        p_dict[FlexiChains._LOGPRIOR_KEY] = DynamicPPL.getlogprior(vi)
        p_dict[FlexiChains._LOGJOINT_KEY] = DynamicPPL.getlogjoint(vi)
        p_dict[FlexiChains._LOGLIKELIHOOD_KEY] = DynamicPPL.getloglikelihood(vi)
        p_dict
    end
    ni, nc = size(chain)
    predictions_chain = FlexiChain{VarName}(
        ni,
        nc,
        param_dicts;
        iter_indices=FlexiChains.iter_indices(chain),
        chain_indices=FlexiChains.chain_indices(chain),
    )
    old_extras_chain = FlexiChains.subset_extras(chain)
    return merge(old_extras_chain, predictions_chain)
end
function DynamicPPL.predict(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}; include_all::Bool=true
)::FlexiChain{VarName}
    return DynamicPPL.predict(Random.default_rng(), model, chain; include_all=include_all)
end

"""
    DynamicPPL.pointwise_logdensities(
        model::Model,
        chain::FlexiChain{T},
        ::Val{whichlogprob}=Val(:both),
    )::FlexiChain{T} where {T<:VarName,whichlogprob}

Calculate the log probability density associated with each variable in the model, for each
iteration in the `FlexiChain`.

The `whichlogprob` argument controls which log probabilities are calculated and stored. It can take the values `:prior`, `:likelihood`, or `:both` (the default).

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
variables to their log probabilities.
"""
function DynamicPPL.pointwise_logdensities(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}, ::Val{whichlogprob}=Val(:both)
) where {whichlogprob}
    AccType = DynamicPPL.PointwiseLogProbAccumulator{whichlogprob}
    pld_dicts = map(reevaluate(model, chain, (AccType(),))) do (_, vi)
        logps = DynamicPPL.getacc(vi, Val(DynamicPPL.accumulator_name(AccType))).logps
        OrderedDict{ParameterOrExtra{<:VarName},Any}(
            Parameter(vn) => only(val) for (vn, val) in logps
        )
    end
    return FlexiChain{VarName}(
        FlexiChains.niters(chain),
        FlexiChains.nchains(chain),
        pld_dicts;
        iter_indices=FlexiChains.iter_indices(chain),
        chain_indices=FlexiChains.chain_indices(chain),
    )
end

"""
    DynamicPPL.pointwise_loglikelihoods(
        model::Model,
        chain::FlexiChain{<:VarName},
    )::FlexiChain{VarName} where

Calculate the log likelihood associated with each observed variable in the model, for each
iteration in the `FlexiChain`.

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
observed variables to their log probabilities.
"""
function DynamicPPL.pointwise_loglikelihoods(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)
    return DynamicPPL.pointwise_logdensities(model, chain, Val(:likelihood))
end

"""
    DynamicPPL.pointwise_prior_logdensities(
        model::Model,
        chain::FlexiChain{<:VarName},
    )::FlexiChain{VarName} where

Calculate the log likelihood associated with each observed variable in the model, for each
iteration in the `FlexiChain`.

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
observed variables to their log probabilities.
"""
function DynamicPPL.pointwise_prior_logdensities(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)
    return DynamicPPL.pointwise_logdensities(model, chain, Val(:prior))
end

end # module FlexiChainsDynamicPPLExt
