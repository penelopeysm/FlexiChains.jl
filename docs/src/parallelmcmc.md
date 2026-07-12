# [ParallelMCMC.jl](@id integrations-parallelmcmc)

[Documentation for ParallelMCMC.jl ↗](https://ryguy.io/ParallelMCMC.jl/stable/)

ParallelMCMC.jl provides an implementation of the DEER algorithm, which performs MCMC sampling that is parallelised along the sequence length itself.
You can either define a log-density function yourself, or use a Turing model.

The default chain type output for ParallelMCMC is a FlexiChain!
Please see the ParallelMCMC docs for more information.
