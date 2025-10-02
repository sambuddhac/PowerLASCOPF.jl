"""
Load Timeseries Integration for PowerLASCOPF.jl

This module handles the integration of Load components with PowerSystems timeseries
and stochastic scenarios for PowerLASCOPF optimization.
"""

using PowerSystems
using InfrastructureSystems
using TimeSeries
using JSON

const PSY = PowerSystems
const IS = InfrastructureSystems

"""
    update_load_from_timeseries!(load::Load, time_step::Int, scenario::Int=1)

Updates the load Pl value from timeseries data for a specific time step and scenario.
"""
function update_load_from_timeseries!(load::Load, time_step::Int, scenario::Int=1)
    if !isnothing(load.load_type) && PSY.has_time_series(load.load_type)
        # Get the timeseries data
        ts_keys = PSY.get_time_series_keys(load.load_type)
        
        for key in ts_keys
            if key.name == "max_active_power" || key.name == "active_power"
                ts_data = PSY.get_time_series(PSY.Deterministic, load.load_type, key.name)
                
                # Extract value for the specific time step
                ts_values = PSY.get_data(ts_data)
                if time_step <= length(ts_values)
                    load.Pl = ts_values[time_step]
                    load.P_avg = load.Pl  # Update average for ADMM
                end
                break
            end
        end
    end
end

"""
    create_stochastic_load_scenarios(base_load::Load, scenario_count::Int, uncertainty::Float64=0.1)

Creates multiple stochastic scenarios for a load based on uncertainty parameters.
"""
function create_stochastic_load_scenarios(base_load::Load, scenario_count::Int, uncertainty::Float64=0.1)
    scenarios = Vector{Load}[]
    
    for scenario in 1:scenario_count
        scenario_load = deepcopy(base_load)
        
        # Add stochastic variation
        random_factor = 1.0 + uncertainty * (2 * rand() - 1)  # ±uncertainty around nominal
        scenario_load.Pl *= random_factor
        
        push!(scenarios, scenario_load)
    end
    
    return scenarios
end

"""
    load_ieee_case_loads(case_number::Int)

Loads IEEE test case load data from JSON files.
"""
function load_ieee_case_loads(case_number::Int)
    case_path = "example_cases/IEEE_Test_Cases/IEEE_$(case_number)_bus/Load$(case_number).json"
    
    if isfile(case_path)
        return JSON.parsefile(case_path)
    else
        error("IEEE $case_number bus case load data not found at $case_path")
    end
end

"""
    create_loads_with_timeseries(system::PSY.System, load_data::Vector, time_horizon::Int)

Creates Load components with timeseries data integrated.
"""
function create_loads_with_timeseries(system::PSY.System, load_data::Vector, time_horizon::Int)
    loads = Load[]
    
    for (idx, load_info) in enumerate(load_data)
        # Try to get existing bus
        bus = PSY.get_component(PSY.Bus, system, "Bus_$(load_info["ConnNode"])")
        
        if isnothing(bus)
            # Create a new bus since it doesn't exist in the system
            bus_number = load_info["ConnNode"]
            
            # Create ACBus (most common bus type for distribution systems)
            bus = PSY.ACBus(
                number = bus_number,
                name = "Bus_$(bus_number)",
                bustype = PSY.BusTypes.PQ,  # Load buses are typically PQ buses
                angle = 0.0,  # Initial angle in radians
                magnitude = 1.0,  # Per-unit voltage magnitude (typically 1.0 for nominal)
                voltage_limits = (min = 0.95, max = 1.05),  # ±5% voltage limits
                base_voltage = 138.0,  # kV - adjust based on your system
                area = PSY.Area(name = "Area_1"),  # Create default area
                load_zone = PSY.LoadZone(name = "Zone_1"),  # Create default load zone
                available = true
            )
            
            # Add the newly created bus to the system
            try
                PSY.add_component!(system, bus)
                @info "Created and added bus $(bus_number) to system"
            catch e
                # Handle potential duplicate bus addition
                if isa(e, ArgumentError) && occursin("already exists", string(e))
                    @warn "Bus $(bus_number) already exists, retrieving existing bus"
                    bus = PSY.get_component(PSY.ACBus, system, "Bus_$(bus_number)")
                else
                    @error "Failed to add bus $(bus_number) to system: $e"
                    continue  # Skip this load if bus creation fails
                end
            end
        end
        
        # Create base PSY load
        psy_load = PSY.PowerLoad(
            name="Load_$(idx)",
            available=true,
            bus=bus,
            active_power=abs(load_info["Interval-1_Load"]),
            reactive_power=abs(load_info["Interval-1_Load"]) * 0.3,  # Assume 0.3 power factor
            base_power=100.0,
            max_active_power=abs(load_info["Interval-1_Load"]) * 1.2,
            max_reactive_power=abs(load_info["Interval-1_Load"]) * 0.4
        )
        
        # Create timeseries data
        dates = collect(DateTime(2024,1,1):Hour(1):DateTime(2024,1,1) + Hour(time_horizon-1))
        
        # Create load profile (using both intervals)
        load_profile = Vector{Float64}(undef, time_horizon)
        for t in 1:time_horizon
            if t <= time_horizon ÷ 2
                load_profile[t] = abs(load_info["Interval-1_Load"])
            else
                load_profile[t] = abs(load_info["Interval-2_Load"])
            end
        end
        
        # Add timeseries to PSY load
        ts_data = PSY.SingleTimeSeries("max_active_power", TimeArray(dates, load_profile))
        PSY.add_component!(system, psy_load)
        PSY.add_time_series!(system, psy_load, ts_data)
        
        # Create PowerLASCOPF Load
        load = Load(psy_load, idx, -abs(load_info["Interval-1_Load"]))  # Negative for consumption
        
        push!(loads, load)
    end
    
    return loads
end

"""
    update_all_loads_for_timestep!(loads::Vector{Load}, time_step::Int, scenario::Int=1)

Updates all loads in a system for a specific time step and scenario.
"""
function update_all_loads_for_timestep!(loads::Vector{Load}, time_step::Int, scenario::Int=1)
    for load in loads
        update_load_from_timeseries!(load, time_step, scenario)
    end
end

# Export functions
export update_load_from_timeseries!, create_stochastic_load_scenarios
export load_ieee_case_loads, create_loads_with_timeseries
export update_all_loads_for_timestep!