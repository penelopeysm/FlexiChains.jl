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
It's nowhere near there yet, so don't get your hopes up.
I have to implement the data structures but probably also a DynamicPPL extension so that it plays well with existing functionality.

If this does ever reach feature parity, then one day you will be able to do:

```julia
import FlexiChains: FlexiChain
sample(model, sampler, N; chain_type=FlexiChain)
```

and everything else will behave exactly the same as it currently does with MCMCChains.jl.

### Why from scratch?

Fixing the problems discussed above requires fundamentally reworking the data structure in MCMCChains.jl, which would essentially be a rewrite, because all of its behaviour stems from its data structure.

So, it's just faster for me to iterate on design choices when I don't also have to undo previous design choices.
Furthermore, at the design stage I don't want to have to wait for people to review my PRs.

Depending on where this goes, it is possible that we may either make it the default chains type in Turing.jl; or we may make a new major release of MCMCChains.jl that uses this instead.
However, right now, I think the most likely scenario is that I will maintain this myself.

### No premature optimisations

I consider performance to be a secondary concern for this package, because the main bottleneck in Bayesian inference is the sampling, not how fast one can construct or index into a chain.

For example, MCMCChains.jl uses AxisArrays.jl under the hood so that you can very quickly index into a chain with `chain[:my_param]`.
However, this is precisely the reason why only `Symbol` indices are allowed.
I don't care about making indexing fast (and honestly, nor should you); thus, FlexiChains doesn't use AxisArrays.
