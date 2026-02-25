"""
Generic Data Reader for PowerLASCOPF Systems

WHY THIS FILE EXISTS:
- Replaces hardcoded arrays in data_5bus_pu.jl and data_14bus_pu.jl
- Reads data from CSV/JSON files instead of Julia arrays
- Makes the system case-independent (works for 5-bus, 14-bus, or custom)
- Separates data storage from code logic

ARCHITECTURE:
1. Data Reading Functions (read_*_data): Load CSV/JSON into Julia structures
2. Factory Functions (*_func): Create PowerSystems objects from loaded data
3. System Creation Functions: Assemble complete PowerLASCOPF system

FILE STRUCTURE:
- Lines 1-100: Imports, logging, utilities
- Lines 101-300: Data reading functions (CSV/JSON parsers)
- Lines 301-600: System creation functions (adapted from data_5bus_pu.jl)
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
                    prime_mover_type = getfield(PrimeMovers, Symbol(row.PrimeMover)),  # e.g., "ST" -> PrimeMovers.ST
                    fuel = getfield(ThermalFuels, Symbol(row.Fuel)),  # e.g., "COAL" -> ThermalFuels.COAL
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
                    prime_mover_type = getfield(PrimeMovers, Symbol(gen_data["PrimeMover"])),
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
