using Test: @testset

@testset verbose = true "FlexiChains.jl" begin
    include("chain.jl")
    include("summaries.jl")
    include("interface.jl")
    include("ext/turing.jl")
    include("ext/posteriordb.jl")
    include("ext/dimdist.jl")
    include("ext/makie/makie.jl")
end
