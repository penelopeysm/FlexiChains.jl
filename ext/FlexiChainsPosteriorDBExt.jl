module FlexiChainsPosteriorDBExt

using PosteriorDB
using OrderedCollections: OrderedDict
using FlexiChains: FlexiChains, FlexiChain, Parameter

"""
    FlexiChains.from_posteriordb_ref(
        ref::PosteriorDB.ReferencePosterior
    )::FlexiChain{String}

Load a `PosteriorDB.ReferencePosterior` into a `FlexiChain`. The keys are stored as strings,
which matches the storage format in PosteriorDB.jl.
"""
function FlexiChains.from_posteriordb_ref(ref::PosteriorDB.ReferencePosterior)
    ref_post = PosteriorDB.load(ref)
    ref_info = PosteriorDB.info(ref)
    # All of this Dict indexing is obviously quite fragile, but surprisingly it just works
    # on all the reference posteriors in PosteriorDB (this is tested in CI), so I guess we
    # can just roll with it.
    nchains = ref_info["inference"]["method_arguments"]["chains"]
    # nsteps = total number of steps including warmup and thinned
    nsteps = ref_info["inference"]["method_arguments"]["iter"]
    nwarmup = ref_info["inference"]["method_arguments"]["warmup"]
    thin = ref_info["inference"]["method_arguments"]["thin"]
    niters, r = divrem(nsteps - nwarmup, thin)
    @assert r == 0

    # `ref_post` is a Vector of OrderedDicts, one per chain. The internal
    # OrderedDicts are in fact already pretty much in the right format
    # for FlexiChains, except that their keys are Symbols.
    #
    # We _could_ convert each OrderedDict to a chain and then hcat them,
    # but let's be good citizens and avoid unnecessary work by hcatting the
    # raw data directly.
    d = OrderedDict{Parameter{String},Matrix{Float64}}()
    for k in keys(ref_post[1])
        d[Parameter(k)] = hcat(map(d -> d[k], ref_post)...)
    end
    iter_indices = if thin != 1
        range(nwarmup + thin; step=thin, length=niters)
    else
        # This returns UnitRange not StepRange -- a bit cleaner
        (nwarmup + 1):nsteps
    end
    return FlexiChain{String}(niters, nchains, d; iter_indices=iter_indices)
end

end # module
