# DimensionalDistributions.jl

[Documentation for DimensionalDistributions.jl ↗](https://github.com/sethaxen/DimensionalDistributions.jl)

!!! note

    DimensionalDistributions.jl is not yet registered in the Julia package registry; at present you will need to install it from GitHub using `]add https://github.com/sethaxen/DimensionalDistributions.jl`.

DimensionalDistributions.jl provides a `withdims` wrapper which lets you create a distribution that returns `DimVector`s:

```julia
using Turing # reexports MvNormal and I
using DimensionalData: Dim
using DimensionalDistributions

school_dim = Dim{:school}([:a, :b, :c])
dim_mvnormal = withdims(MvNormal(zeros(3), I), school_dim)
rand(dim_mvnormal)
```

If you use this in a Turing model, then this information will be carried through all the way to FlexiChains, and indexing into this parameter will let you get a `DimArray` of `DimVector`s.
This leads to a particularly elegant outcome when accessing this parameter with the `stack=true` keyword argument: FlexiChains will return a 3-dimensional `DimArray` with full dimensional information retained.

```julia
using FlexiChains
@model f() = x ~ dim_mvnormal
chn2 = sample(f(), MH(), MCMCThreads(), 5, 2; chain_type=VNChain, progress=false)
chn2[@varname(x), stack=true]
```

!!! note "Default behaviour"

    For `DimArray`-valued parameters, the `stack=true` keyword argument is not necessary in the current version of FlexiChains as stacking happens by default.
    However in a future version this will be changed such that the default behaviour even for `DimArray`s is to not stack.
    Thus it is recommended that you explicitly specify `stack=true` if you want this behaviour.

Sub-VarName indexing also works.

```julia
chn2[@varname(x[1])]
```

In principle, you should be able to even use DimensionalData selectors in the VarName, e.g. `chn2[@varname(x[At(:b)])]`; however, support for this is slightly flaky due to incomplete implementations of `Base.checkbounds` for DimensionalData (which is not something that FlexiChains can control).
If you try this and find that something doesn't work, please do feel free to open an issue and we can help to upstream it.
