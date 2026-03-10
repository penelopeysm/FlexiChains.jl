module FlexiChainsDynamicPPLExt

using FlexiChains:
    FlexiChains, FlexiChain, VarName, Parameter, Extra, ParameterOrExtra, VNChain
using DimensionalData: DimensionalData as DD
using DynamicPPL:
    DynamicPPL,
    AbstractPPL,
    AbstractMCMC,
    Distributions,
    UnlinkAll,
    UntransformedValue,
    VarNamedTuple
using OrderedCollections: OrderedDict
using Random: Random

##################
# bundle_samples #
##################
function AbstractMCMC.bundle_samples(
    # TODO(penelopeysm): When VarNamedTuple is moved into AbstractPPL, this can go back
    # into src/ rather than the extension.
    transitions::AbstractVector,
    @nospecialize(m::AbstractMCMC.AbstractModel),
    @nospecialize(s::AbstractMCMC.AbstractSampler),
    last_sampler_state::Any,
    chain_type::Type{FlexiChain{VarName}};
    save_state=false,
    stats=missing,
    discard_initial::Int=0,
    thinning::Int=1,
    _kwargs...,
)::FlexiChain{VarName}
    niters = length(transitions)
    vnts_and_stats = map(FlexiChains.to_vnt_and_stats, transitions)
    dicts = map(vnts_and_stats) do (vnt, stat)
        d = OrderedDict{ParameterOrExtra{<:VarName},Any}(
            Parameter(vn) => val for (vn, val) in pairs(vnt)
        )
        for (stat_vn, stat_val) in pairs(stat)
            d[Extra(stat_vn)] = stat_val
        end
        d
    end
    # note that FlexiChains constructor expects structures to have size (niters x nchains),
    # so a vector won't do
    skeletons = hcat(map(DynamicPPL.skeleton ∘ first, vnts_and_stats))
    # timings
    tm = stats === missing ? missing : stats.stop - stats.start
    # last sampler state
    st = save_state ? last_sampler_state : missing
    # calculate iteration indices
    start = discard_initial + 1
    iter_indices = if thinning != 1
        range(start; step=thinning, length=niters)
    else
        # This returns UnitRange not StepRange -- a bit cleaner
        start:(start + niters - 1)
    end
    return FlexiChain{VarName}(
        niters,
        1,
        dicts;
        structures=skeletons,
        iter_indices=iter_indices,
        # 1:1 gives nicer DimMatrix output than just [1]
        chain_indices=1:1,
        sampling_time=[tm],
        last_sampler_state=[st],
    )
end

function FlexiChains.reconstruct_values(chn::VNChain, i, j, structure::VarNamedTuple)
    vnt = DynamicPPL.VarNamedTuple()
    nt = NamedTuple()
    for param_or_extra in keys(chn)
        val = chn[param_or_extra][i, j]
        if param_or_extra isa Parameter
            ismissing(val) && continue
            vn = param_or_extra.name
            top_sym = AbstractPPL.getsym(vn)
            template = get(structure.data, top_sym, DynamicPPL.NoTemplate())
            vnt = DynamicPPL.templated_setindex!!(vnt, val, vn, template)
        elseif param_or_extra isa Extra
            nt = merge(nt, (; Symbol(param_or_extra.name) => val))
        end
    end
    return DynamicPPL.ParamsWithStats(vnt, nt)
end

function FlexiChains.reconstruct_parameters(chn::VNChain, i, j, structure::VarNamedTuple)
    vnt = DynamicPPL.VarNamedTuple()
    for vn in FlexiChains.parameters(chn)
        val = chn[Parameter(vn)][i, j]
        ismissing(val) && continue
        top_sym = AbstractPPL.getsym(vn)
        template = get(structure.data, top_sym, DynamicPPL.NoTemplate())
        vnt = DynamicPPL.templated_setindex!!(vnt, val, vn, template)
    end
    return vnt
end

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
            Parameter(vn) => val for (vn, val) in pairs(ps.params)
        )
        # Stats
        for (stat_vn, stat_val) in pairs(ps.stats)
            d[Extra(stat_vn)] = stat_val
        end
        d
    end
    # And get the structures.
    structures = map(ps -> DynamicPPL.skeleton(ps.params), params_and_stats)
    return VNChain(
        size(params_and_stats, 1), size(params_and_stats, 2), dicts; structures=structures
    )
end

