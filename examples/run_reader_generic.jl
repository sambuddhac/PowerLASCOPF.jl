"""
Generic PowerLASCOPF Simulation Runner — run_reader_generic.jl
===============================================================

PURPOSE:
  Single entry-point runner for ANY case in example_cases/, including:
    • IEEE test cases  (Sahar CSV or legacy CSV format)
    • RTS-GMLC         (bus.csv / gen.csv / branch.csv)
    • PSS/E RAW        (*.RAW via PowerSystems.jl parser)
    • MATPOWER         (*.m   via PowerSystems.jl parser)

  Features:
    - Interactive mode: browse available cases and set parameters via prompts
    - Auto-detects file format from folder contents (no manual flag needed)
    - Reads per-case ADMM settings from LASCOPF_settings.yml
    - Falls back to a DataFrame-based dispatch stub when PowerLASCOPF is not
      yet compiled (safe during development)

USAGE MODES:

  1. INTERACTIVE MODE (recommended for first use):
       julia run_reader_generic.jl
     — lists all discovered cases, prompts for selection and parameters.

  2. COMMAND-LINE MODE:
       julia run_reader_generic.jl case=5bus
       julia run_reader_generic.jl case=14bus format=JSON verbose=true
       julia run_reader_generic.jl case=RTS_GMLC contingencies=10
       julia run_reader_generic.jl case=ACTIVSg2000 iterations=50
       julia run_reader_generic.jl case=SyntheticUSA output=synusa_results.json

  3. SPECIAL COMMANDS:
       julia run_reader_generic.jl list    # list all available cases + formats
       julia run_reader_generic.jl help    # argument reference
       julia run_reader_generic.jl all     # run every discovered case

  4. FROM JULIA REPL:
       include("run_reader_generic.jl")
       run_case("14bus")
       run_case("RTS_GMLC", verbose=true)
       run_case("ACTIVSg2000", contingencies=10)
       interactive_mode()
       list_available_cases()
       run_all_cases()

CASE DISCOVERY:
  IEEE cases  →  example_cases/IEEE_Test_Cases/IEEE_<N>_bus/
                 Refer to as "5bus", "14bus", "IEEE_14_bus", etc.
  Other cases →  any top-level folder inside example_cases/ that contains
                 a LASCOPF_settings.yml file.
                 Refer to by folder name: "RTS_GMLC", "ACTIVSg2000", etc.

COMMAND-LINE ARGUMENTS:
  case=<name>           Case name (e.g., 5bus, RTS_GMLC, ACTIVSg2000)
  format=<CSV|JSON>     File format for sahar/legacy cases (default: CSV)
  iterations=<n>        Max ADMM outer iterations (default: 10)
  tolerance=<x>         Convergence tolerance (default: 1e-3)
  contingencies=<n>     N-1 contingency scenarios (default: 2)
  output=<file>         Output JSON path (default: <case>_lascopf_results.json)
  verbose=<true|false>  Print iteration detail (default: false)

FULL DOCUMENTATION:
  example_cases/RUNNING_CASES.md
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
Pkg.instantiate()

#using Pkg;
# Use relative paths from this file's location
#project_dir = abspath(joinpath(@__DIR__, "..")) # repository/project root containing Project.toml
#println("Activating project at: $PROJECT_ROOT")

# Check if this is the first run on this machine
first_run_marker = joinpath(PROJECT_ROOT, ".first_run_complete")
if !isfile(first_run_marker)
    #FOR FIRST TIME USE OR TROUBLESHOOTING
    # Clear any problematic manifest and reinstantiate
    println("Checking and fixing environment...")
    try
        # Remove the problematic Manifest.toml if it exists
        manifest_path = joinpath(PROJECT_ROOT, "Manifest.toml")
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
        
        # Create marker file to indicate first run is complete
        touch(first_run_marker)
        println("First-time setup complete. Marker file created.")
        
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
        
        # Still create marker file even with alternative approach
        try
            touch(first_run_marker)
        catch
            # Ignore if we can't create marker in temp environment
        end
    end
    #FOR FIRST TIME USE OR TROUBLESHOOTING
else
    println("First-time setup already completed. Skipping environment reinstantiation.")
end

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
    
    # Set default output filename based on case name.
    # Use the case name directly rather than extracting a bus count, so that
    # non-numeric names like "RTS_GMLC" or "ACTIVSg2000" work without error.
    if isempty(args["output"]) && !isempty(args["case"]) && isempty(args["command"])
        args["output"] = "$(args["case"])_lascopf_results.json"
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
function validate_data(data::Dict{Symbol, Any})
    println("\n🔍 Validating data...")

    valid    = true
    warnings = String[]
    file_fmt = get(data, :file_format, :unknown)

    # --- PSS/E RAW and MATPOWER: component DataFrames are intentionally empty ---
    # Validation is limited to checking that the network file exists on disk.
    if file_fmt in (:psse_raw, :matpower)
        network_file = get(data, :network_file, "")
        if isempty(network_file) || !isfile(network_file)
            push!(warnings, "PSS/E RAW / MATPOWER: network file not found: '$network_file'")
            valid = false
        else
            println("  ✅ Network file found: $network_file")
        end
        if valid
            println("  ✅ Data validation passed (PSS/E RAW / MATPOWER — components loaded at system-build time)")
        else
            println("  ⚠️  Data validation warnings:")
            for w in warnings; println("     - $w"); end
        end
        return valid
    end

    # --- RTS-GMLC: component DataFrames are loaded; check case_path as fallback ---
    if file_fmt == :rts_gmlc
        case_path = get(data, :case_path, "")
        if !isempty(case_path)
            isfile(joinpath(case_path, "gen.csv"))    || push!(warnings, "RTS-GMLC gen.csv not found in $case_path")
            isfile(joinpath(case_path, "bus.csv"))    || push!(warnings, "RTS-GMLC bus.csv not found in $case_path")
            isfile(joinpath(case_path, "branch.csv")) || push!(warnings, "RTS-GMLC branch.csv not found in $case_path")
        end
    end

    # --- Standard DataFrame checks (sahar / legacy / rts_gmlc) ---
    if isempty(data[:nodes])
        push!(warnings, "No nodes data found!")
        valid = false
    end

    has_generation = !isempty(data[:thermal]) || !isempty(data[:renewable]) || !isempty(data[:hydro])
    if !has_generation
        push!(warnings, "No generators found (thermal, renewable, or hydro)")
        valid = false
    end

    if isempty(data[:loads])
        push!(warnings, "No loads data found!")
        valid = false
    end

    if isempty(data[:branches])
        push!(warnings, "No branches/transmission lines found!")
        valid = false
    end

    # Generation-load balance check
    total_gen_cap = get_total_generation_capacity(data)
    total_load    = get_total_load(data)

    if total_load > 0 && total_gen_cap < total_load
        push!(warnings, @sprintf("Generation capacity (%.2f) may be insufficient for load (%.2f)",
                                  total_gen_cap, total_load))
    end

    if valid && isempty(warnings)
        println("  ✅ Data validation passed")
    else
        println("  ⚠️  Data validation warnings:")
        for w in warnings; println("     - $w"); end
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

function SimulationResults(case_name::String, data::Dict{Symbol, Any})
    bus_count = parse_case_name(case_name)

    # For PSS/E RAW / MATPOWER, component DataFrames are empty at this stage;
    # counts will be updated once the PowerLASCOPFSystem is built (Phase 2.5).
    _nrow(df) = (df isa AbstractDataFrame) ? nrow(df) : 0

    return SimulationResults(
        case_name,
        bus_count,
        Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
        "initialized",

        _nrow(data[:nodes]),
        _nrow(data[:thermal]),
        _nrow(data[:renewable]),
        _nrow(data[:hydro]),
        _nrow(data[:storage]),
        _nrow(data[:loads]),
        _nrow(data[:branches]),

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
  - output: Output file path, default "<case>_lascopf_results.json"

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
        output = "$(case_name)_lascopf_results.json"
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
    
    data = load_case_data(case_name, format) ##This is in data_reader_generic.jl

    # Validate data
    validate_data(data)

    # ========================================================================
    # PHASE 2.5: POWERLASCOPF SYSTEM CONSTRUCTION
    # Builds the real PowerLASCOPFSystem from the loaded data.
    # For PSS/E RAW / MATPOWER: calls PSY.System(network_file) then B8.
    # For RTS-GMLC:             calls B9 powerlascopf_from_rts_gmlc!().
    # For Sahar / Legacy:       calls the existing CSV-based functions.
    # This phase requires data_reader.jl to be included (PowerLASCOPF in scope).
    # ========================================================================

    println("\n🏗️  BUILDING POWERLASCOPF SYSTEM...")
    println("-" ^ 70)

    lascopf_system  = nothing   # will hold PowerLASCOPFSystem if construction succeeds
    system_result   = nothing   # named tuple returned by B8/B9

    file_fmt        = get(data, :file_format, :unknown)
    settings        = get(data, :lascopf_settings, Dict{String, Any}())
    case_path_val   = get(data, :case_path, "")

    # Read LASCOPF settings for system construction parameters (B12)
    rnd_intervals   = Int(get(settings, "RNDIntervals", 3))
    rsd_intervals   = Int(get(settings, "RSDIntervals", 3))

    try
        if file_fmt in (:psse_raw, :matpower)
            # --- B8 path: PSY.System → powerlascopf_from_psy_system! ---
            network_file = data[:network_file]
            println("  Loading PSY.System from: $network_file")
            psy_sys = PSY.System(network_file)
            lascopf_system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
            system_result  = powerlascopf_from_psy_system!(
                lascopf_system, psy_sys, contingencies;
                RND_int = rnd_intervals
            )
            println("  ✅ PSS/E RAW / MATPOWER system built via PSY bridge.")

        elseif file_fmt == :rts_gmlc
            # --- B9 path: powerlascopf_from_rts_gmlc! ---
            println("  Building system from RTS-GMLC CSVs at: $case_path_val")
            lascopf_system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
            system_result  = powerlascopf_from_rts_gmlc!(
                lascopf_system, case_path_val, contingencies;
                RND_int          = rnd_intervals,
                lascopf_settings = settings
            )
            println("  ✅ RTS-GMLC system built.")

        elseif file_fmt in (:sahar, :legacy)
            # --- CSV path: existing powerlascopf_*_from_csv! functions ---
            println("  Building system from sahar / legacy CSVs.")
            bus_count_val = get(data, :bus_count, 0)
            ext = (uppercase(format) == "JSON") ? ".json" : ".csv"
            sfx = file_fmt == :sahar ? "_sahar" : ""
            nodes_path    = joinpath(case_path_val, "Nodes$(bus_count_val)$(sfx)$(ext)")
            thermal_path  = joinpath(case_path_val, (file_fmt == :sahar ?
                "ThermalGenerators$(bus_count_val)$(sfx)$(ext)" : "Gen$(bus_count_val)$(ext)"))
            renew_path    = joinpath(case_path_val, "RenewableGenerators$(bus_count_val)$(sfx)$(ext)")
            hydro_path    = joinpath(case_path_val, "HydroGenerators$(bus_count_val)$(sfx)$(ext)")
            storage_path  = joinpath(case_path_val, "Storage$(bus_count_val)$(sfx)$(ext)")
            loads_path    = joinpath(case_path_val, (file_fmt == :sahar ?
                "Loads$(bus_count_val)$(sfx)$(ext)" : "Load$(bus_count_val)$(ext)"))
            branches_path = joinpath(case_path_val, (file_fmt == :sahar ?
                "Trans$(bus_count_val)$(sfx)$(ext)" : "Tran$(bus_count_val)$(ext)"))

            lascopf_system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
            nodes_v = isfile(nodes_path) ?
                powerlascopf_nodes_from_csv!(lascopf_system, nodes_path) :
                PowerLASCOPF.Node{PSY.Bus}[]

            branches_v = isfile(branches_path) ?
                powerlascopf_branches_from_csv!(lascopf_system, nodes_v, branches_path,
                    collect(1:contingencies), contingencies, rnd_intervals) :
                PowerLASCOPF.transmissionLine[]

            thermal_v   = isfile(thermal_path)  ?
                powerlascopf_thermal_generators_from_csv!(lascopf_system, nodes_v, thermal_path, contingencies) : []
            renew_v     = isfile(renew_path)    ?
                powerlascopf_renewable_generators_from_csv!(lascopf_system, nodes_v, renew_path, Dict(), contingencies) : []
            hydro_v     = isfile(hydro_path)    ?
                powerlascopf_hydro_generators_from_csv!(lascopf_system, nodes_v, hydro_path, Dict(), contingencies) : []
            storage_v   = isfile(storage_path)  ?
                powerlascopf_storage_from_csv!(lascopf_system, nodes_v, storage_path, contingencies) : []
            loads_v     = isfile(loads_path)    ?
                powerlascopf_loads_from_csv!(lascopf_system, nodes_v, loads_path) : []

            system_result = (
                nodes=nodes_v, branches=branches_v,
                thermal_generators=thermal_v, renewable_generators=renew_v,
                hydro_generators=hydro_v, storage=storage_v, loads=loads_v
            )
            println("  ✅ Sahar / legacy system built.")
        else
            println("  ⚠️  Unknown format '$file_fmt': skipping PowerLASCOPFSystem construction.")
        end

    catch e
        println("  ⚠️  PowerLASCOPFSystem construction unavailable: $e")
        println("      (Falling back to DataFrame-based simulation stub.)")
    end

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
    # B12: propagate LASCOPF_settings.yml values into solver config
    config = Dict(
        "max_iterations" => iterations,
        "tolerance"      => tolerance,
        "contingencies"  => contingencies,
        "rnd_intervals"  => Int(get(settings, "RNDIntervals",    3)),
        "rsd_intervals"  => Int(get(settings, "RSDIntervals",    3)),
        "solver_choice"  => Int(get(settings, "solverChoice",    1)),
        "rho_tuning"     => Int(get(settings, "setRhoTuning",    3)),
        "dummy_interval" => Bool(Int(get(settings, "dummyIntervalChoice", 1))),
        "verbose"        => verbose,
        "solver"         => "ipopt"
    )

    # Call execute_simulation from run_reader.jl, passing the real system if built (B12)
    try
        simulation_results = execute_simulation(case_name, lascopf_system, system_data, config)
        
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

Run all available test cases: IEEE cases from IEEE_Test_Cases/ plus any
non-IEEE cases in example_cases/ that contain a LASCOPF_settings.yml file.

Example:
  results = run_all_cases()
"""
function run_all_cases(; kwargs...)
    examples_dir = joinpath(PROJECT_ROOT, "example_cases")
    ieee_dir     = joinpath(examples_dir, "IEEE_Test_Cases")

    cases = String[]

    # Discover IEEE cases (IEEE_N_bus folders)
    if isdir(ieee_dir)
        for folder in readdir(ieee_dir)
            m = match(r"IEEE_(\d+)_bus", folder)
            if m !== nothing && isdir(joinpath(ieee_dir, folder))
                push!(cases, "$(parse(Int, m.captures[1]))bus")
            end
        end
    end

    # Discover non-IEEE cases: top-level example_cases/ folders that carry
    # LASCOPF_settings.yml and are not the IEEE_Test_Cases tree itself.
    if isdir(examples_dir)
        skip = Set(["IEEE_Test_Cases"])
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) &&
               !(entry in skip) &&
               isfile(joinpath(candidate, "LASCOPF_settings.yml"))
                push!(cases, entry)   # use folder name as case name
            end
        end
    end

    if isempty(cases)
        println("⚠️  No cases found under: $examples_dir")
        return Dict{String, SimulationResults}()
    end

    println("\n📁 Found $(length(cases)) cases: $(join(cases, ", "))")
    return run_all_cases(cases; kwargs...)
