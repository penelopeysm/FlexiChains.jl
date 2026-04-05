"""
    to_vnt_and_stats(transition)::Tuple{VarNamedTuple,NamedTuple}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler into a
`VarNamedTuple` mapping parameter names to their values, plus a `NamedTuple` of any
additional statistics.

The `VarNamedTuple` will be converted into `Parameter` keys, and the `NamedTuple` into
`Extra` keys.

If you are writing a custom AbstractMCMC sampler and want to allow users to collect the
samples as a `FlexiChain{VarName}`, i.e., 

    sample(...; chain_type=FlexiChain{VarName})

then you should ensure that your method of `AbstractMCMC.step` returns a transition that can
be passed to this method. (The other return value, the state, is not relevant.)

Note that this method is already implemented for `DynamicPPL.VarNamedTuple` (in which case
the stats are empty) as well as `DynamicPPL.ParamsWithStats`. Thus the easiest solution is
to just return one of those types.
"""
function to_vnt_and_stats end
# Note that `to_vnt_and_stats` has to be overloaded in DynamicPPLExt, not here.
@public to_vnt_and_stats

"""
    to_nt_and_stats(transition)::Tuple{NamedTuple,NamedTuple}

Convert the _first output_ (i.e. the 'transition') of an AbstractMCMC sampler into a
`NamedTuple` mapping parameter names to their values, plus a `NamedTuple` of any additional
statistics.

The first `NamedTuple` will be converted into `Parameter` keys, and the second `NamedTuple`
into `Extra` keys.

If you are writing a custom AbstractMCMC sampler and want to allow users to collect the
samples as a `FlexiChain{Symbol}`, i.e., 

    sample(...; chain_type=FlexiChain{Symbol})

then you should ensure that your method of `AbstractMCMC.step` returns a transition that can
be passed to this method. (The other return value, the state, is not relevant.)
"""
function to_nt_and_stats end
@public to_nt_and_stats
to_nt_and_stats(nt::NamedTuple) = (nt, (;))
