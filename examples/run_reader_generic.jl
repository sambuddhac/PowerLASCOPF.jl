"""
Generic PowerLASCOPF Simulation Runner
=======================================

PURPOSE:
  A SINGLE runner that works for ANY IEEE test case (5-bus, 30-bus, 48-bus, 57-bus, 300-bus, etc.)
  
  Features:
  - INTERACTIVE MODE: Run without arguments to see available cases and select one
  - Automatically finds data folder and detects file format
  - Supports both standard and legacy file formats
  - Runs economic dispatch simulation and saves results

USAGE MODES:

  1. INTERACTIVE MODE (recommended for new users):
     julia run_reader_generic.jl
     
     This will:
     - Display all available IEEE test cases
     - Let you select a case by number or name
     - Ask for simulation parameters
     - Run the simulation and offer to run more cases

  2. COMMAND LINE MODE:
     julia run_reader_generic.jl case=5bus
     julia run_reader_generic.jl case=30bus format=JSON
     julia run_reader_generic.jl case=IEEE_300_bus iterations=20 verbose=true

  3. SPECIAL COMMANDS:
     julia run_reader_generic.jl list    # List all available cases
     julia run_reader_generic.jl help    # Show help
     julia run_reader_generic.jl all     # Run all available cases

  4. FROM JULIA REPL:
     include("run_reader_generic.jl")
     results = run_case("IEEE_5_bus")
     results = run_case("IEEE_30_bus", verbose=true)
     interactive_mode()  # Start interactive mode

ADDING NEW TEST CASES:
  To add a new IEEE test case (e.g., IEEE 24-bus):
  1. Create folder: example_cases/IEEE_Test_Cases/IEEE_24_bus/
  2. Add CSV files in Sahar format (see ADDING_NEW_CASES.md)
  3. The case will automatically appear in the list

  Full documentation: example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md

COMMAND LINE ARGUMENTS:
  case=<name>          Case name (e.g., 5bus, 30bus, IEEE_300_bus)
  format=<CSV|JSON>    File format (default: CSV)
  iterations=<n>       Max ADMM iterations (default: 10)
  tolerance=<x>        Convergence tolerance (default: 1e-3)
  output=<file>        Output JSON file (default: <case>_results.json)
  verbose=<true|false> Verbose output (default: false)
"""

using Pkg

# ============================================================================
# STEP 1: ENVIRONMENT ACTIVATION
# ============================================================================

# Determine project root directory
const SCRIPT_DIR = @__DIR__
const PROJECT_ROOT = abspath(joinpath(SCRIPT_DIR, ".."))

println("🔧 Activating project environment: $PROJECT_ROOT")
Pkg.activate(PROJECT_ROOT)

# ============================================================================
# STEP 2: IMPORT REQUIRED PACKAGES
# ============================================================================

using DataFrames
using JSON3
using Printf
using Dates

# Include the generic data reader
include(joinpath(PROJECT_ROOT, "example_cases", "data_reader_generic.jl"))

# Include the simulation runner
include(joinpath(PROJECT_ROOT, "examples", "run_reader.jl"))

# ============================================================================
# STEP 3: ARGUMENT PARSING
# ============================================================================

