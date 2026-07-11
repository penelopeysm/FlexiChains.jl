module FlexiChainsPigeonsExt

using Pigeons: Pigeons
using FlexiChains: FlexiChains, FlexiChain, Parameter, Extra

function FlexiChains.from_pigeons(pt::Pigeons.PT)
    return FlexiChains._internal_from_pigeons(pt, pt.inputs.target)
end

# Reimplementation of Pigeons.sample_array, which avoids converting to Float unnecessarily
# See: https://github.com/Julia-Tempering/Pigeons.jl/issues/445
# 
# Returns niters x nchains x nparams array (NOTE: this differs from `Pigeons.sample_array`
# which returns niters x nparams x nchains). Also note that the last 'parameter' is the
# log-density.
function FlexiChains._faithful_sample_array(pt::Pigeons.PT)
    # NOTE: chains_with_samples is internal -- but I can't inline its definition because it
    # itself uses internal stuff! The only way to fix this is to upstream this
    # implementation into Pigeons.sample_array. See issue above.
    chains = Pigeons.chains_with_samples(pt)
    # Vector of Vector of samples, where each sample is itself a Vector.
    vec_vec_samples = [Pigeons.get_sample(pt, chn) for chn in chains]
    # This is nparams x niters x nchains
    arr = stack(stack(vec_vec_samples))
    return permutedims(arr, (2, 3, 1))
end

function FlexiChains._internal_from_pigeons(pt::Pigeons.PT, ::Any)
    sarr = FlexiChains._faithful_sample_array(pt)
    param_names = Pigeons.sample_names(pt)[1:(end-1)] # Drop logdensity.
    nparams = length(param_names)
    # For models that don't have names, Pigeons will generate `:param_1`, `:param_2`, etc.
    # In such a case we can just lump them into a single vector parameter. This is a bit of
    # a hack because we are essentially reverse-engineering Pigeons's default, but there
    # isn't really any other way to do it.
    ks = if param_names == [Symbol("param_$i") for i in 1:nparams]
        (Parameter(:param) => (nparams,), Extra(:log_density))
    else
        (Parameter.(param_names)..., Extra(:log_density))
    end
    return FlexiChain{Symbol}(sarr, ks)
end

end # module
