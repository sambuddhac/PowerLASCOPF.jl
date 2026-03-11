"""
Generic Data Reader for PowerLASCOPF Systems — data_reader_generic.jl
======================================================================

PURPOSE:
  Pure data-layer module: discovers case folders, detects file formats,
  reads raw CSVs/JSON into DataFrames, and loads per-case ADMM settings.
  Does NOT require PowerSystems.jl or PowerLASCOPF — safe to include first.

SUPPORTED FORMATS:
  :sahar     — IEEE_Test_Cases Sahar CSV (ThermalGenerators<N>_sahar.csv, …)
  :legacy    — Older IEEE CSV  (Gen<N>.csv, Load<N>.csv, Tran<N>.csv)
  :psse_raw  — PSS/E RAW (*.RAW) — path stored; PSY parsing deferred to data_reader.jl
  :matpower  — MATPOWER  (*.m)   — path stored; PSY parsing deferred to data_reader.jl
  :rts_gmlc  — RTS-GMLC  (bus.csv / gen.csv / branch.csv)

SAHAR FORMAT — required files:
  Nodes<N>_sahar.csv               Bus/node definitions
  ThermalGenerators<N>_sahar.csv   Thermal generator data
  Trans<N>_sahar.csv               Transmission line data
  Loads<N>_sahar.csv               Load data

SAHAR FORMAT — optional files:
  RenewableGenerators<N>_sahar.csv  Solar / wind generators
  HydroGenerators<N>_sahar.csv      Hydro generators
  Storage<N>_sahar.csv              Battery storage
  TimeSeries_DA_sahar.csv           Day-ahead time series

LEGACY FORMAT (backward-compat, IEEE 118/300-bus):
  Gen<N>.csv, Load<N>.csv, Tran<N>.csv

PSS/E RAW / MATPOWER:
  Place the .RAW or .m file in the case folder alongside LASCOPF_settings.yml.
  load_case_data() stores the path in result[:network_file]; the actual
  PSY.System parse happens in powerlascopf_from_psy_system!() (data_reader.jl).

RTS-GMLC:
  bus.csv, gen.csv, branch.csv (optional: storage.csv, reserves.csv).
  Generators are classified by "Unit Type" column.
  System construction is done by powerlascopf_from_rts_gmlc!() (data_reader.jl).

MAIN ENTRY POINT:
  data = load_case_data("14bus", "CSV")          # IEEE 14-bus (sahar)
  data = load_case_data("RTS_GMLC")              # RTS-GMLC
  data = load_case_data("ACTIVSg2000")           # PSS/E RAW

  Returned Dict keys:
    :nodes, :thermal, :renewable, :hydro,
    :storage, :loads, :branches               → DataFrame (empty for PSS/E/MATPOWER)
    :lascopf_settings                         → Dict from LASCOPF_settings.yml
    :network_file                             → path string (PSS/E/MATPOWER only)
    :file_format                              → Symbol (:sahar, :psse_raw, …)
    :case_path                                → absolute path to the case folder
    :bus_count                                → Int bus count parsed from case name

FULL DOCUMENTATION:
  example_cases/RUNNING_CASES.md
  example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md
"""

using CSV
using JSON3
using DataFrames
using Dates
using Random
using Printf
using Logging

Random.seed!(123)

# Note: PowerSystems loading is optional - the data reader works without it
# Users can load PowerSystems in their own scripts if needed

const LOG_FILE = joinpath(@__DIR__, "execution_run.log")
const LOG_IO = open(LOG_FILE, "w")

# ============================================================================
# SECTION 1: LOGGING UTILITIES
# ============================================================================

"""
    log_both(message::String)

WHY: Write to both console (user feedback) and file (permanent record)
WHEN: Every significant operation (reading files, creating objects, errors)
"""
function log_both(message::String)
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    formatted_message = "[$timestamp] $message"
    println(formatted_message)
    println(LOG_IO, formatted_message)
    flush(LOG_IO)  # Ensure immediate write (important if crash occurs)
end

"""Simple logging functions for console output"""
log_info(msg::String) = log_both("ℹ️  INFO: $msg")
log_warn(msg::String) = log_both("⚠️  WARN: $msg")
log_error(msg::String) = log_both("❌ ERROR: $msg")
log_success(msg::String) = log_both("✅ SUCCESS: $msg")

atexit(() -> close(LOG_IO))

log_info("Starting PowerLASCOPF execution script")
log_info("Log file: $LOG_FILE")

