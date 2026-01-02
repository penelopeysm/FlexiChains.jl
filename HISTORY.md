# 0.3.2

Remove the 'exported' `split_varnames` function (the function was removed in 0.2.0, but the export wasn't deleted.)

# 0.3.1

Documentation improvements only.

# 0.3.0

If a model's return value is a `DimArray`, then `returned(model, chain::VNChain)` will now stack the axes together (much like indexing into a FlexiChain).

# 0.2.2

This release contains only documentation updates.

# 0.2.1

This release introduces support for DynamicPPL v0.39 and Turing v0.42.
There are no user-facing changes, but you should see some performance improvements in functions such as `returned` and `predict`.

# 0.2.0

## Breaking changes

### `split_varnames`

`FlexiChains.split_varnames` has been removed (technically, renamed and made internal).
From a user's point of view, summarising and plotting chains will still automatically split VarNames up.
However, you cannot do this for your own chains any more.

### DynamicPPL functions like `returned`, `predict`, `logjoint`

In v0.1, FlexiChains guaranteed that if you called `split_varnames(chn)`, these functions would still work correctly on the resulting split chain.

In v0.2 this is no longer the case.
`returned` and `logjoint` will error, and `predict` will silently give wrong results.
This is the main rationale behind the removal of `split_varnames`.

In return for no longer working on split VarName chains, these functions have been made to run up to 10x faster on unsplit chains.

# 0.1.6

Implemented `InitFromParams(chain::VNChain, i, j)` to allow you to initialise sampling etc. from the `i`-th iteration of the `j`-th chain of a `VNChain`.
Please see [the documentation](https://pysm.dev/FlexiChains.jl/stable/turing) for an example.
`i` and `j` can either be integers, or `At(...)` selectors.

# 0.1.5

Implemented `AbstractMCMC.to_chains` and `AbstractMCMC.from_chains` methods for converting `VNChain` to and from `DynamicPPL.ParamsWithStats`.
Please see the DynamicPPL documentation for more info about this.

# 0.1.4

Added some plotting methods with Makie.jl!
Please see [the docs](https://pysm.dev/FlexiChains.jl/stable/plotting) for more information on what's available and how to use it.

# 0.1.3

Allow passing `layout` and `size` arguments to Plots.jl.

# 0.1.2

Added compatibility with DynamicPPL@0.38 and Turing@0.41.

# 0.1.1

Added extra methods to handle parameters which are `DimArray`-valued: instead of returning a `DimArray` of `DimArrays`, indexing with such a parameter now returns a stacked `DimArray`.

# 0.1.0

FlexiChains now has what I consider to be a reasonably stable core set of functionality, so I'm willing to release 0.1.0.

## Summaries

- There is now [a dedicated page in the documentation for summaries](https://pysm.dev/FlexiChains.jl/stable/summarising).
- `StatsBase.mad`, `Statistics.quantile`, `StatsBase.geomean`, `StatsBase.harmmean`, and `StatsBase.iqr` have been implemented.
- `PosteriorStats.hdi` and `PosteriorStats.eti` have been implemented in an extension.
- The signature of functions passed to `FlexiChains.collapse` has been simplified. It used to be that the signature would differ depending on whether you were collapsing over iterations, chains, or both. Now all the function needs to do is to collapse a vector to a single value (regardless of which dimensions are being collapsed over).

# 0.0.3

## Plotting

(Some) plotting functionality has been added to FlexiChains!

Please see [the plotting docs](https://pysm.dev/FlexiChains.jl/stable/plotting) for information.

## PosteriorDB.jl integration

You can now load a reference posterior from PosteriorDB.jl into a FlexiChain using `FlexiChains.from_posteriordb_ref`.
Please see the package documentation; an example is given there.
The key type of the resulting chain will be `String`, since PosteriorDB stores key names as strings.
(Unfortunately, there is no safe way to automatically convert these to `VarName` types.)

## `subset`

The `FlexiChains.subset()` function has been removed.
Instead of using `subset(chn, keys)` you can now use `chn[keys]`.

`FlexiChains.subset_parameters(chn)` and `FlexiChains.subset_extras(chn)` are still available.

## Equality

Fixed equality comparisons on FlexiChain and FlexiSummary (previously only the data would be compared, not the metadata).
`Base.:(==)` and `Base.isequal` now behave 'as expected'.

A new function `FlexiChains.has_same_data(chn1, chn2; strict)` has been added to compare only the data of two chains.

## Improved dictionary interface

On top of `Base.keys(chn)` and `FlexiChains.parameters(chn)`, the following functions have been added:

- `Base.values(chn; parameters_only)`
- `Base.pairs(chn; parameters_only)`

to extract the matrices, or key-matrix pairs, from a chain. The boolean `parameters_only` can be used to restrict the output to only parameter keys.

## `values_at` and `parameters_at`

These functions have been added to allow you to extract all values, or all parameters, at one or more iterations.
These can be extracted either as `Dict`, `NamedTuple`, or `ComponentArray` (the latter will require you to load ComponentArrays.jl first).

These functions replace what were previously called `get_dict_from_iter` and `get_parameter_from_at_iter`.

## Renaming keys

The `map_keys` and `map_parameters` functions have been introduced to allow you to rename keys in a chain if needed.

## Pointwise log probabilities

The set of DynamicPPL functions `pointwise_logdensities`, `pointwise_loglikelihoods`, and `pointwise_prior_logdensities` have been implemented for FlexiChains.
Note that these methods on FlexiChains return a FlexiChain itself, and you are not allowed to specify the output key type: it is always VarName.

## Other changes

`DynamicPPL.predict` on a FlexiChain now takes the `include_all` keyword argument, which controls whether parameter values are also included in the returned chain.
Please note that the default behaviour is different compared to MCMCChains.jl: FlexiChains by default uses `include_all=true`, whereas MCMCChains.jl uses `include_all=false`.

`vcat` now attempts to very smartly concatenate the iteration indices from two chains.
In any case, it should _always_ be that concatenating two chains will result in the iteration numbers of the second chain being higher than those of the first chain.

Fixed a bug where `hcat` and `vcat` would not preserve the order of keys in the resulting chain.

Fixed a bug where `predict` and `returned` would not work with chains that had already been split up by `VarName`s.

# 0.0.2

There are **many** breaking changes to FlexiChains.jl's interface in this release.
As the version number suggests, this is still a very early release of FlexiChains.jl, and the API is likely to change in future versions.
When the API has somewhat stabilised, the version number will be incremented to 0.1.0.

My current belief is that the core functionality of FlexiChains (base data types, indexing, and summary functions) is largely in place. 
However, I would like to have some real-world battle testing before releasing 0.1.0.

The main changes in 0.0.2 are:

## DimensionalData.jl

Indexing into a FlexiChain now returns `DimensionalData.DimArray` types.

User-facing changes:

 - This is a much richer representation of the data and allows you to index into the resulting matrix with powerful selectors. To make this easier, FlexiChains re-exports all of DimensionalData's selectors.
 - The iteration and chain dimensions are now always explicitly represented, even if there is only one chain. This is probably for the better anyway since it makes the behaviour more consistent.
 - Functions such as `DynamicPPL.returned` now also return a `DimMatrix`.

Indexing into a `FlexiSummary` also returns `DimArray`s, unless all dimensions have been collapsed, in which case it just returns the single value in the array.

## Summaries

Summaries have been completely reworked.

User-facing changes:

- `StatsBase.summarystats` provides a super-quick way to generate summary functions for an entire chain. If the chain type is VarName, this will additionally split VarNames up into their individual scalar-valued components. `summarystats` is re-exported by FlexiChains.
- More high-level functions have been added, namely `ess`, `rhat`, and `mcse` from MCMCDiagnosticTools, as well as `Statistics.quantile`. All of these are re-exported by FlexiChains.
- For low-level, highly customised summary functions, there is now only a single function: `FlexiChains.collapse`. This function also allows you to specify multiple summary functions of your choice.

Furthermore, if you collapse both the iteration and chain dimensions (this is the default when applying summary functions), a nice summary table will be pretty-printed in the REPL.

More internal changes:

There is only one return type, `FlexiSummary`, instead of the three different return types previously.
Indexing behaviour for `FlexiSummary` has been thoroughly designed to be as intuitive, and as similar to `FlexiChain` indexing, as possible.
Please see its docstring, as well as the built documentation, for more information.

## Indexing

In light of the DimensionalData.jl integration, as well as the new `FlexiSummary` format, indexing into chains and summaries has also been completely overhauled.
In particular, indexing can now be done with keyword arguments corresponding to the dimension names.
Furthermore, it is possible to provide a vector of keys to select multiple parameters at once (this will returns a new `FlexiChain` or `FlexiSummary` rather than the `DimArray` itself).

Please see the documentation for more information: there is one whole page dedicated to the indexing behaviour of FlexiChains.jl.

## Sizes as type parameters

The sizes of the chain and iteration dimensions are no longer type parameters of `FlexiChain`.
Instead of constructing a chain with `FlexiChain{TKey,NIter,NChains}(data)` you should now pass these as positional arguments, i.e., `FlexiChain{TKey}(NIter, NChains, data)`.
The same runtime checks are still performed.
This prevents overspecialisation of methods and leads to improved performance.

`FlexiChains.SizedMatrix` has been removed.
All underlying data is stored as raw `Array`s (2D for `FlexiChain`, 3D for `FlexiSummary`).

## Other things

The log-joint probability when sampling with Turing.jl is now stored under the key `Extra(:logjoint)` rather than `Extra(:lp)`.
This is simply to be more explicit about its meaning.

The order of keys in a `FlexiChain` is now guaranteed (and is preserved by all operations on chains).
If you want to construct a chain with a specific order of keys, you should ensure that the input data (either dict-of-arrays or array-of-dicts) can be iterated on to yield the keys in the desired order.
This is most easily done by using `OrderedCollections.OrderedDict`.
(Conversely, if the order does not matter, you can use any other `AbstractDict`.)
To reorder keys, you can index into the chain with a vector of keys in the desired order.

A `split_varnames` function has been added to split VarNames in a chain into their individual scalar components.

Small precompile workloads have been added to improve the time-to-first-chain and summary for typical Turing workflows.

Various fixes have been applied to the behaviour of `hcat`, `vcat`, and `merge`.
In particular `merge` now takes all metadata from the second argument (which mimics the behaviour of `merge` on base Julia types).

# 0.0.1

This is the initial release of FlexiChains.jl.

FlexiChains is a new package for working with Markov chains, with a particular emphasis on supporting features of Turing.jl.
As its name suggests, it is designed to be more flexible than the existing MCMCChains.jl library.
This means that, for example, vector-valued parameters are stored 'as is' without being broken up into individual indices.

This not only makes it much less clunky to work with large arrays; it also leads to performance gains (sometimes), improved compatibility with DynamicPPL.jl, and a more accurate representation of the parameters you have sampled.

Do consult [the documentation](http://pysm.dev/FlexiChains.jl/) for more information, and please feel free to get in touch with issues or suggestions!
