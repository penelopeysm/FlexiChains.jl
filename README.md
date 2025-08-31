## FlexiChains.jl

Flexible Markov chains.

[**Documentation**](http://pysm.dev/FlexiChains.jl/)

### Usage

To obtain a `FlexiChain` via MCMC sampling in Turing.jl, pass the `chain_type` argument to the `sample` function.

```julia
using Turing
using FlexiChains: VNChain

@model f() = x ~ Normal()
chain = sample(f(), NUTS(), 1000; chain_type=VNChain)
```

Functions in Turing.jl which take chains as input, such as `returned`, `predict`, and `logjoint` should work out of the box with exactly the same behaviour as before.
If you find a function that does not work, please let me know by opening an issue.

> [!NOTE]
> While I promise to always satisfy the interface to Turing.jl, this is not necessarily true for functions that are defined directly in MCMCChains.jl, such as data analysis or plotting. Of course I would like to make this package as feature-rich as possible (and issues are therefore *still* very much welcome), but such features may either be deprioritised or omitted due to design decisions.
>
> In the meantime, if you need a feature that is only present in MCMCChains, you can convert to the old `MCMCChains.Chains` type using `MCMCChains.Chains(chain)`.

### How is this better?

Turing's default data type for Markov chains is [`MCMCChains.Chains`](https://turinglang.org/MCMCChains.jl/stable/).

This entire package essentially came about because I think `MCMCChains.Chains` is a bad data structure.
Specifically, it represents data as a mapping of `Symbol`s to arrays of `Float64`s.

<div align="center">
<img width="450" alt="flexichains" src="https://github.com/user-attachments/assets/4101f2e9-d61d-4e02-bb57-e0bf5ec11e31" />
</div>

However, Turing.jl uses `VarName`s as keys in its models, and the values can be anything that is sampled from a distribution.

This leads to several problems:

1. **The conversion from `VarName` to `Symbol` is lossy.** See [here](https://github.com/TuringLang/MCMCChains.jl/issues/469) and [here](https://github.com/TuringLang/MCMCChains.jl/issues/470) for examples of how this can bite users.

1. **Array-valued parameters must be broken up in a chain.** This makes it very annoying to reconstruct the full arrays. It also causes [massive slowdowns for some operations](https://github.com/TuringLang/DynamicPPL.jl/issues/1019), and is also responsible for [some hacky code in AbstractPPL and DynamicPPL](https://github.com/TuringLang/AbstractPPL.jl/pull/125) that has no reason to exist beyond the limitations of MCMCChains.

1. **Inability to store generic information from MCMC sampling.** For example, a model containing a line such as `x := s::String` (see [here](https://turinglang.org/docs/usage/tracking-extra-quantities/) for the meaning of `:=`) will error.

1. **Overly aggressive casting to avoid abstract types.** If you have an integer-valued parameter, it will be cast to `Float64` when sampling using MCMCChains. See [this issue](https://github.com/TuringLang/Turing.jl/issues/2666) for details.

FlexiChains solves all of these by making the mapping of parameters to values much more flexible (hence the name).
Both keys and values can, in general, be of any type.
This makes for a less compact representation of the data, but means that information about the chain is preserved much more faithfully.
