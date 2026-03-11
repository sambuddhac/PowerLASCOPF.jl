"""
PowerLASCOPF System Builder — data_reader.jl
=============================================

PURPOSE:
  Converts raw power-system data (from CSV, PSS/E RAW, MATPOWER, or
  RTS-GMLC files) into fully-initialised PowerLASCOPFSystem objects
  with all eight generator interval types, extended cost structs,
  GenSolver objects, and LineSolverBase objects.

  Requires: PowerSystems.jl, InfrastructureSystems.jl, PowerLASCOPF
  (loaded by the caller before this file is included).

KEY FUNCTIONS:

  powerlascopf_from_psy_system!(system, psy_system, cont_count)
    Bridge for PSS/E RAW and MATPOWER cases.
    Caller: PSY.System(filepath) → this function.
    Iterates PSY component collections (ACBus, Branch, ThermalStandard,
    RenewableDispatch, HydroDispatch/HydroEnergyReservoir, PowerLoad).

  powerlascopf_from_rts_gmlc!(system, case_path, cont_count)
    Builder for RTS-GMLC CSV cases.
    Reads bus.csv, gen.csv, branch.csv directly.
    Classifies generators by "Unit Type" column.
    Converts piecewise heat-rate data to quadratic cost curves via
    _heat_rate_to_quadratic() (least-squares fit).

  apply_lascopf_settings(settings)
    Maps LASCOPF_settings.yml keys to typed construction parameters
    (RND_int, RSD_int, solver_choice, rho_tuning, use_dummy_interval).

  load_timeseries_rts_gmlc(case_path)
    Stub: logs a deferred message and returns an empty Dict.
    Full implementation (reading timeseries_pointers_da.json + forecast CSVs
    and calling PSY.add_time_series!()) is deferred to a later phase.

  powerlascopf_nodes_from_csv!(system, csv_path)
  powerlascopf_branches_from_csv!(system, nodes, csv_path, …)
  powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, …)
  powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, …)
  powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, …)
  powerlascopf_storage_from_csv!(system, nodes, csv_path, …)
  powerlascopf_loads_from_csv!(system, nodes, csv_path)
    Builders for IEEE Sahar/Legacy CSV cases.

CALL CHAIN (via run_reader_generic.jl → Phase 2.5):
  :psse_raw / :matpower  → PSY.System(network_file)
                         → powerlascopf_from_psy_system!()
  :rts_gmlc              → powerlascopf_from_rts_gmlc!()
  :sahar / :legacy       → powerlascopf_nodes_from_csv!()
                         → powerlascopf_branches_from_csv!()
                         → powerlascopf_thermal_generators_from_csv!()  etc.

FULL DOCUMENTATION:
  example_cases/RUNNING_CASES.md
"""

using Revise
using TimeSeries
using Dates
using Random
using PowerSystems
using InfrastructureSystems
using CSV
using JSON3  # Using JSON3 for better performance than JSON.jl
using DataFrames
using Logging

Random.seed!(123)

const PSY = PowerSystems
const IS = InfrastructureSystems

# ============================================================================
# SECTION 1: LOGGING SETUP
# WHY: Track execution flow, debug issues, maintain audit trail
# ============================================================================

const LOG_FILE = joinpath(@__DIR__, "data_reader_execution.log")
const LOG_IO = open(LOG_FILE, "w")

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

log_info(message::String) = log_both("ℹ️  INFO: $message")
log_warn(message::String) = log_both("⚠️  WARN: $message")
log_error(message::String) = log_both("❌ ERROR: $message")
log_success(message::String) = log_both("✅ SUCCESS: $message")

atexit(() -> close(LOG_IO))

log_info("Starting PowerLASCOPF execution script")
log_info("Log file: $LOG_FILE")

import PowerSystems: PrimeMovers, ThermalFuels, Arc

# ============================================================================
# SECTION 2: TIME SERIES DATA READER
# WHY: Solar, wind, hydro, and load profiles change hourly
# INPUT: TimeSeries_DA_sahar.csv or .json
# OUTPUT: Dictionary with arrays for each time series
# ============================================================================

