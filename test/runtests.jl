using Test: @testset

@testset verbose = true "FlexiChains.jl" begin
    include("Aqua.jl")
    include("chain.jl")
    include("summaries.jl")
    include("diagnostics.jl")
    include("interface.jl")
    include("varname.jl")
    include("flatten.jl")
    include("ext/advancedhmc.jl")
    include("ext/mcmcchains.jl")
    include("ext/turing.jl")
    include("serialise.jl")
    include("stancsv.jl")
    include("ext/posteriordb.jl")
    include("ext/posteriorstats.jl")
    include("ext/dimdist.jl")
end