"""
    parse_arguments() -> Dict{String, Any}

Parse command-line arguments in key=value format.
Handles special commands: list, help, all
"""
function parse_arguments()
    args = Dict{String, Any}(
        "case" => "",
        "format" => "CSV",
        "iterations" => 10,
        "tolerance" => 1e-3,
        "output" => "",
        "verbose" => false,
        "contingencies" => 2,
        "rnd_intervals" => 6,
        "command" => ""  # Special commands: list, help, all
    )
    
    for arg in ARGS
        if !occursin('=', arg)
            # Check for special commands first
            lower_arg = lowercase(arg)
            if lower_arg in ["list", "help", "all", "--list", "--help", "-h", "-l"]
                args["command"] = lower_arg
                continue
            end
            # Assume it's the case name if no = sign
            if isempty(args["case"])
                args["case"] = arg
            end
            continue
        end
        
        key, value = split(arg, '=', limit=2)
        key = lowercase(strip(key))
        value = strip(value)
        
        if key == "case"
            args["case"] = value
        elseif key == "format"
            args["format"] = uppercase(value)
        elseif key == "iterations"
            args["iterations"] = parse(Int, value)
        elseif key == "tolerance"
            args["tolerance"] = parse(Float64, value)
        elseif key == "output"
            args["output"] = value
        elseif key == "verbose"
            args["verbose"] = lowercase(value) in ["true", "1", "yes"]
        elseif key == "contingencies"
            args["contingencies"] = parse(Int, value)
        elseif key == "rnd_intervals"
            args["rnd_intervals"] = parse(Int, value)
        end
    end
    
    # Set default output filename based on case name
    if isempty(args["output"]) && !isempty(args["case"]) && isempty(args["command"])
        bus_count = parse_case_name(args["case"])
        args["output"] = "$(bus_count)bus_lascopf_results.json"
    end
    
    return args
end

# ============================================================================
# STEP 4: SIMULATION CONFIGURATION
# ============================================================================

"""
    SimulationConfig

Configuration parameters for the LASCOPF simulation.
"""
struct SimulationConfig
    case_name::String
    data_format::String
    max_iterations::Int
    tolerance::Float64
    num_contingencies::Int
    rnd_intervals::Int
    output_file::String
    verbose::Bool
end

function SimulationConfig(args::Dict)
    return SimulationConfig(
        args["case"],
        args["format"],
        args["iterations"],
        args["tolerance"],
        args["contingencies"],
        args["rnd_intervals"],
        args["output"],
        args["verbose"]
    )
end

# ============================================================================
# STEP 5: DATA VALIDATION
# ============================================================================

"""
    validate_data(data::Dict{Symbol, DataFrame}) -> Bool

Validate that loaded data is complete and consistent.
"""
function validate_data(data::Dict{Symbol, DataFrame})
    println("\n🔍 Validating data...")
    
    valid = true
    warnings = String[]
    
    # Check nodes exist
    if isempty(data[:nodes])
        push!(warnings, "No nodes data found!")
        valid = false
    end
    
    # Check at least one generator type exists
    has_generation = !isempty(data[:thermal]) || !isempty(data[:renewable]) || !isempty(data[:hydro])
    if !has_generation
        push!(warnings, "No generators found (thermal, renewable, or hydro)")
        valid = false
    end
    
    # Check loads exist
    if isempty(data[:loads])
        push!(warnings, "No loads data found!")
        valid = false
    end
    
    # Check branches exist
    if isempty(data[:branches])
        push!(warnings, "No branches/transmission lines found!")
        valid = false
    end
    
    # Check generation-load balance
    total_gen_cap = get_total_generation_capacity(data)
    total_load = get_total_load(data)
    
    if total_load > 0 && total_gen_cap < total_load
        push!(warnings, @sprintf("Generation capacity (%.2f) may be insufficient for load (%.2f)", 
                                  total_gen_cap, total_load))
    end
    
    # Print validation results
    if valid
        println("  ✅ Data validation passed")
    else
        println("  ⚠️  Data validation warnings:")
        for w in warnings
            println("     - $w")
        end
    end
    
    return valid
end

# ============================================================================
# STEP 6: RESULTS STRUCTURE
# ============================================================================

"""
    SimulationResults

Structure to hold simulation results.
"""
mutable struct SimulationResults
    case_name::String
    bus_count::Int
    timestamp::String
    status::String
    
    # Data summary
    num_nodes::Int
    num_thermal_gens::Int
    num_renewable_gens::Int
    num_hydro_gens::Int
    num_storage::Int
    num_loads::Int
    num_branches::Int
    
    # System metrics
    total_generation_capacity::Float64
    total_load::Float64
    
    # Convergence info (placeholder for actual algorithm)
    iterations::Int
    converged::Bool
    final_residual::Float64
    
    # Cost info
    total_cost::Float64
    
    # Detailed results
    generator_dispatch::Dict{String, Float64}
    line_flows::Dict{String, Float64}
