## FlexiChains.jl

This is intended as a drop-in replacement of MCMCChains.jl.
It's nowhere near there yet, so don't get your hopes up.

The main problems I am trying to solve are summarised in 
- https://github.com/TuringLang/MCMCChains.jl/issues/469
- https://github.com/TuringLang/MCMCChains.jl/issues/470

I consider these to be a fundamental flaw in the data structure that MCMCChains.jl uses.

Furthermore, the restriction of the key type in MCMCChains.jl to `Symbol` is very limiting.
This is responsible for some hacky workarounds in Turing.jl and DynamicPPL.jl, which both use `AbstractPPL.VarName` as a key type.

In this package I intend to make a replacement Chains type that does not suffer from these problems.
I consider performance to be a secondary concern for this package, because the main bottleneck in Bayesian inference is the sampling, not how fast one can construct or index into a chain.
