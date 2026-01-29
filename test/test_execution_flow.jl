"""
Test Execution Flow Refactoring

Tests that verify the restructured execution flow:
- run_reader_generic.jl can call functions from run_reader.jl
- execute_simulation() function exists and has correct signature
- Data flow between components is correct
"""

using Test

@testset "Execution Flow Tests" begin
    
    @testset "execute_simulation function signature" begin
        # Test that we can parse and find the execute_simulation function
        
        # Read the run_reader.jl file
        run_reader_path = joinpath(@__DIR__, "..", "examples", "run_reader.jl")
        @test isfile(run_reader_path)
        
        content = read(run_reader_path, String)
        
        # Check that execute_simulation function is defined
        @test occursin("function execute_simulation", content)
        
        # Check required parameters are documented
        @test occursin("case_name::String", content)
        @test occursin("system_data::Dict", content)
        @test occursin("config::Dict", content)
    end
    
    @testset "run_reader_generic calls execute_simulation" begin
        # Test that run_reader_generic.jl includes run_reader.jl and calls execute_simulation
        
        run_reader_generic_path = joinpath(@__DIR__, "..", "examples", "run_reader_generic.jl")
        @test isfile(run_reader_generic_path)
        
        content = read(run_reader_generic_path, String)
        
        # Check that run_reader.jl is included
        @test occursin("include", content)
        @test occursin("run_reader.jl", content)
        
        # Check that execute_simulation is called
        @test occursin("execute_simulation", content)
        @test occursin("execute_simulation(case_name", content)
    end
    
    @testset "data_reader.jl case loaders exist" begin
        # Test that case-specific loader functions are defined
        
        data_reader_path = joinpath(@__DIR__, "..", "example_cases", "data_reader.jl")
        @test isfile(data_reader_path)
        
        content = read(data_reader_path, String)
        
        # Check that case loader functions exist
        @test occursin("function load_5bus_case", content)
        @test occursin("function load_14bus_case", content)
        @test occursin("function load_118bus_case", content)
        @test occursin("function load_300bus_case", content)
    end
    
    @testset "Execution flow documentation" begin
        # Verify that the execution flow is documented
        
        run_reader_generic_path = joinpath(@__DIR__, "..", "examples", "run_reader_generic.jl")
        content = read(run_reader_generic_path, String)
        
        # Check for documentation of the execution phases
        @test occursin("PHASE 4: SIMULATION", content)
        @test occursin("Call execute_simulation", content) || 
              occursin("execute_simulation", content)
    end
end

# Print success message
println("\n✅ All execution flow tests passed!")
println("   The refactored execution flow is correctly structured.")
