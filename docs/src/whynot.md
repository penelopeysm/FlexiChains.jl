# Why not FlexiChains?

Since I wrote one whole page saying why you _should_ use FlexiChains, here are the counterarguments, or at least those I can think of.

## Performance and type stability

FlexiChains uses dictionaries as its internal storage, and it is fundamentally not type stable to index into a dictionary with an abstract value type.
Consequently, the vast majority of operations in FlexiChains are not type stable.
They are potentially also slower than equivalent operations in MCMCChains.

Personally, I consider this to be really unimportant, because chain manipulation and data access are hardly performance bottlenecks in a typical Bayesian workflow.
If you find an instance where FlexiChains is unbearably slow, please do open an issue.

Note that when interfacing with Turing models, [FlexiChains is typically faster](@ref why-perf).

## Feature set

MCMCChains probably still has more plotting and statistics functions available, even though FlexiChains is catching up quite rapidly.
This is mainly because MCMCChains has been around for longer, and has had more contributors.

I would be very happy to accept PRs porting some of this functionality to FlexiChains!

In the meantime, you can always [convert your FlexiChain to a `DataFrame`](@ref integrations-tables), or an [`MCMCChains.Chains`](@ref) if you really need to.

## Interface stability

FlexiChains is still quite young, development is happening quite rapidly, and thus its interface may not be fully stable.
On the other hand MCMCChains is largely stable (although you _may_ consider a lack of development to be a drawback).

My aim is to release a version 1.0 as soon as possible.
(In general, I strongly subscribe to the view that packages that are used by the public should release 1.0 as soon as possible: see [this issue](https://github.com/JuliaRegistries/General/issues/111019).)
My preconditions for FlexiChains 1.0 are twofold:

1. I am happy with the core design and APIs of the package. For example, I don't really care about which statistic functions are implemented, but I do care that they return sensible data structures.

1. The package has been tested by a people in the wild, to catch any obvious gaps or drawbacks.

As of April 2026, I think that (1) is already satisfied: the data structures and APIs are pretty much where I want them to be, and I expect that future changes will mostly be addition of new functionality rather than breaking changes.
However, I am still waiting for (2) to really happen, and I would like to see more people using the package and giving feedback before I release 1.0.
