"""
Generic Data Reader for PowerLASCOPF Systems
=============================================

PURPOSE:
  Reads power system data from CSV/JSON files for ANY IEEE test case.
  Automatically detects file naming conventions and adapts accordingly.

STANDARD DATA FORMAT (SAHAR FORMAT):
  All new test cases MUST use the Sahar format. See documentation:
  example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md

REQUIRED FILES (Sahar Format):
  - Nodes<N>_sahar.csv             : Bus/node definitions
  - ThermalGenerators<N>_sahar.csv : Thermal generator data  
  - Trans<N>_sahar.csv             : Transmission line data
  - Loads<N>_sahar.csv             : Load data
  
OPTIONAL FILES:
  - RenewableGenerators<N>_sahar.csv : Solar/wind generators
  - HydroGenerators<N>_sahar.csv     : Hydro generators
  - Storage<N>_sahar.csv             : Battery storage

FILE LOCATION:
  Place all files in: example_cases/IEEE_Test_Cases/IEEE_<N>_bus/

LEGACY FORMAT (Deprecated):
  Some older cases (118-bus, 300-bus) use legacy format (Gen<N>.csv, Load<N>.csv).
  These are supported for backward compatibility but new cases should use Sahar format.

USAGE:
  include("data_reader_generic.jl")
  system_data = load_case_data("IEEE_5_bus", "CSV")
  system_data = load_case_data("30bus", "CSV")

For adding new cases, see: example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md
"""

using CSV
using JSON3
using DataFrames
using Dates
using Random
using Printf

Random.seed!(123)

# Note: PowerSystems loading is optional - the data reader works without it
# Users can load PowerSystems in their own scripts if needed

# ============================================================================
# SECTION 1: LOGGING UTILITIES
# ============================================================================

"""Simple logging functions for console output"""
log_info(msg::String) = println("ℹ️  INFO: $msg")
log_warn(msg::String) = println("⚠️  WARN: $msg")
log_error(msg::String) = println("❌ ERROR: $msg")
log_success(msg::String) = println("✅ SUCCESS: $msg")

# ============================================================================
# SECTION 2: CASE DETECTION AND PATH RESOLUTION
# ============================================================================

"""
    parse_case_name(case_name::String) -> (bus_count::Int, case_path::String)

Extract bus count from case name and determine the full path.

Examples:
  "5bus" -> 5
  "IEEE_30_bus" -> 30
  "300" -> 300
"""
function parse_case_name(case_name::AbstractString)
    # Try to extract number from case name
    m = match(r"(\d+)", String(case_name))
    if m === nothing
        error("Could not determine bus count from case name: $case_name")
    end
    return parse(Int, m.captures[1])
end

"""
    get_case_path(case_name::String, base_path::String="") -> String

Determine the full path to the case data folder.
"""
function get_case_path(case_name::String, base_path::String="")
    # If base_path provided, use it directly
    if !isempty(base_path) && isdir(base_path)
        return base_path
    end
    
    # Get repository root (go up from example_cases folder)
    repo_root = abspath(joinpath(@__DIR__, ".."))
    
    bus_count = parse_case_name(case_name)
    
    # Try standard IEEE test case paths
    standard_paths = [
        joinpath(repo_root, "example_cases", "IEEE_Test_Cases", "IEEE_$(bus_count)_bus"),
        joinpath(repo_root, "example_cases", "IEEE_Test_Cases", case_name),
        joinpath(repo_root, "example_cases", case_name),
    ]
    
    for path in standard_paths
        if isdir(path)
            return path
        end
    end
    
    error("Could not find data folder for case: $case_name\nTried: $(join(standard_paths, "\n  "))")
end

"""
    detect_file_format(case_path::String, bus_count::Int; silent::Bool=false) -> Symbol

Detect whether the case uses :sahar format (standard) or :legacy format (deprecated).

Note: New cases MUST use Sahar format. Legacy format is only for backward compatibility.
"""
function detect_file_format(case_path::String, bus_count::Int; silent::Bool=false)
    # Check for sahar-format files (STANDARD)
    sahar_file = joinpath(case_path, "ThermalGenerators$(bus_count)_sahar.csv")
    if isfile(sahar_file)
        return :sahar
    end
    
    # Check for nodes file (might only have nodes)
    nodes_file = joinpath(case_path, "Nodes$(bus_count)_sahar.csv")
    if isfile(nodes_file)
        return :sahar
    end
    
    # Check for legacy format (Gen, Load, Tran) - DEPRECATED
    legacy_file = joinpath(case_path, "Gen$(bus_count).csv")
    if isfile(legacy_file)
        if !silent
            log_warn("Legacy format detected. For new cases, please use Sahar format.")
            log_warn("See: example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md")
        end
        return :legacy
    end
    
    error("Could not detect file format in: $case_path\n" *
          "Please ensure data files are in Sahar format (*_sahar.csv).\n" *
          "See: example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md")