import PowerSystems: PrimeMovers, ThermalFuels, Arc

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
const CASE_NAME_REGISTRY = Dict{String, Int}(
    "RTS_GMLC"    => 73,
    "SyntheticUSA" => 70000,
    "ACTIVSg2000"  => 2000,
    "ACTIVSg10k"   => 10000,
    "ACTIVSg70k"   => 70000,
)

function parse_case_name(case_name::AbstractString)
    # Try to extract number from case name
    m = match(r"(\d+)", String(case_name))
    if m === nothing
        if haskey(CASE_NAME_REGISTRY, case_name)
            return CASE_NAME_REGISTRY[case_name]
        end
        return 0  # Unknown non-numeric name — bus count not determinable from name alone
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
    examples_dir = joinpath(repo_root, "example_cases")

    bus_count = parse_case_name(case_name)

    # Priority 1: standard IEEE test case paths (exact)
    standard_paths = [
        joinpath(examples_dir, "IEEE_Test_Cases", "IEEE_$(bus_count)_bus"),
        joinpath(examples_dir, "IEEE_Test_Cases", case_name),
        joinpath(examples_dir, case_name),
    ]

    for path in standard_paths
        if isdir(path)
            return path
        end
    end

    # Priority 2: scan example_cases/ for case-insensitive exact match
    if isdir(examples_dir)
        lower_name = lowercase(case_name)
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) && lowercase(entry) == lower_name
                return candidate
            end
        end

        # Priority 3: scan for partial match, but only accept folders marked with
        # LASCOPF_settings.yml (avoids false positives like "forecasts/", "matpower/")
        for entry in readdir(examples_dir)
            candidate = joinpath(examples_dir, entry)
            if isdir(candidate) &&
               occursin(lower_name, lowercase(entry)) &&
               isfile(joinpath(candidate, "LASCOPF_settings.yml"))
                log_warn("Case '$case_name' matched folder '$entry' via partial name search.")
                return candidate
            end
        end
    end

    error("Could not find data folder for case: $case_name\n" *
          "Tried: $(join(standard_paths, "\n  "))\n" *
          "Also scanned all subdirectories of: $examples_dir")
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

    # Check for PSS/E RAW format: scan for any *.raw or *.RAW file
    # (isfile() does not support glob patterns, so we scan readdir())
    dir_entries = readdir(case_path)
    if any(f -> endswith(lowercase(f), ".raw"), dir_entries)
        return :psse_raw
    end

    # Check for MATPOWER format: any *.m file
    # PSS/E RAW is checked first because ACTIVSg cases carry both formats;
    # the .RAW file is the authoritative network data source there.
    if any(f -> endswith(f, ".m"), dir_entries)
        return :matpower
    end

    # Check for RTS-GMLC CSV format: require gen.csv AND bus.csv together
    # to avoid false positives from folders that happen to have a gen.csv.
    if isfile(joinpath(case_path, "gen.csv")) &&
       isfile(joinpath(case_path, "bus.csv")) &&
       isfile(joinpath(case_path, "branch.csv"))
        return :rts_gmlc
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

For :sahar and :legacy formats, each component has its own file, and the
`component` argument selects which one.

For :psse_raw and :matpower formats, ALL network data lives in a single
monolithic file. The `component` argument is IGNORED — the same file path
is returned regardless. Callers should invoke PSY.System(filepath) once,
then iterate over PSY component collections rather than calling this function
per component type.

For :rts_gmlc format, files are per-data-type but with different names from
Sahar. Importantly, :thermal, :renewable, and :hydro all map to the same
gen.csv (differentiated later by the "Unit Type" column), and :loads maps to
bus.csv (loads are embedded as "MW Load"/"MVAR Load" columns there).

Components: :thermal, :renewable, :hydro, :storage, :loads, :nodes, :branches,
            :timeseries, :reserves
