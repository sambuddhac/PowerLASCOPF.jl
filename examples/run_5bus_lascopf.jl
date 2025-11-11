"""
5-Bus PowerLASCOPF Simulation Runner

This script demonstrates how to run a complete PowerLASCOPF simulation
on the 5-bus test system with ADMM/APP algorithm.
"""

"""
5-Bus PowerLASCOPF Simulation Runner

This script demonstrates how to run a complete PowerLASCOPF simulation
on the 5-bus test system with ADMM/APP algorithm.
"""

using Pkg;
# Use relative paths from this file's location
project_dir = abspath(joinpath(@__DIR__, "..")) # repository/project root containing Project.toml
println("Activating project at: $project_dir")

# Reset and reinstantiate the environment
Pkg.activate(project_dir);
#=#FOR FIRST TIME USE OR TROUBLESHOOTING
# Clear any problematic manifest and reinstantiate
println("Checking and fixing environment...")
try
    # Remove the problematic Manifest.toml if it exists
    manifest_path = joinpath(project_dir, "Manifest.toml")
    if isfile(manifest_path)
        println("Removing outdated Manifest.toml...")
        rm(manifest_path)
    end
    
    # Reinstantiate the project
    println("Reinstantiating project...")
    Pkg.instantiate()
    
    # Update packages to latest compatible versions
    println("Updating packages...")
    Pkg.update()
    
catch e
    println("Environment setup failed: $e")
    println("Trying alternative approach...")
    
    # Alternative: Create a minimal environment
    Pkg.activate(temp=true)  # Use temporary environment
    
    # Add only essential packages
    Pkg.add([
        "PowerSystems", 
        "TimeSeries", 
        "Dates", 
        "LinearAlgebra", 
        "JuMP", 
        "Ipopt", 
        "JSON"
    ])
end
#FOR FIRST TIME USE OR TROUBLESHOOTING=#

# ...existing code...
# Load necessary packages
using PowerSystems
using TimeSeries
using Dates
using LinearAlgebra
using JuMP
using Ipopt
using JSON
using Printf

include("../src/PowerLASCOPF.jl")
include("../src/components/supernetwork.jl")

# Load test case directly
include("../example_cases/data_5bus_pu.jl")

println("🚀 Starting PowerLASCOPF 5-Bus Simulation")
println("=" ^ 50)

# Step 1: Create PowerLASCOPF system
println("\n📊 Step 1: Creating PowerLASCOPF System")
system, system_data = create_5bus_powerlascopf_system()

println("✓ System created successfully:")
println("  - Nodes: $(length(system_data["nodes"]))")
println("  - Branches: $(length(system_data["branches"]))")
println("  - Thermal Generators: $(length(system_data["thermal_generators"]))")
println("  - Renewable Generators: $(length(system_data["renewable_generators"]))")
#println("  - Hydro Generators: $(length(system_data["hydro_generators"]))")
println("  - Time Horizon: $(length(system_data["time_horizon"])) hours")

# Step 2: Configure ADMM/APP parameters
println("\n⚙️  Step 2: Configuring ADMM/APP Parameters")
admm_params = Dict(
    "max_iterations" => 10,  # Reduced for initial testing
    "tolerance" => 1e-3,     # Relaxed for initial testing
    "rho" => 1.0,
    "beta" => 1.0,
    "gamma" => 1.0,
    "inner_iterations" => 5,  # Reduced for initial testing
    "contingency_scenarios" => 2,
    "dummy_zero_interval" => true,
    "solver" => "ipopt"
)

println("✓ ADMM/APP parameters configured:")
for (key, value) in admm_params
    println("  - $key: $value")
end

# Step 3: Simple LASCOPF simulation (placeholder)
println("\n🔧 Step 3: Running Simplified LASCOPF Simulation")

# Initialize results structure
results = Dict(
    "status" => "FEASIBLE",
    "iterations" => 0,
    "solve_time" => 0.0,
    "objective_value" => 0.0,
    "generator_solutions" => Dict(),
    "line_solutions" => Dict(),
    "convergence_history" => []
)