"""
    read_timeseries_data(data_path::String, file_format::String="CSV")

WHAT: Reads hourly time series data (solar, wind, hydro inflows, loads)
WHY: Time series data is large and changes frequently - better in files than code
HOW: 
  - CSV: Read DataFrame, extract columns as arrays
  - JSON: Parse JSON object, extract arrays from keys

STRUCTURE EXPECTED:
  CSV: Columns = Hour, Solar, Wind, HydroInflow, LoadBus2, LoadBus3, LoadBus4
  JSON: {"Solar": [...], "Wind": [...], "HydroInflow": [...], "LoadBus2": [...]}

RETURNS: Dict with keys: "DayAhead", "solar_ts_DA", "wind_ts_DA", etc.
"""
function read_timeseries_data(data_path::String, file_format::String="CSV")
    log_info("Reading time series data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        # CSV Path: DataFrame-based reading
        # WHY: CSV.jl is optimized for tabular data
        df = CSV.read(data_path, DataFrame)
        
        # Create 24-hour DayAhead time array (standard for day-ahead markets)
        # WHY: PowerSystems.jl requires DateTime objects for time series
        DayAhead = collect(
            DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Hour(1):
            DateTime("1/1/2024 23:00:00", "d/m/y H:M:S")
        )
        
        # Extract columns as vectors
        # WHY: PowerSystems SingleTimeSeries expects Vector{Float64}
        timeseries_data = Dict(
            "DayAhead" => DayAhead,
            "solar_ts_DA" => Vector{Float64}(df.Solar),
            "wind_ts_DA" => Vector{Float64}(df.Wind),
            "hydro_inflow_ts_DA" => Vector{Float64}(df.HydroInflow),
            "loadbus2_ts_DA" => Vector{Float64}(df.LoadBus2),
            "loadbus3_ts_DA" => Vector{Float64}(df.LoadBus3),
            "loadbus4_ts_DA" => Vector{Float64}(df.LoadBus4)
        )
        
    elseif uppercase(file_format) == "JSON"
        # JSON Path: Direct parsing to Dict
        # WHY: JSON3.jl handles nested structures efficiently
        json_data = JSON3.read(read(data_path, String))
        
        DayAhead = collect(
            DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Hour(1):
            DateTime("1/1/2024 23:00:00", "d/m/y H:M:S")
        )
        
        # JSON keys map directly to arrays
        # WHY: JSON structure matches our dict structure 1:1
        timeseries_data = Dict(
            "DayAhead" => DayAhead,
            "solar_ts_DA" => Vector{Float64}(json_data["Solar"]),
            "wind_ts_DA" => Vector{Float64}(json_data["Wind"]),
            "hydro_inflow_ts_DA" => Vector{Float64}(json_data["HydroInflow"]),
            "loadbus2_ts_DA" => Vector{Float64}(json_data["LoadBus2"]),
            "loadbus3_ts_DA" => Vector{Float64}(json_data["LoadBus3"]),
            "loadbus4_ts_DA" => Vector{Float64}(json_data["LoadBus4"])
        )
    else
        error("Unsupported file format: $file_format. Use 'CSV' or 'JSON'")
    end
    
    log_success("Time series data loaded: $(length(timeseries_data["DayAhead"])) hours")
    return timeseries_data
end

# ============================================================================
# SECTION 3: NODES (BUSES) DATA READER
# WHY: Nodes are the foundation - generators/loads connect to them
# INPUT: Nodes_sahar.csv or .json
# OUTPUT: Function that creates PSY.ACBus objects
# ============================================================================

"""
    read_nodes_data(data_path::String, file_format::String="CSV")

WHAT: Reads bus/node electrical parameters
WHY: Each bus has voltage limits, base voltage, type (PQ/PV/Slack)
HOW: Returns a FUNCTION (not objects) because nodes need to be created fresh each time

DESIGN DECISION - Why return a function?
  - Original code has nodes5() and nodes14() FUNCTIONS
  - Functions allow lazy evaluation (create objects only when needed)
  - Avoids keeping objects in memory when not used
  - Matches existing codebase pattern

STRUCTURE EXPECTED:
  Columns: BusNumber, BusName, BusType, Angle, Voltage, VoltageMin, VoltageMax, BaseVoltage

RETURNS: Function() that when called returns Vector{PSY.ACBus}
"""
function read_nodes_data(data_path::String, file_format::String="CSV")
    log_info("Reading nodes data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        # Create closure that captures df
        # WHY: Closure preserves data but delays object creation
        nodes_func = function()
            buses = PSY.ACBus[]
            for row in eachrow(df)
                # WHY these parameters:
                # - BusNumber: Unique identifier for connectivity
                # - BusName: Human-readable label
                # - BusType: "PQ" (load), "PV" (generator), "REF" (slack)
                # - Angle/Voltage: Initial operating point
                # - Voltage limits: Constraints for optimization
                # - BaseVoltage: Per-unit system normalization
                bus = PSY.ACBus(
                    row.BusNumber,
                    row.BusName,
                    row.BusType,
                    row.Angle,
                    row.Voltage,
                    (min = row.VoltageMin, max = row.VoltageMax),
                    row.BaseVoltage,
                    nothing,  # area (optional)
                    nothing   # load_zone (optional)
                )
                push!(buses, bus)
            end
            return buses
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        nodes_func = function()
            buses = PSY.ACBus[]
            for node in json_data
                bus = PSY.ACBus(
                    node["BusNumber"],
                    node["BusName"],
                    node["BusType"],
                    node["Angle"],
                    node["Voltage"],
                    (min = node["VoltageMin"], max = node["VoltageMax"]),
                    node["BaseVoltage"],
                    nothing,
                    nothing
                )
                push!(buses, bus)
            end
            return buses
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Nodes data loaded successfully")
    return nodes_func
end

# ============================================================================
# SECTION 4: BRANCHES (TRANSMISSION LINES) DATA READER
# WHY: Transmission lines connect buses and have capacity limits
# INPUT: Trans_sahar.csv or .json
# OUTPUT: Function that creates PSY.Line and PSY.HVDCLine objects
# ============================================================================

"""
    read_branches_data(data_path::String, file_format::String="CSV")

WHAT: Reads transmission line electrical parameters
WHY: Lines have resistance, reactance, and thermal limits
HOW: Supports both AC lines (PSY.Line) and HVDC lines (PSY.HVDCLine)

DESIGN DECISION - Two line types:
  - AC Lines: Normal transmission (has R, X, B parameters)
  - HVDC Lines: High-voltage DC (different model, loss curve)

STRUCTURE EXPECTED:
  Columns: LineName, LineType (AC/HVDC), FromNode, ToNode, Resistance, Reactance, 
           SusceptanceFrom, SusceptanceTo, RateLimit, AngleLimitMin, AngleLimitMax
  
  For HVDC: ActivePowerMin/Max, ReactivePowerFromMin/Max, LossL0, LossL1

RETURNS: Function(nodes) that creates Vector{Union{PSY.Line, PSY.HVDCLine}}
"""
function read_branches_data(data_path::String, file_format::String="CSV")
    log_info("Reading branches data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        # Function takes nodes as argument
        # WHY: Lines need Arc(from=node1, to=node2) - requires node objects
        branches_func = function(nodes)
            branches = []
            for row in eachrow(df)
                if row.LineType == "AC"
                    # AC Line parameters:
                    # - R, X, B: Electrical impedance model
                    # - RateLimit: Maximum power flow (thermal limit)
                    # - AngleLimit: Stability constraint
                    line = PSY.Line(
                        row.LineName,
                        true,  # available
                        0.0,   # active_power_flow (initialized by solver)
                        0.0,   # reactive_power_flow (initialized by solver)
                        Arc(from = nodes[row.fromNode], to = nodes[row.toNode]),
                        row.Resistance,
                        row.Reactance,
                        (from = row.Susceptance_from, to = row.Susceptance_to),
                        row.RateLimit,
                        (min = row.AngleLimit_min, max = row.AngleLimit_max)
                    )
                    push!(branches, line)
                    
                elseif row.LineType == "HVDC"
                    # HVDC Line parameters:
                    # - Active/Reactive power limits (different from AC)
                    # - Loss model: l0 + l1*power (linear approximation)
                    hvdc_line = PSY.HVDCLine(
                        row.LineName,
                        true,
                        0.0,
                        Arc(from = nodes[row.fromNode], to = nodes[row.toNode]),
                        (min = row.ActivePower_min, max = row.ActivePower_max),
                        (min = row.ReactivePowerFromMin, max = row.ReactivePowerFromMax),
                        (min = row.ReactivePowerToMin, max = row.ReactivePowerToMax),
                        (min = row.ReactivePowerToMin, max = row.ReactivePowerToMax),
                        (l0 = row.LossL0, l1 = row.LossL1)
                    )
                    push!(branches, hvdc_line)
                end
            end
            return branches
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        branches_func = function(nodes)
            branches = []
            for branch in json_data
                if branch["LineType"] == "AC"
                    line = PSY.Line(
                        branch["LineName"],
                        true,
                        0.0,
                        0.0,
                        Arc(from = nodes[branch["fromNode"]], to = nodes[branch["toNode"]]),
                        branch["Resistance"],
                        branch["Reactance"],
                        (from = branch["Susceptance_from"], to = branch["Susceptance_to"]),
                        branch["RateLimit"],
                        (min = branch["AngleLimit_min"], max = branch["AngleLimit_max"])
                    )
                    push!(branches, line)
                elseif branch["LineType"] == "HVDC"
                    hvdc_line = PSY.HVDCLine(
                        branch["LineName"],
                        true,
                        0.0,
                        Arc(from = nodes[branch["fromNode"]], to = nodes[branch["toNode"]]),
                        (min = branch["ActivePower_min"], max = branch["ActivePower_max"]),
                        (min = branch["ReactivePowerFrom_min"], max = branch["ReactivePowerFrom_max"]),
                        (min = branch["ReactivePowerTo_min"], max = branch["ReactivePowerTo_max"]),
                        (min = branch["ReactivePowerTo_min"], max = branch["ReactivePowerTo_max"]),
                        (l0 = branch["LossL0"], l1 = branch["LossL1"])
                    )
                    push!(branches, hvdc_line)
                end
            end
            return branches
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Branches data loaded successfully")
    return branches_func
end

# ============================================================================
# SECTION 5: THERMAL GENERATORS DATA READER
# WHY: Thermal generators (coal, gas) have complex cost curves and constraints
# INPUT: ThermalGenerators_sahar.csv or .json
# OUTPUT: Function that creates PSY.ThermalStandard objects
# ============================================================================

"""
    read_thermal_generators_data(data_path::String, file_format::String="CSV")

WHAT: Reads thermal generator parameters (coal, gas, nuclear plants)
WHY: Thermal units have:
  - Quadratic cost curves: C0 + C1*P + C2*P^2
  - Ramp rate limits: How fast they can change output
  - Start-up/shut-down costs: Expensive to turn on/off
  - Min/max power limits: Can't operate below minimum stable generation

STRUCTURE EXPECTED:
  Columns: GeneratorName, BusNumber, ActivePower, ReactivePower, Rating,
           PrimeMover, Fuel, ActivePowerMin/Max, ReactivePowerMin/Max,
           RampUp, RampDown, TimeUp, TimeDown,
           CostC0, CostC1, CostC2, FuelCost, VOMCost, FixedCost,
           StartUpCost, ShutDownCost, BasePower

COST MODEL EXPLANATION:
  - Variable Cost = C0 + C1*P + C2*P^2 (fuel consumption curve)
  - Fixed Cost = constant dollars per hour when running
  - Start-up Cost = dollars to bring online from offline
  - Shut-down Cost = dollars to take offline
"""
function read_thermal_generators_data(data_path::String, file_format::String="CSV")
    log_info("Reading thermal generators data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        thermal_gens_func = function(nodes)
            generators = PSY.ThermalStandard[]
            for row in eachrow(df)
                gen = PSY.ThermalStandard(
                    name = row.GeneratorName,
                    available = row.Available,
                    status = row.Status,
                    bus = nodes[row.BusNumber],
                    active_power = row.ActivePower,
                    reactive_power = row.ReactivePower,
                    rating = row.Rating,
                    prime_mover_type = getfield(PSY.PrimeMovers, Symbol(row.PrimeMover)),  # e.g., "ST" -> PrimeMovers.ST
                    fuel = getfield(PSY.ThermalFuels, Symbol(row.Fuel)),  # e.g., "COAL" -> ThermalFuels.COAL
                    active_power_limits = (min = row.ActivePowerMin, max = row.ActivePowerMax),
                    reactive_power_limits = (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                    # Ramp limits: MW per time period (e.g., MW/hour)
                    ramp_limits = ismissing(row.RampUp) ? nothing : (up = row.RampUp, down = row.RampDown),
                    # Time limits: Minimum up/down time (e.g., must run 4 hours if started)
                    time_limits = ismissing(row.TimeLimitUp) ? nothing : (up = row.TimeLimitUp, down = row.TimeLimitDown),
                    # Cost structure: Quadratic fuel curve + fixed + startup/shutdown
                    operation_cost = PSY.ThermalGenerationCost(
                        variable = IS.FuelCurve(
                            value_curve = IS.QuadraticCurve(row.CostCurve_c, row.CostCurve_b, row.CostCurve_a),
                            fuel_cost = row.FuelCost,
                            vom_cost = IS.LinearCurve(row.VOM_Cost)  # Variable O&M
                        ),
                        fixed = row.FixedCost,
                        start_up = row.StartUpCost,
                        shut_down = row.ShutDownCost
                    ),
                    base_power = row.BasePower
                )
                push!(generators, gen)
            end
            return generators
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        thermal_gens_func = function(nodes)
            generators = PSY.ThermalStandard[]
            for gen_data in json_data
                gen = PSY.ThermalStandard(
                    name = gen_data["GeneratorName"],
                    available = gen_data["Available"],
                    status = gen_data["Status"],
                    bus = nodes[gen_data["BusNumber"]],
                    active_power = gen_data["ActivePower"],
                    reactive_power = gen_data["ReactivePower"],
                    rating = gen_data["Rating"],
                    prime_mover_type = getfield(PSY.PrimeMovers, Symbol(gen_data["PrimeMover"])),
                    fuel = getfield(ThermalFuels, Symbol(gen_data["Fuel"])),
                    active_power_limits = (min = gen_data["ActivePowerMin"], max = gen_data["ActivePowerMax"]),
                    reactive_power_limits = (min = gen_data["ReactivePowerMin"], max = gen_data["ReactivePowerMax"]),
                    # Ramp limits: MW per time period (e.g., MW/hour)
                    ramp_limits = isnothing(get(gen_data, "RampUp", nothing)) ? nothing :
                                  (up = gen_data["RampUp"], down = gen_data["RampDown"]),
                    # Time limits: Minimum up/down time (e.g., must run 4 hours if started)
                    time_limits = isnothing(get(gen_data, "TimeLimitUp", nothing)) ? nothing :
                                  (up = gen_data["TimeLimitUp"], down = gen_data["TimeLimitDown"]),
                    # Cost structure: Quadratic fuel curve + fixed + startup/shutdown
                    operation_cost = PSY.ThermalGenerationCost(
                        variable = IS.FuelCurve(
                            value_curve = IS.QuadraticCurve(gen_data["CostCurve_c"], gen_data["CostCurve_b"], gen_data["CostCurve_a"]),
                            fuel_cost = gen_data["FuelCost"],
                            vom_cost = IS.LinearCurve(gen_data["VOM_Cost"])
                        ),
                        fixed = gen_data["FixedCost"],
                        start_up = gen_data["StartUpCost"],
                        shut_down = gen_data["ShutDownCost"]
                    ),
                    base_power = gen_data["BasePower"]
                )
                push!(generators, gen)
            end
            return generators
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Thermal generators data loaded successfully")
    return thermal_gens_func
end

# ============================================================================
# SECTION 6: RENEWABLE GENERATORS DATA READER
# WHY: Renewable generators (solar, wind) have zero marginal cost but are variable
# INPUT: RenewableGenerators_sahar.csv or .json
# OUTPUT: Function that creates PSY.RenewableDispatch objects
# ============================================================================

"""
    read_renewable_generators_data(data_path::String, file_format::String="CSV")

WHAT: Reads renewable generator parameters (solar PV, wind turbines)
WHY: Renewables differ from thermal:
  - Near-zero variable cost (no fuel)
  - Output varies with weather (needs time series)
  - No ramp limits (can change instantly)
  - No start-up costs (always available)

STRUCTURE EXPECTED:
  Columns: GeneratorName, BusNumber, ActivePower, ReactivePower, Rating,
           PrimeMover (PVe=solar, WT=wind), ReactivePowerMin/Max,
           PowerFactor, VariableCost, BasePower
"""
function read_renewable_generators_data(data_path::String, file_format::String="CSV")
    log_info("Reading renewable generators data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        renewable_gens_func = function(nodes)
            generators = PSY.RenewableDispatch[]
            for row in eachrow(df)
                gen = PSY.RenewableDispatch(
                    row.GeneratorName,
                    row.Available,
                    nodes[row.BusNumber],
                    row.ActivePower,
                    row.ReactivePower,
                    row.Rating,
                    getfield(PrimeMovers, Symbol(row.PrimeMover)),  # PVe = solar, WT = wind
                    (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                    row.PowerFactor,
                    # Simple linear cost (usually very low or zero)
                    PSY.RenewableGenerationCost(CostCurve(LinearCurve(row.VariableCost))),
                    row.BasePower
                )
                push!(generators, gen)
            end
            return generators
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        renewable_gens_func = function(nodes)
            generators = PSY.RenewableDispatch[]
            for gen_data in json_data
                gen = PSY.RenewableDispatch(
                    gen_data["GeneratorName"],
                    gen_data["Available"],
                    nodes[gen_data["BusNumber"]],
                    gen_data["ActivePower"],
                    gen_data["ReactivePower"],
                    gen_data["Rating"],
                    getfield(PrimeMovers, Symbol(gen_data["PrimeMover"])),
                    (min = gen_data["ReactivePowerMin"], max = gen_data["ReactivePowerMax"]),
                    gen_data["PowerFactor"],
                    PSY.RenewableGenerationCost(CostCurve(LinearCurve(gen_data["VariableCost"]))),
                    gen_data["BasePower"]
                )
                push!(generators, gen)
            end
            return generators
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Renewable generators data loaded successfully")
    return renewable_gens_func
end

# ============================================================================
# SECTION 7: HYDRO GENERATORS DATA READER
# WHY: Hydro generators have water reservoirs and inflow constraints
# INPUT: HydroGenerators_sahar.csv or .json
# OUTPUT: Function that creates PSY.Hydro* objects (multiple types)
# ============================================================================

"""
    read_hydro_generators_data(data_path::String, file_format::String="CSV")

WHAT: Reads hydro generator parameters (dams, reservoirs, pumped storage)
WHY: Hydro types:
  1. HydroDispatch: Run-of-river (no storage)
  2. HydroEnergyReservoir: Dam with reservoir (stores water/energy)
  3. HydroPumpedStorage: Can pump water uphill (acts as battery)

KEY CONCEPTS:
  - Inflow: Water entering reservoir (from upstream/rain)
  - Storage capacity: Maximum water in reservoir (MWh equivalent)
  - Conversion factor: Water flow -> electrical power
  - Pump efficiency: Energy loss when pumping

STRUCTURE EXPECTED:
  Columns: GenName, HydroType, BusNumber, ActivePower, Rating,
           StorageCapacity, Inflow, ConversionFactor, InitialStorage,
           RatingPump (for pumped storage), PumpEfficiency
"""
function read_hydro_generators_data(data_path::String, file_format::String="CSV")
    log_info("Reading hydro generators data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        hydro_gens_func = function(nodes)
            generators = []
            for row in eachrow(df)
                if row.GeneratorType == "HydroDispatch"
                    # Run-of-river: No storage, just convert water flow to power
                    gen = PSY.HydroDispatch(
                        row.GeneratorName,
                        row.Available,
                        nodes[row.BusNumber],
                        row.ActivePower,
                        row.ReactivePower,
                        row.Rating,
                        getfield(PrimeMovers, Symbol(row.PrimeMover)),
                        (min = row.ActivePowerMin, max = row.ActivePowerMax),
                        (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                        nothing,  # ramp_limits
                        nothing,  # time_limits
                        row.BasePower,
                        PSY.HydroGenerationCost(
                            variable = FuelCurve(
                                value_curve = LinearCurve(row.VariableCost),
                                fuel_cost = 0.0  # No fuel - uses water
                            ),
                            fixed = row.FixedCost
                        ),
                        PSY.Device[],
                        nothing,
                        Dict{String, Any}()
                    )
                    push!(generators, gen)
                    
                elseif row.GeneratorType == "HydroEnergyReservoir"
                    # Reservoir: Can store water, optimize when to generate
                    gen = PSY.HydroEnergyReservoir(
                        name = row.GeneratorName,
                        available = row.Available,
                        bus = nodes[row.BusNumber],
                        active_power = row.ActivePower,
                        reactive_power = row.ReactivePower,
                        rating = row.Rating,
                        prime_mover_type = getfield(PrimeMovers, Symbol(row.PrimeMover)),
                        active_power_limits = (min = row.ActivePowerMin, max = row.ActivePowerMax),
                        reactive_power_limits = (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                        ramp_limits = (up = row.RampUp, down = row.RampDown),
                        time_limits = nothing,
                        operation_cost = PSY.HydroGenerationCost(
                            variable = FuelCurve(
                                value_curve = LinearCurve(row.VariableCost),
                                fuel_cost = 0.0
                            ),
                            fixed = row.FixedCost
                        ),
                        base_power = row.BasePower,
                        storage_capacity = row.StorageCapacity,  # MWh
                        inflow = row.Inflow,  # m³/s or MWh/hour
                        conversion_factor = row.ConversionFactor,  # m³/s -> MW
                        initial_storage = row.InitialStorage  # Starting reservoir level
                    )
                    push!(generators, gen)
                    
                elseif row.GeneratorType == "HydroPumpedStorage"
                    # Pumped storage: Can generate AND pump (store energy)
                    gen = PSY.HydroPumpedStorage(
                        name = row.GeneratorName,
                        available = row.Available,
                        bus = nodes[row.BusNumber],
                        active_power = row.ActivePower,
                        reactive_power = row.ReactivePower,
                        rating = row.Rating,
                        base_power = row.BasePower,
                        prime_mover_type = getfield(PrimeMovers, Symbol(row.PrimeMover)),
                        active_power_limits = (min = row.ActivePowerMin, max = row.ActivePowerMax),
                        reactive_power_limits = (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                        ramp_limits = (up = row.RampUp, down = row.RampDown),
                        time_limits = nothing,
                        operation_cost = PSY.HydroGenerationCost(
                            variable = FuelCurve(
                                value_curve = LinearCurve(row.VariableCost),
                                fuel_cost = 0.0
                            ),
                            fixed = row.FixedCost
                        ),
                        rating_pump = row.RatingPump,  # Pump capacity (MW)
                        active_power_limits_pump = (min = row.ActivePowerMinPump, max = row.ActivePowerMaxPump),
                        reactive_power_limits_pump = (min = row.ReactivePowerMinPump, max = row.ReactivePowerMaxPump),
                        ramp_limits_pump = (up = row.RampUpPump, down = row.RampDownPump),
                        time_limits_pump = nothing,
                        storage_capacity = (up = row.StorageCapacityUp, down = row.StorageCapacityDown),  # Upper/lower reservoir
                        inflow = row.Inflow,
                        outflow = row.Outflow,
                        initial_storage = (up = row.InitialStorageUp, down = row.InitialStorageDown),
                        storage_target = (up = row.StorageTargetUp, down = row.StorageTargetDown),  # Desired end state
                        conversion_factor = row.ConversionFactor,
                        pump_efficiency = row.PumpEfficiency  # <1.0 (energy lost when pumping)
                    )
                    push!(generators, gen)
                end
            end
            return generators
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        hydro_gens_func = function(nodes)
            generators = []
            for gen_data in json_data
                # Similar structure to CSV parsing
                # (Implementation follows same pattern)
            end
            return generators
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Hydro generators data loaded successfully")
    return hydro_gens_func
end

# ============================================================================
# SECTION 8: STORAGE (BATTERY) DATA READER
# WHY: Battery storage can charge/discharge and shift energy across time
# INPUT: Storage{N}_sahar.csv or .json
# OUTPUT: Function that creates PSY.EnergyReservoirStorage objects
# ============================================================================

"""
    read_storage_data(data_path::String, file_format::String="CSV")

WHAT: Reads battery/storage parameters
WHY: Storage devices can:
  - Charge from grid (consume power)
  - Discharge to grid (produce power)
  - Shift energy from low-price to high-price hours

STRUCTURE EXPECTED:
  Columns: StorageName, BusNumber, Available, ActivePower, ReactivePower,
           Rating, InputActivePowerMin, InputActivePowerMax,
           OutputActivePowerMin, OutputActivePowerMax,
           Efficiency, ReactivePowerMin, ReactivePowerMax,
           StorageCapacity, InitialEnergy, BasePower
"""
function read_storage_data(data_path::String, file_format::String="CSV")
    log_info("Reading storage data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        storage_func = function(nodes)
            devices = PSY.EnergyReservoirStorage[]
            for row in eachrow(df)
                dev = PSY.EnergyReservoirStorage(
                    name = row.StorageName,
                    available = row.Available,
                    bus = nodes[row.BusNumber],
                    prime_mover_type = PrimeMovers.BA,
                    storage_technology_type = PSY.StorageTech.OTHER_CHEM,
                    storage_capacity = row.StorageCapacity,
                    storage_level_limits = (min = row.SOC_Min, max = row.SOC_Max),
                    initial_storage_capacity_level = row.InitialEnergy,
                    rating = row.Rating,
                    active_power = row.ActivePower,
                    input_active_power_limits = (min = row.InputActivePowerMin, max = row.InputActivePowerMax),
                    output_active_power_limits = (min = row.OutputActivePowerMin, max = row.OutputActivePowerMax),
                    efficiency = (in = row.EfficiencyIn, out = row.EfficiencyOut),
                    reactive_power = row.ReactivePower,
                    reactive_power_limits = (min = row.ReactivePowerMin, max = row.ReactivePowerMax),
                    base_power = row.BasePower,
                    operation_cost = PSY.StorageCost(
                        charge_variable_cost = CostCurve(LinearCurve(0.0)),
                        discharge_variable_cost = CostCurve(LinearCurve(0.0)),
                        fixed = 0.0,
                        energy_shortage_cost = row.EnergyShortageCost,
                        energy_surplus_cost = row.EnergySurplusCost
                    )
                )
                push!(devices, dev)
            end
            return devices
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        storage_func = function(nodes)
            devices = PSY.EnergyReservoirStorage[]
            for s in json_data
                dev = PSY.EnergyReservoirStorage(
                    name = s["StorageName"],
                    available = s["Available"],
                    bus = nodes[s["BusNumber"]],
                    prime_mover_type = PrimeMovers.BA,
                    storage_technology_type = PSY.StorageTech.OTHER_CHEM,
                    storage_capacity = s["StorageCapacity"],
                    storage_level_limits = (min = s["StorageLevelMin"], max = s["StorageLevelMax"]),
                    initial_storage_capacity_level = s["InitialEnergy"],
                    rating = s["Rating"],
                    active_power = s["ActivePower"],
                    input_active_power_limits = (min = s["InputActivePowerMin"], max = s["InputActivePowerMax"]),
                    output_active_power_limits = (min = s["OutputActivePowerMin"], max = s["OutputActivePowerMax"]),
                    efficiency = (in = s["EfficiencyIn"], out = s["EfficiencyOut"]),
                    reactive_power = s["ReactivePower"],
                    reactive_power_limits = (min = s["ReactivePowerMin"], max = s["ReactivePowerMax"]),
                    base_power = s["BasePower"],
                    operation_cost = PSY.StorageCost(
                        charge_variable_cost = CostCurve(LinearCurve(0.0)),
                        discharge_variable_cost = CostCurve(LinearCurve(0.0)),
                        fixed = 0.0,
                        energy_shortage_cost = s["EnergyShortageCost"],
                        energy_surplus_cost = s["EnergySurplusCost"]
                    )
                )
                push!(devices, dev)
            end
            return devices
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Storage data loaded successfully")
    return storage_func
end

# ============================================================================
# SECTION 9: LOADS DATA READER
# WHY: Loads represent electricity demand at each bus
# INPUT: Loads{N}_sahar.csv or .json
# OUTPUT: Function that creates PSY.PowerLoad objects
# ============================================================================

"""
    read_loads_data(data_path::String, file_format::String="CSV")

WHAT: Reads electrical load (demand) parameters at each bus
WHY: Loads are the demand side of the power balance equation.
  - Each bus can have one or more loads
  - Loads can be constant or time-varying (via time series)
  - Load curtailment may be allowed at a penalty cost (VOLL)

STRUCTURE EXPECTED:
  Columns: LoadName, BusNumber, Available, ActivePower, ReactivePower,
           MaxActivePower, MaxReactivePower, BasePower, Model
  
  Model: "ConstantPower" (P+jQ fixed), "ConstantImpedance" (Z fixed),
         "ConstantCurrent" (I fixed)

RETURNS: Function(nodes) that creates Vector{PSY.PowerLoad}
"""
function read_loads_data(data_path::String, file_format::String="CSV")
    log_info("Reading loads data from: $data_path")
    
    if uppercase(file_format) == "CSV"
        df = CSV.read(data_path, DataFrame)
        
        loads_func = function(nodes)
            loads = PSY.PowerLoad[]
            for row in eachrow(df)
                # Resolve load model enum
                model = if hasproperty(row, :Model) && !ismissing(row.Model)
                    getfield(PSY, Symbol(row.Model))
                else
                    PSY.ConstantPower  # default
                end
                
                load = PSY.PowerLoad(
                    row.LoadName,
                    row.Available,
                    nodes[row.BusNumber],
                    model,
                    row.ActivePower,
                    row.ReactivePower,
                    row.MaxActivePower,
                    row.MaxReactivePower,
                    row.BasePower
                )
                push!(loads, load)
            end
            return loads
        end
        
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(data_path, String))
        
        loads_func = function(nodes)
            loads = PSY.PowerLoad[]
            for ld in json_data
                model = if haskey(ld, "Model")
                    getfield(PSY, Symbol(ld["Model"]))
                else
                    PSY.ConstantPower
                end
                
                load = PSY.PowerLoad(
                    ld["LoadName"],
                    ld["Available"],
                    nodes[ld["BusNumber"]],
                    model,
                    ld["ActivePower"],
                    ld["ReactivePower"],
                    ld["MaxActivePower"],
                    ld["MaxReactivePower"],
                    ld["BasePower"]
                )
                push!(loads, load)
            end
            return loads
        end
    else
        error("Unsupported file format: $file_format")
    end
    
    log_success("Loads data loaded successfully")
    return loads_func
end

# ============================================================================
# INTERNAL: Generic loader from CSV/JSON _sahar files
# ============================================================================
"""
    _resolve_sahar_file(data_dir, prefix, num_buses, ext; optional=false)

Find a `_sahar` data file. Tries `{prefix}{num_buses}_sahar.{ext}` in `data_dir`.
If `optional=true`, returns `nothing` instead of erroring when file is missing.
"""
function _resolve_sahar_file(data_dir::String, prefix::String, num_buses::Int, ext::String; optional::Bool=false)
    filename = "$(prefix)$(num_buses)_sahar.$(ext)"
    filepath = joinpath(data_dir, filename)
    if !isfile(filepath)
        if optional
            log_warn("Optional data file not found (skipping): $filepath")
            return nothing
        else
            error("❌ Data file not found: $filepath")
        end
    end
    return filepath
end

"""
    _load_case_from_files(data_dir::String, file_format::String, num_buses::Int)

Build a PowerSystems.System from the set of `_sahar` CSV/JSON files in `data_dir`.

Expected files (example for 118-bus CSV):
  - Nodes118_sahar.csv
  - Trans118_sahar.csv
  - ThermalGenerators118_sahar.csv
  - RenewableGenerators118_sahar.csv
  - HydroGenerators118_sahar.csv  (optional)
  - Storage118_sahar.csv          (optional)
  - TimeSeries_DA118_sahar.csv    (optional)
"""
function _load_case_from_files(data_dir::String, file_format::String, num_buses::Int)
    ext = uppercase(file_format) == "JSON" ? "json" : "csv"
    fmt = uppercase(file_format)
    case_label = "$(num_buses)bus"
    
    log_info("Loading $case_label case from $fmt files in: $data_dir")
    
    # Resolve required data files (with bus count in filename)
    nodes_path      = _resolve_sahar_file(data_dir, "Nodes", num_buses, ext)
    branches_path   = _resolve_sahar_file(data_dir, "Trans", num_buses, ext)
    thermal_path    = _resolve_sahar_file(data_dir, "ThermalGenerators", num_buses, ext)
    
    # Resolve optional data files
    renewable_path  = _resolve_sahar_file(data_dir, "RenewableGenerators", num_buses, ext; optional=true)
    hydro_path      = _resolve_sahar_file(data_dir, "HydroGenerators", num_buses, ext; optional=true)
    storage_path    = _resolve_sahar_file(data_dir, "Storage", num_buses, ext; optional=true)
    loads_path      = _resolve_sahar_file(data_dir, "Loads", num_buses, ext; optional=true)
    timeseries_path = _resolve_sahar_file(data_dir, "TimeSeries_DA", num_buses, ext; optional=true)
    
    # Read required data
    nodes_func          = read_nodes_data(nodes_path, fmt)
    branches_func       = read_branches_data(branches_path, fmt)
    thermal_gens_func   = read_thermal_generators_data(thermal_path, fmt)
    
    # Read optional data
    renewable_gens_func = isnothing(renewable_path) ? (_->PSY.RenewableDispatch[]) : read_renewable_generators_data(renewable_path, fmt)
    hydro_gens_func     = isnothing(hydro_path) ? (_->[]) : read_hydro_generators_data(hydro_path, fmt)
    storage_func        = isnothing(storage_path) ? (_->PSY.EnergyReservoirStorage[]) : read_storage_data(storage_path, fmt)
    loads_func          = isnothing(loads_path) ? (_->PSY.PowerLoad[]) : read_loads_data(loads_path, fmt)
    timeseries_data     = isnothing(timeseries_path) ? Dict{String,Any}() : read_timeseries_data(timeseries_path, fmt)
    
    # Create objects
    nodes       = nodes_func()
    branches    = branches_func(nodes)
    thermal     = thermal_gens_func(nodes)
    renewables  = renewable_gens_func(nodes)
    hydro       = hydro_gens_func(nodes)
    storage     = storage_func(nodes)
    loads       = loads_func(nodes)
    
    # Bundle into a system data dict
    system_data = Dict(
        "nodes"       => nodes,
        "branches"    => branches,
        "thermal"     => thermal,
        "renewables"  => renewables,
        "hydro"       => hydro,
        "storage"     => storage,
        "loads"       => loads,
        "timeseries"  => timeseries_data,
        "case_label"  => case_label,
        "num_buses"   => num_buses
    )
    
    # Build PowerSystems.System
    system = PSY.System(100.0)  # 100 MVA base
    for bus in nodes
        PSY.add_component!(system, bus)
    end
    for branch in branches
        PSY.add_component!(system, branch)
    end
    for gen in thermal
        PSY.add_component!(system, gen)
    end
    for gen in renewables
        PSY.add_component!(system, gen)
    end
    for gen in hydro
        PSY.add_component!(system, gen)
    end
    for dev in storage
        PSY.add_component!(system, dev)
    end
    for ld in loads
        PSY.add_component!(system, ld)
    end
    
    log_success("$case_label system created: $(length(nodes)) buses, $(length(branches)) branches, " *
                "$(length(thermal)) thermal, $(length(renewables)) renewable, $(length(hydro)) hydro, " *
                "$(length(storage)) storage, $(length(loads)) loads")
    
    return system, system_data
end

"""
    load_from_csv_json(data_dir::String, file_format::String="CSV"; num_buses::Int=0)

Load case data from CSV/JSON files using generic data reader.
If `num_buses` is 0, tries to auto-detect from files in `data_dir`.
"""
function load_from_csv_json(data_dir::String, file_format::String="CSV"; num_buses::Int=0)
    println("  - Loading from $file_format files in $data_dir")
    
    if num_buses > 0
        return _load_case_from_files(data_dir, file_format, num_buses)
    end
    
    # Auto-detect bus count from Nodes*_sahar files
    ext = uppercase(file_format) == "JSON" ? "json" : "csv"
    for f in readdir(data_dir)
        m = match(r"Nodes(\d+)_sahar\.", f)
        if !isnothing(m)
            detected = parse(Int, m.captures[1])
            log_info("Auto-detected $(detected)-bus case from file: $f")
            return _load_case_from_files(data_dir, file_format, detected)
        end
    end
    
    error("❌ Could not auto-detect bus count. No Nodes*_sahar.$ext file found in $data_dir. " *
          "Pass num_buses explicitly.")
end

log_info("Data reader module loaded successfully")

"""
Case-Specific Data Readers for PowerLASCOPF

Loads data for specific test cases by including their data files.
Called by data_reader_generic.jl

Supported cases: 5-bus, 14-bus, 30-bus, 48-bus, 57-bus, 118-bus, 300-bus
"""

"""
    load_5bus_case(data_dir::String, file_format::String="CSV")

Load 5-bus test case data.
- If data_5bus_pu.jl exists, use it directly.
- Otherwise, read from CSV/JSON files with `_sahar` suffix in `data_dir`.
"""
function load_5bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 5-bus system (format: $file_format, dir: $data_dir)")
    
    # Try the Julia data file first
    data_file = joinpath(@__DIR__, "data_5bus_pu.jl")
    if isfile(data_file)
        include(data_file)
        system, system_data = create_5bus_powerlascopf_system()
        return system, system_data
    end
    
    # Fall back to CSV/JSON in data_dir
    return _load_case_from_files(data_dir, file_format, 5)
end

"""
    load_14bus_case(data_dir::String, file_format::String="CSV")

Load 14-bus test case data.
"""
function load_14bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 14-bus system (format: $file_format, dir: $data_dir)")
    
    data_file = joinpath(@__DIR__, "data_14bus_pu.jl")
    if isfile(data_file)
        include(data_file)
        system, system_data = create_14bus_powerlascopf_system()
        return system, system_data
    end
    
    return _load_case_from_files(data_dir, file_format, 14)
end

"""
    load_30bus_case(data_dir::String, file_format::String="CSV")

Load IEEE 30-bus test case data from CSV/JSON files with `_sahar` suffix.
"""
function load_30bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 30-bus system (format: $file_format, dir: $data_dir)")

    data_folder = joinpath(data_dir, "IEEE_30_bus")
    
    return _load_case_from_files(data_folder, file_format, 30)
end

"""
    load_48bus_case(data_dir::String, file_format::String="CSV")

Load IEEE 48-bus (reliability test system) case data from CSV/JSON files with `_sahar` suffix.
"""
function load_48bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 48-bus system (format: $file_format, dir: $data_dir)")

    data_folder = joinpath(data_dir, "IEEE_48_bus")
    return _load_case_from_files(data_folder, file_format, 48)
end

"""
    load_57bus_case(data_dir::String, file_format::String="CSV")

Load IEEE 57-bus test case data from CSV/JSON files with `_sahar` suffix.
"""
function load_57bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 57-bus system (format: $file_format, dir: $data_dir)")
    data_folder = joinpath(data_dir, "IEEE_57_bus")
    return _load_case_from_files(data_folder, file_format, 57)
end

"""
    load_118bus_case(data_dir::String, file_format::String="CSV")

Load IEEE 118-bus test case data from CSV/JSON files with `_sahar` suffix.
"""
function load_118bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 118-bus system (format: $file_format, dir: $data_dir)")
    data_folder = joinpath(data_dir, "IEEE_118_bus")
    return _load_case_from_files(data_folder, file_format, 118)
end

"""
    load_300bus_case(data_dir::String, file_format::String="CSV")

Load IEEE 300-bus test case data from CSV/JSON files with `_sahar` suffix.
"""
function load_300bus_case(data_dir::String, file_format::String="CSV")
    println("  - Loading 300-bus system (format: $file_format, dir: $data_dir)")
    data_folder = joinpath(data_dir, "IEEE_300_bus")
    return _load_case_from_files(data_folder, file_format, 300)
end

# ============================================================
# SECTION: CONTINGENCY LISTS FOR IEEE TEST CASES
# Extracted from ContingencyMarked column in Trans*_sahar.csv
# ============================================================

"""
    branches_contingency_list(num_buses::Int; data_dir::String=joinpath(@__DIR__, "IEEE_Test_Cases"), file_format::String="CSV")

Read the ContingencyMarked column from the Trans{num_buses}_sahar.csv (or .json) file
and return the 1-based row indices where ContingencyMarked == 1.

Replaces the per-case hardcoded functions (branches_57_contingency_list, etc.).

# Arguments
- `num_buses::Int`: Number of buses (e.g., 57, 118, 300).
- `data_dir::String`: Directory containing the IEEE_*_bus subdirectories.
- `file_format::String`: "CSV" or "JSON".

# Returns
- `Vector{Int}`: 1-based row indices of contingency-marked branches.

# Example
```julia
cont_list = branches_contingency_list(57)   # reads IEEE_57_bus/Trans57_sahar.csv
cont_list = branches_contingency_list(118)  # reads IEEE_118_bus/Trans118_sahar.csv
```
"""
function branches_contingency_list(
    num_buses::Int;
    data_dir::String = joinpath(@__DIR__, "IEEE_Test_Cases"),
    file_format::String = "CSV"
)
    subfolder = joinpath(data_dir, "IEEE_$(num_buses)_bus")
    ext = uppercase(file_format) == "JSON" ? "json" : "csv"
    filepath = joinpath(subfolder, "Trans$(num_buses)_sahar.$(ext)")

    if !isfile(filepath)
        error("❌ Contingency file not found: $filepath")
    end

    contingency_indices = Int[]

    if uppercase(file_format) == "CSV"
        df = CSV.read(filepath, DataFrame)
        if !("ContingencyMarked" in names(df))
            log_warn("No 'ContingencyMarked' column in $filepath — returning empty list.")
            return contingency_indices
        end
        for (i, row) in enumerate(eachrow(df))
            if !ismissing(row.ContingencyMarked) && row.ContingencyMarked == 1
                push!(contingency_indices, i)
            end
        end
    elseif uppercase(file_format) == "JSON"
        json_data = JSON3.read(read(filepath, String))
        for (i, branch) in enumerate(json_data)
            if haskey(branch, "ContingencyMarked") && branch["ContingencyMarked"] == 1
                push!(contingency_indices, i)
            end
        end
    else
        error("Unsupported file format: $file_format. Use 'CSV' or 'JSON'.")
    end

    log_info("Contingency list for $(num_buses)-bus case: $(length(contingency_indices)) branches marked — indices: $contingency_indices")
    return contingency_indices
end

# Convenience wrappers for backward compatibility (optional — can be removed)
branches_57_contingency_list()  = branches_contingency_list(57)
branches_118_contingency_list() = branches_contingency_list(118)
branches_300_contingency_list() = branches_contingency_list(300)

# ============================================================
# SECTION: GENERIC POWERLASCOPF SYSTEM CREATION FROM CSV FILES
# Following the same pattern as data_5bus_pu.jl / data_14bus_pu.jl
# but reading from *_sahar.csv files instead of hardcoded arrays.
# ============================================================
# ============================================================
# SECTION: GENERIC FUNCTIONS
# ============================================================

"""
Create PowerLASCOPF System from PSY System
"""
function power_lascopf_system_generic()
    println("Creating PowerLASCOPF System from PSY System...")
    log_info("Creating PowerLASCOPF System from PSY System...")
    system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
    
    println("Created PowerLASCOPF System ")
    log_info("Created PowerLASCOPF System ")
    return system
end

function powerlascopf_nodes_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Nodes$(bus_num)_sahar.csv")
    json_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Nodes$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        return powerlascopf_nodes_from_csv!(system, csv_path)
    elseif isfile(json_path) && !csv_path
        return powerlascopf_nodes_from_json!(system, json_path)
    else
        error("No valid node file found for $bus_num-bus case.")
    end
end

function powerlascopf_branches_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, cont_count::Int, RND_int::Int, 
    csv_path::Bool = true
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Trans$(bus_num)_sahar.csv")
    json_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Trans$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        return powerlascopf_branches_from_csv!(
            system, nodes, csv_path, branches_contingency_list(bus_num), cont_count, RND_int
        )
    elseif isfile(json_path) && !csv_path
        return powerlascopf_branches_from_json!(
            system, nodes, json_path, branches_contingency_list(bus_num), cont_count, RND_int
        )
    else
        error("No valid branch file found for $bus_num-bus case.")
    end
end

function powerlascopf_thermal_generators_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "ThermalGenerators$(bus_num)_sahar.csv")
    json_path  = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "ThermalGenerators$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        cont_count = length(branches_contingency_list(bus_num))
        return powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, cont_count)
    elseif isfile(json_path) && !csv_path
        cont_count = length(branches_contingency_list(bus_num))
        return powerlascopf_thermal_generators_from_json!(system, nodes, json_path, cont_count)
    else
        error("No valid thermal generator file found for $bus_num-bus case.")
    end
end

function powerlascopf_renewable_generators_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "RenewableGenerators$(bus_num)_sahar.csv")
    json_path  = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "RenewableGenerators$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        cont_count = length(branches_57_contingency_list())
        return powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
    elseif isfile(json_path) && !csv_path
        cont_count = length(branches_57_contingency_list())
        return powerlascopf_renewable_generators_from_json!(system, nodes, json_path, Dict(), cont_count)
    else
        error("No valid renewable generator file found for $bus_num-bus case.")
    end
end

function powerlascopf_hydro_generators_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "HydroGenerators$(bus_num)_sahar.csv")
    json_path  = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "HydroGenerators$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        cont_count = length(branches_118_contingency_list())
        return powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
    elseif isfile(json_path) && !csv_path
        cont_count = length(branches_118_contingency_list())
        return powerlascopf_hydro_generators_from_json!(system, nodes, json_path, Dict(), cont_count)
    else
        error("No valid hydro generator file found for $bus_num-bus case.")
    end
end

function power_lascopf_storage_generators_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Storage$(bus_num)_sahar.csv")
    json_path  = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Storage$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        cont_count = length(branches_57_contingency_list())
        return powerlascopf_storage_from_csv!(system, nodes, csv_path, cont_count)
    elseif isfile(json_path) && !csv_path
        cont_count = length(branches_57_contingency_list())
        return powerlascopf_storage_from_json!(system, nodes, json_path, cont_count)
    else
        error("No valid storage file found for $bus_num-bus case.")
    end
end

function powerlascopf_loads_generic!(
    system::PowerLASCOPF.PowerLASCOPFSystem, 
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, 
    bus_num::Int, csv_path::Bool = true
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Loads$(bus_num)_sahar.csv")
    json_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_$(bus_num)_bus", "Loads$(bus_num)_sahar.json")
    if isfile(csv_path) && csv_path
        return powerlascopf_loads_from_csv!(system, nodes, csv_path)
    elseif isfile(json_path) && !csv_path
        return powerlascopf_loads_from_json!(system, nodes, json_path)
    else
        error("No valid load file found for $bus_num-bus case.")
    end
end

"""
    create_generic_powerlascopf_system(bus_num::Int)

Create a complete PowerLASCOPF system for a generic test case,
reading all data from *_sahar.csv files.
"""
function create_generic_powerlascopf_system(bus_num::Int)
    log_info("Creating a Generic PowerLASCOPF system...")
    cont_count = length(branches_contingency_list(bus_num))
    RND_int    = 6
    RSD_int    = 6

    system    = power_lascopf_system_generic()
    nodes     = powerlascopf_nodes_generic!(system, bus_num, true)
    branches  = powerlascopf_branches_generic!(system, nodes, bus_num, cont_count, RND_int, true)
    thermal   = powerlascopf_thermal_generators_generic!(system, nodes, bus_num, true)
    renewables = powerlascopf_renewable_generators_generic!(system, nodes, bus_num, true)
    hydro     = powerlascopf_hydro_generators_generic!(system, nodes, bus_num, true)
    storage   = power_lascopf_storage_generators_generic!(system, nodes, bus_num, true)
    loads     = powerlascopf_loads_generic!(system, nodes, bus_num, true)
    system_data = Dict(
        "name"                   => "$bus_num-Bus IEEE Test System",
        "nodes"                  => nodes,
        "branches"               => branches,
        "thermal_generators"     => thermal,
        "renewable_generators"   => renewables,
        "hydro_generators"       => hydro,
        "storage_generators"     => storage,
        "loads"                  => loads,
        "number_of_contingencies" => cont_count,
        "RND_intervals"          => RND_int,
        "RSD_intervals"          => RSD_int,
        "base_power"             => 100.0
    )

    log_info("Generic PowerLASCOPF system created successfully.")
    return system, system_data
end

"""
    powerlascopf_nodes_from_csv!(system, csv_path)

Read nodes from a Nodes*_sahar.csv file and create PowerLASCOPF Nodes.
Expected CSV columns: BusNumber, BusName, BusType, Angle, Voltage,
                      VoltageMin, VoltageMax, BaseVoltage
"""
function powerlascopf_nodes_from_csv!(system::PowerLASCOPF.PowerLASCOPFSystem, csv_path::String)
    log_info("Creating PowerLASCOPF Nodes from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)
    nodes = PowerLASCOPF.Node{PSY.Bus}[]

    for (i, row) in enumerate(eachrow(df))
        bus = PSY.ACBus(
            Int(row.BusNumber),
            String(row.BusName),
            String(row.BusType),
            Float64(row.Angle),
            Float64(row.Voltage),
            (min = Float64(row.VoltageMin), max = Float64(row.VoltageMax)),
            Float64(row.BaseVoltage),
            nothing,
            nothing
        )
        println("PSY bus name", PSY.get_name(bus))  # just to suppress unused variable warning
        log_info("PSY bus name: $(PSY.get_name(bus))")
        node = PowerLASCOPF.Node{PSY.Bus}(bus, i, 0)
        PSY.add_component!(system.psy_system, bus)
        PowerLASCOPF.add_node!(system, node)
        push!(nodes, node)
    end
    println("=" ^ 50)
    println("PSY System after adding nodes: ", system.psy_system)
    log_info("PSY System after adding nodes: $(system.psy_system)")
    println("PowerLASCOPF System after adding nodes: ", system)
    log_info("PowerLASCOPF System after adding nodes: $(system)")
    println("Node vector from 14 bus file", nodes)
    log_info("Node vector from 14 bus file: $(nodes)")
    println("Node vector from PowerLASCOPF struct", system.nodes)
    log_info("Node vector from PowerLASCOPF struct: $(system.nodes)")
    PSY.show_components(system.psy_system, PSY.ACBus)
    log_info("Showing PSY ACBus components in the system.")
    log_info("Created $(length(nodes)) PowerLASCOPF Nodes from CSV.")
    println("Created $(length(nodes)) PowerLASCOPF Nodes from CSV: $csv_path")
    return nodes
end

"""
    powerlascopf_nodes_from_json!(system, csv_path)

Read nodes from a Nodes*_sahar.csv file and create PowerLASCOPF Nodes.
Expected CSV columns: BusNumber, BusName, BusType, Angle, Voltage,
                      VoltageMin, VoltageMax, BaseVoltage
"""

function powerlascopf_nodes_from_json!(system::PowerLASCOPF.PowerLASCOPFSystem, json_path::String)
    log_info("Creating PowerLASCOPF Nodes from JSON: $json_path")
    json_data = JSON.parsefile(json_path)
    nodes = PowerLASCOPF.Node{PSY.Bus}[]

    for (i, row) in enumerate(json_data)
        bus = PSY.ACBus(
            Int(row["BusNumber"]),
            String(row["BusName"]),
            String(row["BusType"]),
            Float64(row["Angle"]),
            Float64(row["Voltage"]),
            (min = Float64(row["VoltageMin"]), max = Float64(row["VoltageMax"])),
            Float64(row["BaseVoltage"]),
            nothing,
            nothing
        )
        println("PSY bus name", PSY.get_name(bus))  # just to suppress unused variable warning
        log_info("PSY bus name: $(PSY.get_name(bus))")
        node = PowerLASCOPF.Node{PSY.Bus}(bus, i, 0)
        PSY.add_component!(system.psy_system, bus)
        PowerLASCOPF.add_node!(system, node)
        push!(nodes, node)
    end
    println("=" ^ 50)
    println("PSY System after adding nodes: ", system.psy_system)
    log_info("PSY System after adding nodes: $(system.psy_system)")
    println("PowerLASCOPF System after adding nodes: ", system)
    log_info("PowerLASCOPF System after adding nodes: $(system)")
    println("Node vector from 14 bus file", nodes)
    log_info("Node vector from 14 bus file: $(nodes)")
    println("Node vector from PowerLASCOPF struct", system.nodes)
    log_info("Node vector from PowerLASCOPF struct: $(system.nodes)")
    PSY.show_components(system.psy_system, PSY.ACBus)
    log_info("Showing PSY ACBus components in the system.")
    log_info("Created $(length(nodes)) PowerLASCOPF Nodes from JSON.")
    println("Created $(length(nodes)) PowerLASCOPF Nodes from JSON: $json_path")
    return nodes
end

"""
    powerlascopf_branches_from_csv!(system, nodes, csv_path, contingency_list, cont_count, RND_int)

Read branches from a Trans*_sahar.csv file and create PowerLASCOPF transmission lines.
Expected CSV columns: LineName, LineType, fromNode, toNode, Resistance, Reactance,
  Susceptance_from, Susceptance_to, RateLimit, AngleLimit_min, AngleLimit_max,
  [ActivePowerLimit_min, ActivePowerLimit_max, ReactivePower_from_min,
   ReactivePower_from_max, ReactivePower_to_min, ReactivePower_to_max,
   LossCoefficient_l0, LossCoefficient_l1], ContingencyMarked
"""
function powerlascopf_branches_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    contingency_list::Vector{Int},
    cont_count::Int,
    RND_int::Int
)
    log_info("Creating PowerLASCOPF Branches from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    # Build fast lookup: bus number -> node/bus
    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)

    transmission_lines = PowerLASCOPF.transmissionLine[]
    contingency_tracker = 0

    for (i, row) in enumerate(eachrow(df))
        line_type = String(row.LineType)
        from_num  = Int(row.fromNode)
        to_num    = Int(row.toNode)
        from_bus  = bus_by_busnum[from_num]
        to_bus    = bus_by_busnum[to_num]
        from_node = node_by_busnum[from_num]
        to_node   = node_by_busnum[to_num]

        if i in contingency_list
            contingency_tracker += 1
            temp_tracker = contingency_tracker
        else
            temp_tracker = 0
        end

        if line_type == "AC"
            branch = PSY.Line(
                String(row.LineName),
                true,
                0.0,
                0.0,
                Arc(from = from_bus, to = to_bus),
                Float64(row.Resistance),
                Float64(row.Reactance),
                (from = Float64(row.Susceptance_from), to = Float64(row.Susceptance_to)),
                Float64(row.RateLimit),
                (min = Float64(row.AngleLimit_min), max = Float64(row.AngleLimit_max))
            )

            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = randn(cont_count * (RND_int - 1)),
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [0.9^j for j in 1:RND_int],
                Pt_next_nu    = zeros(cont_count * (RND_int - 1)),
                BSC           = 0.1 * randn(cont_count * (RND_int - 1)),
                E_temp_coeff  = 0.01 * randn(RND_int, RND_int),
                alpha_factor  = 0.05,
                beta_factor   = 0.1,
                beta          = 0.1,
                gamma         = 0.2,
                Pt_max        = 1000.0,
                temp_init     = 340.0,
                temp_amb      = 300.0,
                max_temp      = 473.0,
                RND_int       = 1,
                cont_count    = cont_count
            )

            trans_line = PowerLASCOPF.transmissionLine{PSY.Line}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0,     pt2 = 0.0,
                v1  = 0.0,     v2  = 0.0
            )

            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)

        elseif line_type == "HVDC"
            branch = PSY.HVDCLine(
                String(row.LineName),
                true,
                0.0,
                Arc(from = from_bus, to = to_bus),
                (min = Float64(row.ActivePowerLimit_min),  max = Float64(row.ActivePowerLimit_max)),
                (min = Float64(row.ReactivePower_from_min), max = Float64(row.ReactivePower_from_max)),
                (min = Float64(row.ReactivePower_to_min),  max = Float64(row.ReactivePower_to_max)),
                (min = Float64(row.ReactivePower_to_min),  max = Float64(row.ReactivePower_to_max)),
                (l0  = Float64(row.LossCoefficient_l0),   l1  = Float64(row.LossCoefficient_l1))
            )

            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = [0.0],
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [1.0],
                Pt_next_nu    = [0.0],
                BSC           = [0.0],
                E_temp_coeff  = reshape([0.1], 1, 1),
                RND_int       = 1,
                cont_count    = 1
            )

            trans_line = PowerLASCOPF.transmissionLine{PSY.HVDCLine}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0,     pt2 = 0.0,
                v1  = 0.0,     v2  = 0.0
            )

            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)
        end
    end
    println("=" ^ 50)
    println("PSY System after adding branches: ", system.psy_system)
    log_info("PSY System after adding branches: $(system.psy_system)")
    println("PowerLASCOPF System after adding branches: ", system)
    log_info("PowerLASCOPF System after adding branches: $(system)")
    #println("Transmission Lines vector from 14 bus file", transmission_lines)
    #println("Transmission Lines vector from PowerLASCOPF struct", system.transmission_lines)
    PSY.show_components(system.psy_system, PSY.Line)
    #PSY.show_components(system.psy_system, PSY.HVDCLine)
    log_info("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from CSV.")
    println("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from CSV: $csv_path")
    return transmission_lines
end

"""
    powerlascopf_branches_from_json!(system, nodes, json_path, contingency_list, cont_count, RND_int)

Read branches from a Trans*_sahar.json file and create PowerLASCOPF transmission lines.
Expected CSV columns: LineName, LineType, fromNode, toNode, Resistance, Reactance,
  Susceptance_from, Susceptance_to, RateLimit, AngleLimit_min, AngleLimit_max,
  [ActivePowerLimit_min, ActivePowerLimit_max, ReactivePower_from_min,
   ReactivePower_from_max, ReactivePower_to_min, ReactivePower_to_max,
   LossCoefficient_l0, LossCoefficient_l1], ContingencyMarked
"""
function powerlascopf_branches_from_json!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    json_path::String,
    contingency_list::Vector{Int},
    cont_count::Int,
    RND_int::Int
)
    log_info("Creating PowerLASCOPF Transmission Lines from JSON: $json_path")
    json_data = JSON3.read(read(json_path, String))

    # Build fast lookup: bus number -> node/bus
    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)

    transmission_lines = PowerLASCOPF.transmissionLine[]
    contingency_tracker = 0

    for (i, row) in json_data
        line_type = String(row["LineType"])
        from_num  = Int(row["fromNode"])
        to_num    = Int(row["toNode"])
        from_bus  = bus_by_busnum[from_num]
        to_bus    = bus_by_busnum[to_num]
        from_node = node_by_busnum[from_num]
        to_node   = node_by_busnum[to_num]

        if i in contingency_list
            contingency_tracker += 1
            temp_tracker = contingency_tracker
        else
            temp_tracker = 0
        end

        if line_type == "AC"
            branch = PSY.Line(
                String(row["LineName"]),
                true,
                0.0,
                0.0,
                Arc(from = from_bus, to = to_bus),
                Float64(row["Resistance"]),
                Float64(row["Reactance"]),
                (from = Float64(row["Susceptance_from"]), to = Float64(row["Susceptance_to"])),
                Float64(row["RateLimit"]),
                (min = Float64(row["AngleLimit_min"]), max = Float64(row["AngleLimit_max"]))
            )

            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = randn(cont_count * (RND_int - 1)),
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [0.9^j for j in 1:RND_int],
                Pt_next_nu    = zeros(cont_count * (RND_int - 1)),
                BSC           = 0.1 * randn(cont_count * (RND_int - 1)),
                E_temp_coeff  = 0.01 * randn(RND_int, RND_int),
                alpha_factor  = 0.05,
                beta_factor   = 0.1,
                beta          = 0.1,
                gamma         = 0.2,
                Pt_max        = 1000.0,
                temp_init     = 340.0,
                temp_amb      = 300.0,
                max_temp      = 473.0,
                RND_int       = 1,
                cont_count    = cont_count
            )

            trans_line = PowerLASCOPF.transmissionLine{PSY.Line}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0,     pt2 = 0.0,
                v1  = 0.0,     v2  = 0.0
            )

            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)

        elseif line_type == "HVDC"
            branch = PSY.HVDCLine(
                String(row["LineName"]),
                true,
                0.0,
                Arc(from = from_bus, to = to_bus),
                (min = Float64(row["ActivePowerLimit_min"]),  max = Float64(row["ActivePowerLimit_max"])),
                (min = Float64(row["ReactivePower_from_min"]), max = Float64(row["ReactivePower_from_max"])),
                (min = Float64(row["ReactivePower_to_min"]),  max = Float64(row["ReactivePower_to_max"])),
                (min = Float64(row["ReactivePower_to_min"]),  max = Float64(row["ReactivePower_to_max"])),
                (l0  = Float64(row["LossCoefficient_l0"]),   l1  = Float64(row["LossCoefficient_l1"])))

            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = [0.0],
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [1.0],
                Pt_next_nu    = [0.0],
                BSC           = [0.0],
                E_temp_coeff  = reshape([0.1], 1, 1),
                RND_int       = 1,
                cont_count    = 1
            )

            trans_line = PowerLASCOPF.transmissionLine{PSY.HVDCLine}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0,     pt2 = 0.0,
                v1  = 0.0,     v2  = 0.0
            )

            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)
        end
    end
    println("=" ^ 50)
    println("PSY System after adding branches: ", system.psy_system)
    log_info("PSY System after adding branches: $(system.psy_system)")
    println("PowerLASCOPF System after adding branches: ", system)
    log_info("PowerLASCOPF System after adding branches: $(system)")
    #println("Transmission Lines vector from 14 bus file", transmission_lines)
    #println("Transmission Lines vector from PowerLASCOPF struct", system.transmission_lines)
    PSY.show_components(system.psy_system, PSY.Line)
    #PSY.show_components(system.psy_system, PSY.HVDCLine)
    log_info("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from JSON.")
    println("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from JSON: $json_path")
    return transmission_lines