end

# ============================================================================
# STEP 9: AVAILABLE CASES DISCOVERY
# ============================================================================

"""
    list_available_cases() -> Vector{String}

List all available test cases: IEEE cases (from IEEE_Test_Cases/) and non-IEEE
cases (top-level example_cases/ folders that contain LASCOPF_settings.yml).
Shows format type (sahar, legacy, psse_raw, matpower, rts_gmlc) for each case.
"""
function list_available_cases()
    examples_dir = joinpath(PROJECT_ROOT, "example_cases")
    ieee_dir     = joinpath(examples_dir, "IEEE_Test_Cases")

    # Collect (display_name, case_path, bus_count) for all discoverable cases
    case_entries = []   # (display_name::String, case_path::String, bus_count::Int)

    # IEEE cases
    if isdir(ieee_dir)
        for entry in readdir(ieee_dir)
            path = joinpath(ieee_dir, entry)
            if isdir(path) && startswith(entry, "IEEE_")
                bc = try parse_case_name(entry) catch; 0 end
                push!(case_entries, (entry, path, bc))
            end
        end
    end

    # Non-IEEE cases (folders with LASCOPF_settings.yml)
    if isdir(examples_dir)
        skip = Set(["IEEE_Test_Cases"])
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) &&
               !(entry in skip) &&
               isfile(joinpath(candidate, "LASCOPF_settings.yml"))
                bc = try parse_case_name(entry) catch; 0 end
                push!(case_entries, (entry, candidate, bc))
            end
        end
    end

    # Sort: IEEE cases (bc > 0) first by bus count, then non-numeric cases alphabetically
    sort!(case_entries, by = x -> (x[3] == 0 ? 1 : 0, x[3], x[1]))

    println("\n📁 Available PowerLASCOPF Cases:")
    println("-" ^ 65)
    println("  Case Name                    Format        Status")
    println("-" ^ 65)

    format_counts = Dict{Symbol, Int}()

    for (name, path, bc) in case_entries
        fmt = try detect_file_format(path, bc; silent=true) catch; :unknown end
        get!(format_counts, fmt, 0)
        format_counts[fmt] += 1

        status = if fmt == :sahar;     "✅ Sahar"
                 elseif fmt == :legacy;    "⚠️  Legacy"
                 elseif fmt == :psse_raw;  "🔷 PSS/E RAW"
                 elseif fmt == :matpower;  "🔷 MATPOWER"
                 elseif fmt == :rts_gmlc;  "🔷 RTS-GMLC"
                 else                      "❓ Unknown" end

        @printf("  %-28s %-12s  %s\n", name, fmt, status)
    end

    println("-" ^ 65)
    for (fmt, cnt) in sort(collect(format_counts), by=x->string(x[1]))
        println("  $fmt: $cnt")
    end
    println("-" ^ 65)

    return [e[1] for e in case_entries]
