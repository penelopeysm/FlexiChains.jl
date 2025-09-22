## 0.0.2

There are many interface changes in this release.
As the version number suggests, this is still a very early release of FlexiChains.jl, and the API is likely to change in future versions.
When the API has somewhat stabilised, the version number will be incremented to 0.1.0.

In particular, indexing into a FlexiChain (or summary) now returns a DimMatrix from the DimensionalData.jl package.
This is a much nicer representation of the data.
It does mean that this version now sacrifices the idea that single-chain `FlexiChain`s are "special": `chn[k]` now returns a 2D matrix even if the chain dimension only has length 1.
This is probably for the better anyway since it makes the behaviour more consistent.

To make this work optimally, when constructing a `FlexiChain` you should now also provide `iter_indices` and `chain_indices` keyword arguments which specify how the iteration and chain dimensions should be labelled.
When sampling with Turing.jl these are automatically provided (via the keyword arguments to `bundle_samples`).

There are numerous other changes associated with this.
For example the sampling time and final sampler state should now always be given as vectors, even if there is only one chain.
They are also always returned as vectors.

Functions such as `DynamicPPL.returned` now also return a `DimMatrix`.

## 0.0.1

This is the initial release of FlexiChains.jl.

FlexiChains is a new package for working with Markov chains, with a particular emphasis on supporting features of Turing.jl.
As its name suggests, it is designed to be more flexible than the existing MCMCChains.jl library.
This means that, for example, vector-valued parameters are stored 'as is' without being broken up into individual indices.

This not only makes it much less clunky to work with large arrays; it also leads to performance gains (sometimes), improved compatibility with DynamicPPL.jl, and a more accurate representation of the parameters you have sampled.

Do consult [the documentation](http://pysm.dev/FlexiChains.jl/) for more information, and please feel free to get in touch with issues or suggestions!