"""
    AbstractMCMC.to_samples(
        ::Type{DynamicPPL.ParamsWithStats},
        chain::VNChain,
        [model::DynamicPPL.Model]
    )::DimensionalData.DimMatrix{DynamicPPL.ParamsWithStats}

Convert a `VNChain` to a `DimMatrix` of [`DynamicPPL.ParamsWithStats`](@extref).

The axes of the `DimMatrix` are the same as those of the input `VNChain`.
"""
function AbstractMCMC.to_samples(
    ::Type{DynamicPPL.ParamsWithStats}, chain::FlexiChain{T}, model::DynamicPPL.Model
)::DD.DimMatrix{<:DynamicPPL.ParamsWithStats} where {T<:VarName}
    template_vnt = nothing # Set later on-demand.
    # If there is no skeletal VNT structure stored, then values_at will return a Dict.
    # Otherwise it will return a ParamsWithStats
    dicts_or_pwss = FlexiChains.values_at(chain, :, :)
    pwss = map(dicts_or_pwss) do d_or_pws
        if d_or_pws isa DynamicPPL.ParamsWithStats
            d_or_pws
        else
            # No skeleton -- rerun the model once to get a template, and pray that
            # it's accurate.
            if template_vnt === nothing
                template_vnt = rand(model)
            end
            # Then attempt to reconstruct
            vnt = DynamicPPL.VarNamedTuple()
            for (vn_param, val) in pairs(d_or_pws)
                if vn_param isa Parameter
                    vn = vn_param.name
                    top_sym = AbstractPPL.getsym(vn)
                    template = get(template_vnt.data, top_sym, DynamicPPL.NoTemplate())
                    vnt = DynamicPPL.templated_setindex!!(vnt, val, vn, template)
                end
            end
            # Stats
            stats_nt = NamedTuple(
                Symbol(extra_param.name) => val for
                (extra_param, val) in d_or_pws if extra_param isa Extra
            )
            DynamicPPL.ParamsWithStats(vnt, stats_nt)
        end
    end
    return FlexiChains._raw_to_user_data(chain, pwss)
end

function AbstractMCMC.to_samples(
    ::Type{DynamicPPL.ParamsWithStats}, chain::FlexiChain{T}
)::DD.DimMatrix{<:DynamicPPL.ParamsWithStats} where {T<:VarName}
    # If there is no skeletal VNT structure stored, then values_at will return a Dict.
    # Otherwise it will return a ParamsWithStats
    dicts_or_pwss = FlexiChains.values_at(chain, :, :)
    pwss = map(dicts_or_pwss) do d_or_pws
        if d_or_pws isa DynamicPPL.ParamsWithStats
            d_or_pws
        else
            # No skeleton. Just cry and use setindex!!.
            vnt = DynamicPPL.VarNamedTuple()
            for (vn_param, val) in pairs(d_or_pws)
                if vn_param isa Parameter
                    vnt = DynamicPPL.setindex!!(vnt, val, vn_param.name)
                end
            end
            # Stats
            stats_nt = NamedTuple(
                Symbol(extra_param.name) => val for
                (extra_param, val) in d_or_pws if extra_param isa Extra
            )
            DynamicPPL.ParamsWithStats(vnt, stats_nt)
        end
    end
    return FlexiChains._raw_to_user_data(chain, pwss)
end

# This method will make `bundle_samples` 'just work'
function FlexiChains.to_vnt_and_stats(pws::DynamicPPL.ParamsWithStats)
    return (pws.params, pws.stats)
end
function FlexiChains.to_vnt_and_stats(vnt::DynamicPPL.VarNamedTuple)
    return (vnt, (;))
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
    return InitFromFlexiChain(chn, iter, chain, fallback)
end