"""
function get_file_path(case_path::String, bus_count::Int, component::Symbol,
                       file_format::Symbol, data_format::String="CSV")

    ext = uppercase(data_format) == "JSON" ? ".json" : ".csv"

    if file_format == :sahar
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
            error("Unknown component for :sahar format: $component")
        end
        return joinpath(case_path, filename)

    elseif file_format == :psse_raw
        # Single monolithic file — component is ignored.
        # Prefer a .RAW file whose name matches the folder name; fall back to first found.
        raw_files = filter(f -> endswith(lowercase(f), ".raw"), readdir(case_path))
        isempty(raw_files) && error("No .RAW file found in: $case_path")
        folder_name = lowercase(basename(case_path))
        preferred = filter(f -> occursin(folder_name, lowercase(f)), raw_files)
        return joinpath(case_path, isempty(preferred) ? first(raw_files) : first(preferred))

    elseif file_format == :matpower
        # Single monolithic file — component is ignored.
        m_files = filter(f -> endswith(f, ".m"), readdir(case_path))
        isempty(m_files) && error("No .m file found in: $case_path")
        folder_name = lowercase(basename(case_path))
        preferred = filter(f -> occursin(folder_name, lowercase(f)), m_files)
        return joinpath(case_path, isempty(preferred) ? first(m_files) : first(preferred))

    elseif file_format == :rts_gmlc
        # All generator types share gen.csv; loads are embedded in bus.csv.
        if component in (:thermal, :renewable, :hydro)
            return joinpath(case_path, "gen.csv")
        elseif component == :storage
            return joinpath(case_path, "storage.csv")
        elseif component in (:nodes, :loads)
            return joinpath(case_path, "bus.csv")
        elseif component == :branches
            return joinpath(case_path, "branch.csv")
        elseif component == :reserves
            return joinpath(case_path, "reserves.csv")
        elseif component == :timeseries
            # Prefer day-ahead pointers; fall back to generic name
            da_file = joinpath(case_path, "timeseries_pointers_da.json")
            return isfile(da_file) ? da_file : joinpath(case_path, "timeseries_pointers.json")
        else
            error("Unknown component for :rts_gmlc format: $component")
        end

    else  # :legacy
        filename = if component == :thermal
            "Gen$(bus_count)$ext"
        elseif component == :loads
            "Load$(bus_count)$ext"
        elseif component == :branches
            "Tran$(bus_count)$ext"
        else
            return ""  # legacy format has no separate file for this component
        end
        return joinpath(case_path, filename)
    end
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
# SECTION 6.5: SETTINGS READER AND FORMAT-SPECIFIC HELPERS
# ============================================================================

"""
    read_lascopf_settings(case_path::String) -> Dict{String, Any}

Read LASCOPF_settings.yml from the case folder and return a Dict of solver
parameters. Falls back to sensible defaults when the file is absent (e.g. for
legacy IEEE cases that pre-date the settings file).

Keys returned: contSolverAccuracy, solverChoice, nextChoice, setRhoTuning,
               dummyIntervalChoice, RNDIntervals, RSDIntervals