end

"""
    _make_gen_interval(cont_count::Int)

Helper to create a standard GenFirstBaseInterval initialised to zero.
Uses the same parameter values as data_14bus_pu.jl.
"""
function _make_gen_interval(cont_count::Int)
    return PowerLASCOPF.GenFirstBaseInterval(
        zeros(cont_count + 1),  # lambda_1
        zeros(cont_count + 1),  # lambda_2
        zeros(cont_count + 1),  # B
        zeros(cont_count + 1),  # D
        zeros(cont_count),      # BSC
        cont_count,             # cont_count
        0.1,                    # rho
        0.1,                    # beta
        0.1,                    # beta_inner
        0.2,                    # gamma
        0.2,                    # gamma_sc
        zeros(cont_count),      # lambda_1_sc
        0.0,                    # Pg_N_init
        0.0,                    # Pg_N_avg
        0.0,                    # thetag_N_avg
        0.0,                    # ug_N
        1.0,                    # vg_N
        1.0,                    # Vg_N_avg
        0.0,                    # Pg_nu
        0.0,                    # Pg_nu_inner
        zeros(cont_count),      # Pg_next_nu
        0.0                     # Pg_prev
    )
end

"""
    powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, cont_count)

Read thermal generators from a ThermalGenerators*_sahar.csv file and create
PowerLASCOPF GeneralizedGenerators.

Expected CSV columns: GeneratorName, BusNumber, Available, [Status], ActivePower,
  ReactivePower, Rating, PrimeMover, Fuel, ActivePowerMin, ActivePowerMax,
  ReactivePowerMin, ReactivePowerMax, [RampUp, RampDown, TimeLimitUp, TimeLimitDown],
  CostCurve_a, CostCurve_b, CostCurve_c, FuelCost, [VOM_Cost], FixedCost,
  [StartUpCost, ShutDownCost], BasePower
"""
function powerlascopf_thermal_generators_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    cont_count::Int = 6
)
    log_info("Creating PowerLASCOPF Thermal Generators from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    cols = names(df)

    for (i, row) in enumerate(eachrow(df))
        bus_num = Int(row.BusNumber)
        bus     = bus_by_busnum[bus_num]
        node    = node_by_busnum[bus_num]

        # Handle optional columns with defaults
        status       = "Status"       in cols ? Bool(row.Status)       : true
        ramp_up      = "RampUp"       in cols && !ismissing(row.RampUp) ? Float64(row.RampUp) : nothing
        ramp_down    = "RampDown"     in cols && !ismissing(row.RampDown) ? Float64(row.RampDown) : nothing
        time_up      = "TimeLimitUp"  in cols && !ismissing(row.TimeLimitUp) ? Float64(row.TimeLimitUp) : nothing
        time_down    = "TimeLimitDown" in cols && !ismissing(row.TimeLimitDown) ? Float64(row.TimeLimitDown) : nothing
        vom_cost     = "VOM_Cost"     in cols ? Float64(row.VOM_Cost)  : 0.0
        startup_cost = "StartUpCost"  in cols ? Float64(row.StartUpCost) : 0.0
        shutdown_cost = "ShutDownCost" in cols ? Float64(row.ShutDownCost) : 0.0

        ramp_limits = (ramp_up !== nothing && ramp_down !== nothing) ?
                      (up = ramp_up, down = ramp_down) : nothing
        time_limits = (time_up !== nothing && time_down !== nothing) ?
                      (up = time_up, down = time_down) : nothing

        gen = PSY.ThermalStandard(
            name              = String(row.GeneratorName),
            available         = Bool(row.Available),
            status            = status,
            bus               = bus,
            active_power      = Float64(row.ActivePower),
            reactive_power    = Float64(row.ReactivePower),
            rating            = Float64(row.Rating),
            prime_mover_type  = getfield(PrimeMovers, Symbol(row.PrimeMover)),
            fuel              = getfield(ThermalFuels, Symbol(get(row, :Fuel, "COAL"))),
            active_power_limits   = (min = Float64(row.ActivePowerMin),  max = Float64(row.ActivePowerMax)),
            reactive_power_limits = (min = Float64(row.ReactivePowerMin), max = Float64(row.ReactivePowerMax)),
            ramp_limits       = ramp_limits,
            time_limits       = time_limits,
            operation_cost    = PSY.ThermalGenerationCost(
                variable = IS.FuelCurve(
                    value_curve = IS.QuadraticCurve(
                        Float64(row.CostCurve_a),
                        Float64(row.CostCurve_b),
                        Float64(row.CostCurve_c)
                    ),
                    fuel_cost = Float64(row.FuelCost),
                    vom_cost  = IS.LinearCurve(vom_cost)
                ),
                fixed     = Float64(row.FixedCost),
                start_up  = startup_cost,
                shut_down = shutdown_cost
            ),
            base_power = Float64(row.BasePower)
        )

        PSY.add_component!(system.psy_system, gen)

        gen_interval = _make_gen_interval(cont_count)

        extended_cost = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen  = PowerLASCOPF.ExtendedThermalGenerator(
            gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_thermal_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(generators, lascopf_gen)
    end

    log_info("Created $(length(generators)) PowerLASCOPF Thermal Generators from CSV.")
    println("Created $(length(generators)) PowerLASCOPF Thermal Generators from CSV: $csv_path")
    return generators
end

"""
    powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, timeseries_data, cont_count)

Read renewable generators from a RenewableGenerators*_sahar.csv file.
Expected CSV columns: GeneratorName, BusNumber, Available, ActivePower, ReactivePower,
  Rating, PrimeMover, ReactivePowerMin, ReactivePowerMax, PowerFactor, VariableCost, BasePower
"""
function powerlascopf_renewable_generators_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    timeseries_data::Dict = Dict(),
    cont_count::Int = 6
)
    log_info("Creating PowerLASCOPF Renewable Generators from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)
    generators = PowerLASCOPF.GeneralizedGenerator[]

    DayAhead = get(timeseries_data, "DayAhead",
        collect(DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Hour(1):
                DateTime("1/1/2024 23:00:00", "d/m/y H:M:S")))
    wind_ts  = get(timeseries_data, "wind_ts_DA",  zeros(24))
    solar_ts = get(timeseries_data, "solar_ts_DA", zeros(24))

    for (i, row) in enumerate(eachrow(df))
        bus_num = Int(row.BusNumber)
        bus     = bus_by_busnum[bus_num]
        node    = node_by_busnum[bus_num]

        gen = PSY.RenewableDispatch(
            String(row.GeneratorName),
            Bool(row.Available),
            bus,
            Float64(row.ActivePower),
            Float64(row.ReactivePower),
            Float64(row.Rating),
            getfield(PrimeMovers, Symbol(row.PrimeMover)),
            (min = Float64(row.ReactivePowerMin), max = Float64(row.ReactivePowerMax)),
            Float64(row.PowerFactor),
            PSY.RenewableGenerationCost(CostCurve(LinearCurve(Float64(row.VariableCost)))),
            Float64(row.BasePower)
        )

        PSY.add_component!(system.psy_system, gen)

        # Add time series
        if PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.WT
            ts_data = TimeSeries.TimeArray(DayAhead, wind_ts)
            PSY.add_time_series!(system.psy_system, gen, PSY.SingleTimeSeries("max_active_power", ts_data))
        elseif PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.PVe
            ts_data = TimeSeries.TimeArray(DayAhead, solar_ts)
            PSY.add_time_series!(system.psy_system, gen, PSY.SingleTimeSeries("max_active_power", ts_data))
        end

        gen_interval = _make_gen_interval(cont_count)

        extended_cost = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen  = PowerLASCOPF.ExtendedRenewableGenerator(
            gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_renewable_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(generators, lascopf_gen)
    end

    log_info("Created $(length(generators)) PowerLASCOPF Renewable Generators from CSV.")
    println("Created $(length(generators)) PowerLASCOPF Renewable Generators from CSV: $csv_path")
    return generators
end

"""
    powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, timeseries_data, cont_count)

Read hydro generators from a HydroGenerators*_sahar.csv file.
Expected CSV columns: GeneratorName, BusNumber, GeneratorType, Available, ActivePower,
  ReactivePower, Rating, PrimeMover, ActivePowerMin, ActivePowerMax, ReactivePowerMin,
  ReactivePowerMax, [RampUp, RampDown], VariableCost, FuelCost, FixedCost, BasePower,
  [StorageCapacity, Inflow, ConversionFactor, InitialStorage, ...]
"""
function powerlascopf_hydro_generators_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    timeseries_data::Dict = Dict(),
    cont_count::Int = 6
)
    log_info("Creating PowerLASCOPF Hydro Generators from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    cols = names(df)

    DayAhead = get(timeseries_data, "DayAhead",
        collect(DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Hour(1):
                DateTime("1/1/2024 23:00:00", "d/m/y H:M:S")))
    hydro_ts = get(timeseries_data, "hydro_inflow_ts_DA", zeros(24))

    for (i, row) in enumerate(eachrow(df))
        bus_num   = Int(row.BusNumber)
        bus       = bus_by_busnum[bus_num]
        node      = node_by_busnum[bus_num]
        hydro_type = String(row.GeneratorType)

        ramp_up   = "RampUp"   in cols && !ismissing(row.RampUp)   ? Float64(row.RampUp)   : nothing
        ramp_down = "RampDown" in cols && !ismissing(row.RampDown) ? Float64(row.RampDown) : nothing
        ramp_limits = (ramp_up !== nothing && ramp_down !== nothing) ?
                      (up = ramp_up, down = ramp_down) : nothing

        hydro_cost = PSY.HydroGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.LinearCurve(Float64(row.VariableCost)),
                fuel_cost = Float64(row.FuelCost)
            ),
            fixed = Float64(row.FixedCost)
        )

        if hydro_type == "HydroDispatch"
            gen = PSY.HydroDispatch(
                String(row.GeneratorName),
                Bool(row.Available),
                bus,
                Float64(row.ActivePower),
                Float64(row.ReactivePower),
                Float64(row.Rating),
                getfield(PrimeMovers, Symbol(row.PrimeMover)),
                (min = Float64(row.ActivePowerMin), max = Float64(row.ActivePowerMax)),
                (min = Float64(row.ReactivePowerMin), max = Float64(row.ReactivePowerMax)),
                ramp_limits,
                nothing,
                Float64(row.BasePower),
                hydro_cost,
                PSY.Device[],
                nothing,
                Dict{String, Any}()
            )
        elseif hydro_type == "HydroEnergyReservoir"
            gen = PSY.HydroEnergyReservoir(
                name                  = String(row.GeneratorName),
                available             = Bool(row.Available),
                bus                   = bus,
                active_power          = Float64(row.ActivePower),
                reactive_power        = Float64(row.ReactivePower),
                rating                = Float64(row.Rating),
                prime_mover_type      = getfield(PrimeMovers, Symbol(row.PrimeMover)),
                active_power_limits   = (min = Float64(row.ActivePowerMin), max = Float64(row.ActivePowerMax)),
                reactive_power_limits = (min = Float64(row.ReactivePowerMin), max = Float64(row.ReactivePowerMax)),
                ramp_limits           = ramp_limits,
                time_limits           = nothing,
                operation_cost        = hydro_cost,
                base_power            = Float64(row.BasePower),
                storage_capacity      = Float64(row.StorageCapacity),
                inflow                = Float64(row.Inflow),
                conversion_factor     = Float64(row.ConversionFactor),
                initial_storage       = Float64(row.InitialStorage)
            )
        else
            @warn "Unsupported hydro type: $hydro_type for $(row.GeneratorName), skipping."
            continue
        end

        PSY.add_component!(system.psy_system, gen)

        # Add inflow time series
        if isa(gen, PSY.HydroEnergyReservoir)
            ts_data = TimeSeries.TimeArray(DayAhead, hydro_ts)
            PSY.add_time_series!(system.psy_system, gen, PSY.SingleTimeSeries("inflow", ts_data))
        else
            ts_data = TimeSeries.TimeArray(DayAhead, hydro_ts)
            PSY.add_time_series!(system.psy_system, gen, PSY.SingleTimeSeries("max_active_power", ts_data))
        end

        gen_interval = _make_gen_interval(cont_count)

        extended_cost_h = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_h)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen    = PowerLASCOPF.ExtendedHydroGenerator(
            gen, extended_cost_h, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_hydro_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(generators, lascopf_gen)
    end

    log_info("Created $(length(generators)) PowerLASCOPF Hydro Generators from CSV.")
    println("Created $(length(generators)) PowerLASCOPF Hydro Generators from CSV: $csv_path")
    return generators
end

"""
    powerlascopf_storage_from_csv!(system, nodes, csv_path, cont_count)

Read storage units from a Storage*_sahar.csv file and create PowerLASCOPF objects.
Supports two CSV formats:
  - New format: StorageName, BusNumber, StorageType, PrimeMover, Available, InitialEnergy,
    SOC_Min, SOC_Max, Rating, ActivePower, InputActivePowerMin, InputActivePowerMax,
    OutputActivePowerMin, OutputActivePowerMax, EfficiencyIn, EfficiencyOut, ReactivePower,
    ReactivePowerMin, ReactivePowerMax, BasePower, [StorageTarget, EnergyShortageCost,
    EnergySurplusCost]
  - Old format: BatteryName, BusNumber, Available, ActivePower, ReactivePower, Rating,
    InputActivePowerMin, InputActivePowerMax, OutputActivePowerMin, OutputActivePowerMax,
    EfficiencyIn, EfficiencyOut, StorageCapacity, InitialEnergy, BasePower
"""
function powerlascopf_storage_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    cont_count::Int = 6
)
    log_info("Creating PowerLASCOPF Storage from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    cols = names(df)

    # Detect format: new format has SOC_Min/SOC_Max, old format has StorageCapacity
    is_new_format = "SOC_Min" in cols

    # Support both BatteryName (old) and StorageName (new) column headers
    name_col = "StorageName" in cols ? :StorageName :
               "BatteryName" in cols ? :BatteryName : :StorageName

    for (i, row) in enumerate(eachrow(df))
        bus_num = Int(row.BusNumber)
        bus     = bus_by_busnum[bus_num]
        node    = node_by_busnum[bus_num]

        rating = "Rating" in cols ? Float64(row.Rating) :
                 max(Float64(row.InputActivePowerMax), Float64(row.OutputActivePowerMax))

        if is_new_format
            # New format: has SOC_Min, SOC_Max, StorageTarget, etc.
            soc_min = Float64(row.SOC_Min)
            soc_max = Float64(row.SOC_Max)
            rp_min  = "ReactivePowerMin" in cols ? Float64(row.ReactivePowerMin) : 0.0
            rp_max  = "ReactivePowerMax" in cols ? Float64(row.ReactivePowerMax) : 0.0
            pm      = "PrimeMover" in cols ? getfield(PrimeMovers, Symbol(row.PrimeMover)) : PrimeMovers.BA

            # Check for storage management cost fields
            has_cost = "EnergyShortageCost" in cols &&
                       !ismissing(row.EnergyShortageCost) && !ismissing(row.EnergySurplusCost)
            has_target = "StorageTarget" in cols && !ismissing(row.StorageTarget)

            if has_cost
                op_cost = PSY.StorageManagementCost(
                    variable          = PSY.VariableCost(0.0),
                    fixed             = 0.0,
                    start_up          = 0.0,
                    shut_down         = 0.0,
                    energy_shortage_cost = Float64(row.EnergyShortageCost),
                    energy_surplus_cost  = Float64(row.EnergySurplusCost)
                )
            else
                op_cost = PSY.StorageManagementCost()
            end

            gen = PSY.EnergyReservoirStorage(;
                name                       = String(row[name_col]),
                prime_mover_type           = pm,
                available                  = Bool(row.Available),
                bus                        = bus,
                initial_energy             = Float64(row.InitialEnergy),
                state_of_charge_limits     = (min = soc_min, max = soc_max),
                rating                     = rating,
                active_power               = Float64(row.ActivePower),
                input_active_power_limits  = (min = Float64(row.InputActivePowerMin), max = Float64(row.InputActivePowerMax)),
                output_active_power_limits = (min = Float64(row.OutputActivePowerMin), max = Float64(row.OutputActivePowerMax)),
                efficiency                 = (in = Float64(row.EfficiencyIn), out = Float64(row.EfficiencyOut)),
                reactive_power             = Float64(row.ReactivePower),
                reactive_power_limits      = (min = rp_min, max = rp_max),
                base_power                 = Float64(row.BasePower),
                storage_target             = has_target ? Float64(row.StorageTarget) : 0.0,
                operation_cost             = op_cost
            )
        else
            # Old format: BatteryName, StorageCapacity, no SOC_Min/Max
            cap = "StorageCapacity" in cols ? Float64(row.StorageCapacity) : rating
            gen = PSY.EnergyReservoirStorage(;
                name                       = String(row[name_col]),
                prime_mover_type           = PrimeMovers.BA,
                available                  = Bool(row.Available),
                bus                        = bus,
                initial_energy             = Float64(row.InitialEnergy),
                state_of_charge_limits     = (min = 0.0, max = cap),
                rating                     = rating,
                active_power               = Float64(row.ActivePower),
                input_active_power_limits  = (min = Float64(row.InputActivePowerMin), max = Float64(row.InputActivePowerMax)),
                output_active_power_limits = (min = Float64(row.OutputActivePowerMin), max = Float64(row.OutputActivePowerMax)),
                efficiency                 = (in = Float64(row.EfficiencyIn), out = Float64(row.EfficiencyOut)),
                reactive_power             = Float64(row.ReactivePower),
                reactive_power_limits      = (min = 0.0, max = 0.0),
                base_power                 = Float64(row.BasePower),
                operation_cost             = PSY.StorageManagementCost()
            )
        end

        PSY.add_component!(system.psy_system, gen)

        gen_interval = _make_gen_interval(cont_count)
        lascopf_gen  = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(generators, lascopf_gen)
    end

    log_info("Created $(length(generators)) PowerLASCOPF Storage units from CSV.")
    println("Created $(length(generators)) PowerLASCOPF Storage units from CSV: $csv_path")
    return generators
end

"""
    powerlascopf_loads_from_csv!(system, nodes, csv_path, timeseries_data)

Read loads from a Loads*_sahar.csv file and create PowerLASCOPF Loads.
Expected CSV columns: LoadName, BusNumber, Available, ActivePower, ReactivePower,
  MaxActivePower, MaxReactivePower, BasePower
"""
function powerlascopf_loads_from_csv!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    csv_path::String,
    timeseries_data::Dict = Dict()
)
    log_info("Creating PowerLASCOPF Loads from CSV: $csv_path")
    df = CSV.read(csv_path, DataFrame)

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    bus_by_busnum  = Dict(PSY.get_number(n.node_type) => n.node_type for n in nodes)
    loads = PowerLASCOPF.Load[]

    DayAhead = get(timeseries_data, "DayAhead",
        collect(DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Hour(1):
                DateTime("1/1/2024 23:00:00", "d/m/y H:M:S")))

    for (i, row) in enumerate(eachrow(df))
        bus_num = Int(row.BusNumber)
        bus     = bus_by_busnum[bus_num]
        node    = node_by_busnum[bus_num]

        load = PSY.PowerLoad(
            String(row.LoadName),
            Bool(row.Available),
            bus,
            Float64(row.ActivePower),
            Float64(row.ReactivePower),
            Float64(row.BasePower),
            Float64(row.MaxActivePower),
            Float64(row.MaxReactivePower)
        )

        PSY.add_component!(system.psy_system, load)

        # Use load-specific or default time series
        load_ts_key = "loadbus$(bus_num)_ts_DA"
        load_ts = get(timeseries_data, load_ts_key,
                      ones(24) * Float64(row.ActivePower))
        ts_data = TimeSeries.TimeArray(DayAhead, load_ts)
        PSY.add_time_series!(system.psy_system, load, PSY.SingleTimeSeries("max_active_power", ts_data))

        lascopf_load = PowerLASCOPF.Load(load, i, Float64(row.ActivePower))
        PowerLASCOPF.add_extended_load!(system, lascopf_load)
        push!(loads, lascopf_load)
    end

    log_info("Created $(length(loads)) PowerLASCOPF Loads from CSV.")
    println("Created $(length(loads)) PowerLASCOPF Loads from CSV: $csv_path")
    return loads