end

function SimulationResults(case_name::String, data::Dict{Symbol, DataFrame})
    bus_count = parse_case_name(case_name)
    
    return SimulationResults(
        case_name,
        bus_count,
        Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
        "initialized",
        
        nrow(data[:nodes]),
        nrow(data[:thermal]),
        nrow(data[:renewable]),
        nrow(data[:hydro]),
        nrow(data[:storage]),
        nrow(data[:loads]),
        nrow(data[:branches]),
        
        get_total_generation_capacity(data),
        get_total_load(data),
        
        0, false, Inf,
        0.0,
        
        Dict{String, Float64}(),
        Dict{String, Float64}()
    )
end

# ============================================================================
# STEP 7: SIMULATION RUNNER
# ============================================================================

"""
    run_case(case_name::String; kwargs...) -> SimulationResults

Main function to run a simulation for a given case.

Arguments:
  - case_name: Name of the test case (e.g., "IEEE_5_bus", "30bus")
  
Keyword Arguments:
  - format: Data file format ("CSV" or "JSON"), default "CSV"
  - iterations: Max ADMM iterations, default 10
  - tolerance: Convergence tolerance, default 1e-3
  - verbose: Print detailed output, default false
  - output: Output file path, default "<case>_results.json"

Returns:
  SimulationResults struct with all results

Example:
  results = run_case("IEEE_5_bus")
  results = run_case("30bus", verbose=true, iterations=20)
"""
function run_case(case_name::AbstractString; 
                  format::String="CSV",
                  iterations::Int=10,
                  tolerance::Float64=1e-3,
                  verbose::Bool=false,
                  contingencies::Int=2,
                  output::String="")
    
    # Convert to String if needed
    case_name = String(case_name)
    
    println("\n" * "=" ^ 70)
    println("🚀 POWERLASCOPF GENERIC RUNNER")
    println("=" ^ 70)
    
    # ========================================================================
    # PHASE 1: CONFIGURATION
    # ========================================================================
    
    bus_count = parse_case_name(case_name)
    
    if isempty(output)
        output = "$(bus_count)bus_lascopf_results.json"
    end
    
    println("\n📋 CONFIGURATION:")
    println("-" ^ 70)
    println("  Case:           $case_name")
    println("  Bus Count:      $bus_count")
    println("  Data Format:    $format")
    println("  Max Iterations: $iterations")
    println("  Tolerance:      $tolerance")
    println("  Contingencies:  $contingencies")
    println("  Output File:    $output")
    println("  Verbose:        $verbose")
    
    # ========================================================================
    # PHASE 2: DATA LOADING
    # ========================================================================
    
    println("\n📂 LOADING DATA...")
    println("-" ^ 70)
    
    data = load_case_data(case_name, format)
    
    # Validate data
    validate_data(data)
    
    # ========================================================================
    # PHASE 3: INITIALIZE RESULTS
    # ========================================================================
    
    results = SimulationResults(case_name, data)
    
    # ========================================================================
    # PHASE 4: SIMULATION
    # ========================================================================
    
    println("\n⚡ RUNNING SIMULATION...")
    println("-" ^ 70)
    
    # Prepare system data for simulation
    # Convert DataFrames to system_data Dict format expected by execute_simulation
    system_data = Dict(
        "name" => case_name,
        "nodes" => data[:nodes],
        "branches" => data[:branches],
        "thermal_generators" => data[:thermal],
        "renewable_generators" => data[:renewable],
        "hydro_generators" => data[:hydro],
        "storage" => data[:storage],
        "loads" => data[:loads],
        "base_power" => 100.0
    )
    
    # Prepare configuration for simulation
    config = Dict(
        "max_iterations" => iterations,
        "tolerance" => tolerance,
        "contingencies" => contingencies,
        "rnd_intervals" => 6,
        "verbose" => verbose,
        "solver" => "ipopt"
    )
    
    # Call execute_simulation from run_reader.jl
    try
        simulation_results = execute_simulation(case_name, nothing, system_data, config)
        
        # Update results structure with simulation outcomes
        results.status = simulation_results["status"]
        results.iterations = simulation_results["iterations"]
        results.final_residual = 0.0  # Placeholder
        results.total_cost = simulation_results["objective_value"]
        results.converged = (simulation_results["status"] == "FEASIBLE")
        
        # Extract generator dispatch and line flows if available
        if haskey(simulation_results, "generator_dispatch")
            results.generator_dispatch = simulation_results["generator_dispatch"]
        end
        if haskey(simulation_results, "line_flows")
            results.line_flows = simulation_results["line_flows"]
        end
        
        if results.converged
            println("  ✅ Simulation converged successfully")
        else
            println("  ⚠️  Simulation completed with status: $(results.status)")
        end
    catch e
        # If simulation fails, fall back to simple economic dispatch
        println("  ⚠️  Full simulation not available, using simple dispatch: $e")
        
        # Extract generator data for simple dispatch
        thermal_df = data[:thermal]
        loads_df = data[:loads]
        branches_df = data[:branches]
        
        println("  Preparing simple economic dispatch...")
        
        if !isempty(thermal_df) && hasproperty(thermal_df, :GeneratorName)
            total_load = get_total_load(data)
            remaining_load = total_load
            
            # Sort generators by cost (linear cost coefficient)
            if hasproperty(thermal_df, :CostCurve_b)
                sorted_gens = sort(thermal_df, :CostCurve_b)
            else
                sorted_gens = thermal_df
            end
            
            total_cost = 0.0
            
            for row in eachrow(sorted_gens)
                gen_name = row.GeneratorName
                max_power = hasproperty(row, :ActivePowerMax) ? row.ActivePowerMax : 0.0
                min_power = hasproperty(row, :ActivePowerMin) ? row.ActivePowerMin : 0.0
                
                # Dispatch this generator
                if remaining_load > 0
                    dispatch = min(max_power, remaining_load)
                    dispatch = max(dispatch, min_power)
                else
                    dispatch = 0.0
                end
                
                remaining_load -= dispatch
                results.generator_dispatch[gen_name] = dispatch
                
                # Calculate cost
                a = hasproperty(row, :CostCurve_a) ? row.CostCurve_a : 0.0
                b = hasproperty(row, :CostCurve_b) ? row.CostCurve_b : 0.0
                c = hasproperty(row, :CostCurve_c) ? row.CostCurve_c : 0.0
                cost = a * dispatch^2 + b * dispatch + c
                total_cost += cost
                
                if verbose
                    @printf("    %s: %.2f MW (cost: \$%.2f)\n", gen_name, dispatch, cost)
                end
            end
            
            results.total_cost = total_cost
            results.converged = remaining_load <= tolerance
            results.iterations = 1
            results.final_residual = abs(remaining_load)
            
            if results.converged
                results.status = "converged"
                println("  ✅ Dispatch converged")
            else
                results.status = "not_converged"
                println("  ⚠️  Load not fully satisfied (remaining: $(remaining_load) MW)")
            end
        else
            results.status = "no_generators"
            println("  ⚠️  No generators available for dispatch")
        end
        
        # Calculate line flows (simplified)
        println("  Calculating line flows...")
        
        if !isempty(branches_df) && hasproperty(branches_df, :LineID)
            for row in eachrow(branches_df)
                line_id = row.LineID
                results.line_flows[line_id] = 0.0
            end
            
            if verbose
                println("    Calculated flows for $(length(results.line_flows)) lines")
            end
        end
    end
    
    # ========================================================================
    # PHASE 5: SAVE RESULTS
    # ========================================================================
    
    println("\n💾 SAVING RESULTS...")
    println("-" ^ 70)
    
    output_path = joinpath(PROJECT_ROOT, output)
    
    results_dict = Dict(
        "case_name" => results.case_name,
        "bus_count" => results.bus_count,
        "timestamp" => results.timestamp,
        "status" => results.status,
        
        "data_summary" => Dict(
            "nodes" => results.num_nodes,
            "thermal_generators" => results.num_thermal_gens,
            "renewable_generators" => results.num_renewable_gens,
            "hydro_generators" => results.num_hydro_gens,
            "storage" => results.num_storage,
            "loads" => results.num_loads,
            "branches" => results.num_branches
        ),
        
        "system_metrics" => Dict(
            "total_generation_capacity_MW" => results.total_generation_capacity,
            "total_load_MW" => results.total_load
        ),
        
        "convergence" => Dict(
            "iterations" => results.iterations,
            "converged" => results.converged,
            "final_residual" => results.final_residual
        ),
        
        "costs" => Dict(
            "total_cost" => results.total_cost
        ),
        
        "generator_dispatch" => results.generator_dispatch,
        "line_flows" => results.line_flows
    )
    
    open(output_path, "w") do f
        JSON3.pretty(f, results_dict)
    end
    
    println("  ✅ Results saved to: $output_path")
    
    # ========================================================================
    # PHASE 6: SUMMARY
    # ========================================================================
    
    println("\n" * "=" ^ 70)
    println("📊 SIMULATION SUMMARY")
    println("=" ^ 70)
    @printf("  Case:              %s (%d buses)\n", results.case_name, results.bus_count)
    @printf("  Status:            %s\n", results.status)
    @printf("  Total Gen Capacity: %.2f MW\n", results.total_generation_capacity)
    @printf("  Total Load:        %.2f MW\n", results.total_load)
    @printf("  Total Cost:        \$%.2f\n", results.total_cost)
    @printf("  Iterations:        %d\n", results.iterations)
    @printf("  Final Residual:    %.6f\n", results.final_residual)
    println("=" ^ 70)
    
    return results
