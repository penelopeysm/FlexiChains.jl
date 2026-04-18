# FlexiChains.jl

**Rich, type-preserving storage for Markov chains.**

FlexiChains.jl provides a rich data structure for storing and analysing Markov chain Monte Carlo (MCMC) output.
Unlike traditional approaches that flatten everything to numeric arrays, FlexiChains preserves the original shapes of your parameters: all Julia types, most notably arrays, are stored without modification.

Key features:

- **Stores any Julia type.**
  Scalars work, but so do vectors, matrices, and everything else.

- **First-class Turing.jl integration.**
  Simply add `chain_type=VNChain` to your `sample` call.

- **Powerful and expressive indexing.**
  You can access parameters in a variety of ways, using the full power of DimensionalData.jl selectors.

- **Built-in plotting.**
  Both Plots.jl and Makie.jl backends are supported (work in progress!).

- **Extensive integrations with other Julia packages.**
  FlexiChains has a growing collection of package extensions to ensure maximum interoperability with the wider Julia ecosystem.

Read on to find out more!
