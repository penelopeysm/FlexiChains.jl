module FlexiChainsTuringExt

using FlexiChains: FlexiChain, Parameter, OtherKey
using Turing
using Turing: AbstractMCMC

function AbstractMCMC.bundle_samples(
    ts::Vector{Turing.Inference.Transition},
    model::AbstractMCMC.AbstractModel,
    spl::Any,
    state::Any,
    chain_type::Type{FlexiChain},
)
    # TODO: need to handle save_state to allow resumption of sampling.
    error("Not implemented yet, needs https://github.com/TuringLang/Turing.jl/pull/2632")
end

end # module FlexiChainsTuringExt
