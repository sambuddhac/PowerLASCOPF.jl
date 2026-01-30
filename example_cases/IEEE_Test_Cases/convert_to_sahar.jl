#!/usr/bin/env julia
"""
Convert legacy format IEEE test case files to Sahar format

This script converts Gen*.json, Load*.json, and Tran*.json files
to the Sahar format with proper CSV and JSON structures matching
the IEEE_57_bus reference format.

Usage:
    julia convert_to_sahar.jl
"""

# Try to use packages, but work without project environment
try
    using JSON
    using CSV
    using DataFrames
catch e
    println("Installing required packages...")
    import Pkg
    Pkg.add(["JSON", "CSV", "DataFrames"])
    using JSON
    using CSV
    using DataFrames
end

# Configuration for each test case
const TEST_CASES = [
    (
        name = "IEEE_118_bus",
        n_buses = 118,
        base_voltage = 138.0,  # kV - typical for 118-bus system
        gen_file = "Gen118.json",
        load_file = "Load118.json",
        tran_file = "Tran118.json"
    ),
    (
        name = "IEEE_300_bus",
        n_buses = 300,
        base_voltage = 230.0,  # kV - typical for 300-bus system
        gen_file = "Gen300.json",
        load_file = "Load300.json",
        tran_file = "Tran300.json"
    )
]

# Constants
const BASE_POWER = 100.0  # MVA
const VOLTAGE_MIN = 0.95  # pu
const VOLTAGE_MAX = 1.05  # pu
const ANGLE_LIMIT_MIN = -0.7  # radians
const ANGLE_LIMIT_MAX = 0.7   # radians
const POWER_FACTOR = 0.95  # Assume ~0.95 power factor for reactive power
const DEFAULT_FUEL_COST = 1.5
const DEFAULT_FIXED_COST = 20.0
const DEFAULT_PRIME_MOVER = "ST"  # Steam Turbine

"""
Calculate reactive power from active power assuming power factor
"""
function calculate_reactive_power(active_power::Number, pf::Float64=POWER_FACTOR)
    # Q = P * tan(acos(pf))
    # Convert to Float64 to handle both Int and Float inputs
    p = Float64(abs(active_power))
    return p * tan(acos(pf))
end

"""
Convert legacy generator JSON to Sahar thermal generator CSV
"""
function convert_generators_to_sahar(gen_data::Vector, case_name::String, n_buses::Int)
    generators = DataFrame(
        GeneratorName = String[],
        BusNumber = Int[],
        GeneratorType = String[],
        Available = Bool[],
        ActivePower = Float64[],
        ReactivePower = Float64[],
        Rating = Float64[],
        PrimeMover = String[],
        ActivePowerMin = Float64[],
        ActivePowerMax = Float64[],
        ReactivePowerMin = Float64[],
        ReactivePowerMax = Float64[],
        RampUp = Float64[],
        RampDown = Float64[],
        CostCurve_a = Float64[],
        CostCurve_b = Float64[],
        CostCurve_c = Float64[],
        FuelCost = Float64[],
        FixedCost = Float64[],
        BasePower = Float64[]
    )
    
    for gen in gen_data
        bus_num = gen["connNode"]
        pg_max = gen["PgMax"]
        pg_min = gen["PgMin"]
        ramp_max = gen["RgMax"]
        ramp_min = abs(gen["RgMin"])
        
        # Cost curve mapping: c2 -> a, c1 -> b, c0 -> c
        cost_a = gen["c2"]
        cost_b = gen["c1"]
        cost_c = gen["c0"]
        
        # Calculate reactive power limits (assume 0.75 power factor for limits)
        q_max = pg_max * 0.75
        q_min = -q_max
        
        push!(generators, (
            "ThermalGen_Bus$(bus_num)",
            bus_num,
            "ThermalStandard",
            true,
            0.0,  # Initial active power
            0.0,  # Initial reactive power
            pg_max,  # Rating = PgMax
            DEFAULT_PRIME_MOVER,
            pg_min,
            pg_max,
            q_min,
            q_max,
            ramp_max,
            ramp_min,
            cost_a,
            cost_b,
            cost_c,
            DEFAULT_FUEL_COST,
            DEFAULT_FIXED_COST,
            BASE_POWER
        ))
    end
    
    return generators
end