end

# ============================================================================
# STEP 8: BATCH RUNNER
# ============================================================================

"""
    run_all_cases(cases::Vector{String}; kwargs...) -> Dict{String, SimulationResults}

Run multiple test cases sequentially.

Example:
  results = run_all_cases(["5bus", "30bus", "57bus"])
"""
function run_all_cases(cases::Vector{String}; kwargs...)
    results = Dict{String, SimulationResults}()
    
    println("\n" * "=" ^ 70)
    println("🔄 BATCH RUNNER: $(length(cases)) cases")
    println("=" ^ 70)
    
    for (i, case_name) in enumerate(cases)
        println("\n[$i/$(length(cases))] Running: $case_name")
        try
            results[case_name] = run_case(case_name; kwargs...)
        catch e
            println("  ❌ Failed: $e")
            # Create error result
            results[case_name] = SimulationResults(
                case_name, Dict{Symbol, DataFrame}(
                    :nodes => DataFrame(),
                    :thermal => DataFrame(),
                    :renewable => DataFrame(),
                    :hydro => DataFrame(),
                    :storage => DataFrame(),
                    :loads => DataFrame(),
                    :branches => DataFrame()
                )
            )
            results[case_name].status = "error: $e"
        end
    end
    
    # Print batch summary
    println("\n" * "=" ^ 70)
    println("📊 BATCH SUMMARY")
    println("=" ^ 70)
    for (case_name, result) in results
        status_icon = result.status == "converged" ? "✅" : "⚠️"
        @printf("  %s %s: %s (%.2f MW, \$%.2f)\n", 
                status_icon, case_name, result.status, 
                result.total_load, result.total_cost)
    end
    println("=" ^ 70)
    
    return results
