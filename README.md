## FlexiChains.jl

Flexible Markov chains.

### What do you mean by 'flexible'?

The main problems I am trying to solve are summarised in 
- https://github.com/TuringLang/MCMCChains.jl/issues/469
- https://github.com/TuringLang/MCMCChains.jl/issues/470

I consider these to be a fundamental flaw in the data structure that MCMCChains.jl uses.

In particular, the restriction of the key type in MCMCChains.jl to `Symbol` is very limiting.
This is responsible for some hacky workarounds in Turing.jl and DynamicPPL.jl, which both fundamentally use `AbstractPPL.VarName` as a key type.
It also means that a good amount of code that _should_ be the responsibility of the Chains type is handled in DynamicPPL instead.

### What's the intended interface?

This is intended as a drop-in replacement of MCMCChains.jl.

You can already do this now:

```julia
using Turing, FlexiChains

@model f() = lp ~ Normal()
chain = sample(f(), NUTS(), 1000; chain_type=VNFlexiChain)
```

Notice that (unlike MCMCChains, as shown [in this issue](https://github.com/TuringLang/MCMCChains.jl/issues/469)) FlexiChains allows you to distinguish between the `lp` variable and the `lp` metadata that represents the log probability density:

```julia
julia> chain[:logprobs, :lp] == logpdf.(Normal(), chain[@varname(lp)])
true
```

Do bear in mind that FlexiChains has not reached feature parity with MCMCChains (and may not for a while).

### Why from scratch?

Fixing the problems discussed above requires fundamentally reworking the data structure in MCMCChains.jl, which would essentially be a rewrite, because all of its behaviour stems from its data structure.

So, it's just faster for me to iterate on design choices when I don't also have to undo previous design choices.
Furthermore, at the design stage I don't want to have to wait for people to review my PRs.

Depending on where this goes, it is possible that we may either make it the default chains type in Turing.jl; or we may make a new major release of MCMCChains.jl that uses this instead.