end

# ============================================================================
# SECTION B8: PSY SYSTEM BRIDGE
# Populates a PowerLASCOPFSystem from an already-parsed PSY.System object.
# Used for PSS/E RAW and MATPOWER formats (loaded via PSY.System(filepath)).
# ============================================================================

"""
    powerlascopf_from_psy_system!(system, psy_system, cont_count; contingency_list, RND_int)

Populate a PowerLASCOPFSystem by iterating components in an existing PSY.System.

This is the bridge function for non-IEEE-CSV formats (PSS/E RAW, MATPOWER).
The caller loads `psy_system = PSY.System(filepath)` and then calls this function,
which replicates the same extended-cost / gensolver / extended-generator construction
used by the CSV-based functions.

# Arguments
- `system`           : empty PowerLASCOPFSystem (created with `PowerLASCOPFSystem(PSY.System(base_power))`)
- `psy_system`       : populated PSY.System (e.g. from `PSY.System("case.raw")`)
- `cont_count`       : number of contingency scenarios (default 6)
- `contingency_list` : vector of branch indices marked as contingencies (default: first `cont_count` branches)
- `RND_int`          : number of RND look-ahead intervals for LineSolverBase sizing (default 1)
"""
function powerlascopf_from_psy_system!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    psy_system::PSY.System,
    cont_count::Int = 6;
    contingency_list::Vector{Int} = Int[],
    RND_int::Int = 1
)
    log_info("Building PowerLASCOPFSystem from PSY.System...")

    # ------------------------------------------------------------------
    # 1. NODES (buses)
    # ------------------------------------------------------------------
    nodes = PowerLASCOPF.Node{PSY.Bus}[]
    bus_index = Dict{Int, Int}()           # bus_number => node vector index

    for (i, bus) in enumerate(PSY.get_components(PSY.ACBus, psy_system))
        node = PowerLASCOPF.Node{PSY.Bus}(bus, i, 0)
        # The bus is already in psy_system — do NOT call add_component! again.
        PowerLASCOPF.add_node!(system, node)
        push!(nodes, node)
        bus_index[PSY.get_number(bus)] = i
    end

    node_by_busnum = Dict(PSY.get_number(n.node_type) => n for n in nodes)
    log_info("Added $(length(nodes)) nodes.")

    # ------------------------------------------------------------------
    # 2. BRANCHES
    # ------------------------------------------------------------------
    transmission_lines = PowerLASCOPF.transmissionLine[]
    contingency_tracker = 0

    # Default contingency list: first cont_count AC branches
    effective_cont_list = isempty(contingency_list) ? collect(1:cont_count) : contingency_list

    for (i, branch) in enumerate(PSY.get_components(PSY.Branch, psy_system))
        arc      = PSY.get_arc(branch)
        from_bus = PSY.get_from(arc)
        to_bus   = PSY.get_to(arc)
        from_num = PSY.get_number(from_bus)
        to_num   = PSY.get_number(to_bus)

        from_node = get(node_by_busnum, from_num, nothing)
        to_node   = get(node_by_busnum, to_num,   nothing)
        if from_node === nothing || to_node === nothing
            log_warn("Branch $i: bus $from_num or $to_num not found in nodes, skipping.")
            continue
        end

        if i in effective_cont_list
            contingency_tracker += 1
            temp_tracker = contingency_tracker
        else
            temp_tracker = 0
        end

        if branch isa PSY.Line
            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = randn(cont_count * max(RND_int - 1, 1)),
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [0.9^j for j in 1:max(RND_int, 1)],
                Pt_next_nu    = zeros(cont_count * max(RND_int - 1, 1)),
                BSC           = 0.1 * randn(cont_count * max(RND_int - 1, 1)),
                E_temp_coeff  = 0.01 * randn(max(RND_int, 1), max(RND_int, 1)),
                alpha_factor  = 0.05,
                beta_factor   = 0.1,
                beta          = 0.1,
                gamma         = 0.2,
                Pt_max        = 1000.0,
                temp_init     = 340.0,
                temp_amb      = 300.0,
                max_temp      = 473.0,
                RND_int       = 1,
                cont_count    = cont_count
            )
            trans_line = PowerLASCOPF.transmissionLine{PSY.Line}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0, pt2 = 0.0,
                v1  = 0.0, v2  = 0.0
            )
            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)

        elseif branch isa PSY.HVDCLine
            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr    = [0.0],
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff       = [1.0],
                Pt_next_nu    = [0.0],
                BSC           = [0.0],
                E_temp_coeff  = reshape([0.1], 1, 1),
                RND_int       = 1,
                cont_count    = 1
            )
            trans_line = PowerLASCOPF.transmissionLine{PSY.HVDCLine}(
                transl_type       = branch,
                solver_line_base  = solver_base,
                transl_id         = i,
                conn_nodet1_ptr   = from_node,
                conn_nodet2_ptr   = to_node,
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0, thetat2 = 0.0,
                pt1 = 0.0, pt2 = 0.0,
                v1  = 0.0, v2  = 0.0
            )
            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)

        else
            log_warn("Branch $i ($(PSY.get_name(branch))): unsupported type $(typeof(branch)), skipping.")
        end
    end
    log_info("Added $(length(transmission_lines)) transmission lines.")

    # ------------------------------------------------------------------
    # 3. THERMAL GENERATORS
    # ------------------------------------------------------------------
    thermal_gens = PowerLASCOPF.GeneralizedGenerator[]

    for (i, gen) in enumerate(PSY.get_components(PSY.ThermalStandard, psy_system))
        bus_num = PSY.get_number(PSY.get_bus(gen))
        node    = get(node_by_busnum, bus_num, nothing)
        if node === nothing
            log_warn("Thermal gen $(PSY.get_name(gen)): bus $bus_num not found, skipping.")
            continue
        end

        # Retrieve or build operation cost.
        # PSS/E RAW files often have no cost data; provide a linear default.
        op_cost = PSY.get_operation_cost(gen)
        if op_cost === nothing || !(op_cost isa PSY.ThermalGenerationCost)
            op_cost = PSY.ThermalGenerationCost(
                variable  = IS.FuelCurve(
                    value_curve = IS.LinearCurve(10.0),
                    fuel_cost   = 1.0,
                    vom_cost    = IS.LinearCurve(0.0)
                ),
                fixed     = 0.0,
                start_up  = 0.0,
                shut_down = 0.0
            )
        end

        gen_interval = _make_gen_interval(cont_count)

        extended_cost = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedThermalGenerationCost(op_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen = PowerLASCOPF.ExtendedThermalGenerator(
            gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_thermal_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(thermal_gens, lascopf_gen)
    end
    log_info("Added $(length(thermal_gens)) thermal generators.")

    # ------------------------------------------------------------------
    # 4. RENEWABLE GENERATORS
    # ------------------------------------------------------------------
    renewable_gens = PowerLASCOPF.GeneralizedGenerator[]

    for (i, gen) in enumerate(PSY.get_components(PSY.RenewableDispatch, psy_system))
        bus_num = PSY.get_number(PSY.get_bus(gen))
        node    = get(node_by_busnum, bus_num, nothing)
        if node === nothing
            log_warn("Renewable gen $(PSY.get_name(gen)): bus $bus_num not found, skipping.")
            continue
        end

        op_cost = PSY.get_operation_cost(gen)
        if op_cost === nothing || !(op_cost isa PSY.RenewableGenerationCost)
            op_cost = PSY.RenewableGenerationCost(
                CostCurve(IS.LinearCurve(0.0))
            )
        end

        gen_interval = _make_gen_interval(cont_count)

        extended_cost = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(op_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen = PowerLASCOPF.ExtendedRenewableGenerator(
            gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_renewable_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(renewable_gens, lascopf_gen)
    end
    log_info("Added $(length(renewable_gens)) renewable generators.")

    # ------------------------------------------------------------------
    # 5. HYDRO GENERATORS
    # ------------------------------------------------------------------
    hydro_gens = PowerLASCOPF.GeneralizedGenerator[]

    for (i, gen) in enumerate(Iterators.flatten((
            PSY.get_components(PSY.HydroDispatch, psy_system),
            PSY.get_components(PSY.HydroEnergyReservoir, psy_system)
        )))

        bus_num = PSY.get_number(PSY.get_bus(gen))
        node    = get(node_by_busnum, bus_num, nothing)
        if node === nothing
            log_warn("Hydro gen $(PSY.get_name(gen)): bus $bus_num not found, skipping.")
            continue
        end

        op_cost = PSY.get_operation_cost(gen)
        if op_cost === nothing || !(op_cost isa PSY.HydroGenerationCost)
            op_cost = PSY.HydroGenerationCost(
                variable = IS.FuelCurve(
                    value_curve = IS.LinearCurve(0.0),
                    fuel_cost   = 0.0
                ),
                fixed = 0.0
            )
        end

        gen_interval = _make_gen_interval(cont_count)

        extended_cost_h = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, gen_interval)
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_h)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenFirstContInterval(nothing))
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedHydroGenerationCost(op_cost, PowerLASCOPF.GenLastContInterval(nothing))
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_gen = PowerLASCOPF.ExtendedHydroGenerator(
            gen, extended_cost_h, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        PowerLASCOPF.add_extended_hydro_generator!(system, extended_gen)

        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
        )
        push!(hydro_gens, lascopf_gen)
    end
    log_info("Added $(length(hydro_gens)) hydro generators.")

    # ------------------------------------------------------------------
    # 6. LOADS
    # ------------------------------------------------------------------
    lascopf_loads = PowerLASCOPF.Load[]

    for (i, load) in enumerate(PSY.get_components(PSY.PowerLoad, psy_system))
        bus_num = PSY.get_number(PSY.get_bus(load))
        node    = get(node_by_busnum, bus_num, nothing)
        if node === nothing
            log_warn("Load $(PSY.get_name(load)): bus $bus_num not found, skipping.")
            continue
        end
        active_power = PSY.get_active_power(load)
        lascopf_load = PowerLASCOPF.Load(load, i, active_power)
        PowerLASCOPF.add_extended_load!(system, lascopf_load)
        push!(lascopf_loads, lascopf_load)
    end
    log_info("Added $(length(lascopf_loads)) loads.")

    log_success("PowerLASCOPFSystem populated from PSY.System: " *
                "$(length(nodes)) buses, $(length(transmission_lines)) branches, " *
                "$(length(thermal_gens)) thermal, $(length(renewable_gens)) renewable, " *
                "$(length(hydro_gens)) hydro, $(length(lascopf_loads)) loads.")

    return (
        nodes              = nodes,
        branches           = transmission_lines,
        thermal_generators = thermal_gens,
        renewable_generators = renewable_gens,
        hydro_generators   = hydro_gens,
        loads              = lascopf_loads
    )
end

# ============================================================================
# SECTION B10: HEAT RATE → QUADRATIC COST CURVE HELPER
# Converts RTS-GMLC piecewise incremental heat rate data into a least-squares
# quadratic fit suitable for IS.FuelCurve / IS.QuadraticCurve.
# ============================================================================

"""
    _heat_rate_to_quadratic(p_max, hr_avg_0, hr_incr_1..4, out_pct_0..4, fuel_price)

Fit a quadratic heat-consumption curve H(P) = a·P² + b·P + c (MMBTU/hr, P in MW)
to the RTS-GMLC piecewise heat-rate data, using ordinary least squares.

Returns `(a, b, c)` suitable for `IS.QuadraticCurve(a, b, c)` inside an
`IS.FuelCurve(value_curve=..., fuel_cost=fuel_price, vom_cost=LinearCurve(0))`.

Heat-rate conversion: BTU/kWh × MW × (1000 kW/MW) / (10^6 BTU/MMBTU) = MMBTU/hr
"""
function _heat_rate_to_quadratic(
    p_max::Float64,
    hr_avg_0,  hr_incr_1,  hr_incr_2,  hr_incr_3,  hr_incr_4,
    out_pct_0, out_pct_1,  out_pct_2,  out_pct_3,  out_pct_4,
    fuel_price::Float64
)
    pcts  = [out_pct_0,  out_pct_1,  out_pct_2,  out_pct_3,  out_pct_4]
    incrs = [hr_avg_0,   hr_incr_1,  hr_incr_2,  hr_incr_3,  hr_incr_4]

    P = Float64[]
    H = Float64[]   # cumulative heat consumption (MMBTU/hr) at each breakpoint

    cumulative_heat = 0.0
    prev_p          = 0.0

    for k in 1:5
        (ismissing(pcts[k]) || ismissing(incrs[k])) && break
        p_k   = Float64(pcts[k]) * p_max
        hr_k  = Float64(incrs[k])
        if k == 1
            # Average heat rate at minimum output: heat = HR_avg_0 × P_0 (BTU/kWh × MW = MMBTU/hr ÷ 1000)
            h_k = hr_k * p_k * 1000.0 / 1.0e6
        else
            h_k = cumulative_heat + hr_k * (p_k - prev_p) * 1000.0 / 1.0e6
        end
        push!(P, p_k)
        push!(H, h_k)
        cumulative_heat = h_k
        prev_p          = p_k
    end

    # Fallback: single linear curve using HR_avg_0
    if length(P) < 2
        base_hr  = Float64(coalesce(hr_avg_0,  10000.0))
        linear_b = base_hr * 1000.0 / 1.0e6   # slope (MMBTU/hr per MW)
        return 0.0, linear_b, 0.0
    end

    # Least-squares quadratic fit: A * [a, b, c]' = H
    A = hcat(P .^ 2, P, ones(length(P)))
    coefs = try
        (A' * A) \ (A' * H)
    catch
        [0.0, H[end] / max(P[end], 1.0), 0.0]
    end
    return coefs[1], coefs[2], coefs[3]
end

# ============================================================================
# SECTION B11: TIME SERIES LOADER (RTS-GMLC) — DEFERRED STUB
# Full implementation reads timeseries_pointers_da.json and attaches
# PSY.SingleTimeSeries to each component. For now returns empty Dict so
# that powerlascopf_from_rts_gmlc! can proceed with the static snapshot.
# ============================================================================

"""
    load_timeseries_rts_gmlc(case_path) -> Dict

Stub: load RTS-GMLC day-ahead time series from timeseries_pointers_da.json.
Returns an empty Dict; time series attachment is deferred (static snapshot used).
"""
function load_timeseries_rts_gmlc(case_path::String)
    pointer_file = joinpath(case_path, "timeseries_pointers_da.json")
    if isfile(pointer_file)
        log_info("RTS-GMLC time series deferred: found $pointer_file but not yet loaded. " *
                 "Static snapshot will be used.")
    else
        log_info("No timeseries_pointers_da.json found in $case_path. Static snapshot only.")
    end
    return Dict{String, Any}()
end

# ============================================================================
# SECTION B12: LASCOPF SETTINGS INTEGRATION
# Maps LASCOPF_settings.yml keys to the parameters used during system
# construction, so every case uses its own configured intervals/solver.
# ============================================================================

"""
    apply_lascopf_settings(settings) -> NamedTuple

Convert a LASCOPF_settings.yml Dict into typed construction parameters.

Returned fields:
- `cont_count`          : from RNDIntervals (number of contingency scenarios)
- `RND_int`             : from RNDIntervals (look-ahead intervals for LineSolverBase)
- `RSD_int`             : from RSDIntervals
- `use_dummy_interval`  : from dummyIntervalChoice (include GenFirstBaseIntervalDZ?)
- `solver_choice`       : from solverChoice (1=GUROBI-APMP, 2=CVXGEN-APMP, …)
- `rho_tuning`          : from setRhoTuning (ADMM ρ update mode)
"""
function apply_lascopf_settings(settings::Dict)
    RND_int          = get(settings, "RNDIntervals",       3)
    RSD_int          = get(settings, "RSDIntervals",       3)
    solver_choice    = get(settings, "solverChoice",       1)
    rho_tuning       = get(settings, "setRhoTuning",       3)
    dummy_interval   = get(settings, "dummyIntervalChoice", 1)

    log_info("LASCOPF settings applied: RND_int=$RND_int  RSD_int=$RSD_int  " *
             "solver=$solver_choice  rho_tuning=$rho_tuning  " *
             "dummy_interval=$(Bool(dummy_interval))")

    return (
        RND_int           = Int(RND_int),
        RSD_int           = Int(RSD_int),
        use_dummy_interval = Bool(dummy_interval),
        solver_choice     = Int(solver_choice),
        rho_tuning        = Int(rho_tuning),
    )
end

# ============================================================================
# SECTION B9: RTS-GMLC FORMAT READER
# Reads bus.csv / gen.csv / branch.csv / storage.csv from case_path and
# builds a fully-populated PowerLASCOPFSystem.  Calls B10 for cost curves,
# B11 for time series, and honours B12 settings if provided.
# ============================================================================

"""
    powerlascopf_from_rts_gmlc!(system, case_path, cont_count; kwargs)

Populate a PowerLASCOPFSystem from an RTS-GMLC formatted case directory.

Reads: bus.csv, gen.csv, branch.csv, (optionally storage.csv, reserves.csv).
Derives generator cost curves from piecewise heat rate data via a least-squares
quadratic fit (see `_heat_rate_to_quadratic`).
Classifies generators by Unit Type column → correct PSY / PowerLASCOPF types.

# Arguments
- `system`           : empty PowerLASCOPFSystem
- `case_path`        : path to folder containing bus.csv, gen.csv, branch.csv
- `cont_count`       : number of contingency scenarios
- `contingency_list` : branch indices marked as contingencies (default: first `cont_count`)
- `RND_int`          : RND look-ahead intervals for LineSolverBase sizing
- `lascopf_settings` : Dict from `read_lascopf_settings()` / `apply_lascopf_settings()`
"""
function powerlascopf_from_rts_gmlc!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    case_path::String,
    cont_count::Int = 6;
    contingency_list::Vector{Int} = Int[],
    RND_int::Int = 1,
    lascopf_settings::Dict = Dict()
)
    log_info("Building PowerLASCOPFSystem from RTS-GMLC data at: $case_path")

    # Apply settings if provided
    if !isempty(lascopf_settings)
        sp = apply_lascopf_settings(lascopf_settings)
        RND_int = sp.RND_int
        log_info("Settings override: RND_int=$RND_int")
    end

    # ------------------------------------------------------------------
    # Read raw CSV files (bypass data_reader_generic helpers for
    # self-contained operation within data_reader.jl)
    # ------------------------------------------------------------------
    bus_csv    = joinpath(case_path, "bus.csv")
    gen_csv    = joinpath(case_path, "gen.csv")
    branch_csv = joinpath(case_path, "branch.csv")

    isfile(bus_csv)    || error("RTS-GMLC bus.csv not found in $case_path")
    isfile(gen_csv)    || error("RTS-GMLC gen.csv not found in $case_path")
    isfile(branch_csv) || error("RTS-GMLC branch.csv not found in $case_path")

    bus_df    = CSV.read(bus_csv,    DataFrame)
    gen_df    = CSV.read(gen_csv,    DataFrame)
    branch_df = CSV.read(branch_csv, DataFrame)

    storage_csv = joinpath(case_path, "storage.csv")
    storage_df  = isfile(storage_csv) ? CSV.read(storage_csv, DataFrame) : DataFrame()

    # Deferred time series (B11)
    _ts = load_timeseries_rts_gmlc(case_path)

    # ------------------------------------------------------------------
    # 1. NODES (bus.csv)
    # ------------------------------------------------------------------
    nodes          = PowerLASCOPF.Node{PSY.Bus}[]
    node_by_busnum = Dict{Int, PowerLASCOPF.Node{PSY.Bus}}()
    bus_by_busnum  = Dict{Int, PSY.ACBus}()

    for (i, row) in enumerate(eachrow(bus_df))
        bus_num     = Int(row[Symbol("Bus ID")])
        bus_name    = string(row[Symbol("Bus Name")])
        bus_type    = string(row[Symbol("Bus Type")])
        base_kv     = Float64(coalesce(row[Symbol("BaseKV")], 138.0))
        v_mag       = Float64(coalesce(row[Symbol("V Mag")], 1.0))
        v_ang       = Float64(coalesce(row[Symbol("V Angle")], 0.0))

        bus = PSY.ACBus(
            bus_num, bus_name, bus_type,
            v_ang, v_mag,
            (min = 0.94, max = 1.06),
            base_kv, nothing, nothing
        )
        node = PowerLASCOPF.Node{PSY.Bus}(bus, i, 0)
        PSY.add_component!(system.psy_system, bus)
        PowerLASCOPF.add_node!(system, node)
        push!(nodes, node)
        node_by_busnum[bus_num] = node
        bus_by_busnum[bus_num]  = bus
    end
    log_info("Added $(length(nodes)) nodes (RTS-GMLC).")

    # ------------------------------------------------------------------
    # 2. BRANCHES (branch.csv)
    # ------------------------------------------------------------------
    transmission_lines  = PowerLASCOPF.transmissionLine[]
    effective_cont_list = isempty(contingency_list) ? collect(1:cont_count) : contingency_list
    contingency_tracker = 0

    for (i, row) in enumerate(eachrow(branch_df))
        from_num = Int(row[Symbol("From Bus")])
        to_num   = Int(row[Symbol("To Bus")])
        from_bus  = get(bus_by_busnum,  from_num, nothing)
        to_bus    = get(bus_by_busnum,  to_num,   nothing)
        from_node = get(node_by_busnum, from_num, nothing)
        to_node   = get(node_by_busnum, to_num,   nothing)

        if from_bus === nothing || to_bus === nothing
            log_warn("Branch $i: bus $from_num or $to_num not in bus list, skipping.")
            continue
        end

        tr_ratio = Float64(coalesce(row[Symbol("Tr Ratio")], 0.0))
        is_ac    = (tr_ratio == 0.0)   # Tr Ratio == 0 ↔ plain AC line

        temp_tracker = if i in effective_cont_list
            contingency_tracker += 1
            contingency_tracker
        else
            0
        end

        line_name = string(row[Symbol("UID")])
        r         = Float64(coalesce(row[Symbol("R")], 0.0))
        x         = Float64(coalesce(row[Symbol("X")], 1e-4))   # avoid zero reactance
        b_total   = Float64(coalesce(row[Symbol("B")], 0.0))
        rate      = Float64(coalesce(row[Symbol("Cont Rating")], 9999.0))

        branch = PSY.Line(
            line_name, true, 0.0, 0.0,
            Arc(from = from_bus, to = to_bus),
            r, x,
            (from = b_total / 2, to = b_total / 2),
            rate,
            (min = -0.7, max = 0.7)
        )
        PSY.add_component!(system.psy_system, branch)

        n_lambda = cont_count * max(RND_int - 1, 1)
        solver_base = PowerLASCOPF.LineSolverBase(
            lambda_txr    = randn(n_lambda),
            interval_type = PowerLASCOPF.LineBaseInterval(),
            E_coeff       = [0.9^j for j in 1:max(RND_int, 1)],
            Pt_next_nu    = zeros(n_lambda),
            BSC           = 0.1 * randn(n_lambda),
            E_temp_coeff  = 0.01 * randn(max(RND_int, 1), max(RND_int, 1)),
            alpha_factor  = 0.05,
            beta_factor   = 0.1,
            beta          = 0.1,
            gamma         = 0.2,
            Pt_max        = 1000.0,
            temp_init     = 340.0,
            temp_amb      = 300.0,
            max_temp      = 473.0,
            RND_int       = 1,
            cont_count    = cont_count
        )

        trans_line = PowerLASCOPF.transmissionLine{PSY.Line}(
            transl_type       = branch,
            solver_line_base  = solver_base,
            transl_id         = i,
            conn_nodet1_ptr   = from_node,
            conn_nodet2_ptr   = to_node,
            cont_scen_tracker = temp_tracker,
            thetat1 = 0.0, thetat2 = 0.0,
            pt1 = 0.0, pt2 = 0.0,
            v1  = 0.0, v2  = 0.0
        )
        PowerLASCOPF.assign_conn_nodes(trans_line)
        PowerLASCOPF.add_transmission_line!(system, trans_line)
        push!(transmission_lines, trans_line)
    end
    log_info("Added $(length(transmission_lines)) branches (RTS-GMLC).")

    # ------------------------------------------------------------------
    # 3. GENERATORS (gen.csv)  — classified by Unit Type
    # ------------------------------------------------------------------
    thermal_gens   = PowerLASCOPF.GeneralizedGenerator[]
    renewable_gens = PowerLASCOPF.GeneralizedGenerator[]
    hydro_gens     = PowerLASCOPF.GeneralizedGenerator[]

    # Unit type → generator category
    _THERMAL_TYPES   = Set(["CT", "CC", "ST", "STEAM", "DR", "GAS", "COAL", "OIL", "NUCLEAR"])
    _RENEWABLE_TYPES = Set(["WT", "PV", "RTPV", "CSP"])
    _HYDRO_TYPES     = Set(["HY", "ROR"])
    # PS (pumped storage) deferred to storage section

    fuel_price_col = Symbol("Fuel Price \$/MMBTU")
    start_col      = Symbol("Non Fuel Start Cost \$")
    stop_col       = Symbol("Non Fuel Shutdown Cost \$")
    ramp_col       = Symbol("Ramp Rate MW/Min")

    for (i, row) in enumerate(eachrow(gen_df))
        unit_type = string(row[Symbol("Unit Type")])
        bus_num   = Int(row[Symbol("Bus ID")])
        node      = get(node_by_busnum, bus_num, nothing)
        bus       = get(bus_by_busnum,  bus_num, nothing)

        if node === nothing
            log_warn("Generator $(row[Symbol("GEN UID")]): bus $bus_num not found, skipping.")
            continue
        end

        p_max    = Float64(row[Symbol("PMax MW")])
        p_min    = Float64(row[Symbol("PMin MW")])
        q_max    = Float64(coalesce(row[Symbol("QMax MVAR")], 0.0))
        q_min    = Float64(coalesce(row[Symbol("QMin MVAR")], 0.0))
        base_pwr = Float64(coalesce(row[Symbol("Base MVA")], 100.0))
        ramp_mw  = Float64(coalesce(row[ramp_col], 0.0)) * 60.0  # MW/min → MW/hr
        fuel_prc = Float64(coalesce(row[fuel_price_col], 1.0))
        start_c  = Float64(coalesce(row[start_col], 0.0))
        stop_c   = Float64(coalesce(row[stop_col],  0.0))
        gen_name = string(row[Symbol("GEN UID")])

        ramp_limits = ramp_mw > 0 ? (up = ramp_mw, down = ramp_mw) : nothing

        # B10: fit quadratic to piecewise heat rate (→ IS.QuadraticCurve)
        qa, qb, qc = _heat_rate_to_quadratic(
            p_max,
            row[Symbol("HR_avg_0")],  row[Symbol("HR_incr_1")],
            row[Symbol("HR_incr_2")], row[Symbol("HR_incr_3")],
            row[Symbol("HR_incr_4")],
            row[Symbol("Output_pct_0")], row[Symbol("Output_pct_1")],
            row[Symbol("Output_pct_2")], row[Symbol("Output_pct_3")],
            row[Symbol("Output_pct_4")],
            fuel_prc
        )

        gen_interval = _make_gen_interval(cont_count)

        # ---- THERMAL ----
        if unit_type in _THERMAL_TYPES
            fuel_sym = if unit_type in ("CC", "CT", "GAS") ; ThermalFuels.NATURAL_GAS
                       elseif unit_type == "COAL"          ; ThermalFuels.COAL
                       elseif unit_type == "OIL"           ; ThermalFuels.DISTILLATE_FUEL_OIL
                       elseif unit_type == "NUCLEAR"       ; ThermalFuels.NUCLEAR
                       else                                ; ThermalFuels.OTHER
                       end

            pm_sym = if unit_type == "CT"                  ; PrimeMovers.CT
                     elseif unit_type == "CC"              ; PrimeMovers.CC
                     elseif unit_type in ("ST", "STEAM")   ; PrimeMovers.ST
                     elseif unit_type == "NUCLEAR"         ; PrimeMovers.ST
                     else                                  ; PrimeMovers.OT
                     end

            op_cost = PSY.ThermalGenerationCost(
                variable  = IS.FuelCurve(
                    value_curve = IS.QuadraticCurve(qa, qb, qc),
                    fuel_cost   = fuel_prc,
                    vom_cost    = IS.LinearCurve(0.0)
                ),
                fixed     = 0.0,
                start_up  = start_c,
                shut_down = stop_c
            )

            gen = PSY.ThermalStandard(
                name                  = gen_name,
                available             = true,
                status                = true,
                bus                   = bus,
                active_power          = p_min,
                reactive_power        = 0.0,
                rating                = p_max,
                prime_mover_type      = pm_sym,
                fuel                  = fuel_sym,
                active_power_limits   = (min = p_min, max = p_max),
                reactive_power_limits = (min = q_min, max = q_max),
                ramp_limits           = ramp_limits,
                time_limits           = nothing,
                operation_cost        = op_cost,
                base_power            = base_pwr
            )
            PSY.add_component!(system.psy_system, gen)

            extended_cost = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, gen_interval)
            gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

            extended_cost_first_base_dz = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
            gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

            extended_cost_first_cont = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
            gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

            extended_cost_first_cont_dz = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
            gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

            extended_cost_last_base = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
            gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

            extended_cost_RND = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
            gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

            extended_cost_RSD = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
            gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

            extended_cost_last_cont = PowerLASCOPF.ExtendedThermalGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
            gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

            extended_gen = PowerLASCOPF.ExtendedThermalGenerator(
                gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            PowerLASCOPF.add_extended_thermal_generator!(system, extended_gen)

            lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
                gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            push!(thermal_gens, lascopf_gen)

        # ---- RENEWABLE ----
        elseif unit_type in _RENEWABLE_TYPES
            pm_sym = if unit_type == "WT"   ; PrimeMovers.WT
                     elseif unit_type == "PV"   ; PrimeMovers.PVe
                     elseif unit_type == "RTPV" ; PrimeMovers.PVe
                     elseif unit_type == "CSP"  ; PrimeMovers.CP
                     else                       ; PrimeMovers.OT
                     end

            # Renewables: variable cost only (no fuel combustion)
            var_cost = fuel_prc * Float64(coalesce(row[Symbol("HR_avg_0")], 0.0)) / 1000.0
            op_cost  = PSY.RenewableGenerationCost(CostCurve(LinearCurve(var_cost)))

            gen = PSY.RenewableDispatch(
                gen_name, true, bus,
                p_min, 0.0, p_max,
                pm_sym,
                (min = q_min, max = q_max),
                1.0,
                op_cost,
                base_pwr
            )
            PSY.add_component!(system.psy_system, gen)

            extended_cost = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, gen_interval)
            gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost)

            extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
            gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

            extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
            gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

            extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
            gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

            extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
            gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

            extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
            gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

            extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
            gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

            extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
            gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

            extended_gen = PowerLASCOPF.ExtendedRenewableGenerator(
                gen, extended_cost, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            PowerLASCOPF.add_extended_renewable_generator!(system, extended_gen)

            lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
                gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            push!(renewable_gens, lascopf_gen)

        # ---- HYDRO ----
        elseif unit_type in _HYDRO_TYPES
            hydro_cost = PSY.HydroGenerationCost(
                variable = IS.FuelCurve(
                    value_curve = IS.LinearCurve(Float64(coalesce(row[Symbol("HR_avg_0")], 0.0)) / 1000.0),
                    fuel_cost   = fuel_prc
                ),
                fixed = 0.0
            )

            if unit_type == "HY"
                # HydroEnergyReservoir (reservoir hydro)
                gen = PSY.HydroEnergyReservoir(
                    name                  = gen_name,
                    available             = true,
                    bus                   = bus,
                    active_power          = p_min,
                    reactive_power        = 0.0,
                    rating                = p_max,
                    prime_mover_type      = PrimeMovers.HA,
                    active_power_limits   = (min = p_min, max = p_max),
                    reactive_power_limits = (min = q_min, max = q_max),
                    ramp_limits           = ramp_limits,
                    time_limits           = nothing,
                    operation_cost        = hydro_cost,
                    base_power            = base_pwr,
                    storage_capacity      = p_max * 6.0,  # 6h reservoir default
                    inflow                = p_min,
                    conversion_factor     = 1.0,
                    initial_storage       = p_max * 3.0
                )
            else  # ROR — run-of-river
                gen = PSY.HydroDispatch(
                    gen_name, true, bus, p_min, 0.0, p_max,
                    PrimeMovers.HA,
                    (min = p_min, max = p_max),
                    (min = q_min, max = q_max),
                    ramp_limits, nothing, base_pwr, hydro_cost,
                    PSY.Device[], nothing, Dict{String, Any}()
                )
            end
            PSY.add_component!(system.psy_system, gen)

            extended_cost_h = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, gen_interval)
            gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_h)

            extended_cost_first_base_dz = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstBaseIntervalDZ(nothing))
            gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

            extended_cost_first_cont = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContInterval(nothing))
            gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

            extended_cost_first_cont_dz = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenFirstContIntervalDZ(nothing))
            gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

            extended_cost_last_base = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastBaseInterval(nothing))
            gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

            extended_cost_RND = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRNDInterval(nothing))
            gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

            extended_cost_RSD = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenInterRSDInterval(nothing))
            gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

            extended_cost_last_cont = PowerLASCOPF.ExtendedHydroGenerationCost(gen.operation_cost, PowerLASCOPF.GenLastContInterval(nothing))
            gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

            extended_gen = PowerLASCOPF.ExtendedHydroGenerator(
                gen, extended_cost_h, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            PowerLASCOPF.add_extended_hydro_generator!(system, extended_gen)

            lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
                gen, gen_interval, i, 1, false, cont_count, cont_count + 1, 1, 0, 1, node, cont_count
            )
            push!(hydro_gens, lascopf_gen)

        else
            log_warn("Generator $gen_name (Unit Type '$unit_type'): unsupported type, skipping.")
        end
    end
    log_info("Added $(length(thermal_gens)) thermal, $(length(renewable_gens)) renewable, $(length(hydro_gens)) hydro generators (RTS-GMLC).")

    # ------------------------------------------------------------------
    # 4. LOADS (bus.csv — MW/MVAR Load columns)
    # ------------------------------------------------------------------
    lascopf_loads = PowerLASCOPF.Load[]
    load_idx = 0

    for row in eachrow(bus_df)
        mw_load   = Float64(coalesce(row[Symbol("MW Load")],   0.0))
        mvar_load = Float64(coalesce(row[Symbol("MVAR Load")], 0.0))
        mw_load > 0 || continue

        bus_num    = Int(row[Symbol("Bus ID")])
        node       = get(node_by_busnum, bus_num, nothing)
        bus        = get(bus_by_busnum,  bus_num, nothing)
        node === nothing && continue

        load_idx += 1
        load_name = "Load_$(bus_num)"

        load = PSY.PowerLoad(
            load_name, true, bus,
            mw_load, mvar_load, 100.0,
            mw_load, mvar_load
        )
        PSY.add_component!(system.psy_system, load)

        lascopf_load = PowerLASCOPF.Load(load, load_idx, mw_load)
        PowerLASCOPF.add_extended_load!(system, lascopf_load)
        push!(lascopf_loads, lascopf_load)
    end
    log_info("Added $(length(lascopf_loads)) loads (RTS-GMLC).")

    log_success("PowerLASCOPFSystem populated from RTS-GMLC: " *
                "$(length(nodes)) buses, $(length(transmission_lines)) branches, " *
                "$(length(thermal_gens)) thermal, $(length(renewable_gens)) renewable, " *
                "$(length(hydro_gens)) hydro, $(length(lascopf_loads)) loads.")

    return (
        nodes                = nodes,
        branches             = transmission_lines,
        thermal_generators   = thermal_gens,
        renewable_generators = renewable_gens,
        hydro_generators     = hydro_gens,
        loads                = lascopf_loads
    )
