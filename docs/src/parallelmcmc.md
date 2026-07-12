# ParallelMCMC.jl

[Documentation for ParallelMCMC.jl](https://ryguy.io/ParallelMCMC.jl/stable/)

ParallelMCMC.jl provides an implementation of the DEER algorithm for MCMC sampling that is parallelised along the sequence length itself.
You can either define a log-density function yourself, or use a Turing model.
The default output for ParallelMCMC.jl is a FlexiChain!