"""
function read_lascopf_settings(case_path::String)
    defaults = Dict{String, Any}(
        "contSolverAccuracy"  => 0,
        "solverChoice"        => 1,
        "nextChoice"          => 1,
        "setRhoTuning"        => 3,
        "dummyIntervalChoice" => 1,
        "RNDIntervals"        => 3,
        "RSDIntervals"        => 3,
    )

    settings_file = joinpath(case_path, "LASCOPF_settings.yml")
    if !isfile(settings_file)
        log_info("No LASCOPF_settings.yml in $case_path; using defaults.")
        return defaults
    end

    settings = copy(defaults)
    for line in eachline(settings_file)
        line = strip(line)
        (isempty(line) || startswith(line, "#")) && continue
        # Strip inline comment (e.g.  "RNDIntervals: 3 #Enter the number ...")
        line = strip(first(split(line, " #", limit=2)))
        m = match(r"^(\w+)\s*:\s*(.+)$", line)
        m === nothing && continue
        key  = String(m.captures[1])
        vstr = strip(String(m.captures[2]))
        # Try Int → Float64 → String
        val = try parse(Int, vstr) catch
              try parse(Float64, vstr) catch vstr end end
        settings[key] = val
    end
    log_success("Loaded LASCOPF settings from: $settings_file")
    return settings
end

# ---------------------------------------------------------------------------
# RTS-GMLC / 5-bus-hydro CSV format helpers
#
# These cases store all generators in a single gen.csv distinguished by
# "Unit Type".  Loads are embedded in bus.csv.
# ---------------------------------------------------------------------------

# Unit type strings used in gen.csv (RTS-GMLC and 5-bus-hydro formats)
const _RTSGMLC_THERMAL_UNIT_TYPES  = Set(["CT", "CC", "ST", "STEAM", "DR",
                                           "GAS", "COAL", "OIL", "NUCLEAR"])
const _RTSGMLC_RENEWABLE_UNIT_TYPES = Set(["WT", "PV", "RTPV", "CSP"])
const _RTSGMLC_HYDRO_UNIT_TYPES    = Set(["HY", "ROR"])
const _RTSGMLC_STORAGE_UNIT_TYPES  = Set(["PS"])

"""Read and remap bus.csv → nodes DataFrame (RTS-GMLC format)."""
function read_rts_nodes(case_path::String)
    df = read_csv_file(joinpath(case_path, "bus.csv"))
    isempty(df) && return df

    n = nrow(df)
    out = DataFrame(
        BusNumber   = df[!, Symbol("Bus ID")],
        BusName     = String.(df[!, Symbol("Bus Name")]),
        BusType     = String.(df[!, Symbol("Bus Type")]),
        Voltage     = Float64.(df[!, Symbol("V Mag")]),
        Angle       = Float64.(df[!, Symbol("V Angle")]),
        BaseVoltage = Float64.(df[!, Symbol("BaseKV")]),
        VoltageMin  = fill(0.94, n),
        VoltageMax  = fill(1.06, n),
        BasePower   = fill(100.0, n),
    )
    log_success("Loaded $(nrow(out)) nodes from RTS-GMLC bus.csv")
    return out
end

"""Read and remap bus.csv → loads DataFrame (loads embedded in bus data)."""
function read_rts_loads(case_path::String)
    df = read_csv_file(joinpath(case_path, "bus.csv"))
    isempty(df) && return DataFrame()

    mw_col = Symbol("MW Load")
    mask = coalesce.(df[!, mw_col], 0.0) .> 0
    sub  = df[mask, :]
    n    = nrow(sub)
    n == 0 && return DataFrame()

    out = DataFrame(
        BusNumber     = sub[!, Symbol("Bus ID")],
        LoadName      = ["Load_$(id)" for id in sub[!, Symbol("Bus ID")]],
        ActivePower   = Float64.(coalesce.(sub[!, mw_col], 0.0)),
        ReactivePower = Float64.(coalesce.(sub[!, Symbol("MVAR Load")], 0.0)),
        BasePower     = fill(100.0, n),
        Available     = fill(true, n),
    )
    log_success("Loaded $(nrow(out)) loads from RTS-GMLC bus.csv")
    return out
end

"""
Read gen.csv and split into (thermal_df, renewable_df, hydro_df) based on Unit Type.
Retains heat-rate curve columns so downstream cost construction has access to them.
"""
function read_rts_generators(case_path::String)
    df = read_csv_file(joinpath(case_path, "gen.csv"))
    isempty(df) && return DataFrame(), DataFrame(), DataFrame()

    unit_type_col = Symbol("Unit Type")
    unit_types    = String.(df[!, unit_type_col])

    thermal_mask   = [t in _RTSGMLC_THERMAL_UNIT_TYPES   for t in unit_types]
    renewable_mask = [t in _RTSGMLC_RENEWABLE_UNIT_TYPES for t in unit_types]
    hydro_mask     = [t in _RTSGMLC_HYDRO_UNIT_TYPES     for t in unit_types]

    # Columns with spaces need Symbol("...") lookup
    fuel_price_col = Symbol("Fuel Price \$/MMBTU")
    start_cost_col = Symbol("Non Fuel Start Cost \$")
    stop_cost_col  = Symbol("Non Fuel Shutdown Cost \$")
    ramp_col       = Symbol("Ramp Rate MW/Min")

    function _make_gen_df(mask)
        sub = df[mask, :]
        isempty(sub) && return DataFrame()
        n    = nrow(sub)
        ramp = Float64.(coalesce.(sub[!, ramp_col], 0.0)) .* 60.0  # MW/Min → MW/Hr
        DataFrame(
            GeneratorName    = String.(sub[!, Symbol("GEN UID")]),
            BusNumber        = sub[!, Symbol("Bus ID")],
            ActivePowerMax   = Float64.(sub[!, Symbol("PMax MW")]),
            ActivePowerMin   = Float64.(sub[!, Symbol("PMin MW")]),
            ReactivePowerMax = Float64.(coalesce.(sub[!, Symbol("QMax MVAR")], 0.0)),
            ReactivePowerMin = Float64.(coalesce.(sub[!, Symbol("QMin MVAR")], 0.0)),
            RampUp           = ramp,
            RampDown         = ramp,
            MinDownTime      = Float64.(coalesce.(sub[!, Symbol("Min Down Time Hr")], 0.0)),
            MinUpTime        = Float64.(coalesce.(sub[!, Symbol("Min Up Time Hr")], 0.0)),
            BasePower        = Float64.(sub[!, Symbol("Base MVA")]),
            FuelType         = String.(coalesce.(sub[!, Symbol("Fuel")], "Unknown")),
            UnitType         = String.(sub[!, unit_type_col]),
            FuelPrice        = Float64.(coalesce.(sub[!, fuel_price_col], 0.0)),
            # Heat-rate curve columns (may contain missing for generators with
            # fewer than 5 breakpoints — kept as-is for downstream cost fitting)
            HR_avg_0         = sub[!, Symbol("HR_avg_0")],
            HR_incr_1        = sub[!, Symbol("HR_incr_1")],
            HR_incr_2        = sub[!, Symbol("HR_incr_2")],
            HR_incr_3        = sub[!, Symbol("HR_incr_3")],
            HR_incr_4        = sub[!, Symbol("HR_incr_4")],
            Output_pct_0     = sub[!, Symbol("Output_pct_0")],
            Output_pct_1     = sub[!, Symbol("Output_pct_1")],
            Output_pct_2     = sub[!, Symbol("Output_pct_2")],
            Output_pct_3     = sub[!, Symbol("Output_pct_3")],
            Output_pct_4     = sub[!, Symbol("Output_pct_4")],
            StartCost        = Float64.(coalesce.(sub[!, start_cost_col], 0.0)),
            ShutdownCost     = Float64.(coalesce.(sub[!, stop_cost_col],  0.0)),
            Available        = fill(true, n),
        )
    end

    thermal_df   = _make_gen_df(thermal_mask)
    renewable_df = _make_gen_df(renewable_mask)
    hydro_df     = _make_gen_df(hydro_mask)

    !isempty(thermal_df)   && log_success("Loaded $(nrow(thermal_df)) thermal generators (RTS-GMLC)")
    !isempty(renewable_df) && log_success("Loaded $(nrow(renewable_df)) renewable generators (RTS-GMLC)")
    !isempty(hydro_df)     && log_success("Loaded $(nrow(hydro_df)) hydro generators (RTS-GMLC)")

    return thermal_df, renewable_df, hydro_df
end

"""Read and remap branch.csv → branches DataFrame (RTS-GMLC format)."""
function read_rts_branches(case_path::String)
    df = read_csv_file(joinpath(case_path, "branch.csv"))
    isempty(df) && return df

    tr_ratio = Float64.(coalesce.(df[!, Symbol("Tr Ratio")], 0.0))
    # Tr Ratio == 0 means "plain AC line" — treat tap as 1.0
    tr_ratio_clean = [r == 0.0 ? 1.0 : r for r in tr_ratio]
    b_total = Float64.(coalesce.(df[!, Symbol("B")], 0.0))

    out = DataFrame(
        LineID           = String.(df[!, Symbol("UID")]),
        fromNode         = df[!, Symbol("From Bus")],
        toNode           = df[!, Symbol("To Bus")],
        Resistance       = Float64.(coalesce.(df[!, Symbol("R")], 0.0)),
        Reactance        = Float64.(coalesce.(df[!, Symbol("X")], 0.0)),
        Susceptance_from = b_total ./ 2,
        Susceptance_to   = b_total ./ 2,
        RateLimit        = Float64.(coalesce.(df[!, Symbol("Cont Rating")], 9999.0)),
        TransformerRatio = tr_ratio_clean,
        AngleLimit_min   = fill(-0.7, nrow(df)),
        AngleLimit_max   = fill(0.7,  nrow(df)),
        LineType         = [r == 1.0 ? "AC" : "Transformer" for r in tr_ratio_clean],
    )
    log_success("Loaded $(nrow(out)) branches from RTS-GMLC branch.csv")
    return out
end

"""Read and remap storage.csv → storage DataFrame (RTS-GMLC format)."""
function read_rts_storage(case_path::String)
    filepath = joinpath(case_path, "storage.csv")
    !isfile(filepath) && return DataFrame()
    df = read_csv_file(filepath)
    isempty(df) && return DataFrame()

    # storage.csv can have multiple rows per unit (head/tail reservoirs);
    # keep only the "head" position row as the primary storage entry.
    pos_col  = Symbol("position")
    head_df  = hasproperty(df, pos_col) ? df[df[!, pos_col] .== "head", :] : df
    isempty(head_df) && (head_df = df)

    out = DataFrame(
        StorageName    = String.(head_df[!, Symbol("GEN UID")]),
        EnergyMax_MWh  = Float64.(coalesce.(head_df[!, Symbol("Max Volume GWh")], 0.0)) .* 1000.0,
        EnergyInit_MWh = Float64.(coalesce.(head_df[!, Symbol("Initial Volume GWh")], 0.0)) .* 1000.0,
        PowerMax       = Float64.(coalesce.(head_df[!, Symbol("Rating MVA")], 0.0)),
        Available      = fill(true, nrow(head_df)),
    )
    log_success("Loaded $(nrow(out)) storage devices from RTS-GMLC storage.csv")
    return out
end

# ============================================================================
# SECTION 7: MAIN DATA LOADING FUNCTION
# ============================================================================

"""
    load_case_data(case_name::String, data_format::String="CSV";
                   base_path::String="") -> Dict{Symbol, Any}