end

#=
# ============================================================
# SECTION: 57-BUS CASE-SPECIFIC FUNCTIONS
# Following the same pattern as data_14bus_pu.jl
# ============================================================

"""
    power_lascopf_system57()

Create an empty PowerLASCOPF system for the IEEE 57-bus test case.
"""
function power_lascopf_system57()
    log_info("Creating PowerLASCOPF System for 57-bus case...")
    system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
    log_info("Created PowerLASCOPF System for 57-bus case.")
    return system
end

"""
    powerlascopf_nodes57!(system)

Create PowerLASCOPF Nodes for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_nodes57!(system::PowerLASCOPF.PowerLASCOPFSystem)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "Nodes57_sahar.csv")
    return powerlascopf_nodes_from_csv!(system, csv_path)
end

"""
    powerlascopf_branches57!(system, nodes, cont_count, RND_int)

Create PowerLASCOPF transmission lines for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_branches57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    cont_count::Int,
    RND_int::Int
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "Trans57_sahar.csv")
    return powerlascopf_branches_from_csv!(
        system, nodes, csv_path, branches_57_contingency_list(), cont_count, RND_int
    )
end

"""
    powerlascopf_thermal_generators57!(system, nodes)

Create PowerLASCOPF thermal generators for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_thermal_generators57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "ThermalGenerators57_sahar.csv")
    cont_count = length(branches_57_contingency_list())
    return powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_renewable_generators57!(system, nodes)

Create PowerLASCOPF renewable generators for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_renewable_generators57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "RenewableGenerators57_sahar.csv")
    cont_count = length(branches_57_contingency_list())
    return powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    powerlascopf_hydro_generators57!(system, nodes)

Create PowerLASCOPF hydro generators for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_hydro_generators57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "HydroGenerators57_sahar.csv")
    cont_count = length(branches_57_contingency_list())
    return powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    power_lascopf_storage_generators57!(system, nodes)

Create PowerLASCOPF storage generators for the IEEE 57-bus case from CSV data.
"""
function power_lascopf_storage_generators57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "Storage57_sahar.csv")
    cont_count = length(branches_57_contingency_list())
    return powerlascopf_storage_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_loads57!(system, nodes)

