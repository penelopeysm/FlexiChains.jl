# ArviZ.jl

[Documentation for ArviZ.jl](https://julia.arviz.org/ArviZ/stable/)

FlexiChains contains an extension that allows you to convert a `FlexiChain` into an `InferenceObjects.InferenceData` (InferenceObjects.jl is one of the sublibraries of ArviZ.jl, and is re-exported by ArviZ).

```@docs
InferenceObjects.convert_to_inference_data
```

For example:

```@example arviz
using InferenceObjects, FlexiChains, DynamicPPL, Distributions

@model function f(y)
    x ~ Normal()
    y ~ Normal(x)
end
model = f(1.0)

chn = FlexiChains._make_prior_chain(model, 100, 2)
idata = InferenceObjects.convert_to_inference_data(chn)
```

You can combine multiple `InferenceData` objects with `merge`:

```@example arviz
llike_chn = DynamicPPL.pointwise_loglikelihoods(model, chn)
idata2 = InferenceObjects.convert_to_inference_data(llike_chn; group=:log_likelihood)
idata_merged = merge(idata, idata2)
```

From here you can use the full functionality of ArviZ.jl, which includes various plotting and analysis tools: please see [the ArviZ.jl documentation](https://julia.arviz.org/ArviZ/stable/) for more info.
