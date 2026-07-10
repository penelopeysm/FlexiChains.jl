module FlexiChainsPigeonsDynamicPPLExt

using Pigeons: Pigeons
using DynamicPPL: LogDensityFunction, UnlinkAll, ParamsWithStats, Model

using FlexiChains: FlexiChains
using AbstractMCMC

function FlexiChains._internal_from_pigeons(pt::Pigeons.PT, model::Model)
    # spls is a vector (length niters) of vectors (length nparams); the last param is
    # actually the log density...
    # Note that Pigeons unfortunately returns us a **flattened vector** of **unlinked**
    # parameters, which is annoying. Because it's flattened, we don't have any way to
    # extract the original parameter structure, so we need to feed it back through a
    # LogDensityFunction.
    spls = Pigeons.get_sample(pt)
    # Because the parameters are unlinked we use UnlinkAll() here.
    ldf = LogDensityFunction(model, UnlinkAll())
    # Then the usual stuff, reevaluate and make a chain. We drop the last element (which is
    # the log density) and also use `map(identity)` to concretise, because again annoyingly,
    # Pigeons always returns Vector{Union{Float64, Int64}}. See `extract_sample` in the
    # PigeonsDynamicPPLExt for info.
    pwss = hcat([ParamsWithStats(map(identity, s[1:(end-1)]), ldf) for s in spls])
    chn = AbstractMCMC.from_samples(FlexiChains.VNChain, pwss)
end

end # module