Create PowerLASCOPF loads for the IEEE 57-bus case from CSV data.
"""
function powerlascopf_loads57!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_57_bus", "Loads57_sahar.csv")
    return powerlascopf_loads_from_csv!(system, nodes, csv_path)
end

"""
    create_57bus_powerlascopf_system()

Create a complete PowerLASCOPF system for the IEEE 57-bus test case,
reading all data from *_sahar.csv files.
"""
function create_57bus_powerlascopf_system()
    log_info("Creating 57-bus PowerLASCOPF system...")
    cont_count = length(branches_57_contingency_list())
    RND_int    = 6
    RSD_int    = 6

    nodes_func   = () -> begin
        system = power_lascopf_system57()
        nodes  = powerlascopf_nodes57!(system)
        (system, nodes)
    end
    system, nodes = nodes_func()

    branches  = powerlascopf_branches57!(system, nodes, cont_count, RND_int)
    thermal   = powerlascopf_thermal_generators57!(system, nodes)
    renewables = powerlascopf_renewable_generators57!(system, nodes)
    hydro     = powerlascopf_hydro_generators57!(system, nodes)
    storage   = power_lascopf_storage_generators57!(system, nodes)
    loads     = powerlascopf_loads57!(system, nodes)

    system_data = Dict(
        "name"                   => "57-Bus IEEE Test System",
        "nodes"                  => nodes,
        "branches"               => branches,
        "thermal_generators"     => thermal,
        "renewable_generators"   => renewables,
        "hydro_generators"       => hydro,
        "storage_generators"     => storage,
        "loads"                  => loads,
        "number_of_contingencies" => cont_count,
        "RND_intervals"          => RND_int,
        "RSD_intervals"          => RSD_int,
        "base_power"             => 100.0
    )

    log_info("57-bus PowerLASCOPF system created successfully.")
    return system, system_data
end

# ============================================================
# SECTION: 118-BUS CASE-SPECIFIC FUNCTIONS
# ============================================================

"""
    power_lascopf_system118()

