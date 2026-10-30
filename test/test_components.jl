using Test
using PowerLASCOPF

@testset "Component Tests" begin
    @testset "Multiple load demand updates" begin
        node = Node(PowerLASCOPF.PSY.ACBus(nothing), 1, 1)
        first_load = Load(1, 10.0)
        second_load = Load(2, 20.0)
        attach_profile!(first_load, [10.0, 15.0])
        attach_profile!(second_load, [20.0, 25.0])
        connect_to_node!(first_load, node)
        connect_to_node!(second_load, node)

        @test get_load_val(node) == 30.0
        set_interval!(first_load, 2)
        @test get_load_val(node) == 35.0
        set_interval!(second_load, 2)
        @test get_load_val(node) == 40.0
    end

    @testset "Empty profile restores nominal demand" begin
        node = Node(PowerLASCOPF.PSY.ACBus(nothing), 1, 1)
        load = Load(1, 10.0)
        attach_profile!(load, [5.0, 8.0])
        connect_to_node!(load, node)

        set_interval!(load, 2)
        attach_profile!(load, Float64[])

        @test load.Pl == 10.0
        @test load.interval == 0
        @test get_load_val(node) == 10.0
    end
end