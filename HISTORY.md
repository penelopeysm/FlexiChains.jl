## 0.0.2

Implemented methods for `SizedMatrix{1,1}` (i.e. actually a scalar) such that `data(sm::SizedMatrix{1,1,T})` returns a single `T` rather than a 1-element array.

## 0.0.1

This is the initial release of FlexiChains.jl.

FlexiChains is a new package for working with Markov chains, with a particular emphasis on supporting features of Turing.jl.
As its name suggests, it is designed to be more flexible than the existing MCMCChains.jl library.
This means that, for example, vector-valued parameters are stored 'as is' without being broken up into individual indices.

This not only makes it much less clunky to work with large arrays; it also leads to performance gains (sometimes), improved compatibility with DynamicPPL.jl, and a more accurate representation of the parameters you have sampled.

Do consult [the documentation](http://pysm.dev/FlexiChains.jl/) for more information, and please feel free to get in touch with issues or suggestions!
