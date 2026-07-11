module FlexiChainsPigeonsExt

using Pigeons: Pigeons
using FlexiChains: FlexiChains

function FlexiChains.from_pigeons(pt::Pigeons.PT)
    # We have a special dispatch for when the model is a DynamicPPL model, so we need
    # to add a layer of indirection here.
    # Claude tells me that Pigeons does not provide an accessor function to get the model
    # so we have to just access the field directly, which I'm not entirely pleased about.
    return FlexiChains._internal_from_pigeons(pt, pt.inputs.target.model)
end

# Reimplementation of Pigeons.sample_array, which avoids converting to Float unnecessarily
# See: https://github.com/Julia-Tempering/Pigeons.jl/issues/445
function FlexiChains._faithful_sample_array(pt::Pigeons.PT)
    # NOTE: chains_with_samples is internal -- but I can't inline its definition because it
    # itself uses internal stuff! The only way to fix this is to upstream this
    # implementation into Pigeons.sample_array. See issue above.
    chains = Pigeons.chains_with_samples(pt)
    # Vector of Vector of samples, where each sample is itself a Vector.
    vec_vec_samples = [Pigeons.get_sample(pt, chn) for chn in chains]
    # This is nparams x niters x nchains
    arr = stack(stack(vec_vec_samples))
    return permutedims(arr, (2, 1, 3))
end

function FlexiChains._internal_from_pigeons(::Pigeons.PT, ::Any)
    error("unimplemented")
end

end # module
