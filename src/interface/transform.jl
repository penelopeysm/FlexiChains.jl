export transform_values

"""
    FlexiChains.transform_values(chn::FlexiChain{T}, args...)

Perform one or more transformations on the values inside a `FlexiChain`.

`args` can be one or more of the following:

- `key => f => new_key`

  Applies `f` to each draw of `key` and stores the result in `new_key`.

- `key => f`

  Shorthand for `{key} => f => {key}`, i.e., applies `f` to each draw of `key` and stores
  the result back in `key`.

- `[key1, key2, ..., keyN] => f => new_key`

  Calculates `f(key1, key2, ..., keyN)` for each draw and stores the result in
  `new_key`. Note that the LHS **must** be an `AbstractVector`; other iterables like Tuples
  are not accepted.

`key` accepts any value that can be used to index into a `FlexiChain`, including `Symbol`s
when unambiguous. However, `new_key` is more restricted: it **must** be either
`FlexiChains.Extra`, `FlexiChains.Parameter{<:T}`, or just a `T` (in which case it is
assumed to be a parameter).
"""
function transform_values(chn::FlexiChain{T}, args...) where {T}
    isempty(args) && return chn
    # No need deepcopy as we aren't mutating the matrices themselves, only the outermost
    # OrderedDict.
    data = copy(chn._data)

    for arg in args
        ks, f, new_k = if arg isa Pair{<:Any,<:Pair}
            # key(s) => f => new_key
            ks, (f, new_k) = arg.first, arg.second
            if !(ks isa AbstractVector)
                ks = [ks]
            end
            new_k = if new_k isa ParameterOrExtra{<:T}
                new_k
            elseif new_k isa T
                Parameter(new_k)
            else
                throw(
                    ArgumentError(
                        "transform_values: invalid output key type $(typeof(new_k))",
                    ),
                )
            end
            ks, f, new_k
        elseif arg isa Pair
            # key => f
            ks, f = arg.first, arg.second
            if !(ks isa AbstractVector)
                ks = [ks]
            else
                throw(
                    ArgumentError(
                        "transform_values: LHS must be a single key when no output key is provided",
                    ),
                )
            end
            # We can't just wrap keys[1] because it might be a Symbol which is unambiguous;
            # instead we have to tap into the getindex machinery to figure out what the
            # actual key is.
            new_k = _resolve_getindex_key(T, keys(chn), only(ks))
            ks, f, new_k
        else
            throw(ArgumentError("transform_values: invalid argument type $(typeof(arg))"))
        end
        # Map `f` over each draw
        new_data = map(f, (chn[k] for k in ks)...)
        data[new_k] = new_data
    end
    return _replace_data(chn, T, data)
end
