# [Stan](@id integrations-stan)

FlexiChains has a function to read in chains stored in Stan CSV format:

```@docs
FlexiChains.from_stan_csv
```

This of course assumes that you already have the CSV files on disk somewhere, e.g. if you have run Stan externally.

If you are using [StanSample.jl](https://github.com/StanJulia/StanSample.jl) you can also read data directly from a `SampleModel` once you have sampled with it.

!!! note

    This code block is not run, as running it would necessitate setting up CmdStan on GitHub runners.

```julia
using StanSample, FlexiChains

sm = SampleModel(args...)
# Note: this mutates `sm` -- StanSample has a rather unconventional interface
stan_sample(sm; data)

# The key type has to be `Symbol`.
chn = FlexiChain{Symbol}(sm)
```

If you are using [BridgeStan.jl](https://roualdes.us/bridgestan/latest/languages/julia.html) and/or [StanLogDensityProblems.jl](https://sethaxen.github.io/StanLogDensityProblems.jl/stable/) plus a native Julia sampler, you should check whether there is an integration for the sampler in question.
For example if you use AdvancedHMC.jl then you can pass the `chain_type=FlexiChain{Symbol}` keyword argument (see [above](@ref integrations-advancedhmc)).

(If the sampler in question does *not* have an integration with FlexiChains, please feel free to open an issue!)