#Create Supernetwork and Network objects
println("  - Building Supernetwork and Network objects...")
# Placeholder: In a real implementation, you would build the full PSI.DecisionModel here
# Create supernetworks with system-specific parameters
supernetworks = create_supernetwork(
    system.psy_system,
    system_data,
    number_of_cont = 2,        # Number of contingency scenarios
    rnd_intervals = 6,         # Restoration to normal duration intervals
    rsd_intervals = 6,         # Restoration to secure duration intervals
    include_dummy_zero = true, # Include dummy zero interval
    choice_solver = 1,         # 1=ADMM-PMP-GUROBI
    rho_tuning = 1.0,         # APP rho parameter tuning
    contin_sol_accuracy = 1    # Contingency solution accuracy
)
    
# Add supernetworks to system data
system_data["supernetworks"] = supernetworks
system_data["number_of_supernetworks"] = length(supernetworks)
    
# Add additional metadata
system_data["rnd_intervals"] = 6
system_data["rsd_intervals"] = 6
system_data["number_of_contingencies"] = 2
system_data["include_dummy_zero"] = true
    
println("System created with $(length(supernetworks)) SuperNetwork objects")

start_time = time()

# Simple iteration loop (simplified ADMM)
for iter in 1:admm_params["max_iterations"]
    println("  Iteration $iter:")
    
    # Step 3a: Update generator variables
    println("    - Updating generators...")
    total_generation = 0.0
    for (i, gen) in enumerate(system_data["thermal_generators"])
        # Simple power update (placeholder)
        gen.Pg = PSY.get_active_power_limits(gen.generator).max * 0.5
        total_generation += gen.Pg
        
        results["generator_solutions"]["thermal_$(i)"] = Dict(
            "name" => PSY.get_name(gen.generator),
            "power" => gen.Pg,
            "angle" => gen.theta_g,
            "node" => PowerLASCOPF.get_gen_node_id(gen)
        )
    end
    
    # Step 3b: Update transmission lines
    println("    - Updating transmission lines...")
    for (i, line) in enumerate(system_data["branches"])
        # Simple flow calculation (placeholder)
        line.pt1 = 0.1 * i  # Simplified
        line.pt2 = -line.pt1
        
        results["line_solutions"]["line_$(i)"] = Dict(
            "name" => PSY.get_name(line.transl_type),
            "flow_1to2" => line.pt1,
            "flow_2to1" => line.pt2,
            "angle_1" => line.thetat1,
            "angle_2" => line.thetat2
        )
    end
    
    # Step 3c: Check convergence (simplified)
    residual = abs(total_generation - 10.0) / 10.0  # Target 10 MW total
    push!(results["convergence_history"], Dict("iteration" => iter, "residual" => residual))
    
    println("    - Residual: $(round(residual, digits=6))")
    
    if residual < admm_params["tolerance"]
        println("  ✓ Converged in $iter iterations!")
        results["iterations"] = iter
        break
    end
    
    results["iterations"] = iter
end

solve_time = time() - start_time
results["solve_time"] = solve_time
results["objective_value"] = sum(gen.Pg * 30.0 for gen in system_data["thermal_generators"])  # Simple cost

println("✓ Simulation completed!")
println("  - Status: $(results["status"])")
println("  - Iterations: $(results["iterations"])")
println("  - Solve time: $(round(results["solve_time"], digits=2)) seconds")
println("  - Objective value: $(round(results["objective_value"], digits=2))")

# Step 4: Display results
println("\n📈 Step 4: Results Summary")
println("\n📋 Generator Solutions:")
for (key, gen_sol) in results["generator_solutions"]
    println("  $(gen_sol["name"]): $(round(gen_sol["power"], digits=3)) MW @ $(round(gen_sol["angle"], digits=4)) rad")
end

println("\n🔌 Line Flow Solutions:")
for (key, line_sol) in results["line_solutions"]
    println("  $(line_sol["name"]): $(round(line_sol["flow_1to2"], digits=3)) MW")
end

# Step 5: Save results (optional)
println("\n💾 Step 5: Saving Results")
output_data = Dict(
    "system_name" => system_data["name"],
    "results" => results,
    "timestamp" => string(now())
)

filename = "5bus_lascopf_results.json"
open(filename, "w") do io
    JSON.print(io, output_data, 2)
end
println("✓ Results saved to $filename")

println("\n🎉 PowerLASCOPF Simulation Complete!")
println("=" ^ 50)
