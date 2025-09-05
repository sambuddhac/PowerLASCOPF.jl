using Test

@testset "Hello World Tests" begin
    @test "Hello World should return 'Hello, World!'" begin
        result = "Hello, World!"
        @test result == "Hello, World!"
    end
end