"""
Extended Hydro Generator component for PowerLASCOPF.jl

This module defines the ExtendedHydroGenerator struct that extends PowerSystems hydro generators
for LASCOPF optimization with ADMM/APP state variables, hydro-specific constraints,
and enhanced hydro cost modeling.
"""

using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries

# Include necessary modules from the codebase
include("../core/types.jl")
include("node.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedHydroGenerationCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

"""
    ExtendedHydroGenerator{T<:PSY.HydroGen, U<:GenIntervals}

An extended hydro generator component that extends PowerSystems hydro generators for LASCOPF optimization.
Supports HydroDispatch, HydroEnergyReservoir, HydroPumpedStorage, and other hydro types with
hydro-specific constraints like water flow limits, reservoir levels, and pumping capabilities.
"""
@kwdef mutable struct ExtendedHydroGenerator{T<:PSY.HydroGen, U<:GenIntervals} <: PowerGenerator
    # Core hydro generator from PowerSystems
    generator::T  # Can be HydroDispatch, HydroEnergyReservoir, HydroPumpedStorage, etc.
    
    # Extended hydro cost function with regularization
    hydro_cost_function::ExtendedHydroGenerationCost{U}
    
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
    
    # Node connection
    conn_nodeg_ptr::Node
    
    # Solver interface for hydro generators
    gen_solver::GenSolver{ExtendedHydroGenerationCost{U}, U}
    
    # Power variables (MW)
    P_gen_prev::Float64      # Previous interval power output
    Pg::Float64              # Current power output
    P_gen_next::Float64      # Next interval power output
    theta_g::Float64         # Generator bus angle (radians)
    v::Float64               # Nodal price/multiplier
    
    # Hydro-specific operating variables
    reservoir_level::Float64 = 0.0              # Current reservoir level (MWh or acre-feet)
    water_flow_rate::Float64 = 0.0              # Water flow rate (acre-feet/hour)
    spillage::Float64 = 0.0                     # Water spillage (acre-feet/hour)
    pumping_power::Float64 = 0.0                # Pumping power for PSH (MW)
    generation_efficiency::Float64 = 0.9        # Generation efficiency
    pumping_efficiency::Float64 = 0.8           # Pumping efficiency (for PSH)
    
    # Hydro constraints tracking
    water_flow_violation::Float64 = 0.0         # Water flow constraint violations
    reservoir_level_violation::Float64 = 0.0    # Reservoir level violations
    ramp_rate_violation::Float64 = 0.0          # Ramp rate violations
    
    # Environmental and operational variables
    water_value::Float64 = 0.0                  # Water opportunity cost ($/acre-foot)
    environmental_flow::Float64 = 0.0           # Minimum environmental flow requirement
    fish_ladder_flow::Float64 = 0.0             # Fish ladder flow requirement
    irrigation_demand::Float64 = 0.0            # Irrigation water demand
    
    # Hydro timeseries management
    current_time::Union{DateTime, Nothing} = nothing
    time_series_resolution::Dates.Period = Dates.Hour(1)
    inflow_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    water_price_forecast::Union{TimeSeries.TimeArray, Nothing} = nothing
    irrigation_schedule::Union{TimeSeries.TimeArray, Nothing} = nothing
    environmental_constraints::Union{TimeSeries.TimeArray, Nothing} = nothing
    
    # Performance tracking
    capacity_factor::Float64 = 0.0              # Capacity factor
    availability_factor::Float64 = 1.0          # Availability factor
    water_utilization_efficiency::Float64 = 0.0 # Water utilization efficiency
    
    # Hydro-specific cache
    _hydro_cache::Dict{String, Any} = Dict()
    _cache_valid::Bool = false

    # Constructor
    function ExtendedHydroGenerator(
        generator::T,
        hydro_cost_function::ExtendedHydroGenerationCost{U},
        id_of_gen::Int64,
        interval::Int64,
        last_flag::Bool,
        cont_scenario_count::Int64,
        PC_scenario_count::Int64,
        baseCont::Int64,
        dummyZero::Int64,
        accuracy::Int64,
        nodeConng::Node,
        countOfContingency::Int64;
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.HydroGen, U<:GenIntervals}
        
        # Create solver with hydro cost model
        gensolver = GenSolver(
            interval_type = hydro_cost_function.regularization_term,
            cost_curve = hydro_cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.hydro_cost_function = hydro_cost_function
        self.gen_id = id_of_gen
        self.dispatch_interval = interval
        self.flag_last = last_flag
        self.dummy_zero_int_flag = dummyZero
        self.cont_solver_accuracy = accuracy
        self.scenario_cont_count = cont_scenario_count
        self.post_cont_scen_count = PC_scenario_count
        self.base_cont_scenario = baseCont
        self.conn_nodeg_ptr = nodeConng
        self.cont_count_gen = countOfContingency
        self.gen_solver = gensolver
        
        # Initialize connection node
        set_g_conn!(self.conn_nodeg_ptr, id_of_gen)
        
        # Initialize hydro-specific parameters
        initialize_hydro_parameters!(self)
        
        # Extract timeseries data
        extract_hydro_timeseries!(self)
        
        # Set initial generator data
        set_hydro_gen_data!(self)
        
        return self
    end
end

"""
    initialize_hydro_parameters!(gen::ExtendedHydroGenerator)

Initialize hydro-specific parameters from the PowerSystems hydro generator.
"""
function initialize_hydro_parameters!(gen::ExtendedHydroGenerator{T}) where T
    psy_gen = gen.generator
    
    # Extract basic parameters
    gen.Pg = PSY.get_active_power(psy_gen)
    gen.P_gen_prev = gen.Pg
    gen.P_gen_next = gen.Pg
    
    # Initialize hydro-specific parameters based on type
    if isa(psy_gen, PSY.HydroEnergyReservoir)
        # Reservoir-based hydro
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits  # Extract the upper limit (Float64)
        gen.reservoir_level = max_storage * 0.5  # Start at 50% of max capacity
        
        # Get inflow and outflow characteristics
        inflow = PSY.get_inflow(psy_gen)
        gen.water_flow_rate = inflow
        
    elseif isa(psy_gen, PSY.HydroPumpedStorage)
        # Pumped storage hydro
        # Reservoir-based hydro
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits.up  # Extract the upper limit (Float64)
        gen.reservoir_level = max_storage * 0.5  # Start at 50% of max capacity
        outflow = PSY.get_outflow(psy_gen)
        
        # Get pump and generation characteristics
        pump_load = PSY.get_pump_efficiency(psy_gen) #**THIS NEEDS FURTHER CHECKING**
        gen.pumping_power = pump_load
        gen.pumping_efficiency = 0.8  # Default efficiency
        
    elseif isa(psy_gen, PSY.HydroDispatch)
        # Run-of-river or dispatch hydro
        gen.water_flow_rate = 100.0  # Default flow rate
        gen.reservoir_level = 0.0    # No reservoir
    end
    
    # Initialize efficiency and water value
    gen.generation_efficiency = 0.9
    gen.water_value = 10.0  # $/acre-foot
    
    # Initialize performance metrics
    rating = PSY.get_rating(psy_gen)
    if rating > 0 && gen.Pg >= 0
        gen.capacity_factor = gen.Pg / rating
    end
end

"""
    extract_hydro_timeseries!(gen::ExtendedHydroGenerator)

Extract hydro-specific timeseries data from PowerSystems generator.
"""
function extract_hydro_timeseries!(gen::ExtendedHydroGenerator)
    psy_gen = gen.generator
    gen._cache_valid = false
    
    # Extract available timeseries - use correct PowerSystems function
    try
        if IS.has_time_series(psy_gen)
            # Get all time series keys
            ts_keys = PSY.get_time_series_keys(psy_gen)

            if !isempty(ts_keys)
                for ts_name in ts_keys
                    try
                        ts_data = PSY.get_time_series(psy_gen, ts_name)
                        key_name = string(ts_name.name)
                
                        # Map timeseries based on name
                        if occursin("Inflow", string(ts_name)) || occursin("Flow", string(ts_name))
                            gen.inflow_forecast = ts_data
                        elseif occursin("WaterPrice", string(ts_name)) || occursin("Water", string(ts_name))
                            gen.water_price_forecast = ts_data
                        elseif occursin("Irrigation", string(ts_name))
                            gen.irrigation_schedule = ts_data
                        elseif occursin("Environmental", string(ts_name)) || occursin("MinFlow", string(ts_name))
                            gen.environmental_constraints = ts_data
                        end
                    
                    catch e
                        @debug "Could not extract timeseries $ts_name for hydro generator $(PSY.get_name(psy_gen)): $e"
                    end
                end
            end
        else
            @info "No timeseries data available for hydro generator $(PSY.get_name(psy_gen))"
        end
        
    catch e
        @warn "Failed to get timeseries names for hydro generator $(PSY.get_name(psy_gen)): $e"
    end
end

"""
    set_hydro_gen_data!(gen::ExtendedHydroGenerator)

Set hydro generator data and validate hydro-specific constraints.
"""
function set_hydro_gen_data!(gen::ExtendedHydroGenerator{T}) where T
    psy_gen = gen.generator
    
    # Validate power constraints
    active_power_limits = PSY.get_active_power_limits(psy_gen)
    gen.Pg = clamp(gen.Pg, active_power_limits.min, active_power_limits.max)
    
    # Validate hydro-specific constraints based on type
    if isa(psy_gen, PSY.HydroEnergyReservoir)
        # Check reservoir level constraints
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits
        min_storage = 0.0  # Assuming minimum storage is 0 for simplicity

        if gen.reservoir_level > max_storage
            gen.reservoir_level_violation = gen.reservoir_level - max_storage
            gen.reservoir_level = max_storage
        elseif gen.reservoir_level < min_storage
            gen.reservoir_level_violation = min_storage - gen.reservoir_level
            gen.reservoir_level = min_storage
        end
        
        # Check water flow constraints
        inflow_limits = PSY.get_inflow(psy_gen)
        if gen.water_flow_rate > inflow_limits
            gen.water_flow_violation = gen.water_flow_rate - inflow_limits
            gen.water_flow_rate = inflow_limits
        end
        
    elseif isa(psy_gen, PSY.HydroPumpedStorage)
        storage_limits = PSY.get_storage_capacity(psy_gen)
        max_storage = storage_limits.up
        min_storage = storage_limits.down
        gen.reservoir_level = clamp(gen.reservoir_level, min_storage, max_storage)

        # Check water flow constraints
        outflow_limits = PSY.get_outflow(psy_gen)
        if gen.water_flow_rate > outflow_limits
            gen.water_flow_violation = gen.water_flow_rate - outflow_limits
            gen.water_flow_rate = outflow_limits
        end
        
        # Ensure only generation OR pumping, not both
        pump_load = PSY.get_pump_efficiency(psy_gen) #**THIS NEEDS FURTHER CHECKING**
        if gen.Pg > 0 && gen.pumping_power > 0
            # Prioritize generation
            gen.pumping_power = 0.0
        end
    end
    
    # Update water utilization efficiency
    update_hydro_performance!(gen)
end

"""
    update_hydro_performance!(gen::ExtendedHydroGenerator)

Update hydro performance metrics based on current operating point.
"""
function update_hydro_performance!(gen::ExtendedHydroGenerator{T}) where T
    if gen.Pg > 0
        # Calculate water utilization efficiency
        if gen.water_flow_rate > 0
            gen.water_utilization_efficiency = gen.Pg / gen.water_flow_rate
        end
        
        # Update reservoir level based on generation (simplified)
        if isa(gen.generator, PSY.HydroEnergyReservoir)
            # Decrease reservoir level based on generation
            water_used = gen.Pg / gen.generation_efficiency
            gen.reservoir_level = max(0.0, gen.reservoir_level - water_used)
            
        elseif isa(gen.generator, PSY.HydroPumpedStorage)
            # For PSH in generation mode, decrease reservoir level
            water_used = gen.Pg / gen.generation_efficiency
            
            # Get minimum storage capacity to respect lower bound
            storage_limits = PSY.get_storage_capacity(gen.generator)
            min_storage = storage_limits.down  # Extract lower limit
            
            gen.reservoir_level = max(min_storage, gen.reservoir_level - water_used)
        end
        
    elseif isa(gen.generator, PSY.HydroPumpedStorage) && gen.pumping_power > 0
        # Pumping mode - increase reservoir level
        water_pumped = gen.pumping_power * gen.pumping_efficiency
        
        # Get storage capacity limits and extract the upper bound
        storage_limits = PSY.get_storage_capacity(gen.generator)
        max_storage = storage_limits.up  # Extract upper limit (Float64)
        min_storage = storage_limits.down  # Extract lower limit (Float64)
        
        # Increase reservoir level but don't exceed maximum capacity
        gen.reservoir_level = min(max_storage, gen.reservoir_level + water_pumped)
        gen.capacity_factor = 0.0  # Not generating
        
    else
        gen.water_utilization_efficiency = 0.0
        gen.capacity_factor = 0.0
    end

    # Additional safety check: ensure reservoir level stays within bounds for all hydro types
    #=if isa(gen.generator, PSY.HydroEnergyReservoir) || isa(gen.generator, PSY.HydroPumpedStorage)
        storage_limits = PSY.get_storage_capacity(gen.generator)
        max_storage = storage_limits.up
        min_storage = storage_limits.down
        
        # Clamp reservoir level to valid range
        gen.reservoir_level = clamp(gen.reservoir_level, min_storage, max_storage)=#
        
        # Track violations if they occur
        #=if gen.reservoir_level == max_storage && (gen.reservoir_level + water_pumped > max_storage rescue false)
            gen.reservoir_level_violation = (gen.reservoir_level + water_pumped) - max_storage
        elseif gen.reservoir_level == min_storage && (gen.reservoir_level - water_used < min_storage rescue false)
            gen.reservoir_level_violation = min_storage - (gen.reservoir_level - water_used)
        else
            gen.reservoir_level_violation = 0.0
        end
    end=#
end

"""
    calculate_hydro_operating_cost(gen::ExtendedHydroGenerator, time_step::Float64 = 1.0)::Float64

Calculate total hydro operating cost including water opportunity cost.
"""
function calculate_hydro_operating_cost(gen::ExtendedHydroGenerator, time_step::Float64 = 1.0)::Float64
    total_cost = 0.0
    
    # Variable operating cost (typically low for hydro)
    if is_regularization_active(gen.hydro_cost_function)
        total_cost += build_hydro_cost_expression(
            gen.hydro_cost_function, 
            gen.Pg, 
            gen.P_gen_next, 
            gen.theta_g
        )
    else
        # Simple cost model
        op_cost = PSY.get_operation_cost(gen.generator)
        var_cost = PSY.get_variable(op_cost)
        total_cost += var_cost * gen.Pg * time_step
    end
    
    # Water opportunity cost
    if gen.Pg > 0
        water_used = gen.Pg / gen.generation_efficiency
        total_cost += gen.water_value * water_used * time_step
    end
    
    # Pumping cost for PSH
    if isa(gen.generator, PSY.HydroPumpedStorage) && gen.pumping_power > 0
        # Cost of electricity for pumping (simplified)
        pumping_cost = 50.0  # $/MWh
        total_cost += pumping_cost * gen.pumping_power * time_step
    end
    
    return total_cost
end

# ...existing code for solver functions...

export ExtendedHydroGenerator
export initialize_hydro_parameters!, extract_hydro_timeseries!, set_hydro_gen_data!
export update_hydro_performance!, calculate_hydro_operating_cost
