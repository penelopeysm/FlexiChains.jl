d = fill(Dict(Parameter(:x) => rand(), Extra("y") => rand()), 200, 3)
chns = FlexiChain{Symbol}(200, 3, d)

reftest("two traceplots") do
    fig = traceplot(chns, ["A", "B"])
    return fig
end

reftest("two trankplots") do
    fig = trankplot(chns, ["A", "B"])
    return fig
end

reftest("two densities") do
    fig = density(chns, ["A", "B"])
    return fig
end

reftest("two hists") do
    fig = hist(chns, ["A", "B"])
    return fig
end

reftest("legend position right") do
    fig = hist(chns, ["A", "B"], legend_position = :right, colormap = :viridis)
    return fig
end

reftest("ridgeline") do
    fig = ridgeline(chns, ["A", "B"])
    return fig
end

reftest("forestplot median") do
    fig = forestplot(chns, [:A, :B, :C, :D])
    return fig
end

reftest("two autocorplots") do
    fig = autocorplot(chns, ["A", "B"])
    return fig
end

reftest("autocorplots lags") do
    fig = autocorplot(chns; lags = 0:5:100)
    return fig
end

reftest("two meanplots") do
    fig = meanplot(chns, ["A", "B"])
    return fig
end

reftest("violin") do
    fig = violin(chns, orientation = :horizontal)
    return fig
end

reftest("violin link x") do
    chns = testchains()
    fig = violin(chns, link_x = true, orientation = :horizontal)
    return fig
end

reftest("violin vertical") do
    chns = testchains()
    fig = violin(chns)
    return fig
end

reftest("plot vanilla") do
    chns = testchains(continuous_samples(p = 2))
    fig = plot(chns)
    return fig
end

reftest("plot custom colors") do
    chns = testchains(continuous_samples(p = 2))
    fig = plot(chns; color = first(Makie.to_colormap(:tab20), 10))
    return fig
end

reftest("plot two banks") do
    chns = testchains(continuous_samples(p = 2, c = 6))
    fig = plot(chns)
    return fig
end

reftest("plot many chains") do
    chns = testchains(continuous_samples(p = 2, c = 8))
    fig = plot(chns)
    return fig
end

reftest("plot mixed densities") do
    a = Real[discrete_samples() continuous_samples(p = 1)]
    chns = testchains(a)
    fig = plot(chns)
    return fig
end

reftest("plot custom funs") do
    chns = testchains(continuous_samples(p = 2, c = 6))
    fig = plot(chns, trankplot!, chainshist!, meanplot!)
    return fig
end

reftest("plot custom funs and colors") do
    chns = testchains(continuous_samples(p = 2, c = 6))
    color = first(Makie.to_colormap(:tab20), 10)
    funs = [trankplot!, chainshist!, meanplot!]
    fig = plot(chns, funs...; color)
    return fig
end