Main entry point: Load all data for a given test case.

Arguments:
  - case_name: Name of the case (e.g., "5bus", "RTS_GMLC", "ACTIVSg2000")
  - data_format: "CSV" or "JSON" (used for :sahar/:legacy formats only)
  - base_path: Optional explicit path to data folder

Returns a Dict{Symbol, Any} with the following keys:
  :nodes, :thermal, :renewable, :hydro, :storage, :loads, :branches
    → DataFrame for :sahar, :legacy, :rts_gmlc formats.
    → Empty DataFrame for :psse_raw / :matpower (use :network_file instead).
  :lascopf_settings → Dict{String,Any} from LASCOPF_settings.yml (or defaults).
  :network_file     → Absolute path to the .RAW / .m file for PSS/E and
                      MATPOWER cases. Empty string for other formats.
                      Used by powerlascopf_from_psy_system!() in data_reader.jl.
  :file_format      → Symbol (:sahar, :legacy, :psse_raw, :matpower, :rts_gmlc).
"""
function load_case_data(case_name::String, data_format::String="CSV";
                        base_path::String="")

    println("=" ^ 70)
    println("📂 LOADING CASE DATA: $case_name")
    println("=" ^ 70)

    case_path   = get_case_path(case_name, base_path)
    bus_count   = parse_case_name(case_name)
    file_format = detect_file_format(case_path, bus_count)

    log_info("Case path:    $case_path")
    log_info("Bus count:    $bus_count")
    log_info("Data format:  $data_format")
    log_info("File format:  $file_format")

    # Always read LASCOPF_settings.yml (defaults if absent)
    settings = read_lascopf_settings(case_path)

    # Pre-populate result with empty DataFrames so all keys always exist
    result = Dict{Symbol, Any}(
        :nodes            => DataFrame(),
        :thermal          => DataFrame(),
        :renewable        => DataFrame(),
        :hydro            => DataFrame(),
        :storage          => DataFrame(),
        :loads            => DataFrame(),
        :branches         => DataFrame(),
        :lascopf_settings => settings,
        :network_file     => "",
        :file_format      => file_format,
        :case_path        => case_path,
        :bus_count        => bus_count,
    )

    if file_format == :sahar
        # ====== SAHAR FORMAT ======
        nodes_path    = get_file_path(case_path, bus_count, :nodes,     file_format, data_format)
        thermal_path  = get_file_path(case_path, bus_count, :thermal,   file_format, data_format)
        renew_path    = get_file_path(case_path, bus_count, :renewable, file_format, data_format)
        hydro_path    = get_file_path(case_path, bus_count, :hydro,     file_format, data_format)
        storage_path  = get_file_path(case_path, bus_count, :storage,   file_format, data_format)
        loads_path    = get_file_path(case_path, bus_count, :loads,     file_format, data_format)
        branches_path = get_file_path(case_path, bus_count, :branches,  file_format, data_format)

        result[:nodes]     = isfile(nodes_path)    ? read_nodes_sahar(nodes_path,       data_format) : DataFrame()
        result[:thermal]   = isfile(thermal_path)  ? read_thermal_sahar(thermal_path,   data_format) : DataFrame()
        result[:renewable] = isfile(renew_path)    ? read_renewable_sahar(renew_path,   data_format) : DataFrame()
        result[:hydro]     = isfile(hydro_path)    ? read_hydro_sahar(hydro_path,       data_format) : DataFrame()
        result[:storage]   = isfile(storage_path)  ? read_storage_sahar(storage_path,   data_format) : DataFrame()
        result[:loads]     = isfile(loads_path)    ? read_loads_sahar(loads_path,       data_format) : DataFrame()
        result[:branches]  = isfile(branches_path) ? read_branches_sahar(branches_path, data_format) : DataFrame()

    elseif file_format in (:psse_raw, :matpower)
        # ====== PSS/E RAW or MATPOWER FORMAT ======
        # These are monolithic network files — all component data lives in one file.
        # We store the file path and let powerlascopf_from_psy_system!() in
        # data_reader.jl call PSY.System(network_file) and extract components.
        network_path = get_file_path(case_path, bus_count, :thermal, file_format)
        result[:network_file] = network_path
        log_info("Network file: $network_path")
        log_warn("PSS/E RAW / MATPOWER: component DataFrames will be populated " *
                 "by powerlascopf_from_psy_system!() in data_reader.jl (D1 step).")

    elseif file_format == :rts_gmlc
        # ====== RTS-GMLC / 5-bus-hydro CSV FORMAT ======
        result[:nodes]   = read_rts_nodes(case_path)
        result[:loads]   = read_rts_loads(case_path)
        result[:branches] = read_rts_branches(case_path)
        result[:storage]  = read_rts_storage(case_path)
        thermal_df, renewable_df, hydro_df = read_rts_generators(case_path)
        result[:thermal]   = thermal_df
        result[:renewable] = renewable_df
        result[:hydro]     = hydro_df

    else
        # ====== LEGACY FORMAT (300-bus style) ======
        gen_path    = get_file_path(case_path, bus_count, :thermal,  file_format, data_format)
        load_path   = get_file_path(case_path, bus_count, :loads,    file_format, data_format)
        branch_path = get_file_path(case_path, bus_count, :branches, file_format, data_format)

        result[:thermal]  = isfile(gen_path)    ? read_generators_legacy(gen_path,    data_format) : DataFrame()
        result[:loads]    = isfile(load_path)   ? read_loads_legacy(load_path,        data_format) : DataFrame()
        result[:branches] = isfile(branch_path) ? read_branches_legacy(branch_path,   data_format) : DataFrame()
        result[:nodes]    = generate_nodes_from_components(
            result[:thermal], result[:loads], result[:branches]
        )
    end

    # Summary
    println("\n" * "-" ^ 70)
    println("📊 DATA LOADING SUMMARY")
    println("-" ^ 70)
    println("  Format:     $file_format")
    if file_format in (:psse_raw, :matpower)
        println("  Network:    $(result[:network_file])")
        println("  (Component DataFrames populated after PSY.System parse in D1)")
    else
        println("  Nodes:      $(nrow(result[:nodes])) buses")
        println("  Thermal:    $(nrow(result[:thermal])) generators")
        println("  Renewable:  $(nrow(result[:renewable])) generators")
        println("  Hydro:      $(nrow(result[:hydro])) generators")
        println("  Storage:    $(nrow(result[:storage])) devices")
        println("  Loads:      $(nrow(result[:loads])) loads")
        println("  Branches:   $(nrow(result[:branches])) lines")
    end
    println("  RNDIntervals: $(settings["RNDIntervals"])  RSDIntervals: $(settings["RSDIntervals"])")
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
function get_generator_at_bus(data::Dict{Symbol, Any}, bus_number::Int)
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
function get_load_at_bus(data::Dict{Symbol, Any}, bus_number::Int)
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
function get_branches_from_bus(data::Dict{Symbol, Any}, bus_number::Int)
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
function get_total_generation_capacity(data::Dict{Symbol, Any})
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
function get_total_load(data::Dict{Symbol, Any})
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
function export_case_data(data::Dict{Symbol, Any}, output_path::String, 
                          data_format::String="CSV")
    
    mkpath(output_path)
    ext = uppercase(data_format) == "JSON" ? ".json" : ".csv"
    
    for (component, df) in data
        # Skip non-DataFrame entries (e.g. :lascopf_settings, :network_file, :file_format)
        !(df isa AbstractDataFrame) && continue
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

"""
Generic Data Reader for PowerLASCOPF Test Cases

