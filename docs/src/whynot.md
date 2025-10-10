# Why _not_ FlexiChains?

Since I wrote one whole page saying why you _should_ use FlexiChains, here are the counterarguments, or at least those I can think of.

## Performance and type stability

FlexiChains uses dictionaries as its internal storage, and it is simply not type stable to index into a dictionary (with abstract key / value types).
Consequently, the vast majority of operations in FlexiChains are not type stable.
They are quite potentially also slower than equivalent operations in MCMCChains.

Personally, I consider this to be really unimportant, because chain manipulation and data access are hardly performance bottlenecks in a typical Bayesian workflow.
If you find an instance where FlexiChains is unbearably slow, please do open an issue.

## Feature set

MCMCChains has more plotting and statistics functions available.
This is mainly because MCMCChains has been around for longer, and has had more contributors.
But it should not be very difficult to make FlexiChains catch up.
For example, adding a new statistic essentially entails copying some existing code and changing the function name.

I would be very happy to accept PRs porting some of this functionality to FlexiChains!

In the meantime, you can always convert your FlexiChain to an `MCMCChains.Chains`.

## Interface stability

FlexiChains is still quite young, development is happening quite rapidly, and thus its interface may not be fully stable.
On the other hand MCMCChains is largely stable (although you _may_ consider a lack of development to be a drawback).

My aim is to release a version 1.0 as soon as possible.
(In general, I strongly subscribe to the view that packages that are used by the public should release 1.0 as soon as possible: see [this issue](https://github.com/JuliaRegistries/General/issues/111019).)
My preconditions for FlexiChains 1.0 are twofold:

1. I am happy with the core design and APIs of the package. That is to say, I don't care about which statistic functions are implemented, but I do care that they return sensible data structures.
1. The package has been tested by a few people in the wild for a month or so, to catch any obvious gaps or drawbacks.
