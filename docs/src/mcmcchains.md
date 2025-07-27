# Migrating from MCMCChains.jl

FlexiChains.jl has been designed from the ground up to address existing limitations of [MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl).

This page describes some key differences from MCMCChains.jl and how you can migrate your code to use FlexiChains.jl.

To make this clearer, let's sample from a typical Turing model and store the results in both `MCMCChains.Chains` and `FlexiChains.FlexiChain`.

```julia
# using Turing, MCMCChains, FlexiChains
# 
# @model function f()
#     x ~ MvNormal(zeros(2), I)
# end
```

## Chain key types

Under the hood, MCMCChains.jl uses [`AxisArrays.AxisArray`](https://github.com/JuliaArrays/AxisArrays.jl/) as its data structure.
Specifically, this allows it to store data in a compact 3-dimensional matrix, and index into the matrix using `Symbol`s.

The downside of this is that it enforces a key type of `Symbol` and a value type of `Tval<:Real`.
This means that, for example, if you have a model with vector-valued parameters (like `x` above), the vectors will be split up into their individual elements before being stored in the chain.

(To be continued...)
