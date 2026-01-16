"""
Generic PowerLASCOPF Simulation Runner
=======================================

PURPOSE:
  A SINGLE runner that works for ANY IEEE test case (5-bus, 30-bus, 48-bus, 57-bus, 300-bus, etc.)
  Just specify the case name and it automatically:
  1. Finds the correct data folder
  2. Detects the file format (sahar vs legacy)
  3. Loads all component data
  4. Sets up the simulation
  5. Runs and saves results

USAGE EXAMPLES:
  # Run from command line
  julia run_reader_generic.jl case=5bus
  julia run_reader_generic.jl case=30bus format=JSON
  julia run_reader_generic.jl case=IEEE_300_bus iterations=20 verbose=true
  
  # Run from Julia REPL
  include("run_reader_generic.jl")
  results = run_case("IEEE_5_bus")
  results = run_case("IEEE_30_bus", verbose=true)
  results = run_case("IEEE_300_bus", iterations=20)

SUPPORTED TEST CASES:
  - 5bus, IEEE_5_bus     (5-bus test system)
  - 30bus, IEEE_30_bus   (IEEE 30-bus system)
  - 48bus, IEEE_48_bus   (IEEE 48-bus system)
  - 57bus, IEEE_57_bus   (IEEE 57-bus system)
  - 300bus, IEEE_300_bus (IEEE 300-bus system)
  - Any custom case following the naming convention

COMMAND LINE ARGUMENTS:
  case=<name>          Case name (required)
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
    
    # Extract generator data for dispatch simulation
    thermal_df = data[:thermal]
    loads_df = data[:loads]
    branches_df = data[:branches]
    
    # Simple economic dispatch (placeholder for full ADMM/APP algorithm)
    # This demonstrates how the data would be used
    
    println("  Preparing generator dispatch...")
    
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
    
    # Calculate line flows (simplified DC power flow approximation)
    println("  Calculating line flows...")
    
    if !isempty(branches_df) && hasproperty(branches_df, :LineID)
        for row in eachrow(branches_df)
            line_id = row.LineID
            # Placeholder - actual power flow calculation would go here
            results.line_flows[line_id] = 0.0
        end
        
        if verbose
            println("    Calculated flows for $(length(results.line_flows)) lines")
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
    
    if isempty(args["case"])
        println("❌ No case specified!")
        println("\nUsage: julia run_reader_generic.jl case=<case_name> [options]")
        println("\nExamples:")
        println("  julia run_reader_generic.jl case=5bus")
        println("  julia run_reader_generic.jl case=IEEE_30_bus format=JSON")
        println("  julia run_reader_generic.jl case=300bus iterations=20 verbose=true")
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