end

# ============================================================================
# SECTION 3: FILE PATH BUILDERS
# ============================================================================

"""
    get_file_path(case_path::String, bus_count::Int, component::Symbol, 
                  file_format::Symbol, data_format::String) -> String

Build the file path for a specific component type.

Components: :thermal, :renewable, :hydro, :storage, :loads, :nodes, :branches, :timeseries
"""
function get_file_path(case_path::String, bus_count::Int, component::Symbol, 
                       file_format::Symbol, data_format::String="CSV")
    
    ext = uppercase(data_format) == "JSON" ? ".json" : ".csv"
    
    if file_format == :sahar
        # Modern sahar naming convention
        filename = if component == :thermal
            "ThermalGenerators$(bus_count)_sahar$ext"
        elseif component == :renewable
            "RenewableGenerators$(bus_count)_sahar$ext"
        elseif component == :hydro
            "HydroGenerators$(bus_count)_sahar$ext"
        elseif component == :storage
            "Storage$(bus_count)_sahar$ext"
        elseif component == :loads
            "Loads$(bus_count)_sahar$ext"
        elseif component == :nodes
            "Nodes$(bus_count)_sahar$ext"
        elseif component == :branches
            "Trans$(bus_count)_sahar$ext"
        elseif component == :timeseries
            "TimeSeries_DA_sahar$ext"
        else
            error("Unknown component: $component")
        end
    else
        # Legacy naming convention (Gen, Load, Tran)
        filename = if component == :thermal
            "Gen$(bus_count)$ext"
        elseif component == :loads
            "Load$(bus_count)$ext"
        elseif component == :branches
            "Tran$(bus_count)$ext"
        else
            # Legacy format doesn't have these - return empty
            return ""
        end
    end
    
    return joinpath(case_path, filename)
end

# ============================================================================
# SECTION 4: GENERIC CSV/JSON READERS
# ============================================================================

"""
    read_csv_file(filepath::String) -> DataFrame

Read a CSV file, handling both comma and tab delimiters.
"""
function read_csv_file(filepath::String)
    if !isfile(filepath)
        log_warn("File not found: $filepath")
        return DataFrame()
    end
    
    # Try to detect delimiter
    first_line = readline(filepath)
    delimiter = occursin('\t', first_line) ? '\t' : ','
    
    return CSV.read(filepath, DataFrame; delim=delimiter)
end

"""
    read_json_file(filepath::String) -> Vector{Dict}

Read a JSON file and return as vector of dictionaries.
"""
function read_json_file(filepath::String)
    if !isfile(filepath)
        log_warn("File not found: $filepath")
        return Dict[]
    end
    
    content = read(filepath, String)
    return JSON3.read(content)
end

# ============================================================================
# SECTION 5: COMPONENT READERS - SAHAR FORMAT
# ============================================================================

"""
    read_nodes_sahar(filepath::String, data_format::String) -> DataFrame

Read nodes data from sahar-format file.
Expected columns: BusNumber, BusName, BusType, Angle, Voltage, VoltageMin, VoltageMax, BaseVoltage
"""
function read_nodes_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading nodes from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    # Ensure required columns exist with defaults
    if !hasproperty(df, :BusName)
        df.BusName = ["Bus$(i)" for i in df.BusNumber]
    end
    if !hasproperty(df, :Angle)
        df.Angle = zeros(nrow(df))
    end
    if !hasproperty(df, :Voltage)
        df.Voltage = ones(nrow(df))
    end
    
    log_success("Loaded $(nrow(df)) nodes")
    return df
end

"""
    read_thermal_sahar(filepath::String, data_format::String) -> DataFrame

Read thermal generators from sahar-format file.
"""
function read_thermal_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading thermal generators from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    log_success("Loaded $(nrow(df)) thermal generators")
    return df
end

