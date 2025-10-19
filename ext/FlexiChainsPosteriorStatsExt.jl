module FlexiChainsPosteriorStatsExt

using PosteriorStats
using FlexiChains: FlexiChains

"""
$(FlexiChains._stat_docstring("PosteriorStats.hdi", "highest density interval"))
"""
FlexiChains.@_forward_stat PosteriorStats.hdi

"""
$(FlexiChains._stat_docstring("PosteriorStats.eti", "equal-tailed interval"))
"""
FlexiChains.@_forward_stat PosteriorStats.eti

end # module
