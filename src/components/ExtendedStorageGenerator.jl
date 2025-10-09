"""
Extended Storage Generator component for PowerLASCOPF.jl

This module defines the ExtendedStorageGenerator struct that extends PowerSystems storage devices
for LASCOPF optimization with ADMM/APP state variables, storage-specific constraints,
and enhanced storage cost modeling including cycling costs and degradation.
"""

using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries

# Include necessary modules from the codebase
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedStorageCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedStorageGenerator{T<:PSY.Storage, U<:GenIntervals}

An extended storage device component that extends PowerSystems storage devices for LASCOPF optimization.
Supports BatteryEMS, GenericBattery, and other storage technologies with storage-specific constraints
like state of charge, cycling limits, and degradation modeling.
"""
@kwdef mutable struct ExtendedStorageGenerator{T<:PSY.Storage, U<:GenIntervals} <: PowerGenerator
    # Core storage device from PowerSystems
    generator::T  # BatteryEMS, GenericBattery, etc. (treating as generator for dispatch)
    
    # Extended storage cost function with regularization
    storage_cost_function::ExtendedStorageCost{U}
    
    # Generator identification
    gen_id::Int64
    number_of_generators::Int64
    dispatch_interval::Int64
    flag_last::Bool
    dummy_zero_int_flag::Int64
    cont_solver_accuracy::Int64
    
    # Scenario management
    scenario_cont_count::Int64
    post_cont_scen_count::Int64
    base_cont_scenario::Int64
    cont_count_gen::Int64
    gen_total::Int64
    
    # Node connection
    conn_nodeg_ptr::Node
    
    # Solver interface for storage devices
    gen_solver::GenSolver{ExtendedStorageCost, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output (positive = discharge, negative = charge)
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Storage-specific operating variables
    state_of_charge::Float64 = 0.5              # Current SOC (0-1)
    energy_level::Float64 = 0.0                 # Current energy level (MWh)
    charging_power::Float64 = 0.0               # Charging power (MW, positive)
    discharging_power::Float64 = 0.0            # Discharging power (MW, positive)
    charging_efficiency::Float64 = 0.95         # Charging efficiency
    discharging_efficiency::Float64 = 0.95      # Discharging efficiency
    round_trip_efficiency::Float64 = 0.90       # Overall round-trip efficiency
    
    # Storage constraints and limits
    soc_min::Float64 = 0.1                      # Minimum SOC (typically 10%)
    soc_max::Float64 = 0.9                      # Maximum SOC (typically 90%)
    charge_rate_limit::Float64 = 0.0            # Maximum charge rate (MW)
    discharge_rate_limit::Float64 = 0.0         # Maximum discharge rate (MW)
    
    # Storage degradation and lifecycle
    cycle_count::Float64 = 0.0                  # Total number of equivalent full cycles
    depth_of_discharge::Float64 = 0.0           # Current depth of discharge
    temperature::Float64 = 25.0                 # Operating temperature (°C)
    calendar_aging::Float64 = 0.0               # Calendar aging factor
    cycle_aging::Float64 = 0.0                  # Cycle aging factor
    capacity_retention::Float64 = 1.0           # Remaining capacity (fraction of original)
    
    # Economic variables
    cycling_cost::Float64 = 0.0                 # Cost per cycle ($/MWh)
    degradation_cost::Float64 = 0.0             # Degradation cost ($/MWh)
    ancillary_service_revenue::Float64 = 0.0    # Revenue from ancillary services
    arbitrage_value::Float64 = 0.0              # Energy arbitrage value
    
    # Grid services capabilities
    frequency_regulation::Bool = true           # Can provide frequency regulation
    spinning_reserve::Bool = true               # Can provide spinning reserve
    non_spinning_reserve::Bool = true           # Can provide non-spinning reserve
    voltage_support::Bool = false               # Can provide voltage support
    black_start_capability::Bool = false        # Black start capability
    
    # Storage timeseries management
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    degradation_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    service_signals::Union{TimeSeries.TimeArray, Nothing} = nothing
    thermal_constraints::Union{TimeSeries.TimeArray, Nothing} = nothing
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Capacity factor (discharge only)
    availability_factor::Float64 = 1.0          # Availability factor
    energy_throughput::Float64 = 0.0            # Cumulative energy throughput (MWh)
    revenue_total::Float64 = 0.0                # Total revenue earned
    
    # Storage-specific cache
    _storage_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedStorageGenerator(
        generator::T,
        storage_cost_function::ExtendedStorageCost{U},
        id_of_gen::Int64,
        interval::Int64,
        last_flag::Bool,
        cont_scenario_count::Int64,
        PC_scenario_count::Int64,
        baseCont::Int64,
        dummyZero::Int64,
        accuracy::Int64,
        nodeConng::Node,
        countOfContingency::Int64,
        gen_total::Int64;
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.Storage, U<:GenIntervals}
        
        # Create solver with storage cost model
        gensolver = GenSolver(
            interval_type = storage_cost_function.regularization_term,
            cost_curve = storage_cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.storage_cost_function = storage_cost_function
        # ...existing code for other assignments...
        
        # Initialize storage-specific parameters
        initialize_storage_parameters!(self)
        
        # Extract timeseries data
        extract_storage_timeseries!(self)
        
        # Set initial storage data
        set_storage_gen_data!(self)
        
        return self
    end
end

"""
    initialize_storage_parameters!(gen::ExtendedStorageGenerator)