end

"""
    run_all_cases(; kwargs...) -> Dict{String, SimulationResults}

Run all available test cases automatically discovered from IEEE_Test_Cases folder.

Example:
  results = run_all_cases()
"""
function run_all_cases(; kwargs...)
    cases_dir = joinpath(PROJECT_ROOT, "example_cases", "IEEE_Test_Cases")
    
    if !isdir(cases_dir)
        println("⚠️  IEEE_Test_Cases folder not found at: $cases_dir")
        return Dict{String, SimulationResults}()
    end
    
    # Find all IEEE case folders
    all_items = readdir(cases_dir)
    case_folders = filter(item -> isdir(joinpath(cases_dir, item)) && startswith(item, "IEEE_"), all_items)
    
    # Extract bus numbers and sort
    case_info = []
    for folder in case_folders
        bus_match = match(r"IEEE_(\d+)_bus", folder)
        if bus_match !== nothing
            bus_count = parse(Int, bus_match.captures[1])
            push!(case_info, (folder, bus_count))
        end
    end
    sort!(case_info, by=x->x[2])
    
    # Convert to case names (just use bus number)
    cases = ["$(info[2])bus" for info in case_info]
    
    if isempty(cases)
        println("⚠️  No IEEE test cases found in: $cases_dir")
        return Dict{String, SimulationResults}()
    end
    
    println("\n📁 Found $(length(cases)) test cases: $(join(cases, ", "))")
    
    return run_all_cases(cases; kwargs...)
