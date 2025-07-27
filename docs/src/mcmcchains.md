# Migrating from MCMCChains.jl

FlexiChains.jl has been designed from the ground up to address existing limitations of [MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl).

This page describes some key differences from MCMCChains.jl and how you can migrate your code to use FlexiChains.jl.

## Chain key types

MCMCChains.jl enforces a key type of `Symbol` and a value type of `Tval<:Real`.
This means that, for example, if you have a model with vector-valued parameters, the vectors will be split up into their individual elements before being stored in the chain.

(To be continued...)