Initialize storage-specific parameters from the PowerSystems storage device.
"""
function initialize_storage_parameters!(gen::ExtendedStorageGenerator{T}) where T
    psy_storage = gen.generator
    
    # Extract basic power parameters
    if hasmethod(PSY.get_output_active_power_limits, (T,))
        power_limits = PSY.get_output_active_power_limits(psy_storage)
        gen.discharge_rate_limit = power_limits.max
    end
    
    if hasmethod(PSY.get_input_active_power_limits, (T,))
        charge_limits = PSY.get_input_active_power_limits(psy_storage)
        gen.charge_rate_limit = charge_limits.max
    end
    
    # Extract energy capacity
    if hasmethod(PSY.get_state_of_charge_limits, (T,))
        soc_limits = PSY.get_state_of_charge_limits(psy_storage)
        gen.soc_min = soc_limits.min
        gen.soc_max = soc_limits.max
    end
    
    if hasmethod(PSY.get_storage_capacity, (T,))
        capacity = PSY.get_storage_capacity(psy_storage)
        gen.energy_level = capacity * gen.state_of_charge
    end
    
    # Extract efficiency parameters
    if hasmethod(PSY.get_efficiency, (T,))
        efficiency = PSY.get_efficiency(psy_storage)
        if isa(efficiency, NamedTuple)
            gen.charging_efficiency = get(efficiency, :in, 0.95)
            gen.discharging_efficiency = get(efficiency, :out, 0.95)
        else
            gen.round_trip_efficiency = efficiency
            gen.charging_efficiency = sqrt(efficiency)
            gen.discharging_efficiency = sqrt(efficiency)
        end
    end
    
    # Initialize power dispatch
    gen.Pg = 0.0  # Start with no charging or discharging
    gen.P_gen_prev = 0.0
    gen.P_gen_next = 0.0
    
    # Initialize degradation parameters
    gen.cycling_cost = 5.0    # $/MWh typical cycling cost
    gen.degradation_cost = 2.0  # $/MWh degradation cost
    gen.capacity_retention = 1.0
    
    # Initialize performance metrics
    gen.availability_factor = PSY.get_available(psy_storage) ? 1.0 : 0.0
end

"""
    extract_storage_timeseries!(gen::ExtendedStorageGenerator)

Extract storage-specific timeseries data from PowerSystems storage device.
"""
function extract_storage_timeseries!(gen::ExtendedStorageGenerator)
    psy_storage = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries
    time_series_names = PSY.get_time_series_names(psy_storage)
    
    for ts_name in time_series_names
        try
            ts_data = PSY.get_time_series(psy_storage, ts_name)
            
            # Map timeseries based on name
            if occursin("Price", string(ts_name)) || occursin("LMP", string(ts_name))
                gen.price_forecast = ts_data
            elseif occursin("Degradation", string(ts_name)) || occursin("Aging", string(ts_name))
                gen.degradation_forecast = ts_data
            elseif occursin("Service", string(ts_name)) || occursin("Regulation", string(ts_name))
                gen.service_signals = ts_data
            elseif occursin("Thermal", string(ts_name)) || occursin("Temperature", string(ts_name))
                gen.thermal_constraints = ts_data
            end
            
        catch e
            @debug "Could not extract timeseries $ts_name for storage device $(PSY.get_name(psy_storage)): $e"
        end
    end
end

"""
    update_storage_state!(gen::ExtendedStorageGenerator, power::Float64, time_step::Float64 = 1.0)

Update storage state of charge and energy level based on power dispatch.
"""
function update_storage_state!(gen::ExtendedStorageGenerator, power::Float64, time_step::Float64 = 1.0)
    gen.Pg = power
    
    # Determine charging vs discharging
    if power > 0  # Discharging
        gen.discharging_power = power
        gen.charging_power = 0.0
        
        # Decrease energy level accounting for efficiency
        energy_delivered = power * time_step
        energy_from_storage = energy_delivered / gen.discharging_efficiency
        gen.energy_level = max(0.0, gen.energy_level - energy_from_storage)
        
    elseif power < 0  # Charging
        gen.charging_power = -power
        gen.discharging_power = 0.0
        
        # Increase energy level accounting for efficiency
        energy_consumed = -power * time_step
        energy_to_storage = energy_consumed * gen.charging_efficiency
        capacity = PSY.get_storage_capacity(gen.generator)
        gen.energy_level = min(capacity, gen.energy_level + energy_to_storage)
        
    else  # Idle
        gen.charging_power = 0.0
        gen.discharging_power = 0.0
    end
    
    # Update state of charge
    capacity = PSY.get_storage_capacity(gen.generator)
    if capacity > 0
        gen.state_of_charge = gen.energy_level / capacity
    end
    
    # Update cycle counting and degradation
    update_storage_degradation!(gen, time_step)
    
    # Update performance metrics
    update_storage_performance!(gen, time_step)
end

"""
    update_storage_degradation!(gen::ExtendedStorageGenerator, time_step::Float64)