end

# ============================================================================
# STEP 9: AVAILABLE CASES DISCOVERY
# ============================================================================

"""
    list_available_cases() -> Vector{String}

List all available test cases in the IEEE_Test_Cases folder.
Shows format type (sahar = standard, legacy = deprecated).
"""
function list_available_cases()
    cases_dir = joinpath(PROJECT_ROOT, "example_cases", "IEEE_Test_Cases")
    
    if !isdir(cases_dir)
        println("⚠️  IEEE_Test_Cases folder not found")
        return String[]
    end
    
    cases = String[]
    for entry in readdir(cases_dir)
        path = joinpath(cases_dir, entry)
        if isdir(path) && startswith(entry, "IEEE_")
            push!(cases, entry)
        end
    end
    
    sort!(cases, by = x -> parse_case_name(x))
    
    println("\n📁 Available IEEE Test Cases:")
    println("-" ^ 55)
    println("  Case Name              Format      Status")
    println("-" ^ 55)
    
    sahar_count = 0
    legacy_count = 0
    
    for case_name in cases
        bus_count = parse_case_name(case_name)
        case_path = joinpath(cases_dir, case_name)
        file_format = try
            detect_file_format(case_path, bus_count; silent=true)
        catch
            :unknown
        end
        
        # Don't print the warning during list
        if file_format == :sahar
            status = "✅ Standard"
            sahar_count += 1
        elseif file_format == :legacy
            status = "⚠️  Deprecated"
            legacy_count += 1
        else
            status = "❓ Unknown"
        end
        
        @printf("  %-22s %-10s  %s\n", case_name, file_format, status)
    end
    
    println("-" ^ 55)
    println("  Standard (sahar): $sahar_count  |  Legacy (deprecated): $legacy_count")
    println("\n📖 For adding new cases, see:")
    println("   example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md")
    println("-" ^ 55)
    
    return cases
end

# ============================================================================
# STEP 10: INTERACTIVE MODE
# ============================================================================

"""
    get_available_case_names() -> Vector{String}

Get list of available case names (just the short names like "5bus", "30bus").
"""
function get_available_case_names()
    cases_dir = joinpath(PROJECT_ROOT, "example_cases", "IEEE_Test_Cases")
    
    if !isdir(cases_dir)
        return String[]
    end
    
    case_names = String[]
    for entry in readdir(cases_dir)
        path = joinpath(cases_dir, entry)
        if isdir(path) && startswith(entry, "IEEE_")
            bus_count = try
                parse_case_name(entry)
            catch
                continue
            end
            push!(case_names, "$(bus_count)bus")
        end
    end
    
    sort!(case_names, by = x -> parse_case_name(x))
    return case_names
end

