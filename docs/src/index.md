# Overview

FlexiChains.jl provides an information-rich data structure for Markov chains.

FlexiChains.jl is designed to be completely general, in that you can store any kind of data in a `FlexiChain`.
However, its intended primary use is as a drop-in (but better) replacement for MCMCChains.jl in the Turing.jl ecosystem.
Thus, there is some extra functionality available for chains that contain `AbstractPPL.VarName` parameters.
