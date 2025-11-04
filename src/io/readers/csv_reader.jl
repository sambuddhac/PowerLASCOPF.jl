"""
CSV Reader for PowerLASCOPF

This module provides functionality to read various CSV-based power system data formats
and convert them into PowerSystems.jl compatible objects for use with PowerLASCOPF.

Supported formats:
- RTS-GMLC CSV format (PowerSystems standard)
- Custom csv_118 format
- Generic CSV formats with appropriate mappings

Author: PowerLASCOPF Development Team
"""

using CSV
using DataFrames
using PowerSystems
using Dates
using TimeSeries

const PSY = PowerSystems

"""
    CSVReaderConfig

Configuration for CSV reader, allowing customization of field mappings
and default values for missing fields.
"""
Base.@kwdef struct CSVReaderConfig
    # Base power in MVA for per-unit calculations
    base_power::Float64 = 100.0

    # Default voltage limits (min, max) in per-unit
    default_voltage_limits::Tuple{Float64, Float64} = (0.9, 1.1)

    # Default base voltage in kV
    default_base_voltage::Float64 = 138.0

    # Default ramp rate as fraction of capacity per minute
    default_ramp_rate::Float64 = 0.02

    # Default minimum up/down times in hours
    default_min_up_time::Float64 = 1.0
    default_min_down_time::Float64 = 1.0

    # Default fuel types
    default_thermal_fuel::PSY.ThermalFuels.ThermalFuel = PSY.ThermalFuels.COAL
    default_prime_mover::PSY.PrimeMovers.PrimeMover = PSY.PrimeMovers.ST

    # Time series defaults
    default_horizon::Int = 24  # hours
    start_time::DateTime = DateTime("2024-01-01T00:00:00")
end

"""
    detect_csv_format(data_dir::String) -> Symbol

Detect the CSV format by examining files in the directory.
Returns :rts_gmlc, :csv_118, or :unknown
"""
function detect_csv_format(data_dir::String)
    files = readdir(data_dir)

    # Check for RTS-GMLC format
    if "bus.csv" in files && "gen.csv" in files && "branch.csv" in files
        return :rts_gmlc
    end

    # Check for csv_118 format
    if "Buses.csv" in files && "Generators.csv" in files && "Lines.csv" in files
        return :csv_118
    end

    return :unknown
end

