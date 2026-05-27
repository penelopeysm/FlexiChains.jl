# Deprecated versions of plotting functions. These are in the top-level namespace but we
# eventually want to remove them in favour of the versions in the `Plots` and `Makie`
# submodules.

# Plots.jl
@public traceplot, traceplot!
@public mixeddensity, mixeddensity!
@public meanplot, meanplot!
@public rankplot, rankplot!
@public autocorplot, autocorplot!

Base.@deprecate traceplot FlexiChains.Plots.traceplot false
Base.@deprecate traceplot! FlexiChains.Plots.traceplot! false
Base.@deprecate mixeddensity FlexiChains.Plots.mixeddensity false
Base.@deprecate mixeddensity! FlexiChains.Plots.mixeddensity! false
Base.@deprecate meanplot FlexiChains.Plots.meanplot false
Base.@deprecate meanplot! FlexiChains.Plots.meanplot! false
Base.@deprecate rankplot FlexiChains.Plots.rankplot false
Base.@deprecate rankplot! FlexiChains.Plots.rankplot! false
Base.@deprecate autocorplot FlexiChains.Plots.autocorplot false
Base.@deprecate autocorplot! FlexiChains.Plots.autocorplot! false

# Makie.jl
@public mtraceplot, mtraceplot!
@public mmixeddensity, mmixeddensity!
@public mrankplot, mrankplot!
@public mmeanplot, mmeanplot!
@public mautocorplot, mautocorplot!

Base.@deprecate mtraceplot FlexiChains.Makie.traceplot false
Base.@deprecate mtraceplot! FlexiChains.Makie.traceplot! false
Base.@deprecate mmixeddensity FlexiChains.Makie.mixeddensity false
Base.@deprecate mmixeddensity! FlexiChains.Makie.mixeddensity! false
Base.@deprecate mrankplot FlexiChains.Makie.rankplot false
Base.@deprecate mrankplot! FlexiChains.Makie.rankplot! false
Base.@deprecate mmeanplot FlexiChains.Makie.meanplot false
Base.@deprecate mmeanplot! FlexiChains.Makie.meanplot! false
Base.@deprecate mautocorplot FlexiChains.Makie.autocorplot false
Base.@deprecate mautocorplot! FlexiChains.Makie.autocorplot! false