Create an empty PowerLASCOPF system for the IEEE 118-bus test case.
"""
function power_lascopf_system118()
    log_info("Creating PowerLASCOPF System for 118-bus case...")
    system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
    log_info("Created PowerLASCOPF System for 118-bus case.")
    return system
end

"""
    powerlascopf_nodes118!(system)

Create PowerLASCOPF Nodes for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_nodes118!(system::PowerLASCOPF.PowerLASCOPFSystem)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "Nodes118_sahar.csv")
    return powerlascopf_nodes_from_csv!(system, csv_path)
end

"""
    powerlascopf_branches118!(system, nodes, cont_count, RND_int)

Create PowerLASCOPF transmission lines for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_branches118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    cont_count::Int,
    RND_int::Int
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "Trans118_sahar.csv")
    return powerlascopf_branches_from_csv!(
        system, nodes, csv_path, branches_118_contingency_list(), cont_count, RND_int
    )
end

"""
    powerlascopf_thermal_generators118!(system, nodes)

Create PowerLASCOPF thermal generators for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_thermal_generators118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "ThermalGenerators118_sahar.csv")
    cont_count = length(branches_118_contingency_list())
    return powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_renewable_generators118!(system, nodes)

Create PowerLASCOPF renewable generators for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_renewable_generators118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "RenewableGenerators118_sahar.csv")
    cont_count = length(branches_118_contingency_list())
    return powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    powerlascopf_hydro_generators118!(system, nodes)