"""
    read_buses_rts_gmlc(file_path::String, config::CSVReaderConfig) -> Vector{PSY.Bus}

Read buses from RTS-GMLC format CSV file.
"""
function read_buses_rts_gmlc(file_path::String, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    buses = PSY.Bus[]

    for row in eachrow(df)
        bus_number = row[Symbol("Bus ID")]
        bus_name = string(row[Symbol("Bus Name")])
        base_voltage = row[:BaseKV]
        bus_type = string(row[Symbol("Bus Type")])

        # Convert bus type to PowerSystems format
        psy_bus_type = if bus_type == "Ref"
            "REF"
        elseif bus_type == "PV"
            "PV"
        else
            "PQ"
        end

        # Get voltage magnitude, default to 1.0 if missing
        v_mag = hasproperty(df, Symbol("V Mag")) ? row[Symbol("V Mag")] : 1.0

        # Get voltage angle, default to 0.0 if missing
        v_angle = hasproperty(df, Symbol("V Angle")) ? row[Symbol("V Angle")] : 0.0

        bus = PSY.Bus(
            bus_number,
            bus_name,
            psy_bus_type,
            v_angle,
            v_mag,
            config.default_voltage_limits,
            base_voltage,
            nothing,  # area
            nothing   # load_zone
        )
        push!(buses, bus)
    end

    return buses
end

"""
    read_buses_csv118(file_path::String, config::CSVReaderConfig) -> Vector{PSY.Bus}

Read buses from csv_118 format CSV file.
"""
function read_buses_csv118(file_path::String, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    buses = PSY.Bus[]

    for (idx, row) in enumerate(eachrow(df))
        bus_name = string(row[Symbol("Bus Name")])

        # Extract bus number from name (e.g., "bus026" -> 26)
        bus_number = parse(Int, replace(bus_name, "bus" => ""))

        # For csv_118 format, we don't have explicit bus types
        # We'll infer based on load participation factor
        load_participation = row[Symbol("Load Participation Factor")]
        bus_type = load_participation > 0 ? "PQ" : "PV"

        bus = PSY.Bus(
            bus_number,
            bus_name,
            bus_type,
            0.0,  # angle
            1.0,  # voltage magnitude
            config.default_voltage_limits,
            config.default_base_voltage,
            nothing,  # area
            nothing   # load_zone
        )
        push!(buses, bus)
    end

    return buses
end

"""
    read_branches_rts_gmlc(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.Branch}

Read branches (lines) from RTS-GMLC format CSV file.
"""
function read_branches_rts_gmlc(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    branches = PSY.Branch[]

    # Create bus lookup dictionary
    bus_dict = Dict(b.number => b for b in buses)

    for (idx, row) in enumerate(eachrow(df))
        from_bus_id = row[Symbol("From Bus")]
        to_bus_id = row[Symbol("To Bus")]

        # Get buses
        from_bus = get(bus_dict, from_bus_id, nothing)
        to_bus = get(bus_dict, to_bus_id, nothing)

        if isnothing(from_bus) || isnothing(to_bus)
            @warn "Skipping branch $idx: buses $from_bus_id or $to_bus_id not found"
            continue
        end

        # Read branch parameters
        r = row[:R]
        x = row[:X]
        b_from = hasproperty(df, :B) ? row[:B] / 2 : 0.0
        b_to = b_from

        # Read rating
        rating = hasproperty(df, Symbol("Cont Rating")) ? row[Symbol("Cont Rating")] / config.base_power : 10.0

        # Read angle limits if available
        angle_limits = if hasproperty(df, Symbol("Min Angle Diff")) && hasproperty(df, Symbol("Max Angle Diff"))
            (min = row[Symbol("Min Angle Diff")], max = row[Symbol("Max Angle Diff")])
        else
            (min = -π/6, max = π/6)
        end

        branch_name = "branch_$(from_bus_id)_$(to_bus_id)_$(idx)"

        line = PSY.Line(
            branch_name,
            true,  # available
            0.0,   # active_power_flow
            0.0,   # reactive_power_flow
            PSY.Arc(from = from_bus, to = to_bus),
            r,
            x,
            (from = b_from, to = b_to),
            rating,
            angle_limits
        )

        push!(branches, line)
    end

    return branches
end

"""
    read_branches_csv118(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.Branch}

Read branches (lines) from csv_118 format CSV file.
"""
function read_branches_csv118(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    branches = PSY.Branch[]

    # Create bus lookup dictionary by name
    bus_dict = Dict(b.name => b for b in buses)

    for row in eachrow(df)
        line_name = string(row[Symbol("Line Name")])
        from_bus_name = string(row[Symbol("Bus from ")])  # Note the space
        to_bus_name = string(row[Symbol("Bus to")])

        # Get buses
        from_bus = get(bus_dict, from_bus_name, nothing)
        to_bus = get(bus_dict, to_bus_name, nothing)

        if isnothing(from_bus) || isnothing(to_bus)
            @warn "Skipping line $line_name: buses $from_bus_name or $to_bus_name not found"
            continue
        end

        # Read line parameters
        r = row[Symbol("Resistance (p.u.)")]
        x = row[Symbol("Reactance (p.u.)")]

        # Calculate susceptance (assuming no explicit b in the file)
        b_from = 0.0
        b_to = 0.0

        # Read rating (convert from MW to per-unit)
        max_flow = row[Symbol("Max Flow (MW)")]
        rating = max_flow / config.base_power

        # Set angle limits based on flow limits
        angle_limits = (min = -π/6, max = π/6)

        line = PSY.Line(
            line_name,
            true,  # available
            0.0,   # active_power_flow
            0.0,   # reactive_power_flow
            PSY.Arc(from = from_bus, to = to_bus),
            r,
            x,
            (from = b_from, to = b_to),
            rating,
            angle_limits
        )

        push!(branches, line)
    end

    return branches
end

"""
    read_generators_rts_gmlc(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.Generator}

Read generators from RTS-GMLC format CSV file.
"""
function read_generators_rts_gmlc(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    generators = PSY.Generator[]

    # Create bus lookup dictionary
    bus_dict = Dict(b.number => b for b in buses)

    for row in eachrow(df)
        gen_uid = string(row[Symbol("GEN UID")])
        bus_id = row[Symbol("Bus ID")]

        # Get bus
        bus = get(bus_dict, bus_id, nothing)
        if isnothing(bus)
            @warn "Skipping generator $gen_uid: bus $bus_id not found"
            continue
        end

        # Read generator parameters
        pmax = row[Symbol("PMax MW")] / config.base_power
        pmin = row[Symbol("PMin MW")] / config.base_power
        qmax = row[Symbol("QMax MVAR")] / config.base_power
        qmin = row[Symbol("QMin MVAR")] / config.base_power

        # Get current injection
        p = hasproperty(df, Symbol("MW Inj")) ? row[Symbol("MW Inj")] / config.base_power : pmin
        q = hasproperty(df, Symbol("MVAR Inj")) ? row[Symbol("MVAR Inj")] / config.base_power : 0.0

        # Determine generator type and fuel
        unit_type = string(row[Symbol("Unit Type")])
        fuel = hasproperty(df, :Fuel) ? string(row[:Fuel]) : "COAL"

        # Map fuel string to PowerSystems enum
        psy_fuel = if fuel == "NG" || fuel == "Gas"
            PSY.ThermalFuels.NATURAL_GAS
        elseif fuel == "Coal"
            PSY.ThermalFuels.COAL
        elseif fuel == "Oil"
            PSY.ThermalFuels.DISTILLATE_FUEL_OIL
        else
            config.default_thermal_fuel
        end

        # Map unit type to prime mover
        psy_prime_mover = if unit_type == "CT"
            PSY.PrimeMovers.CT
        elseif unit_type == "CC"
            PSY.PrimeMovers.CC
        elseif unit_type == "STEAM"
            PSY.PrimeMovers.ST
        else
            config.default_prime_mover
        end

        # Get ramp rates
        ramp_rate = if hasproperty(df, Symbol("Ramp Rate MW/Min"))
            row[Symbol("Ramp Rate MW/Min")] / config.base_power
        else
            pmax * config.default_ramp_rate
        end

        # Get time limits
        min_up_time = hasproperty(df, Symbol("Min Up Time Hr")) ? row[Symbol("Min Up Time Hr")] : config.default_min_up_time
        min_down_time = hasproperty(df, Symbol("Min Down Time Hr")) ? row[Symbol("Min Down Time Hr")] : config.default_min_down_time

        # Create operation cost (simplified)
        # In a real implementation, you'd parse the heat rate curve
        variable_cost = 30.0  # Default $/MWh
        fixed_cost = 0.0
        startup_cost = 0.0
        shutdn_cost = 0.0

        operation_cost = PSY.ThreePartCost(
            (0.0, variable_cost),
            fixed_cost,
            startup_cost,
            shutdn_cost
        )

        # Create generator
        gen = PSY.ThermalStandard(
            name = gen_uid,
            available = true,
            status = true,
            bus = bus,
            active_power = p,
            reactive_power = q,
            rating = pmax * 1.1,  # Rating slightly higher than Pmax
            prime_mover = psy_prime_mover,
            fuel = psy_fuel,
            active_power_limits = (min = pmin, max = pmax),
            reactive_power_limits = (min = qmin, max = qmax),
            ramp_limits = (up = ramp_rate, down = ramp_rate),
            time_limits = (up = min_up_time, down = min_down_time),
            operation_cost = operation_cost,
            base_power = config.base_power
        )

        push!(generators, gen)
    end

    return generators
end

"""
    read_generators_csv118(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.Generator}

Read generators from csv_118 format CSV file.
"""
function read_generators_csv118(file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(file_path, DataFrame)
    generators = PSY.Generator[]

    # Create bus lookup dictionary by name
    bus_dict = Dict(b.name => b for b in buses)

    for row in eachrow(df)
        gen_name = string(row[Symbol("Generator Name")])
        bus_name = string(row[Symbol("bus of connection")])

        # Get bus
        bus = get(bus_dict, bus_name, nothing)
        if isnothing(bus)
            @warn "Skipping generator $gen_name: bus $bus_name not found"
            continue
        end

        # Read generator parameters
        max_capacity_mw = row[Symbol("Max Capacity (MW)")]
        pmax = max_capacity_mw / config.base_power

        # Read minimum stable level if available
        pmin = if hasproperty(df, Symbol("Min Stable Level (MW)"))
            row[Symbol("Min Stable Level (MW)")] / config.base_power
        else
            pmax * 0.3  # Default to 30% of max
        end

        # Default reactive power limits
        qmax = pmax * 0.5
        qmin = -pmax * 0.5

        # Get ramp rates if available
        ramp_up = if hasproperty(df, Symbol("Max Ramp Up (MW/min)"))
            row[Symbol("Max Ramp Up (MW/min)")] / config.base_power
        else
            pmax * config.default_ramp_rate
        end

        ramp_down = if hasproperty(df, Symbol("Max Ramp Down (MW/min)"))
            row[Symbol("Max Ramp Down (MW/min)")] / config.base_power
        else
            pmax * config.default_ramp_rate
        end

        # Get time limits if available
        min_up_time = if hasproperty(df, Symbol("Min Up Time (h)"))
            row[Symbol("Min Up Time (h)")]
        else
            config.default_min_up_time
        end

        min_down_time = if hasproperty(df, Symbol("Min Down Time (h)"))
            row[Symbol("Min Down Time (h)")]
        else
            config.default_min_down_time
        end

        # Parse generator type from name to determine fuel and prime mover
        gen_type_lower = lowercase(gen_name)
        psy_fuel = if contains(gen_type_lower, "ng") || contains(gen_type_lower, "gas")
            PSY.ThermalFuels.NATURAL_GAS
        elseif contains(gen_type_lower, "coal")
            PSY.ThermalFuels.COAL
        elseif contains(gen_type_lower, "oil")
            PSY.ThermalFuels.DISTILLATE_FUEL_OIL
        elseif contains(gen_type_lower, "biomass")
            PSY.ThermalFuels.WASTE_COAL
        else
            config.default_thermal_fuel
        end

        psy_prime_mover = if contains(gen_type_lower, "ct")
            PSY.PrimeMovers.CT
        elseif contains(gen_type_lower, "cc")
            PSY.PrimeMovers.CC
        elseif contains(gen_type_lower, "st")
            PSY.PrimeMovers.ST
        else
            config.default_prime_mover
        end

        # Get O&M cost if available
        vom_cost = if hasproperty(df, Symbol("VO&M Charge (\$/MWh)"))
            row[Symbol("VO&M Charge (\$/MWh)")]
        else
            30.0  # Default
        end

        # Get start cost if available
        start_cost = if hasproperty(df, Symbol("Start Cost (\$)"))
            row[Symbol("Start Cost (\$)")]
        else
            0.0
        end

        operation_cost = PSY.ThreePartCost(
            (0.0, vom_cost),
            0.0,  # fixed cost
            start_cost,
            0.0   # shutdown cost
        )

        # Create generator
        gen = PSY.ThermalStandard(
            name = gen_name,
            available = true,
            status = true,
            bus = bus,
            active_power = pmin,  # Start at minimum
            reactive_power = 0.0,
            rating = pmax * 1.1,
            prime_mover = psy_prime_mover,
            fuel = psy_fuel,
            active_power_limits = (min = pmin, max = pmax),
            reactive_power_limits = (min = qmin, max = qmax),
            ramp_limits = (up = ramp_up, down = ramp_down),
            time_limits = (up = min_up_time, down = min_down_time),
            operation_cost = operation_cost,
            base_power = config.base_power
        )

        push!(generators, gen)
    end

    return generators
end

"""
    read_loads_rts_gmlc(bus_file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.PowerLoad}

Read loads from RTS-GMLC format bus CSV file (loads are specified in the bus file).
"""
function read_loads_rts_gmlc(bus_file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(bus_file_path, DataFrame)
    loads = PSY.PowerLoad[]

    # Create bus lookup dictionary
    bus_dict = Dict(b.number => b for b in buses)

    for row in eachrow(df)
        bus_id = row[Symbol("Bus ID")]
        mw_load = row[Symbol("MW Load")]
        mvar_load = row[Symbol("MVAR Load")]

        # Only create load if non-zero
        if mw_load > 0 || mvar_load > 0
            bus = get(bus_dict, bus_id, nothing)
            if isnothing(bus)
                @warn "Skipping load at bus $bus_id: bus not found"
                continue
            end

            # Convert to per-unit
            p = mw_load / config.base_power
            q = mvar_load / config.base_power

            load = PSY.PowerLoad(
                "Load_$(bus_id)",
                true,  # available
                bus,
                PSY.LoadModels.ConstantPower,
                p,
                q,
                config.base_power,
                p,  # max_active_power
                q   # max_reactive_power
            )

            push!(loads, load)
        end
    end

    return loads
end

"""
    read_loads_csv118(bus_file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig) -> Vector{PSY.PowerLoad}

Read loads from csv_118 format. Since the csv_118 Buses file only has load participation factors,
we'll create nominal loads based on those factors.
"""
function read_loads_csv118(bus_file_path::String, buses::Vector{PSY.Bus}, config::CSVReaderConfig)
    df = CSV.read(bus_file_path, DataFrame)
    loads = PSY.PowerLoad[]

    # Create bus lookup dictionary by name
    bus_dict = Dict(b.name => b for b in buses)

    # Assume total system load of 1000 MW for scaling
    total_system_load_mw = 1000.0
    total_system_load_pu = total_system_load_mw / config.base_power

    for row in eachrow(df)
        bus_name = string(row[Symbol("Bus Name")])
        load_participation = row[Symbol("Load Participation Factor")]

        # Only create load if participation factor is non-zero
        if load_participation > 0
            bus = get(bus_dict, bus_name, nothing)
            if isnothing(bus)
                @warn "Skipping load at bus $bus_name: bus not found"
                continue
            end

            # Calculate load based on participation factor
            p = total_system_load_pu * load_participation
            q = p * 0.33  # Assume power factor of 0.95 (tan(acos(0.95)) ≈ 0.33)

            load = PSY.PowerLoad(
                "Load_$bus_name",
                true,  # available
                bus,
                PSY.LoadModels.ConstantPower,
                p,
                q,
                config.base_power,
                p,  # max_active_power
                q   # max_reactive_power
            )

            push!(loads, load)
        end
    end

    return loads
end

"""
    read_csv_system(data_dir::String; config::CSVReaderConfig=CSVReaderConfig()) -> PSY.System

Read a complete power system from CSV files in the specified directory.
Automatically detects the CSV format and reads all necessary files.
"""
function read_csv_system(data_dir::String; config::CSVReaderConfig=CSVReaderConfig())
    format = detect_csv_format(data_dir)

    if format == :unknown
        error("Unknown CSV format in directory: $data_dir")
    end

    @info "Detected CSV format: $format"

    # Read components based on format
    buses, branches, generators, loads = if format == :rts_gmlc
        bus_file = joinpath(data_dir, "bus.csv")
        branch_file = joinpath(data_dir, "branch.csv")
        gen_file = joinpath(data_dir, "gen.csv")

        buses = read_buses_rts_gmlc(bus_file, config)
        @info "Read $(length(buses)) buses"

        branches = read_branches_rts_gmlc(branch_file, buses, config)
        @info "Read $(length(branches)) branches"

        generators = read_generators_rts_gmlc(gen_file, buses, config)
        @info "Read $(length(generators)) generators"

        loads = read_loads_rts_gmlc(bus_file, buses, config)
        @info "Read $(length(loads)) loads"

        (buses, branches, generators, loads)

    elseif format == :csv_118
        bus_file = joinpath(data_dir, "Buses.csv")
        line_file = joinpath(data_dir, "Lines.csv")
        gen_file = joinpath(data_dir, "Generators.csv")

        buses = read_buses_csv118(bus_file, config)
        @info "Read $(length(buses)) buses"

        branches = read_branches_csv118(line_file, buses, config)
        @info "Read $(length(branches)) branches"

        generators = read_generators_csv118(gen_file, buses, config)
        @info "Read $(length(generators)) generators"

        loads = read_loads_csv118(bus_file, buses, config)
        @info "Read $(length(loads)) loads"

        (buses, branches, generators, loads)
    end

    # Create system
    system = PSY.System(config.base_power)
    system.name = "System_$(basename(data_dir))"

    # Add all components to system
    for bus in buses
        PSY.add_component!(system, bus)
    end

    for branch in branches
        PSY.add_component!(system, branch)
    end

    for gen in generators
        PSY.add_component!(system, gen)
    end

    for load in loads
        PSY.add_component!(system, load)
    end

    @info "Created PowerSystems.System with $(length(buses)) buses, $(length(branches)) branches, $(length(generators)) generators, and $(length(loads)) loads"

    return system
end

export CSVReaderConfig, read_csv_system, detect_csv_format
export read_buses_rts_gmlc, read_buses_csv118
export read_branches_rts_gmlc, read_branches_csv118
export read_generators_rts_gmlc, read_generators_csv118
export read_loads_rts_gmlc, read_loads_csv118