Dispatches to case-specific data readers based on case name/path.
Called by run_reader.jl → calls data_reader.jl
"""

# Include the case-specific data reader
include("../src/PowerLASCOPF.jl")
include("../src/components/supernetwork.jl")
include("../example_cases/data_reader.jl")

"""
    load_case_data(case_name::String, case_path::String)

Load system data for the specified test case.

# Arguments
- `case_name::String`: Name of the test case (e.g., "5bus_pu", "14bus_pu")
- `case_path::String`: Path to case data file or directory

# Returns
- `system`: PowerLASCOPF system object
- `system_data`: Dictionary containing all system component data
"""
function _load_case_data_legacy(case_name::String, case_path::String)
    println("  - Loading case: $case_name")
    println("  - From path: $case_path")
    
    # Normalize case name for matching
    normalized_name = lowercase(replace(case_name, "_" => ""))
    extracted_bus_count = parse_case_name(normalized_name)
    println("  - Normalized case name: $normalized_name")
    println("  - Extracted bus count: $extracted_bus_count")
    _load_case_data_legacy(extracted_bus_count, case_path)
    # Dispatch to appropriate case loader via data_reader.jl
    if contains(normalized_name, "5bus")
        println("  - Detected 5-bus test case")
        return load_5bus_case(case_path)
    elseif contains(normalized_name, "14bus")
        println("  - Detected 14-bus test case")
        return load_14bus_case(case_path)
    elseif contains(normalized_name, "118bus")
        println("  - Detected 118-bus test case")
        return load_118bus_case(case_path)
    elseif contains(normalized_name, "300bus")
        println("  - Detected 300-bus test case")
        return load_300bus_case(case_path)
    else
        # Attempt generic CSV/JSON loading
        println("  - Attempting generic data loading")
        return load_generic_case(case_path)
    end
end


function _load_case_data_legacy(num_buses::Int, file_format::String="CSV")

    data_dir = joinpath(@__DIR__, "IEEE_Test_Cases")

    return load_system(num_buses=num_buses, data_dir=data_dir, file_format=file_format)

end
"""
    load_generic_case(case_path::String)