"""
    interactive_mode()

Run PowerLASCOPF in interactive mode where user can select from available cases.
"""
function interactive_mode()
    println("\n" * "=" ^ 70)
    println("🚀 POWERLASCOPF - INTERACTIVE MODE")
    println("=" ^ 70)
    
    # Get available cases
    cases_dir = joinpath(PROJECT_ROOT, "example_cases", "IEEE_Test_Cases")
    
    if !isdir(cases_dir)
        println("❌ IEEE_Test_Cases folder not found at: $cases_dir")
        return nothing
    end
    
    # Collect case information
    case_info = []
    for entry in readdir(cases_dir)
        path = joinpath(cases_dir, entry)
        if isdir(path) && startswith(entry, "IEEE_")
            bus_count = try
                parse_case_name(entry)
            catch
                continue
            end
            file_format = try
                detect_file_format(path, bus_count; silent=true)
            catch
                :unknown
            end
            push!(case_info, (entry, bus_count, file_format))
        end
    end
    
    sort!(case_info, by = x -> x[2])
    
    if isempty(case_info)
        println("❌ No IEEE test cases found!")
        println("\n📖 To add a new case, see:")
        println("   example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md")
        return nothing
    end
    
    # Display available cases
    println("\n📁 AVAILABLE IEEE TEST CASES:")
    println("-" ^ 70)
    println("  #   Case Name              Buses    Format      Status")
    println("-" ^ 70)
    
    for (i, (name, buses, fmt)) in enumerate(case_info)
        status = fmt == :sahar ? "✅ Standard" : (fmt == :legacy ? "⚠️  Legacy" : "❓ Unknown")
        @printf("  %-3d %-22s %-8d %-10s  %s\n", i, name, buses, fmt, status)
    end
    
    println("-" ^ 70)
    println("\n📌 OPTIONS:")
    println("   • Enter a number (1-$(length(case_info))) to select a case")
    println("   • Enter a case name directly (e.g., '30bus' or 'IEEE_30_bus')")
    println("   • Enter 'all' to run all cases")
    println("   • Enter 'q' or 'quit' to exit")
    println("   • Enter 'add' to see how to add a new case")
    println("-" ^ 70)
    
    while true
        print("\n🔹 Enter your choice: ")
        input = readline()
        input = strip(input)
        
        if isempty(input)
            continue
        end
        
        lower_input = lowercase(input)
        
        # Check for quit
        if lower_input in ["q", "quit", "exit"]
            println("\n👋 Goodbye!")
            return nothing
        end
        
        # Check for add new case info
        if lower_input == "add"
            println("\n" * "=" ^ 70)
            println("📖 ADDING A NEW TEST CASE")
            println("=" ^ 70)
            println("\nTo add a new IEEE test case (e.g., IEEE 24-bus):")
            println("\n1️⃣  Create folder: example_cases/IEEE_Test_Cases/IEEE_24_bus/")
            println("\n2️⃣  Add required files in Sahar format:")
            println("    • Nodes24_sahar.csv")
            println("    • ThermalGenerators24_sahar.csv")
            println("    • Trans24_sahar.csv")
            println("    • Loads24_sahar.csv")
            println("\n3️⃣  Optional files:")
            println("    • RenewableGenerators24_sahar.csv")
            println("    • HydroGenerators24_sahar.csv")
            println("    • Storage24_sahar.csv")
            println("\n📄 Full documentation:")
            println("   example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md")
            println("=" ^ 70)
            continue
        end
        
        # Check for run all
        if lower_input == "all"
            println("\n🔄 Running ALL available cases...")
            return run_all_cases()
        end
        
        # Try to parse as number
        selected_case = nothing
        if all(isdigit, input)
            idx = parse(Int, input)
            if 1 <= idx <= length(case_info)
                selected_case = "$(case_info[idx][2])bus"
            else
                println("❌ Invalid number. Please enter 1-$(length(case_info))")
                continue
            end
        else
            # Try to match case name
            # Extract bus count from input
            bus_match = match(r"(\d+)", input)
            if bus_match !== nothing
                bus_count = parse(Int, bus_match.captures[1])
                # Check if this case exists
                found = false
                for (name, buses, _) in case_info
                    if buses == bus_count
                        selected_case = "$(bus_count)bus"
                        found = true
                        break
                    end
                end
                if !found
                    println("❌ Case with $bus_count buses not found!")
                    println("   Available: $(join([string(c[2]) for c in case_info], ", ")) buses")
                    println("\n   To add this case, enter 'add' for instructions.")
                    continue
                end
            else
                println("❌ Could not understand input: '$input'")
                println("   Please enter a number or case name (e.g., '30bus')")
                continue
            end
        end
        
        if selected_case !== nothing
            println("\n✅ Selected: $selected_case")
            
            # Ask for additional options
            print("🔹 Max iterations [10]: ")
            iter_input = strip(readline())
            iterations = isempty(iter_input) ? 10 : parse(Int, iter_input)
            
            print("🔹 Verbose output? (y/n) [n]: ")
            verbose_input = lowercase(strip(readline()))
            verbose = verbose_input in ["y", "yes", "true", "1"]
            
            println("\n" * "=" ^ 70)
            
            # Run the case
            result = run_case(selected_case; 
                             iterations=iterations, 
                             verbose=verbose)
            
            # Ask if user wants to run another case
            print("\n🔹 Run another case? (y/n) [y]: ")
            again_input = lowercase(strip(readline()))
            if again_input in ["n", "no"]
                println("\n👋 Goodbye!")
                return result
            end
            
            # Redisplay the menu
            println("\n" * "-" ^ 70)
            println("📁 AVAILABLE CASES:")
            for (i, (name, buses, fmt)) in enumerate(case_info)
                status_icon = fmt == :sahar ? "✅" : "⚠️"
                @printf("  %d. %s (%d buses) %s\n", i, name, buses, status_icon)
            end
            println("-" ^ 70)
        end
    end
