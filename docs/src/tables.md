# [Tables.jl](@id integrations-tables)

[Documentation for Tables.jl](https://tables.juliadata.org/stable/)

FlexiChains implements a Tables.jl interface which allows you to easily convert a `FlexiChain` or `FlexiSummary` into any type that consumes tabular data, e.g., a `DataFrame`.

In fact, FlexiChains implements *two* different Tables.jl interfaces for chains: one for wide data and one for long data.

This is best demonstrated with an example.
First let's sample a chain as usual:

```@example tables
using FlexiChains, Turing, DataFrames

@model function f()
    x ~ Normal(10.0)
    y ~ Bernoulli()
    z ~ MvNormal(zeros(2), I)
end

chn = sample(f(), MH(), MCMCThreads(), 4, 2; chain_type=VNChain, progress=false)
```

Now we can convert this into a `DataFrame` in wide format (this is also the default for unwrapped `FlexiChain`s, so you technically don't have to wrap `chn` in `Wide` if you don't want to):

```@example tables
DataFrame(Wide(chn))
```

or long format (although notice that this will promote `y` to `Float64`):

```@example tables
DataFrame(Long(chn))
```

Both the [`Wide`](@ref) and [`Long`](@ref) wrapper structs accept keyword arguments which determine whether array-valued parameters (like `z`) are split up, and whether or not to include the `Extra` keys in the chain as well, like Turing log-probabilities.

```@docs
Wide
Long
```

For `FlexiSummary`, the long format is not (yet?) supported: only the wide format is implemented.
In contrast to `Wide(::FlexiChain)`, where each _parameter_ is given a different column, the wide format for `FlexiSummary` splits each _statistic_ into a separate column.

```@example tables
fs = summarystats(chn)
DataFrame(Wide(fs))
```

Like for `FlexiChain`, the `Wide` wrapper is the default Tables.jl implementation for `FlexiSummary`, so you can also just do `DataFrame(fs)`.

`Wide(::FlexiSummary)` takes the same keyword arguments as `Wide(::FlexiChain)`.

!!! note "Splitting VarNames"

    Please note that the act of summarising will typically already cause array-valued variables to be split up.
    If this has already been done, then using `Wide(...; split_varnames=false)` cannot reverse this!

    ```@example tables
    w = Wide(mean(chn), split_varnames=false)
    DataFrame(w)
    ```

    Notice how `z[1]` and `z[2]` are already split up despite the `split_varnames=false` argument.
    If you want to prevent this, you need to specify `split_varnames=false` at the summary step as well:

    ```@example tables
    w = Wide(mean(chn; split_varnames=false), split_varnames=false)
    DataFrame(w)
    ```