Generic loader for cases with CSV/JSON data files.
"""
function load_generic_case(case_path::String)
    if isdir(case_path)
        # Look for standard data files in directory
        csv_files = filter(f -> endswith(f, ".csv"), readdir(case_path))
        json_files = filter(f -> endswith(f, ".json"), readdir(case_path))
        
        if !isempty(csv_files) || !isempty(json_files)
            println("  - Found data files in directory, attempting CSV/JSON loading")
            return load_from_csv_json(case_path)
        end
    end
    
    error("❌ Unable to load case data from $case_path. Ensure case data file exists or implement case-specific loader.")
end

"""
Generic Data Reader Dispatcher for PowerLASCOPF

Routes to the correct case loader based on configuration.
Supports: 5, 14, 30, 48, 57, 118, 300 bus IEEE test cases.
"""

include(joinpath(@__DIR__, "data_reader.jl"))

# Map of supported bus counts to their loader functions
const CASE_LOADERS = Dict{Int, Function}(
    5   => load_5bus_case,
    14  => load_14bus_case,
    30  => load_30bus_case,
    48  => load_48bus_case,
    57  => load_57bus_case,
    118 => load_118bus_case,
    300 => load_300bus_case,
)

"""
    load_system(; num_buses::Int, data_dir::String="", file_format::String="CSV")

