# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Julia tooling

All Julia code must be run via the Julia MCP tool (`mcp__julia__julia_eval`). Only run small code snippets (not full test suites or formatters — the user handles those).

Code style follows Blue style (`.JuliaFormatter.toml`).

## Architecture

`FlexiChains` is a Julia package providing a flexible MCMC chain type (`FlexiChain{TKey}`) that stores samples keyed by arbitrary types rather than `Symbol`s. The primary use case is Turing.jl, where `VNChain = FlexiChain{VarName}` is the chain type.

### Core data model

The central type is `FlexiChain{TKey}` (`src/chain.jl`). Internally it is an `OrderedDict{ParameterOrExtra{<:TKey}, Matrix}` — each key maps to a `(niters, nchains)` matrix of sampled values. Values can be of any type (integers, vectors, strings, etc.), unlike MCMCChains which casts everything to `Float64`.

Keys are one of two wrapper types:
- `Parameter{T}(name::T)` — a model parameter
- `Extra(name)` — non-parameter data (log-probabilities, return values, etc.)

Indexing returns `DimensionalData.DimMatrix` with named `(:iter, :chain)` dimensions.

### File layout

- `src/chain.jl` — `FlexiChain`, `Parameter`, `Extra`, `FlexiChainMetadata` types and constructors
- `src/getindex.jl` — `getindex` overloads for chains and summaries
- `src/varname.jl` — `VarName`-specific indexing logic (optic-based traversal to handle e.g. `x[1]` when the chain stores `x`)
- `src/summary.jl` — `FlexiSummary` type and summary statistics
- `src/interface/` — `cat`, `show`, `size`, `equal`, `mergesubset`, `decomp` implementations
- `src/FlexiChains.jl` — module entry point; defines `bundle_samples` (the AbstractMCMC hook that creates a `VNChain` from sampler output) and `to_varname_dict` (the extension point for custom samplers)

### Extensions (`ext/`)

All Turing/DynamicPPL functionality lives in extensions, not the core package:

- **`FlexiChainsDynamicPPLExt`** — the main Turing integration. Implements `reevaluate`, `predict`, `returned`, `pointwise_logdensities/loglikelihoods/prior_logdensities`, `InitFromFlexiChain` (init strategy that reads values from the chain), `to_varname_dict` for `ParamsWithStats`, and `to_samples`/`from_samples`.
- **`FlexiChainsTuringExt`** — precompilation workload for Turing.
- **`FlexiChainsMCMCChainsExt`** — conversion to/from `MCMCChains.Chains`.
- **`FlexiChainsMakieExt`** — Makie plotting recipes.
- **`FlexiChainsRecipesBaseExt`** — Plots.jl recipes.
- **`FlexiChainsComponentArraysExt`** — `ComponentArray` support.
- **`FlexiChainsPosteriorDBExt`** — PosteriorDB integration.

### VarName indexing

`src/varname.jl` implements optic-based resolution: when you index by `@varname(x[1])` but the chain stores `@varname(x)` (a vector-valued parameter), the code walks up the optic chain (`oinit`/`olast` from AbstractPPL) to find the stored parent and applies the remaining optic to reconstruct the element.

### `reevaluate` and `InitFromFlexiChain`

`reevaluate` (in `FlexiChainsDynamicPPLExt`) re-runs the model at each stored sample to compute derived quantities (log probs, predictions, return values). It uses `InitFromFlexiChain` — a `DynamicPPL.AbstractInitStrategy` that reads variable values from the chain. The lookup is three-step: exact key match → reconstruct from `parameters_at` via `VarNamedTuple` → fallback strategy.

### Special keys

Three `Extra` keys with fixed meanings are defined in `src/FlexiChains.jl`:
- `Extra(:logjoint)` → `_LOGJOINT_KEY`
- `Extra(:logprior)` → `_LOGPRIOR_KEY`
- `Extra(:loglikelihood)` → `_LOGLIKELIHOOD_KEY`
