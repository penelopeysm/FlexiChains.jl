# Custom AbstractMCMC samplers

If you have written a sampler that conforms to the AbstractMCMC interface, then you can get 'free' support for bundling into a `FlexiChain{VarName}` and a `FlexiChain{Symbol}` respectively by overloading these functions:

```@docs
FlexiChains.to_vnt_and_stats
FlexiChains.to_nt_and_stats
```

As a concrete example, let's use the following setup:

```@example sampler
using FlexiChains: FlexiChains, FlexiChain
using AbstractMCMC

struct M <: AbstractMCMC.AbstractModel end
struct S <: AbstractMCMC.AbstractSampler end
struct T end
function AbstractMCMC.step(rng, ::M, ::S, state=nothing; kwargs...)
    T(), nothing
end
```

Here `T` represents what AbstractMCMC calls a 'transition': it is the first return value of `AbstractMCMC.step`.
Of course, in practice, your transition will carry more information than this.

Now suppose you want to sample with this and obtain a `FlexiChain{Symbol}`.
As the docstrings above allude to, you will want to overload `to_nt_and_stats`:

```@example sampler
FlexiChains.to_nt_and_stats(::T) = ((; hello=1.0), (; world=2.0))
```

Then you can do

```@example sampler
sample(M(), S(), 10; chain_type=FlexiChain{Symbol})
```

Likewise for `VarNamedTuple` (although in this case, you should think carefully about whether you *really* need `VarNamedTuple`: if your sampler transition does not carry enough information to justify the richer data type, then it would probably be more meaningful to stick to `NamedTuple` and `FlexiChain{Symbol}`).

```@example sampler
using DynamicPPL: VarNamedTuple, VarName
FlexiChains.to_vnt_and_stats(::T) = (VarNamedTuple(hello=1.0), (; world=2.0))
sample(M(), S(), 10; chain_type=FlexiChain{VarName})
```