Create PowerLASCOPF hydro generators for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_hydro_generators118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "HydroGenerators118_sahar.csv")
    cont_count = length(branches_118_contingency_list())
    return powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    power_lascopf_storage_generators118!(system, nodes)

Create PowerLASCOPF storage generators for the IEEE 118-bus case from CSV data.
"""
function power_lascopf_storage_generators118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "Storage118_sahar.csv")
    cont_count = length(branches_118_contingency_list())
    return powerlascopf_storage_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_loads118!(system, nodes)

Create PowerLASCOPF loads for the IEEE 118-bus case from CSV data.
"""
function powerlascopf_loads118!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_118_bus", "Loads118_sahar.csv")
    return powerlascopf_loads_from_csv!(system, nodes, csv_path)
end

"""
    create_118bus_powerlascopf_system()

Create a complete PowerLASCOPF system for the IEEE 118-bus test case,
reading all data from *_sahar.csv files.
"""
function create_118bus_powerlascopf_system()
    log_info("Creating 118-bus PowerLASCOPF system...")
    cont_count = length(branches_118_contingency_list())
    RND_int    = 6
    RSD_int    = 6

    system    = power_lascopf_system118()
    nodes     = powerlascopf_nodes118!(system)
    branches  = powerlascopf_branches118!(system, nodes, cont_count, RND_int)
    thermal   = powerlascopf_thermal_generators118!(system, nodes)
    renewables = powerlascopf_renewable_generators118!(system, nodes)
    hydro     = powerlascopf_hydro_generators118!(system, nodes)
    storage   = power_lascopf_storage_generators118!(system, nodes)
    loads     = powerlascopf_loads118!(system, nodes)

    system_data = Dict(
        "name"                   => "118-Bus IEEE Test System",
        "nodes"                  => nodes,
        "branches"               => branches,
        "thermal_generators"     => thermal,
        "renewable_generators"   => renewables,
        "hydro_generators"       => hydro,
        "storage_generators"     => storage,
        "loads"                  => loads,
        "number_of_contingencies" => cont_count,
        "RND_intervals"          => RND_int,
        "RSD_intervals"          => RSD_int,
        "base_power"             => 100.0
    )

    log_info("118-bus PowerLASCOPF system created successfully.")
    return system, system_data
end

# ============================================================
# SECTION: 300-BUS CASE-SPECIFIC FUNCTIONS
# ============================================================

"""
    power_lascopf_system300()

Create an empty PowerLASCOPF system for the IEEE 300-bus test case.
"""
function power_lascopf_system300()
    log_info("Creating PowerLASCOPF System for 300-bus case...")
    system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
    log_info("Created PowerLASCOPF System for 300-bus case.")
    return system
end

"""
    powerlascopf_nodes300!(system)

Create PowerLASCOPF Nodes for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_nodes300!(system::PowerLASCOPF.PowerLASCOPFSystem)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "Nodes300_sahar.csv")
    return powerlascopf_nodes_from_csv!(system, csv_path)
end

"""
    powerlascopf_branches300!(system, nodes, cont_count, RND_int)

Create PowerLASCOPF transmission lines for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_branches300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}},
    cont_count::Int,
    RND_int::Int
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "Trans300_sahar.csv")
    return powerlascopf_branches_from_csv!(
        system, nodes, csv_path, branches_300_contingency_list(), cont_count, RND_int
    )
end

"""
    powerlascopf_thermal_generators300!(system, nodes)

Create PowerLASCOPF thermal generators for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_thermal_generators300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "ThermalGenerators300_sahar.csv")
    cont_count = length(branches_300_contingency_list())
    return powerlascopf_thermal_generators_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_renewable_generators300!(system, nodes)

Create PowerLASCOPF renewable generators for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_renewable_generators300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "RenewableGenerators300_sahar.csv")
    cont_count = length(branches_300_contingency_list())
    return powerlascopf_renewable_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    powerlascopf_hydro_generators300!(system, nodes)

Create PowerLASCOPF hydro generators for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_hydro_generators300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "HydroGenerators300_sahar.csv")
    cont_count = length(branches_300_contingency_list())
    return powerlascopf_hydro_generators_from_csv!(system, nodes, csv_path, Dict(), cont_count)
end

"""
    power_lascopf_storage_generators300!(system, nodes)

Create PowerLASCOPF storage generators for the IEEE 300-bus case from CSV data.
"""
function power_lascopf_storage_generators300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path   = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "Storage300_sahar.csv")
    cont_count = length(branches_300_contingency_list())
    return powerlascopf_storage_from_csv!(system, nodes, csv_path, cont_count)
end

"""
    powerlascopf_loads300!(system, nodes)

Create PowerLASCOPF loads for the IEEE 300-bus case from CSV data.
"""
function powerlascopf_loads300!(
    system::PowerLASCOPF.PowerLASCOPFSystem,
    nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}
)
    csv_path = joinpath(@__DIR__, "IEEE_Test_Cases", "IEEE_300_bus", "Loads300_sahar.csv")
    return powerlascopf_loads_from_csv!(system, nodes, csv_path)
end

"""
    create_300bus_powerlascopf_system()

Create a complete PowerLASCOPF system for the IEEE 300-bus test case,
reading all data from *_sahar.csv files.
"""
function create_300bus_powerlascopf_system()
    log_info("Creating 300-bus PowerLASCOPF system...")
    cont_count = length(branches_300_contingency_list())
    RND_int    = 6
    RSD_int    = 6

    system    = power_lascopf_system300()
    nodes     = powerlascopf_nodes300!(system)
    branches  = powerlascopf_branches300!(system, nodes, cont_count, RND_int)
    thermal   = powerlascopf_thermal_generators300!(system, nodes)
    renewables = powerlascopf_renewable_generators300!(system, nodes)
    hydro     = powerlascopf_hydro_generators300!(system, nodes)
    storage   = power_lascopf_storage_generators300!(system, nodes)
    loads     = powerlascopf_loads300!(system, nodes)

    system_data = Dict(
        "name"                   => "300-Bus IEEE Test System",
        "nodes"                  => nodes,
        "branches"               => branches,
        "thermal_generators"     => thermal,
        "renewable_generators"   => renewables,
        "hydro_generators"       => hydro,
        "storage_generators"     => storage,
        "loads"                  => loads,
        "number_of_contingencies" => cont_count,
        "RND_intervals"          => RND_int,
        "RSD_intervals"          => RSD_int,
        "base_power"             => 100.0
    )

    log_info("300-bus PowerLASCOPF system created successfully.")
    return system, system_data
end
=#

log_info("PowerLASCOPF data reader module with CSV-based system creation loaded.")