end

# ============================================================================
# STEP 10: INTERACTIVE MODE
# ============================================================================

"""
    get_available_case_names() -> Vector{String}

Get list of available case names (just the short names like "5bus", "30bus").
"""
function get_available_case_names()
    examples_dir = joinpath(PROJECT_ROOT, "example_cases")
    ieee_dir     = joinpath(examples_dir, "IEEE_Test_Cases")

    case_names = String[]

    # IEEE cases → short numeric names ("5bus", "30bus", ...)
    if isdir(ieee_dir)
        for entry in readdir(ieee_dir)
            path = joinpath(ieee_dir, entry)
            if isdir(path) && startswith(entry, "IEEE_")
                bc = try parse_case_name(entry) catch; continue end
                push!(case_names, "$(bc)bus")
            end
        end
    end

    # Non-IEEE cases → use folder name directly ("RTS_GMLC", "ACTIVSg2000", ...)
    if isdir(examples_dir)
        skip = Set(["IEEE_Test_Cases"])
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) &&
               !(entry in skip) &&
               isfile(joinpath(candidate, "LASCOPF_settings.yml"))
                push!(case_names, entry)
            end
        end
    end

    # Sort: numeric-named cases first (by bus count), then alphabetically
    sort!(case_names, by = x -> begin
        bc = try parse_case_name(x) catch; 0 end
        (bc == 0 ? 1 : 0, bc, x)
    end)

    return case_names
