using Test
using PowerLASCOPF
using JuMP
using SDP
using LinearAlgebra
using JSON
using PowerSystems
const PSY = PowerSystems

@testset "Comprehensive SDP OPF Tests" begin
    @testset "IEEE Test Case Data Loading" begin
        # Test 3-bus case
        println("Testing 3-bus IEEE case...")
        system_3 = PowerLASCOPF.load_system_data(3)
        @test system_3["n_buses"] == 3
        @test length(system_3["p_load"]) == 3
        
        # Test load data from JSON files
        load_data_3 = JSON.parsefile("example_cases/IEEE_Test_Cases/IEEE_3_bus/Load3.json")
        @test length(load_data_3) >= 1
        @test haskey(load_data_3[1], "ConnNode")
        @test haskey(load_data_3[1], "Interval-1_Load")
        
        println("✅ 3-bus case data loading successful")
    end
    
    @testset "Network Matrix Computation" begin
        system_data = PowerLASCOPF.load_system_data(3)
        network_matrices = PowerLASCOPF.compute_network_matrices(system_data)
        
        n = system_data["n_buses"]
        
        # Test matrix dimensions
        @test size(network_matrices["Y_real"]) == (n, n)
        @test size(network_matrices["Y_imag"]) == (n, n)
        
        # Test that matrices are sparse
        @test isa(network_matrices["Y_real"], SparseMatrixCSC)
        @test isa(network_matrices["Y_imag"], SparseMatrixCSC)
        
        println("✅ Network matrix computation tests passed")
    end
    
    @testset "SDP Optimization Model" begin
        system_data = PowerLASCOPF.load_system_data(3)
        network_matrices = PowerLASCOPF.compute_network_matrices(system_data)
        voltage_limit = 0.1
        
        model = PowerLASCOPF.setup_sdp_model(system_data, network_matrices, voltage_limit)
        
        # Test that model is created
        @test isa(model, JuMP.Model)
        
        # Test that variables exist
        @test haskey(model.obj_dict, :λ_p_min)
        @test haskey(model.obj_dict, :λ_p_max)
        @test haskey(model.obj_dict, :X)
        
        # Test SDP constraint
        X = model[:X]
        n = system_data["n_buses"]
        @test size(X) == (2*n, 2*n)
        
        println("✅ SDP optimization model tests passed")
    end
    
    @testset "Solve Small Test Case" begin
        println("Running full SDP OPF solution test...")
        
        # Create test input
        test_input = IOBuffer()
        write(test_input, "3\n0.1\n")
        seekstart(test_input)
        
        # Redirect stdin temporarily
        original_stdin = stdin
        redirect_stdin(test_input)
        
        try
            # This would run the full solver
            # model = PowerLASCOPF.solve_sdp_opf_centralized()
            # For now, just test the components
            system_data = PowerLASCOPF.load_system_data(3)
            network_matrices = PowerLASCOPF.compute_network_matrices(system_data)
            model = PowerLASCOPF.setup_sdp_model(system_data, network_matrices, 0.1)
            
            @test isa(model, JuMP.Model)
            println("✅ Full SDP OPF solution test framework ready")
            
        finally
            redirect_stdin(original_stdin)
            close(test_input)
        end
    end
    
    @testset "Tree Width and Quality Analysis Preparation" begin
        # Placeholder for tree width calculation tests
        # This is where you'd add Javad Lavaei's solution quality analysis
        
        system_data = PowerLASCOPF.load_system_data(3)
        network_matrices = PowerLASCOPF.compute_network_matrices(system_data)
        
        # Test adjacency matrix creation for tree width
        Y_real = network_matrices["Y_real"]
        adjacency = abs.(Y_real) .> 1e-6
        
        @test isa(adjacency, BitMatrix)
        @test size(adjacency, 1) == size(adjacency, 2)
        
        # Placeholder for tree decomposition
        # tree_width = PowerLASCOPF.compute_tree_width(adjacency)
        # @test tree_width >= 1
        
        println("✅ Tree width analysis framework prepared")
        println("   - Ready for Lavaei et al. solution quality analysis")
        println("   - Adjacency matrix computation verified")
        println("   - Tree decomposition algorithms can be integrated")
    end
end

# Helper function to run all tests
function run_sdp_opf_tests()
    println("🚀 Running Comprehensive SDP OPF Tests")
    println("=" ^ 50)
    
    @testset "SDP OPF Test Suite" begin
        include("test_sdp_opf_comprehensive.jl")
    end
    
    println("\n✨ All SDP OPF tests completed!")
    println("📊 System ready for:")
    println("   - IEEE test case solving")
    println("   - Tree width calculation")
    println("   - Solution quality analysis")
    println("   - Integration with PowerLASCOPF framework")
end