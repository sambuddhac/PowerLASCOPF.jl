using Test

include("test/test_hello_world.jl")
include("test/test_components.jl")
include("test/test_solvers.jl")
include("test/test_io.jl")

@testset "All Tests" begin
    include("test/test_hello_world.jl")
    include("test/test_components.jl")
    include("test/test_solvers.jl")
    include("test/test_io.jl")
end