end

"""
    interactive_mode()

Run PowerLASCOPF in interactive mode where user can select from all available
cases (IEEE sahar/legacy, RTS-GMLC, PSS/E RAW, MATPOWER).
"""
function interactive_mode()
    println("\n" * "=" ^ 70)
    println("🚀 POWERLASCOPF - INTERACTIVE MODE")
    println("=" ^ 70)

    examples_dir = joinpath(PROJECT_ROOT, "example_cases")
    ieee_dir     = joinpath(examples_dir, "IEEE_Test_Cases")

    # Collect ALL cases: (display_name, run_name, bus_count, case_path, file_format)
    # run_name is the name to pass to run_case(): "5bus", "RTS_GMLC", etc.
    case_info = []

    # IEEE cases → short numeric run names ("5bus", "30bus", …)
    if isdir(ieee_dir)
        for entry in readdir(ieee_dir)
            path = joinpath(ieee_dir, entry)
            if isdir(path) && startswith(entry, "IEEE_")
                bc  = try parse_case_name(entry) catch; continue end
                fmt = try detect_file_format(path, bc; silent=true) catch; :unknown end
                push!(case_info, (entry, "$(bc)bus", bc, path, fmt))
            end
        end
    end

    # Non-IEEE cases → folder name is both display name and run name
    if isdir(examples_dir)
        skip = Set(["IEEE_Test_Cases"])
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) && !(entry in skip) &&
               isfile(joinpath(candidate, "LASCOPF_settings.yml"))
                bc  = try parse_case_name(entry) catch; 0 end
                fmt = try detect_file_format(candidate, bc; silent=true) catch; :unknown end
                push!(case_info, (entry, entry, bc, candidate, fmt))
            end
        end
    end

    # Sort: IEEE cases first (by bus count), then non-IEEE alphabetically
    sort!(case_info, by = x -> (x[3] == 0 ? 1 : 0, x[3], x[1]))

    if isempty(case_info)
        println("❌ No test cases found in: $examples_dir")
        println("   Add cases per example_cases/RUNNING_CASES.md")
        return nothing
    end

    # ── Display table ──────────────────────────────────────────────────────
    println("\n📁 AVAILABLE TEST CASES:")
    println("-" ^ 75)
    println("  #   Folder / Display Name       Run Name         Buses    Status")
    println("-" ^ 75)

    for (i, (display, run, bc, path, fmt)) in enumerate(case_info)
        status = if fmt == :sahar;    "✅ Sahar"
                 elseif fmt == :legacy;   "⚠️  Legacy"
                 elseif fmt == :psse_raw; "🔷 PSS/E RAW"
                 elseif fmt == :matpower; "🔷 MATPOWER"
                 elseif fmt == :rts_gmlc; "🔷 RTS-GMLC"
                 else                     "❓ Unknown" end
        buses_str = bc > 0 ? string(bc) : "—"
        @printf("  %-3d %-28s %-16s %-8s %s\n", i, display, run, buses_str, status)
    end

    println("-" ^ 75)
    println("\n📌 OPTIONS:")
    println("   • Enter a number (1-$(length(case_info))) to select a case")
    println("   • Enter a run name directly  (e.g., '30bus', 'RTS_GMLC', 'ACTIVSg2000')")
    println("   • Enter 'all'  to run all discovered cases")
    println("   • Enter 'list' for the detailed case listing")
    println("   • Enter 'add'  to see how to add a new case")
    println("   • Enter 'q' or 'quit' to exit")
    println("-" ^ 75)

    _show_compact_menu(case_info) = begin
        println("\n" * "-" ^ 75)
        println("📁 AVAILABLE CASES:")
        for (i, (display, run, bc, path, fmt)) in enumerate(case_info)
            icon = fmt == :sahar ? "✅" : (fmt == :legacy ? "⚠️" :
                   fmt in (:psse_raw, :matpower, :rts_gmlc) ? "🔷" : "❓")
            @printf("  %d. %-28s %-16s %s\n", i, display, run, icon)
        end
        println("-" ^ 75)
    end

    while true
        print("\n🔹 Enter your choice: ")
        input = strip(readline())

        isempty(input) && continue

        lower_input = lowercase(input)

        # ── quit ──────────────────────────────────────────────────────────
        if lower_input in ["q", "quit", "exit"]
            println("\n👋 Goodbye!")
            return nothing
        end

        # ── list ──────────────────────────────────────────────────────────
        if lower_input == "list"
            list_available_cases()
            continue
        end

        # ── add ───────────────────────────────────────────────────────────
        if lower_input == "add"
            println("\n" * "=" ^ 70)
            println("📖 ADDING A NEW TEST CASE")
            println("=" ^ 70)
            println("\nOption A — IEEE Sahar CSV (e.g., IEEE 24-bus):")
            println("  1. Create  example_cases/IEEE_Test_Cases/IEEE_24_bus/")
            println("  2. Add:    Nodes24_sahar.csv  ThermalGenerators24_sahar.csv")
            println("             Trans24_sahar.csv  Loads24_sahar.csv")
            println("  3. Run:    julia run_reader_generic.jl case=24bus")
            println("\nOption B — PSS/E RAW or MATPOWER:")
            println("  1. Create  example_cases/MyCaseName/")
            println("  2. Add:    MyCaseName.RAW  (or .m)  +  LASCOPF_settings.yml")
            println("  3. Run:    julia run_reader_generic.jl case=MyCaseName")
            println("\nOption C — RTS-GMLC CSV:")
            println("  1. Create  example_cases/MyCaseName/")
            println("  2. Add:    bus.csv  gen.csv  branch.csv  +  LASCOPF_settings.yml")
            println("  3. Run:    julia run_reader_generic.jl case=MyCaseName")
            println("\n📄 Full documentation: example_cases/RUNNING_CASES.md")
            println("=" ^ 70)
            continue
        end

        # ── all ───────────────────────────────────────────────────────────
        if lower_input == "all"
            println("\n🔄 Running ALL available cases...")
            return run_all_cases()
        end

        # ── select by number or name ───────────────────────────────────────
        selected_run = nothing

        if all(isdigit, input)
            idx = parse(Int, input)
            if 1 <= idx <= length(case_info)
                selected_run = case_info[idx][2]   # run_name
            else
                println("❌ Invalid number. Please enter 1-$(length(case_info))")
                continue
            end
        else
            # Match against run_name or display_name (case-insensitive)
            for (display, run, bc, path, fmt) in case_info
                if lowercase(input) == lowercase(run) || lowercase(input) == lowercase(display)
                    selected_run = run
                    break
                end
            end
            if selected_run === nothing
                println("❌ Case not found: '$input'")
                println("   Available run names: $(join([c[2] for c in case_info], ", "))")
                continue
            end
        end

        if selected_run !== nothing
            println("\n✅ Selected: $selected_run")

            print("🔹 Max iterations [10]: ")
            iter_input = strip(readline())
            iterations = isempty(iter_input) ? 10 : parse(Int, iter_input)

            print("🔹 Verbose output? (y/n) [n]: ")
            verbose_input = lowercase(strip(readline()))
            verbose = verbose_input in ["y", "yes", "true", "1"]

            println("\n" * "=" ^ 70)

            result = run_case(selected_run; iterations=iterations, verbose=verbose)

            print("\n🔹 Run another case? (y/n) [y]: ")
            again_input = lowercase(strip(readline()))
            if again_input in ["n", "no"]
                println("\n👋 Goodbye!")
                return result
            end

            _show_compact_menu(case_info)
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
        println("  output=<file> Output filename (default: <case>_lascopf_results.json)")
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

