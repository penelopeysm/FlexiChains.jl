module FlexiChainsMonteCarloMeasurementsExt

import FlexiChains as FC
import OrderedCollections: OrderedDict
import MonteCarloMeasurements as MCM

"""
    MonteCarloMeasurements.Particles(
        chain::FC.FlexiChain{Tparam},
        ::Type{Tout}=OrderedDict,
    ) where {Tparam,Tout}

Convert a chain into an `OrderedDict`, mapping parameters in the chain (of type `Tparam`) to
`MonteCarloMeasurements.Particles` or collections thereof.

`Extra`s in the chain will be dropped.

Scalar-valued parameters will become single `Particles`; array-valued parameters will become
arrays of `Particles` (as long as all the arrays have the same size).

Note that if parameters have different sizes or types in different samples, this will
conservatively throw an error. Suggestions for improvements are very welcome!

`Tout` can also be:

- `Dict`, in which case the output will be `Dict` rather than `OrderedDict`;
- `NamedTuple`. Note that this conversion can be lossy if `Tparam` is a richer type than
Symbol.
"""
function MCM.Particles(
    chain::FC.FlexiChain{Tparam},
    ::Type{Tout}=OrderedDict,
) where {Tparam,Tout}
    output = if Tout == OrderedDict || Tout == NamedTuple
        OrderedDict{Tparam,Any}()
        # We'll perform the NamedTuple conversion at the end
    elseif Tout == Dict
        Dict{Tparam,Any}()
    end

    for param in FC.parameters(chain)
        # use `_get_raw_data` to avoid unnecessary wrapping in DimArray
        val_matrix = FC._get_raw_data(chain, FC.Parameter(param))
        output[param] = _to_particles(vec(val_matrix), param)
    end

    return if Tout == NamedTuple
        NamedTuple(Symbol(k) => v for (k, v) in output)
    else
        output
    end
end

_to_particles(values::AbstractVector{<:Number}, _) = MCM.Particles(values)

function _to_particles(values::AbstractVector{<:AbstractArray}, param)
    sz = size(first(values))
    if !all(x -> size(x) == sz, values)
        throw(
            DimensionMismatch(
                "cannot convert parameter $param to `MonteCarloMeasurements.Particles` because the arrays have different sizes. Please open an issue if you think this should be supported!",
            ),
        )
    end
    # Let's say each element has size `(d1, d2, ..., dn)`, and also define `S =
    # niters * nchains`. Then `stack(vec(x))` has size `(d1, d2, ..., dn, S)`.
    # However, the `Particles` constructor expects the first dimension to be the one
    # containing the samples, so we need to call `permutedims`.
    stacked = stack(values)
    N = ndims(stacked)
    permuted = permutedims(stacked, (N, 1:(N-1)...))
    return MCM.Particles(permuted)
end

function _to_particles(values::AbstractVector{<:NamedTuple}, param)
    ks = keys(first(values))
    return NamedTuple(k => _to_particles([v[k] for v in values], param) for k in ks)
end

function _to_particles(values::AbstractVector, param)
    et = eltype(values)
    throw(
        ArgumentError(
            "cannot convert parameter $(param) to `MonteCarloMeasurements.Particles` because the values have type $(et) and are not scalars or arrays/NamedTuples thereof. Please feel free to open an issue if you think this should be supported!",
        ),
    )
end

end # module