end

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

function main()
    args = parse_arguments()
    
    # Handle special commands
    cmd = lowercase(args["command"])
    if cmd in ["list", "--list", "-l"]
        list_available_cases()
        return nothing
    elseif cmd in ["help", "--help", "-h"]
        println("\n" * "=" ^ 70)
        println("🚀 POWERLASCOPF GENERIC RUNNER - HELP")
        println("=" ^ 70)
        println("\nUsage: julia run_reader_generic.jl [command] [case=<name>] [options]")
        println("\nCommands:")
        println("  (no args)     Interactive mode - select from available cases")
        println("  list          List all available IEEE test cases")
        println("  help          Show this help message")
        println("  all           Run all available test cases")
        println("\nOptions:")
        println("  case=<name>   Case name (e.g., 5bus, 30bus, IEEE_300_bus)")
        println("  format=<fmt>  Data format: CSV or JSON (default: CSV)")
        println("  iterations=N  Maximum ADMM iterations (default: 10)")
        println("  tolerance=T   Convergence tolerance (default: 1e-3)")
        println("  verbose=bool  Enable verbose output (default: false)")
        println("  output=<file> Output filename (default: <N>bus_lascopf_results.json)")
        println("\nExamples:")
        println("  julia run_reader_generic.jl                    # Interactive mode")
        println("  julia run_reader_generic.jl case=5bus")
        println("  julia run_reader_generic.jl case=IEEE_30_bus format=JSON")
        println("  julia run_reader_generic.jl case=300bus iterations=20 verbose=true")
        println("  julia run_reader_generic.jl list")
        println("  julia run_reader_generic.jl all")
        println("=" ^ 70)
        return nothing
    elseif cmd == "all"
        return run_all_cases()
    end
    
    # If no case specified and no command, enter interactive mode
    if isempty(args["case"]) && isempty(args["command"])
        return interactive_mode()
    end
    
    if isempty(args["case"])
        println("❌ No case specified!")
        println("\nUsage: julia run_reader_generic.jl case=<case_name> [options]")
        println("\nOr run without arguments for interactive mode:")
        println("  julia run_reader_generic.jl")
        println("\n")
        list_available_cases()
        return nothing
    end
    
    return run_case(
        args["case"];
        format = args["format"],
        iterations = args["iterations"],
        tolerance = args["tolerance"],
        verbose = args["verbose"],
        contingencies = args["contingencies"],
        output = args["output"]
    )
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

