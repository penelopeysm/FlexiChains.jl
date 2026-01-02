module AquaTests

using Aqua: Aqua
using FlexiChains: FlexiChains

@info "Testing Aqua.jl"
Aqua.test_all(FlexiChains)

end
