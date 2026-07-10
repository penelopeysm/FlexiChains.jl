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

function FlexiChains._internal_from_pigeons(::Pigeons.PT, ::Any)
    error("unimplemented")
end

end # module
