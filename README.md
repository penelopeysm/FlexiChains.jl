## FlexiChains.jl

Flexible Markov chains.

> [!WARNING]
> This package is in early development and its interface is subject to change. This is especially so because I don't have a lot of time to spend on this and to think about interface design. (Suggestions are more than welcome.)

### Usage

To obtain a chain using Turing.jl's MCMC sampling, pass the `chain_type` argument to the `sample` function.

```julia
using Turing
using FlexiChains: VNChain

@model f() = x ~ Normal()
chain = sample(f(), NUTS(), 1000; chain_type=VNChain)
```

Whenever you attempt to use a function from Turing.jl or DynamicPPL.jl that takes a chain as an argument, you should be able to use a `FlexiChains.VNChain` instead of `MCMCChains.Chains`.

Other functions, such as `returned`, `predict`, and `logjoint` should work out of the box with exactly the same behaviour as before.
If you find a function that does not work, please let me know by opening an issue!

> [!INFO]
> While I promise to always satisfy the interface to Turing.jl, this is not necessarily true for functions that are defined directly in MCMCChains.jl, such as data analysis or plotting. Of course I would like to make this package as feature-rich as possible (and issues are therefore *still* very much welcome), but such features may either be deprioritised or omitted due to design decisions.
>
> In the meantime, if you need a feature that is only present in MCMCChains, there is a conversion function to transform a `FlexiChains.VNChain` into `MCMCChains.Chains`.

### How is this better?

The main data type for Markov chains is [`MCMCChains.Chains`](https://turinglang.org/MCMCChains.jl/stable/).

This entire package essentially came about because I think `MCMCChains.Chains` is a bad data structure.
The problem is that it is very restrictive in terms of its key and value types: fundamentally it is a mapping of `Symbol`s to arrays of `Real`s.
However, Turing.jl uses `VarName`s as keys in its models.

This leads to several problems:

1. **The conversion from `VarName` to `Symbol` is lossy.** See [here](https://github.com/TuringLang/MCMCChains.jl/issues/469) and [here](https://github.com/TuringLang/MCMCChains.jl/issues/470) for examples of how this can bite users.

1. **Array-valued parameters must be broken up in a chain.** This makes it very annoying to reconstruct the full arrays. It also causes [massive slowdowns for some operations](https://github.com/TuringLang/DynamicPPL.jl/issues/1019), and is also responsible for [some hacky code in AbstractPPL and DynamicPPL](https://github.com/TuringLang/AbstractPPL.jl/pull/125) that has no reason to exist beyond the limitations of MCMCChains.

1. **Inability to store generic information from MCMC sampling.** For example, a model containing a line such as `x := s::String` (see [here](https://turinglang.org/docs/usage/tracking-extra-quantities/) for the meaning of `:=`) will error.

### Why write this from scratch?

Fixing the problems discussed above requires fundamentally reworking the data structure in MCMCChains.jl, which would essentially be a rewrite, because all of its behaviour stems from its data structure.

So, it's just faster for me to iterate on design choices when I don't also have to undo previous design choices.
Furthermore, at the design stage I don't want to have to wait for people to review my PRs.

Depending on where this goes, it is possible that we may either make it the default chains type in Turing.jl; or we may make a new major release of MCMCChains.jl that uses this instead.