"""
Convert legacy load JSON to Sahar load JSON
"""
function convert_loads_to_sahar(load_data::Vector, case_name::String)
    loads = []
    
    for load in load_data
        bus_num = load["ConnNode"]
        
        # Skip invalid bus numbers (empty strings, etc.)
        if bus_num == "" || bus_num === nothing
            continue
        end
        
        # Convert to integer if it's a string
        if bus_num isa String
            try
                bus_num = parse(Int, bus_num)
            catch
                continue  # Skip if can't parse
            end
        end
        
        # Use Interval-1_Load and convert negative to positive
        active_power = abs(load["Interval-1_Load"])
        reactive_power = calculate_reactive_power(active_power)
        
        push!(loads, Dict(
            "LoadName" => "Load_Bus$(bus_num)",
            "BusNumber" => bus_num,
            "Available" => true,
            "ActivePower" => active_power,
            "ReactivePower" => reactive_power,
            "MaxActivePower" => active_power,
            "MaxReactivePower" => reactive_power,
            "BasePower" => BASE_POWER
        ))
    end
    
    return loads
end

"""
Convert legacy transmission JSON to Sahar transmission CSV
"""
function convert_transmission_to_sahar(tran_data::Vector, case_name::String)
    transmission = DataFrame(
        LineID = String[],
        LineType = String[],
        fromNode = Int[],
        toNode = Int[],
        Resistance = Float64[],
        Reactance = Float64[],
        Susceptance_from = Float64[],
        Susceptance_to = Float64[],
        RateLimit = Float64[],
        AngleLimit_min = Float64[],
        AngleLimit_max = Float64[],
        ContingencyMarked = Int[]
    )
    
    for (idx, line) in enumerate(tran_data)
        from_node = line["fromNode"]
        to_node = line["toNode"]
        
        push!(transmission, (
            "$(from_node)_$(to_node)",
            "AC",
            from_node,
            to_node,
            line["Resistance"],
            line["Reactance"],
            0.0,  # Susceptance_from (not in legacy format)
            0.0,  # Susceptance_to (not in legacy format)
            get(line, "Capacity", 10000.0),  # Use large default if not present
            ANGLE_LIMIT_MIN,
            ANGLE_LIMIT_MAX,
            get(line, "ContingencyMarked", 0)
        ))
    end
    
    return transmission
end

"""
Generate nodes CSV based on generators and loads
"""
function generate_nodes(gen_data::Vector, load_data::Vector, n_buses::Int, base_voltage::Float64)
    nodes = DataFrame(
        BusNumber = Int[],
        BusType = String[],
        VoltageMin = Float64[],
        VoltageMax = Float64[],
        BaseVoltage = Float64[],
        BasePower = Float64[]
    )
    
    # Create sets of generator and load buses
    # Filter out empty or invalid bus numbers
    gen_buses = Set{Int}()
    for gen in gen_data
        bus = gen["connNode"]
        if bus isa Number && bus > 0
            push!(gen_buses, Int(bus))
        end
    end
    
    load_buses = Set{Int}()
    for load in load_data
        bus = load["ConnNode"]
        # Skip empty strings and invalid values
        if bus isa Number && bus > 0
            push!(load_buses, Int(bus))
        elseif bus isa String && bus != ""
            try
                push!(load_buses, parse(Int, bus))
            catch
                # Skip invalid string values
            end
        end
    end
    
    # Determine all buses from connections
    all_buses = sort(collect(union(gen_buses, load_buses)))
    
    for bus_num in all_buses
        # Determine bus type
        if bus_num == 1
            bus_type = "REF"  # Bus 1 is typically the reference/slack bus
        elseif bus_num in gen_buses
            bus_type = "PV"   # Generator buses are PV buses
        else
            bus_type = "PQ"   # Load-only buses are PQ buses
        end
        
        push!(nodes, (
            bus_num,
            bus_type,
            VOLTAGE_MIN,
            VOLTAGE_MAX,
            base_voltage,
            BASE_POWER
        ))
    end
    
    return nodes
end