Main entry point for loading a PowerLASCOPF system.

# Arguments
- `num_buses::Int`: Number of buses (5, 14, 30, 48, 57, 118, or 300)
- `data_dir::String`: Directory containing `_sahar` data files. 
   Defaults to `@__DIR__` (the example_cases folder).
- `file_format::String`: "CSV" or "JSON"

# Returns
- `(system, system_data)` tuple

# Examples
```julia
system, data = load_system(num_buses=118, data_dir="/path/to/data", file_format="CSV")
system, data = load_system(num_buses=5)  # uses data_5bus_pu.jl if available
```
"""
function load_system(; num_buses::Int, data_dir::String="", file_format::String="CSV")
    # Default data_dir to the example_cases directory
    if isempty(data_dir)
        data_dir = @__DIR__
    end
    
    println("=" ^ 60)
    println("Loading PowerLASCOPF System")
    println("  Case:     $(num_buses)-bus")
    println("  Format:   $file_format")
    println("  Data dir: $data_dir")
    println("=" ^ 60)
    
    if haskey(CASE_LOADERS, num_buses)
        loader = CASE_LOADERS[num_buses]
        system, system_data = loader(data_dir, file_format)
    else
        # Try generic CSV/JSON loader for unsupported bus counts
        println("  ⚠️  No dedicated loader for $(num_buses)-bus. Trying generic loader...")
        system, system_data = load_from_csv_json(data_dir, file_format; num_buses=num_buses)
    end
    
    println("=" ^ 60)
    println("✅ System loaded successfully: $(num_buses)-bus")
    println("=" ^ 60)
    
    return system, system_data
end

"""
    list_supported_cases()

Print all supported IEEE test cases.
"""
function list_supported_cases()
    println("Supported IEEE test cases:")
    for n in sort(collect(keys(CASE_LOADERS)))
        println("  - $(n)-bus")
    end
    println("  - Custom (any bus count via CSV/JSON files)")
end