"""
    InitFromFlexiChain(
        chain::FlexiChain, iter_index::Int, chain_index::Int, fallback=nothing
    )

A DynamicPPL initialisation strategy that obtains values from the given `FlexiChain` at the
specified iteration and chain indices.

In order for `InitFromFlexiChain` to work correctly, two things must be ensured:

1. The variables being asked for must **exactly** match those stored in the FlexiChain. That
   is, if the chain contains `@varname(y)` and the model asks for `@varname(y)`, this will
   either error (if no fallback is provided) or silently use the fallback.

2. The `iter_index` and `chain_index` arguments must be 1-based indices.

These requirements allow us to skip the usual `getindex` method when retrieving values from
the `FlexiChain`, and instead index directly into the data storage, which is much faster.

These conditions, especially (1), can be guaranteed if and only if the chain used to
re-evaluate the model was generated from the same model (or a model with the same
structure).

`fallback` provides the same functionality as it does in `DynamicPPL.InitFromParams`, that
is, if a variable is not found in the `FlexiChain`, the fallback strategy is used to
generate its value. This is necessary for `predict`.
"""
struct InitFromFlexiChain{
    C<:FlexiChains.VNChain,S<:Union{DynamicPPL.AbstractInitStrategy,Nothing}
} <: DynamicPPL.AbstractInitStrategy
    chain::C
    iter_index::Int
    chain_index::Int
    fallback::S
end
function DynamicPPL.init(
    rng::Random.AbstractRNG,
    vn::VarName,
    dist::Distributions.Distribution,
    strategy::InitFromFlexiChain,
)
    param = FlexiChains.Parameter(vn)
    # First check if there's an exact match in the chain, and if so, use that.
    #
    # Otherwise, attempt to construct the full dictionary of parameters and use
    # that. (That guards against cases where the chain has a densified variable
    # e.g. `x`, but the model has `x[1]` and `x[2]`: e.g. x = zeros(2); x .~
    # Normal().)
    #
    # Finally, if even that isn't found, just use the fallback strategy (if
    # provided).
    if haskey(strategy.chain._data, param)
        x = strategy.chain._data[param][strategy.iter_index, strategy.chain_index]
        return UntransformedValue(x)
    else
        # TODO: We could be smarter here; if the variable is completely a different symbol
        # from whatever is in the chain, we could skip straight to the fallback.
        vnt = FlexiChains.parameters_at(
            strategy.chain, strategy.iter_index, strategy.chain_index
        )
        augmented_fallback = DynamicPPL.InitFromParams(vnt, strategy.fallback)
        return DynamicPPL.init(rng, vn, dist, augmented_fallback)
    end
end

###########################################
# DynamicPPL: predict, returned, logjoint #
###########################################