"""
Process a single test case
"""
function process_test_case(test_case)
    println("\n" * "="^70)
    println("Processing $(test_case.name)...")
    println("="^70)
    
    # Set up paths
    case_dir = joinpath(@__DIR__, test_case.name)
    gen_path = joinpath(case_dir, test_case.gen_file)
    load_path = joinpath(case_dir, test_case.load_file)
    tran_path = joinpath(case_dir, test_case.tran_file)
    
    # Check if files exist
    if !isfile(gen_path)
        println("ERROR: Generator file not found: $gen_path")
        return false
    end
    if !isfile(load_path)
        println("ERROR: Load file not found: $load_path")
        return false
    end
    if !isfile(tran_path)
        println("ERROR: Transmission file not found: $tran_path")
        return false
    end
    
    # Read legacy format files
    println("\n1. Reading legacy format files...")
    gen_data_raw = JSON.parsefile(gen_path)
    load_data = JSON.parsefile(load_path)
    tran_data = JSON.parsefile(tran_path)
    
    # Handle different generator data formats
    # Gen118.json is an array, Gen300.json has a "Generators" object
    if (isa(gen_data_raw, Dict) || isa(gen_data_raw, JSON.Object)) && haskey(gen_data_raw, "Generators")
        # Convert dict of generators to array
        gen_obj = gen_data_raw["Generators"]
        gen_data = [gen_obj[key] for key in keys(gen_obj)]
    elseif isa(gen_data_raw, Vector) || isa(gen_data_raw, Array)
        gen_data = gen_data_raw
    else
        error("Unexpected generator data format: $(typeof(gen_data_raw))")
    end
    
    println("   - Generators: $(length(gen_data))")
    println("   - Loads: $(length(load_data))")
    println("   - Transmission lines: $(length(tran_data))")
    
    # Convert data
    println("\n2. Converting to Sahar format...")
    
    # Generators
    println("   - Converting generators...")
    generators = convert_generators_to_sahar(gen_data, test_case.name, test_case.n_buses)
    
    # Loads
    println("   - Converting loads...")
    loads = convert_loads_to_sahar(load_data, test_case.name)
    
    # Transmission
    println("   - Converting transmission lines...")
    transmission = convert_transmission_to_sahar(tran_data, test_case.name)
    
    # Nodes
    println("   - Generating nodes...")
    nodes = generate_nodes(gen_data, load_data, test_case.n_buses, test_case.base_voltage)
    
    # Write output files
    println("\n3. Writing Sahar format files...")
    
    n = test_case.n_buses
    
    # Thermal Generators CSV
    gen_csv_path = joinpath(case_dir, "ThermalGenerators$(n)_sahar.csv")
    CSV.write(gen_csv_path, generators)
    println("   ✓ $gen_csv_path")
    
    # Loads JSON
    loads_json_path = joinpath(case_dir, "Loads$(n)_sahar.json")
    open(loads_json_path, "w") do io
        JSON.print(io, loads, 2)
    end
    println("   ✓ $loads_json_path")
    
    # Transmission CSV
    trans_csv_path = joinpath(case_dir, "Trans$(n)_sahar.csv")
    CSV.write(trans_csv_path, transmission)
    println("   ✓ $trans_csv_path")
    
    # Nodes CSV
    nodes_csv_path = joinpath(case_dir, "Nodes$(n)_sahar.csv")
    CSV.write(nodes_csv_path, nodes)
    println("   ✓ $nodes_csv_path")
    
    println("\n✓ Successfully processed $(test_case.name)")
    println("   Generated $(nrow(generators)) generators")
    println("   Generated $(length(loads)) loads")
    println("   Generated $(nrow(transmission)) transmission lines")
    println("   Generated $(nrow(nodes)) nodes")
    
    return true
end

"""
Main execution
"""
function main()
    println("╔════════════════════════════════════════════════════════════════════╗")
    println("║  Legacy to Sahar Format Converter for IEEE Test Cases             ║")
    println("╚════════════════════════════════════════════════════════════════════╝")
    
    success_count = 0
    total_count = length(TEST_CASES)
    
    for test_case in TEST_CASES
        try
            if process_test_case(test_case)
                success_count += 1
            end
        catch e
            println("\n✗ ERROR processing $(test_case.name):")
            println("  $e")
            showerror(stdout, e, catch_backtrace())
            println()
        end
    end
    
    println("\n" * "="^70)
    println("SUMMARY: Successfully processed $success_count/$total_count test cases")
    println("="^70)
    
    if success_count == total_count
        println("\n✓ All test cases converted successfully!")
        return 0
    else
        println("\n⚠ Some test cases failed to convert")
        return 1
    end
end

# Run the script
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