"""
    read_renewable_sahar(filepath::String, data_format::String) -> DataFrame

Read renewable generators from sahar-format file.
"""
function read_renewable_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading renewable generators from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        log_warn("No renewable generators found")
        return df
    end
    
    log_success("Loaded $(nrow(df)) renewable generators")
    return df
end

"""
    read_hydro_sahar(filepath::String, data_format::String) -> DataFrame

Read hydro generators from sahar-format file.
"""
function read_hydro_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading hydro generators from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        log_warn("No hydro generators found")
        return df
    end
    
    log_success("Loaded $(nrow(df)) hydro generators")
    return df
end

"""
    read_storage_sahar(filepath::String, data_format::String) -> DataFrame

Read storage devices from sahar-format file.
"""
function read_storage_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading storage from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        log_warn("No storage devices found")
        return df
    end
    
    log_success("Loaded $(nrow(df)) storage devices")
    return df
end

"""
    read_loads_sahar(filepath::String, data_format::String) -> DataFrame

Read loads from sahar-format file.
"""
function read_loads_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading loads from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    log_success("Loaded $(nrow(df)) loads")
    return df
end

"""
    read_branches_sahar(filepath::String, data_format::String) -> DataFrame

Read transmission lines/branches from sahar-format file.
"""
function read_branches_sahar(filepath::String, data_format::String="CSV")
    log_info("Reading branches from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    log_success("Loaded $(nrow(df)) branches")
    return df
end

# ============================================================================
# SECTION 6: COMPONENT READERS - LEGACY FORMAT (300-bus style)
# ============================================================================

"""
    read_generators_legacy(filepath::String, data_format::String) -> DataFrame

Read generators from legacy format (Gen300.csv style).
Columns: connNode, c2, c1, c0, PgMax, PgMin, RgMax, RgMin, PgPrev
"""
function read_generators_legacy(filepath::String, data_format::String="CSV")
    log_info("Reading generators (legacy format) from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    # Convert legacy column names to sahar format
    rename_map = Dict(
        :connNode => :BusNumber,
        :c2 => :CostCurve_a,
        :c1 => :CostCurve_b,
        :c0 => :CostCurve_c,
        :PgMax => :ActivePowerMax,
        :PgMin => :ActivePowerMin,
        :RgMax => :RampUp,
        :RgMin => :RampDown,
        :PgPrev => :ActivePower
    )
    
    for (old_name, new_name) in rename_map
        if hasproperty(df, old_name)
            rename!(df, old_name => new_name)
        end
    end
    
    # Add missing columns with defaults
    if !hasproperty(df, :GeneratorName)
        df.GeneratorName = ["Gen_Bus$(row.BusNumber)" for row in eachrow(df)]
    end
    if !hasproperty(df, :GeneratorType)
        df.GeneratorType = fill("ThermalStandard", nrow(df))
    end
    if !hasproperty(df, :Available)
        df.Available = fill(true, nrow(df))
    end
    if !hasproperty(df, :Rating)
        df.Rating = df.ActivePowerMax
    end
    if !hasproperty(df, :ReactivePowerMax)
        df.ReactivePowerMax = df.ActivePowerMax .* 0.75
    end
    if !hasproperty(df, :ReactivePowerMin)
        df.ReactivePowerMin = -df.ActivePowerMax .* 0.75
    end
    if !hasproperty(df, :BasePower)
        df.BasePower = fill(100.0, nrow(df))
    end
    
    log_success("Loaded $(nrow(df)) generators (legacy format)")
    return df
end

"""
    read_loads_legacy(filepath::String, data_format::String) -> DataFrame

Read loads from legacy format (Load300.csv style).
Columns: ConnNode, Interval-1_Load, Interval-2_Load
"""
function read_loads_legacy(filepath::String, data_format::String="CSV")
    log_info("Reading loads (legacy format) from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    # Filter out summary rows (empty ConnNode)
    if hasproperty(df, :ConnNode)
        df = filter(row -> !ismissing(row.ConnNode) && row.ConnNode != "", df)
    end
    
    # Convert to numeric if needed
    if hasproperty(df, :ConnNode)
        df.ConnNode = [ismissing(x) ? 0 : (x isa Number ? Int(x) : parse(Int, string(x))) for x in df.ConnNode]
        df = filter(row -> row.ConnNode > 0, df)
    end
    
    # Convert legacy column names
    rename_map = Dict(
        :ConnNode => :BusNumber,
        Symbol("Interval-1_Load") => :ActivePower_Interval1,
        Symbol("Interval-2_Load") => :ActivePower_Interval2
    )
    
    for (old_name, new_name) in rename_map
        if hasproperty(df, old_name)
            rename!(df, old_name => new_name)
        end
    end
    
    # Convert negative loads to positive (convention)
    if hasproperty(df, :ActivePower_Interval1)
        df.ActivePower = abs.(df.ActivePower_Interval1)
    end
    
    # Add missing columns
    if !hasproperty(df, :LoadName)
        df.LoadName = ["Load_Bus$(row.BusNumber)" for row in eachrow(df)]
    end
    if !hasproperty(df, :Available)
        df.Available = fill(true, nrow(df))
    end
    if !hasproperty(df, :ReactivePower)
        df.ReactivePower = df.ActivePower .* 0.3287
    end
    if !hasproperty(df, :BasePower)
        df.BasePower = fill(100.0, nrow(df))
    end
    
    log_success("Loaded $(nrow(df)) loads (legacy format)")
    return df
end

"""
    read_branches_legacy(filepath::String, data_format::String) -> DataFrame

Read branches from legacy format (Tran300.csv style).
Columns: fromNode, toNode, Resistance, Reactance, ContingencyMarked, Capacity
"""
function read_branches_legacy(filepath::String, data_format::String="CSV")
    log_info("Reading branches (legacy format) from: $filepath")
    
    if uppercase(data_format) == "CSV"
        df = read_csv_file(filepath)
    else
        data = read_json_file(filepath)
        df = DataFrame(data)
    end
    
    if isempty(df)
        return df
    end
    
    # Add LineID if not present
    if !hasproperty(df, :LineID)
        df.LineID = ["$(row.fromNode)_$(row.toNode)" for row in eachrow(df)]
    end
    
    # Add LineType if not present (all AC for legacy)
    if !hasproperty(df, :LineType)
        df.LineType = fill("AC", nrow(df))
    end
    
    # Convert Capacity to RateLimit
    if hasproperty(df, :Capacity) && !hasproperty(df, :RateLimit)
        df.RateLimit = df.Capacity
    end
    
    # Add angle limits if not present
    if !hasproperty(df, :AngleLimit_min)
        df.AngleLimit_min = fill(-0.7, nrow(df))
    end
    if !hasproperty(df, :AngleLimit_max)
        df.AngleLimit_max = fill(0.7, nrow(df))
    end
    
    # Add susceptance if not present
    if !hasproperty(df, :Susceptance_from)
        df.Susceptance_from = fill(0.0, nrow(df))
    end
    if !hasproperty(df, :Susceptance_to)
        df.Susceptance_to = fill(0.0, nrow(df))
    end
    
    log_success("Loaded $(nrow(df)) branches (legacy format)")
    return df
end

"""
    generate_nodes_from_components(generators_df::DataFrame, loads_df::DataFrame, 
                                    branches_df::DataFrame) -> DataFrame

Generate nodes data when no explicit nodes file exists (legacy format).
"""
function generate_nodes_from_components(generators_df::DataFrame, loads_df::DataFrame, 
                                         branches_df::DataFrame)
    log_info("Generating nodes from component data...")
    
    # Collect all unique bus numbers
    bus_numbers = Set{Int}()
    
    if !isempty(generators_df) && hasproperty(generators_df, :BusNumber)
        union!(bus_numbers, generators_df.BusNumber)
    end
    
    if !isempty(loads_df) && hasproperty(loads_df, :BusNumber)
        union!(bus_numbers, loads_df.BusNumber)
    end
    
    if !isempty(branches_df)
        if hasproperty(branches_df, :fromNode)
            union!(bus_numbers, branches_df.fromNode)
        end
        if hasproperty(branches_df, :toNode)
            union!(bus_numbers, branches_df.toNode)
        end
    end
    
    bus_numbers = sort(collect(bus_numbers))
    
    # Determine which buses have generators (PV buses)
    gen_buses = Set{Int}()
    if !isempty(generators_df) && hasproperty(generators_df, :BusNumber)
        gen_buses = Set(generators_df.BusNumber)
    end
    
    # Create nodes dataframe
    n = length(bus_numbers)
    df = DataFrame(
        BusNumber = bus_numbers,
        BusName = ["Bus$(i)" for i in bus_numbers],
        BusType = [i == bus_numbers[1] ? "REF" : (i in gen_buses ? "PV" : "PQ") for i in bus_numbers],
        Angle = zeros(n),
        Voltage = ones(n),
        VoltageMin = fill(0.95, n),
        VoltageMax = fill(1.05, n),
        BaseVoltage = fill(132.0, n),
        BasePower = fill(100.0, n)
    )
    
    log_success("Generated $(nrow(df)) nodes from components")
    return df
end

# ============================================================================
# SECTION 7: MAIN DATA LOADING FUNCTION
# ============================================================================

"""
    load_case_data(case_name::String, data_format::String="CSV"; 
                   base_path::String="") -> Dict{Symbol, DataFrame}

Main entry point: Load all data for a given test case.

Arguments:
  - case_name: Name of the case (e.g., "5bus", "IEEE_30_bus", "300")
  - data_format: "CSV" or "JSON"
  - base_path: Optional explicit path to data folder

Returns:
  Dictionary with keys: :nodes, :thermal, :renewable, :hydro, :storage, :loads, :branches
  Each value is a DataFrame with the component data.

Example:
  data = load_case_data("IEEE_5_bus", "CSV")
  nodes_df = data[:nodes]
  generators_df = data[:thermal]
"""
function load_case_data(case_name::String, data_format::String="CSV"; 
                        base_path::String="")
    
    println("=" ^ 70)
    println("📂 LOADING CASE DATA: $case_name")
    println("=" ^ 70)
    
    # Determine case path and bus count
    case_path = get_case_path(case_name, base_path)
    bus_count = parse_case_name(case_name)
    
    log_info("Case path: $case_path")
    log_info("Bus count: $bus_count")
    log_info("Data format: $data_format")
    
    # Detect file format (sahar vs legacy)
    file_format = detect_file_format(case_path, bus_count)
    log_info("File format detected: $file_format")
    
    # Initialize result dictionary
    result = Dict{Symbol, DataFrame}()
    
    if file_format == :sahar
        # ====== SAHAR FORMAT ======
        
        # Read nodes
        nodes_path = get_file_path(case_path, bus_count, :nodes, file_format, data_format)
        result[:nodes] = isfile(nodes_path) ? read_nodes_sahar(nodes_path, data_format) : DataFrame()
        
        # Read thermal generators
        thermal_path = get_file_path(case_path, bus_count, :thermal, file_format, data_format)
        result[:thermal] = isfile(thermal_path) ? read_thermal_sahar(thermal_path, data_format) : DataFrame()
        
        # Read renewable generators
        renewable_path = get_file_path(case_path, bus_count, :renewable, file_format, data_format)
        result[:renewable] = isfile(renewable_path) ? read_renewable_sahar(renewable_path, data_format) : DataFrame()
        
        # Read hydro generators
        hydro_path = get_file_path(case_path, bus_count, :hydro, file_format, data_format)
        result[:hydro] = isfile(hydro_path) ? read_hydro_sahar(hydro_path, data_format) : DataFrame()
        
        # Read storage
        storage_path = get_file_path(case_path, bus_count, :storage, file_format, data_format)
        result[:storage] = isfile(storage_path) ? read_storage_sahar(storage_path, data_format) : DataFrame()
        
        # Read loads
        loads_path = get_file_path(case_path, bus_count, :loads, file_format, data_format)
        result[:loads] = isfile(loads_path) ? read_loads_sahar(loads_path, data_format) : DataFrame()
        
        # Read branches
        branches_path = get_file_path(case_path, bus_count, :branches, file_format, data_format)
        result[:branches] = isfile(branches_path) ? read_branches_sahar(branches_path, data_format) : DataFrame()
        
    else
        # ====== LEGACY FORMAT (300-bus style) ======
        
        # Read generators
        gen_path = get_file_path(case_path, bus_count, :thermal, file_format, data_format)
        result[:thermal] = isfile(gen_path) ? read_generators_legacy(gen_path, data_format) : DataFrame()
        
        # Read loads
        load_path = get_file_path(case_path, bus_count, :loads, file_format, data_format)
        result[:loads] = isfile(load_path) ? read_loads_legacy(load_path, data_format) : DataFrame()
        
        # Read branches
        branch_path = get_file_path(case_path, bus_count, :branches, file_format, data_format)
        result[:branches] = isfile(branch_path) ? read_branches_legacy(branch_path, data_format) : DataFrame()
        
        # Generate nodes from components (legacy format doesn't have explicit nodes file)
        result[:nodes] = generate_nodes_from_components(
            result[:thermal], result[:loads], result[:branches]
        )
        
        # No renewable/hydro/storage in legacy format
        result[:renewable] = DataFrame()
        result[:hydro] = DataFrame()
        result[:storage] = DataFrame()
    end
    
    # Print summary
    println("\n" * "-" ^ 70)
    println("📊 DATA LOADING SUMMARY")
    println("-" ^ 70)
    println("  Nodes:      $(nrow(result[:nodes])) buses")
    println("  Thermal:    $(nrow(result[:thermal])) generators")
    println("  Renewable:  $(nrow(result[:renewable])) generators")
    println("  Hydro:      $(nrow(result[:hydro])) generators")
    println("  Storage:    $(nrow(result[:storage])) devices")
    println("  Loads:      $(nrow(result[:loads])) loads")
    println("  Branches:   $(nrow(result[:branches])) lines")
    println("-" ^ 70)
    
    return result
end

# ============================================================================
# SECTION 8: DATA CONVERSION UTILITIES
# ============================================================================

"""
    get_generator_at_bus(data::Dict, bus_number::Int) -> Union{DataFrameRow, Nothing}

Find generator at a specific bus.
"""
function get_generator_at_bus(data::Dict{Symbol, DataFrame}, bus_number::Int)
    thermal = data[:thermal]
    if !isempty(thermal) && hasproperty(thermal, :BusNumber)
        idx = findfirst(thermal.BusNumber .== bus_number)
        if idx !== nothing
            return thermal[idx, :]
        end
    end
    return nothing
end

"""
    get_load_at_bus(data::Dict, bus_number::Int) -> Union{DataFrameRow, Nothing}

Find load at a specific bus.
"""
function get_load_at_bus(data::Dict{Symbol, DataFrame}, bus_number::Int)
    loads = data[:loads]
    if !isempty(loads) && hasproperty(loads, :BusNumber)
        idx = findfirst(loads.BusNumber .== bus_number)
        if idx !== nothing
            return loads[idx, :]
        end
    end
    return nothing
end

"""
    get_branches_from_bus(data::Dict, bus_number::Int) -> DataFrame

Get all branches connected to a specific bus.
"""
function get_branches_from_bus(data::Dict{Symbol, DataFrame}, bus_number::Int)
    branches = data[:branches]
    if isempty(branches)
        return DataFrame()
    end
    
    mask = (branches.fromNode .== bus_number) .| (branches.toNode .== bus_number)
    return branches[mask, :]
end

"""
    get_total_generation_capacity(data::Dict) -> Float64

Calculate total generation capacity.
"""
function get_total_generation_capacity(data::Dict{Symbol, DataFrame})
    total = 0.0
    
    for gen_type in [:thermal, :renewable, :hydro]
        df = data[gen_type]
        if !isempty(df) && hasproperty(df, :ActivePowerMax)
            total += sum(df.ActivePowerMax)
        end
    end
    
    return total
end

"""
    get_total_load(data::Dict) -> Float64

Calculate total load demand.
"""
function get_total_load(data::Dict{Symbol, DataFrame})
    loads = data[:loads]
    if isempty(loads)
        return 0.0
    end
    
    if hasproperty(loads, :ActivePower)
        return sum(loads.ActivePower)
    end
    
    return 0.0
end

# ============================================================================
# SECTION 9: EXPORT FUNCTIONS
# ============================================================================

"""
    export_case_data(data::Dict, output_path::String, data_format::String="CSV")

Export case data to files.
"""
function export_case_data(data::Dict{Symbol, DataFrame}, output_path::String, 
                          data_format::String="CSV")
    
    mkpath(output_path)
    ext = uppercase(data_format) == "JSON" ? ".json" : ".csv"
    
    for (component, df) in data
        if !isempty(df)
            filename = "$(component)$ext"
            filepath = joinpath(output_path, filename)
            
            if uppercase(data_format) == "CSV"
                CSV.write(filepath, df)
            else
                open(filepath, "w") do f
                    JSON3.write(f, df)
                end
            end
            
            log_info("Exported: $filepath")
        end
    end
    
    log_success("Data exported to: $output_path")
end

# ============================================================================
# MODULE INFO
# ============================================================================

log_info("Generic data reader module loaded successfully")
log_info("Usage: data = load_case_data(\"IEEE_5_bus\", \"CSV\")")