function _default_reevaluate_accs()
    return (
        DynamicPPL.LogPriorAccumulator(),
        DynamicPPL.LogJacobianAccumulator(),
        DynamicPPL.LogLikelihoodAccumulator(),
        DynamicPPL.RawValueAccumulator(true),
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
    fallback_strategy::Union{DynamicPPL.AbstractInitStrategy,Nothing}=nothing,
)::DD.DimMatrix{<:Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    niters, nchains = size(chain)
    tuples = Iterators.product(1:niters, 1:nchains)
    vi = DynamicPPL.OnlyAccsVarInfo(DynamicPPL.AccumulatorTuple(accs))
    retvals_and_varinfos = map(tuples) do (i, j)
        DynamicPPL.init!!(
            rng,
            model,
            vi,
            InitFromFlexiChain(chain, i, j, fallback_strategy),
            UnlinkAll(),
        )
    end
    return FlexiChains._raw_to_user_data(chain, retvals_and_varinfos)
end
function reevaluate(
    model::DynamicPPL.Model,
    chain::FlexiChain{<:VarName},
    accs::NTuple{N,DynamicPPL.AbstractAccumulator}=_default_reevaluate_accs(),
    fallback_strategy::Union{DynamicPPL.AbstractInitStrategy,Nothing}=nothing,
)::DD.DimMatrix{<:Tuple{<:Any,<:DynamicPPL.AbstractVarInfo}} where {N}
    return reevaluate(Random.default_rng(), model, chain, accs, fallback_strategy)
end

"""
    DynamicPPL.returned(model::DynamicPPL.Model, chain::FlexiChain{<:VarName})

Returns a `DimMatrix` of the model's return values, re-evaluated using the parameters in
each iteration of the chain.

If the return value is a `DimArray`, the dimensions will be stacked.
"""
function DynamicPPL.returned(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)::DD.DimArray
    return FlexiChains._raw_to_user_data(chain, map(first, reevaluate(model, chain)))
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
    accs = _default_reevaluate_accs()
    fallback = DynamicPPL.InitFromPrior()
    param_dicts_and_skeletons =
        map(reevaluate(rng, model, chain, accs, fallback)) do (_, vi)
            vnt = DynamicPPL.densify!!(DynamicPPL.get_raw_values(vi))
            p_dict = OrderedDict{ParameterOrExtra{<:VarName},Any}(
                Parameter(vn) => val for
                (vn, val) in pairs(vnt) if (include_all || !(vn in existing_parameters))
            )
            # Use skeletons from reevaluation, since they will be appropriate for the new
            # chain that we are constructing.
            skeleton = DynamicPPL.skeleton(vnt)
            # Tack on the probabilities
            p_dict[FlexiChains._LOGPRIOR_KEY] = DynamicPPL.getlogprior(vi)
            p_dict[FlexiChains._LOGJOINT_KEY] = DynamicPPL.getlogjoint(vi)
            p_dict[FlexiChains._LOGLIKELIHOOD_KEY] = DynamicPPL.getloglikelihood(vi)
            (p_dict, skeleton)
        end
    ni, nc = size(chain)
    predictions_chain = FlexiChain{VarName}(
        ni,
        nc,
        map(first, param_dicts_and_skeletons);
        structures=map(last, param_dicts_and_skeletons),
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

# Shared internal helper function.
function _pointwise_logprobs(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}, ::Val{Prior}, ::Val{Likelihood}
) where {Prior,Likelihood}
    acc = DynamicPPL.VNTAccumulator{DynamicPPL.POINTWISE_ACCNAME}(
        DynamicPPL.PointwiseLogProb{Prior,Likelihood}()
    )
    pointwise_dicts = map(reevaluate(model, chain, (acc,), nothing)) do (_, oavi)
        logprobs = DynamicPPL.densify!!(DynamicPPL.get_pointwise_logprobs(oavi))
        OrderedDict{ParameterOrExtra{<:VarName},Any}(
            Parameter(vn) => val for (vn, val) in pairs(logprobs)
        )
    end
    ni, nc = size(chain)
    return FlexiChain{VarName}(
        ni,
        nc,
        pointwise_dicts;
        iter_indices=FlexiChains.iter_indices(chain),
        chain_indices=FlexiChains.chain_indices(chain),
    )
end

"""
    DynamicPPL.pointwise_logdensities(
        model::Model,
        chain::FlexiChain{<:VarName}
    )::FlexiChain{VarName}

Calculate the log probability density associated with each variable in the model, for each
iteration in the `FlexiChain`.

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
variables to their log probabilities.
"""
function DynamicPPL.pointwise_logdensities(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)
    return _pointwise_logprobs(model, chain, Val(true), Val(true))
end

"""
    DynamicPPL.pointwise_loglikelihoods(
        model::Model,
        chain::FlexiChain{<:VarName},
    )::FlexiChain{VarName}

Calculate the log likelihood associated with each observed variable in the model, for each
iteration in the `FlexiChain`.

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
observed variables to their log probabilities.
"""
function DynamicPPL.pointwise_loglikelihoods(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)
    return _pointwise_logprobs(model, chain, Val(false), Val(true))
end

"""
    DynamicPPL.pointwise_prior_logdensities(
        model::Model,
        chain::FlexiChain{<:VarName},
    )::FlexiChain{VarName}

Calculate the log prior associated with each random variable in the model, for each
iteration in the `FlexiChain`.

Returns a new `FlexiChain` with the same structure as the input `chain`, mapping the
observed variables to their log probabilities.
"""
function DynamicPPL.pointwise_prior_logdensities(
    model::DynamicPPL.Model, chain::FlexiChain{<:VarName}
)
    return _pointwise_logprobs(model, chain, Val(true), Val(false))
end

#######################
# Precompile workload #
#######################

using DynamicPPL: DynamicPPL, Distributions, AbstractMCMC, @model, VarInfo, ParamsWithStats
using FlexiChains: VNChain, summarystats
using PrecompileTools: @setup_workload, @compile_workload

# dummy, needed to satisfy interface of bundle_samples
struct NotASampler <: AbstractMCMC.AbstractSampler end
@setup_workload begin
    @model function f()
        x ~ Distributions.MvNormal(zeros(2), [1.0 0.5; 0.5 1.0])
        return y ~ Distributions.Normal()
    end
    model = f()
    transitions = [ParamsWithStats(VarInfo(model), model) for _ in 1:10]
    @compile_workload begin
        chn = AbstractMCMC.bundle_samples(
            transitions, model, NotASampler(), nothing, VNChain
        )
        summarystats(chn)
    end
end

end # module FlexiChainsDynamicPPLExt