Update storage degradation based on cycling and calendar aging.
"""
function update_storage_degradation!(gen::ExtendedStorageGenerator, time_step::Float64)
    # Calendar aging (simplified linear model)
    calendar_aging_rate = 0.02 / 8760  # 2% per year
    gen.calendar_aging += calendar_aging_rate * time_step
    
    # Cycle aging based on depth of discharge
    if gen.charging_power > 0 || gen.discharging_power > 0
        # Calculate depth of discharge for this interval
        capacity = PSY.get_storage_capacity(gen.generator)
        energy_cycled = max(gen.charging_power, gen.discharging_power) * time_step
        dod_increment = energy_cycled / capacity
        
        gen.depth_of_discharge += dod_increment
        
        # Count equivalent full cycles (simplified)
        if gen.depth_of_discharge >= 1.0
            gen.cycle_count += gen.depth_of_discharge
            gen.depth_of_discharge = 0.0  # Reset
        end
        
        # Cycle aging (Arrhenius equation simplified)
        cycle_aging_rate = 0.05 / 5000  # 5% after 5000 cycles
        gen.cycle_aging += cycle_aging_rate * dod_increment
    end
    
    # Update capacity retention
    total_aging = gen.calendar_aging + gen.cycle_aging
    gen.capacity_retention = max(0.7, 1.0 - total_aging)  # Minimum 70% retention
end

"""
    update_storage_performance!(gen::ExtendedStorageGenerator, time_step::Float64)

Update storage performance metrics.
"""
function update_storage_performance!(gen::ExtendedStorageGenerator, time_step::Float64)
    # Update energy throughput
    energy_throughput_increment = max(gen.charging_power, gen.discharging_power) * time_step
    gen.energy_throughput += energy_throughput_increment
    
    # Update capacity factor (discharge only)
    if gen.discharge_rate_limit > 0
        gen.capacity_factor = gen.discharging_power / gen.discharge_rate_limit
    end
    
    # Update arbitrage value (simplified)
    if !isnothing(gen.price_forecast) && !isnothing(gen.current_time)
        try
            current_price = PSY.get_value_at_time(gen.price_forecast, gen.current_time)
            
            if gen.discharging_power > 0
                gen.arbitrage_value += current_price * gen.discharging_power * time_step
            elseif gen.charging_power > 0
                gen.arbitrage_value -= current_price * gen.charging_power * time_step
            end
        catch e
            @debug "Could not calculate arbitrage value: $e"
        end
    end
end

"""
    check_storage_constraints(gen::ExtendedStorageGenerator)::Vector{String}

Check storage-specific constraints and return violations.
"""
function check_storage_constraints(gen::ExtendedStorageGenerator)::Vector{String}
    violations = String[]
    
    # SOC constraints
    if gen.state_of_charge < gen.soc_min
        push!(violations, "SOC below minimum: $(gen.state_of_charge) < $(gen.soc_min)")
    elseif gen.state_of_charge > gen.soc_max
        push!(violations, "SOC above maximum: $(gen.state_of_charge) > $(gen.soc_max)")
    end
    
    # Power rate constraints
    if gen.charging_power > gen.charge_rate_limit
        push!(violations, "Charging power exceeds limit: $(gen.charging_power) > $(gen.charge_rate_limit)")
    end
    
    if gen.discharging_power > gen.discharge_rate_limit
        push!(violations, "Discharging power exceeds limit: $(gen.discharging_power) > $(gen.discharge_rate_limit)")
    end
    
    # Cannot charge and discharge simultaneously
    if gen.charging_power > 0 && gen.discharging_power > 0
        push!(violations, "Simultaneous charging and discharging not allowed")
    end
    
    return violations
end

"""
    calculate_storage_operating_cost(gen::ExtendedStorageGenerator, time_step::Float64 = 1.0)::Float64

Calculate total storage operating cost including cycling and degradation costs.
"""
function calculate_storage_operating_cost(gen::ExtendedStorageGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    # Base operating cost (typically very low for storage)
    if is_regularization_active(gen.storage_cost_function)
        total_cost += build_storage_cost_expression(
            gen.storage_cost_function, 
            gen.Pg, 
            gen.state_of_charge,
            time_step,
            gen.P_gen_next, 
            gen.theta_g
        )
    end
    
    # Cycling cost (wear and tear)
    energy_cycled = max(gen.charging_power, gen.discharging_power) * time_step
    total_cost += gen.cycling_cost * energy_cycled
    
    # Degradation cost
    total_cost += gen.degradation_cost * energy_cycled * (1.0 - gen.capacity_retention)
    
    # Subtract ancillary service revenue
    total_cost -= gen.ancillary_service_revenue * time_step
    
    return total_cost
end

# ...existing code for solver functions...

export ExtendedStorageGenerator
export initialize_storage_parameters!, extract_storage_timeseries!
export update_storage_state!, update_storage_degradation!, update_storage_performance!
export check_storage_constraints, calculate_storage_operating_cost
