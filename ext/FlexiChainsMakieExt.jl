module FlexiChainsMakieExt

using FlexiChains: FlexiChains as FC
using Makie: Makie, Plot

# Only one parameter for now!
function FC.mtraceplot(
    chn::FC.FlexiChain, param_or_params=FC.Parameter.(FC.parameters(chn)); kwargs...
)
    kwdict = Dict{Symbol,Any}(kwargs)
    return Makie._create_plot(
        FC.mtraceplot, kwdict, FC.PlotUtils.FlexiChainTrace(chn, param_or_params)
    )
end

function Makie.plot!(plot::Plot{FC.mtraceplot})
    @show plot
    chn, param = plot.args
    # only one param for now... we'll figure the rest out later
    keys_to_plot = FC.PlotUtils.get_keys_to_plot(chn, param)
    k = only(keys_to_plot)
    x = collect(FC.iter_indices(chn))
    y = FC._get_raw_data(chn, k)
    FC.PlotUtils.check_eltype_is_real(y)
    return Makie.convert_arguments(T, x, y)
end

# function Makie.convert_arguments(::Type{<:AbstractPlot}, t::FC.PlotUtils.FlexiChainTrace)
#     x = FC.iter_indices(chn)
#     y = FC._get_raw_data(chn, param)
#     FC.PlotUtils.check_eltype_is_real(y)
#     return x, y
# end

end # module
