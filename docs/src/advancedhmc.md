# [AdvancedHMC.jl](@id integrations-advancedhmc)

[Documentation for AdvancedHMC.jl ↗](@extref AdvancedHMC :doc:`index`)

[`FlexiChains.to_nt_and_stats`](@ref) is overloaded for `AdvancedHMC.Transition`, so you can sample with AdvancedHMC into a `FlexiChain{Symbol}`.
This is a slightly simplified version of the example in the AdvancedHMC README (here we use an analytical gradient rather than automatic differentiation):

```@example advancedhmc
using AdvancedHMC, AbstractMCMC
using LogDensityProblems
using FlexiChains: FlexiChain

# Set up AD-aware log-density function
struct LogTargetDensity
    dim::Int
end
LogDensityProblems.logdensity(::LogTargetDensity, θ) = -sum(abs2, θ) / 2
LogDensityProblems.logdensity_and_gradient(::LogTargetDensity, θ) = (-sum(abs2, θ) / 2, -θ)
LogDensityProblems.dimension(p::LogTargetDensity) = p.dim
function LogDensityProblems.capabilities(::Type{LogTargetDensity})
    return LogDensityProblems.LogDensityOrder{1}()
end

chn = AbstractMCMC.sample(
    LogTargetDensity(10),
    AdvancedHMC.NUTS(0.8),
    20;
    n_adapts=10,
    chain_type=FlexiChain{Symbol},
)
```
