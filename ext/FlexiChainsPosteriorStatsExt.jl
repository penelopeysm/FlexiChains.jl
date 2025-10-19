module FlexiChainsPosteriorStatsExt

using PosteriorStats
using FlexiChains: FlexiChains

"""
$(FlexiChains._stat_docstring("PosteriorStats.hdi", "highest density interval"))

Please see the docstring of [`PosteriorStats.hdi`](@extref) for details of keyword arguments.
"""
FlexiChains.@_forward_stat PosteriorStats.hdi

"""
$(FlexiChains._stat_docstring("PosteriorStats.eti", "equal-tailed interval"))

Please see the docstring of [`PosteriorStats.eti`](@extref) for details of keyword arguments.
"""
FlexiChains.@_forward_stat PosteriorStats.eti

end # module
