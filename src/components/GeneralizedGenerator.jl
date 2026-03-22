"""
Generalized Generator component for PowerLASCOPF.jl

This module defines the GeneralizedGenerator struct that can handle thermal, renewable, 
hydro, and storage generators with full timeseries and stochastic support.
"""
#=
using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries
=#
#const PSY = PowerSystems
#const IS = InfrastructureSystems
# Unified Generator Framework for PowerLASCOPF
# This module creates a unified interface that links the 5 specialized generator types
# with the common APP+ADMM-PMP messaging functionality from ExtendedThermalGenerator.jl

using PowerSystems
using InfrastructureSystems

# Import the specialized generator types
include("extended_hydro.jl")
include("extended_storage.jl") 
include("renewable_generator.jl")
include("storage_generator.jl")
# Import the common messaging framework
include("ExtendedThermalGenerator.jl")
include("GeneralizedGenerator.jl")

# Include necessary modules from the codebase
include("GeneratorScenario.jl")
include("node.jl")
include("transmission_line.jl")
include("../core/solver_model_types.jl")
include("../core/ExtendedThermalGenerationCost.jl")
include("../core/ExtendedRenewableGenerationCost.jl")
include("../core/ExtendedHydroGenerationCost.jl")
include("../core/cost_utilities.jl")
include("../solvers/generator_solvers/gensolver_first_base.jl")

# Define abstract type for unified generator interface
abstract type UnifiedGenerator end

"""
    GeneralizedGenerator{T<:PSY.Generator, U<:GenIntervals}

A generalized generator component that extends PowerSystems generators for LASCOPF optimization.
Supports thermal, renewable, hydro, and storage generators with ADMM/APP state variables,
timeseries handling, and stochastic scenarios.
"""
mutable struct GeneralizedGenerator{T<:PSY.StaticInjection,U<:GenIntervals} <: PowerGenerator
    # Core generator properties
    generator::T # PowerSystems StaticInjection (ThermalGen, RenewableGen, HydroGen, Storage, etc.)
    cost_function::Union{ExtendedThermalGenerationCost{U}, ExtendedRenewableGenerationCost{U}, 
                        ExtendedHydroGenerationCost{U}, ExtendedStorageCost{U}}
    
    # Generator identification
    gen_id::Int64
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
    
    # Solver interface - now uses the proper GenSolver type
    gen_solver::GenSolver{<:Union{ExtendedThermalGenerationCost, ExtendedRenewableGenerationCost, ExtendedHydroGenerationCost, ExtendedStorageCost}, U}
    
    # Power variables
    P_gen_prev::Float64
    Pg::Float64
    P_gen_next::Float64
    theta_g::Float64
    v::Float64
    
    # Timeseries management
    current_time::Union{DateTime, Nothing}
    time_series_resolution::Dates.Period
    scenarios::Vector{GeneratorScenario}
    current_scenario::Int
    stochastic_mode::Bool
    
    # Timeseries cache for performance
    _power_cache::Dict{DateTime, Float64}
    _availability_cache::Dict{DateTime, Bool}
    _cache_valid::Bool

    # Constructor for GeneralizedGenerator
    function GeneralizedGenerator(
        generator::T, 
        interval_type::U,
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
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.StaticInjection, U<:GenIntervals}

        # Create appropriate extended cost model based on generator type
        cost_function = create_extended_cost_for_generator(generator, interval_type)
        
        # Create solver with the cost model
        gensolver = GenSolver(
            interval_type = interval_type,
            cost_curve = cost_function,
            config = config
        )
        
        self = new{T,U}()
        self.generator = generator
        self.cost_function = cost_function
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
        
        # Initialize timeseries fields
        self.current_time = nothing
        self.time_series_resolution = Dates.Hour(1)
        self.scenarios = GeneratorScenario[]
        self.current_scenario = 1
        self.stochastic_mode = false
        
        # Initialize cache
        self._power_cache = Dict{DateTime, Float64}()
        self._availability_cache = Dict{DateTime, Bool}()
        self._cache_valid = false
        
        # Initialize connection node
        set_g_conn!(self.conn_nodeg_ptr, id_of_gen)
        
        # Initialize previous power
        self.P_gen_prev = 0.0
        
        # Extract timeseries from PSY generator if available
        extract_timeseries_from_psy!(self)

        # Set generator data
        #set_gen_data!(self)
        
        return self
    end
end

"""
    create_extended_cost_for_generator(generator::PSY.Generator, interval_type::GenIntervals)

Factory function to create the appropriate extended cost model based on generator type.
"""
function create_extended_cost_for_generator(generator::T, interval_type::U) where {T<:PSY.StaticInjection, U<:GenIntervals}
    if isa(generator, PSY.ThermalGen)
        psy_cost = PSY.get_operation_cost(generator)
        return ExtendedThermalGenerationCost{U}(
            thermal_cost_core = psy_cost,
            regularization_term = interval_type
        )
    elseif isa(generator, PSY.RenewableGen)
        psy_cost = PSY.get_operation_cost(generator)
        return ExtendedRenewableGenerationCost{U}(
            renewable_cost_core = psy_cost,
            regularization_term = interval_type
        )
    elseif isa(generator, Union{PSY.HydroGen, PSY.HydroDispatch, PSY.HydroEnergyReservoir})
        psy_cost = PSY.get_operation_cost(generator)
        return ExtendedHydroGenerationCost{U}(
            hydro_cost_core = psy_cost,
            regularization_term = interval_type
        )
    elseif isa(generator, PSY.Storage)
        psy_cost = PSY.get_operation_cost(generator)
        return ExtendedStorageCost{U}(
            storage_cost_core = psy_cost,
            regularization_term = interval_type
        )
    else
        error("Unsupported generator type: $(typeof(generator))")
    end
end

"""
    extract_timeseries_from_psy!(gen::GeneralizedGenerator)

Extract timeseries data from PowerSystems generator and populate scenarios.
Handles renewable, thermal, hydro, and storage generators.
"""
function extract_timeseries_from_psy!(gen::GeneralizedGenerator)
    psy_gen = gen.generator
    
    # Clear existing scenarios
    empty!(gen.scenarios)
    gen._cache_valid = false
    
    try
        # Extract available timeseries from PSY generator
        
        if IS.has_time_series(psy_gen)
            ts_keys = IS.get_time_series_keys(psy_gen)
            println("Found $(length(ts_keys)) timeseries for generator $(PSY.get_name(psy_gen))")

            # Extract timeseries data
            for (idx, ts_name) in enumerate(ts_keys)
                try
                    println("  Processing timeseries: $(ts_name.name)")
                    ts_data = PSY.get_time_series(psy_gen, ts_name)
                    
                    scenario = GeneratorScenario(
                        scenario_id = idx,
                        probability = 1.0 / length(ts_data)  # Equal probability for now
                    )
                    
                    # Map timeseries based on type and name
                    ts_name_str = string(ts_name.name)
                    if occursin("max_active_power", ts_name_str) || occursin("ActivePower", ts_name_str) || occursin("P", ts_name_str)
                        scenario.active_power_series = ts_data
                        # Extract the first value properly from TimeArray
                        if isa(ts_data, IS.TimeSeriesData)
                            data_values = IS.get_data(ts_data)
                            if isa(data_values, TimeSeries.TimeArray)
                                scenario.current_active_power = Float64(TimeSeries.values(data_values)[1])
                            else
                                scenario.current_active_power = Float64(first(data_values))
                            end
                        else
                            scenario.current_active_power = Float64(first(ts_data))
                        end
                    elseif occursin("ReactivePower", ts_name_str) || occursin("Q", ts_name_str)
                        scenario.reactive_power_series = ts_data
                    elseif occursin("Availability", ts_name_str) || occursin("Available", ts_name_str)
                        scenario.availability_series = ts_data
                        if isa(ts_data, IS.TimeSeriesData)
                            data_values = IS.get_data(ts_data)
                            if isa(data_values, TimeSeries.TimeArray)
                                scenario.current_availability = Float64(TimeSeries.values(data_values)[1]) > 0.5
                            else
                                scenario.current_availability = Float64(first(data_values)) > 0.5
                            end
                        else
                            scenario.current_availability = Float64(first(ts_data)) > 0.5
                        end
                        
                    elseif occursin("Renewable", ts_name_str) || occursin("Wind", ts_name_str) || occursin("Solar", ts_name_str)
                        scenario.renewable_power_series = ts_data
                        if isa(ts_data, IS.TimeSeriesData)
                            data_values = IS.get_data(ts_data)
                            if isa(data_values, TimeSeries.TimeArray)
                                scenario.current_renewable_power = Float64(TimeSeries.values(data_values)[1])
                            else
                                scenario.current_renewable_power = Float64(first(data_values))
                            end
                        else
                            scenario.current_renewable_power = Float64(first(ts_data))
                        end
                    else
                        # Default to active power for unknown series
                        scenario.active_power_series = ts_data
                        if isa(ts_data, IS.TimeSeriesData)
                            data_values = IS.get_data(ts_data)
                            if isa(data_values, TimeSeries.TimeArray)
                                scenario.current_active_power = Float64(TimeSeries.values(data_values)[1])
                            else
                                scenario.current_active_power = Float64(first(data_values))
                            end
                        else
                            scenario.current_active_power = Float64(first(ts_data))
                        end
                    end
                    
                    # Set default values if not set from timeseries
                    if scenario.current_active_power == 0.0
                        scenario.current_active_power = PSY.get_active_power(psy_gen)
                    end
                    
                    if scenario.current_renewable_power == 0.0 && isa(psy_gen, PSY.RenewableGen)
                        scenario.current_renewable_power = PSY.get_rating(psy_gen)
                    end
                    
                    if scenario.current_availability == false
                        scenario.current_availability = PSY.get_available(psy_gen)
                    end
                    
                    push!(gen.scenarios, scenario)
                    println("    ✅ Added scenario $(idx) with active_power=$(scenario.current_active_power)")
                    
                catch e
                    @warn "Failed to extract timeseries $ts_name for generator $(PSY.get_name(psy_gen)): $e"
                end
            end
             if !isempty(gen.scenarios)
                @info "Successfully extracted $(length(gen.scenarios)) scenarios for generator $(PSY.get_name(psy_gen))"
                return
            end
        else
            println("No timeseries available for generator $(PSY.get_name(psy_gen)), creating single deterministic scenario")
        end
        
        # If no timeseries or extraction failed, create default scenario
        scenario = GeneratorScenario(
            scenario_id = 1,
            probability = 1.0,
            current_active_power = PSY.get_active_power(psy_gen),
            current_availability = PSY.get_available(psy_gen)
        )
        
        # For renewable generators, set renewable power
        if isa(psy_gen, PSY.RenewableGen)
            scenario.current_renewable_power = PSY.get_rating(psy_gen)
        end
        
        push!(gen.scenarios, scenario)
        @info "Created default scenario for generator $(PSY.get_name(psy_gen))"
        
    catch e
        @warn "Error extracting timeseries for generator $(PSY.get_name(psy_gen)): $e"
        
        # Create fallback scenario
        fallback_scenario = GeneratorScenario(
            scenario_id = 1,
            probability = 1.0,
            current_active_power = PSY.get_active_power(psy_gen),
            current_availability = PSY.get_available(psy_gen)
        )
        
        if isa(psy_gen, PSY.RenewableGen)
            fallback_scenario.current_renewable_power = PSY.get_rating(psy_gen)
        end
        
        push!(gen.scenarios, fallback_scenario)
    end
end

"""
    update_timeseries!(gen::GeneralizedGenerator, current_time::DateTime)

Update generator values based on timeseries data at the given time.
"""
function update_timeseries!(gen::GeneralizedGenerator, current_time::DateTime)
    gen.current_time = current_time
    
    # Update current scenario values
    if gen.current_scenario <= length(gen.scenarios)
        scenario = gen.scenarios[gen.current_scenario]
        
        # Update from timeseries if available
        if !isnothing(scenario.active_power_series)
            try
                # FIX: Handle TimeArray properly
                if isa(scenario.active_power_series, IS.TimeSeriesData)
                    data_values = IS.get_data(scenario.active_power_series)
                    if isa(data_values, TimeSeries.TimeArray)
                        # Find the value at the current time
                        time_index = findfirst(t -> t == current_time, TimeSeries.timestamp(data_values))
                        if !isnothing(time_index)
                            scenario.current_active_power = Float64(TimeSeries.values(data_values)[time_index])
                        end
                    end
                else
                    # Alternative approach if not IS.TimeSeriesData
                    scenario.current_active_power = Float64(PSY.get_value_at_time(scenario.active_power_series, current_time))
                end
            catch e
                @debug "Could not get active power at time $current_time: $e"
            end
        end
        
        if !isnothing(scenario.renewable_power_series)
            try
                if isa(scenario.renewable_power_series, IS.TimeSeriesData)
                    data_values = IS.get_data(scenario.renewable_power_series)
                    if isa(data_values, TimeSeries.TimeArray)
                        time_index = findfirst(t -> t == current_time, TimeSeries.timestamp(data_values))
                        if !isnothing(time_index)
                            scenario.current_renewable_power = Float64(TimeSeries.values(data_values)[time_index])
                        end
                    end
                else
                    scenario.current_renewable_power = Float64(PSY.get_value_at_time(scenario.renewable_power_series, current_time))
                end
            catch e
                @debug "Could not get renewable power at time $current_time: $e"
            end
        end
        
        if !isnothing(scenario.availability_series)
            try
                if isa(scenario.availability_series, IS.TimeSeriesData)
                    data_values = IS.get_data(scenario.availability_series)
                    if isa(data_values, TimeSeries.TimeArray)
                        time_index = findfirst(t -> t == current_time, TimeSeries.timestamp(data_values))
                        if !isnothing(time_index)
                            scenario.current_availability = Float64(TimeSeries.values(data_values)[time_index]) > 0.5
                        end
                    end
                else
                    scenario.current_availability = Float64(PSY.get_value_at_time(scenario.availability_series, current_time)) > 0.5
                end
            catch e
                @debug "Could not get availability at time $current_time: $e"
            end
        end
        
        # Cache values for performance
        gen._power_cache[current_time] = scenario.current_active_power
        gen._availability_cache[current_time] = scenario.current_availability
    end
    
    gen._cache_valid = true
end

"""
    get_current_power(gen::GeneralizedGenerator, time::DateTime = gen.current_time)

Get the current active power for the generator, with timeseries support.
"""
function get_current_power(gen::GeneralizedGenerator, time::Union{DateTime, Nothing} = nothing)
    if isnothing(time)
        time = gen.current_time
    end
    
    if isnothing(time)
        return gen.scenarios[gen.current_scenario].current_active_power
    end
    
    # Check cache first
    if haskey(gen._power_cache, time) && gen._cache_valid
        return gen._power_cache[time]
    end
    
    # Update timeseries and return value
    update_timeseries!(gen, time)
    return gen.scenarios[gen.current_scenario].current_active_power
end

"""
    get_renewable_power(gen::GeneralizedGenerator, time::Union{DateTime, Nothing} = nothing)

Get the renewable power forecast for renewable generators.
"""
function get_renewable_power(gen::GeneralizedGenerator, time::Union{DateTime, Nothing} = nothing)
    if !isa(gen.generator, PSY.RenewableGen)
        return 0.0
    end
    
    if isnothing(time)
        time = gen.current_time
    end
    
    if isnothing(time)
        return gen.scenarios[gen.current_scenario].current_renewable_power
    end
    
    # Update timeseries if needed
    if !gen._cache_valid || gen.current_time != time
        update_timeseries!(gen, time)
    end
    
    return gen.scenarios[gen.current_scenario].current_renewable_power
end

# Utility functions
function gen_power(gen::GeneralizedGenerator)
    return gen.Pg
end

function gen_power_prev(gen::GeneralizedGenerator)
    if gen.dispatch_interval == 0
        return get_pg_prev(gen.gen_solver)
    else
        return gen.P_gen_prev
    end
end

function gen_power_next(gen::GeneralizedGenerator, next_scen::Int=1)
    if gen.flag_last == true
        return gen.Pg
    elseif gen.dispatch_interval != 0 && gen.flag_last == false
        # Return next power for specific scenario
        return gen.P_gen_next  # Simplified - would need proper scenario indexing
    else
        return gen.P_gen_next
    end
end

"""
Solve the generator subproblem using the integrated solver
"""
function solve_generator_subproblem!(gen::GeneralizedGenerator, sys::PSY.System; 
                                   optimizer_factory=nothing, 
                                   solve_options=Dict(),
                                   time_horizon=24)
    
    # Update solver parameters from generator state
    update_solver_from_generator!(gen)
    
    # Solve using the integrated solver
    results = build_and_solve_gensolver!(
        gen.gen_solver, 
        sys;
        optimizer_factory=optimizer_factory,
        solve_options=solve_options,
        time_horizon=time_horizon
    )
    
    # Extract results back to generator
    extract_results_to_generator!(gen, results)
    
    return results
end

"""
Update solver parameters from current generator state
"""
function update_solver_from_generator!(gen::GeneralizedGenerator)
    # Get the interval type
    interval_type = gen.gen_solver.interval_type
    
    # Update interval parameters based on generator's current state
    if isa(interval_type, GenFirstBaseInterval)
        interval_type.Pg_prev = gen.P_gen_prev
        interval_type.Pg_nu = gen.Pg
        interval_type.Pg_nu_inner = gen.Pg
        # Additional parameter updates would go here based on ADMM coordination
    end
    
    # Update cost function regularization if needed
    if is_regularization_active(gen.cost_function)
        # Parameters would be updated here based on coordination with other subproblems
    end
end

"""
Extract solver results back to generator variables
"""
function extract_results_to_generator!(gen::GeneralizedGenerator, results::Dict)
    device_name = PSY.get_name(gen.generator)
    
    # Extract power values (assuming single time step for now)
    if haskey(results, "Pg") && !isempty(results["Pg"])
        # Get the first time step result
        for ((name, t), value) in results["Pg"]
            if name == device_name
                gen.Pg = value
                break
            end
        end
    end
    
    if haskey(results, "PgNext") && !isempty(results["PgNext"])
        for ((name, t), value) in results["PgNext"]
            if name == device_name
                gen.P_gen_next = value
                break
            end
        end
    end
    
    if haskey(results, "thetag") && !isempty(results["thetag"])
        for ((name, t), value) in results["thetag"]
            if name == device_name
                gen.theta_g = value
                break
            end
        end
    end
end

"""
Update ADMM/APP parameters for the generator
"""
function update_generator_admm_parameters!(gen::GeneralizedGenerator, new_params::Dict)
    # Update solver parameters
    update_admm_parameters!(gen.gen_solver, new_params)
    
    # Update cost function regularization parameters
    update_regularization_parameters!(gen.cost_function, new_params)
end

"""
Switch generator to different interval type (e.g., base case to contingency)
"""
function switch_generator_interval_type!(gen::GeneralizedGenerator, new_interval_type::Type{T}, params::Dict) where {T<:GenIntervals}
    # Create new interval
    new_interval = create_regularization_interval(new_interval_type, params)
    
    # Update solver interval type
    gen.gen_solver.interval_type = new_interval
    
    # Switch cost function regularization type
    switch_regularization_type!(gen.cost_function, new_interval_type, params)
end

# Updated solver calling functions to use the new infrastructure

function handle_dummy_zero_base_case!(
    gen::GeneralizedGenerator,
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    # Update solver parameters with current ADMM/APP values
    admm_params = Dict(
        "rho" => gsRho,
        "Pg_N_avg" => Pgenavg,
        "ug_N" => Powerprice,
        "thetag_N_avg" => Angavg,
        "vg_N" => Angprice,
        "Vg_N_avg" => Angpriceavg,
        "Pg_nu" => PgenAPP,
        "Pg_nu_inner" => PgenAPPInner,
        "Pg_prev" => gen.P_gen_prev,
        "B" => BAPPNew,
        "D" => DAPPExtNew,
        "BSC" => get(BAPPExtNew, 1, 0.0),  # Simplified
        "lambda_1" => LambdaAPPNew,
        "lambda_2" => LambdaAPP2ExtNew,
        "lambda_1_sc" => LambdaAPP1ExtNew
    )
    
    update_generator_admm_parameters!(gen, admm_params)
    
    if gen.dispatch_interval == 0 && gen.flag_last == false # Dummy zeroth interval
        # Create a minimal system with just this generator for solving
        mini_sys = create_single_generator_system(gen.generator)
        
        try
            results = solve_generator_subproblem!(gen, mini_sys)
            
            # Results are already extracted to generator variables by solve_generator_subproblem!
            @info "Generator $(gen.gen_id) solved successfully: Pg=$(gen.Pg), θg=$(gen.theta_g)"
            
        catch e
            @warn "Generator solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
            # Set fallback values
            gen.Pg = max(0.0, min(100.0, PgenAPP))  # Bounded fallback
            gen.theta_g = 0.0
            gen.P_gen_next = gen.Pg
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == false # First interval
        # Similar logic for first interval with DZ base solver
        admm_params["A"] = AAPPExternal
        admm_params["lambda_3"] = LambAPP3External
        admm_params["lambda_4"] = LambAPP4External
        
        update_generator_admm_parameters!(gen, admm_params)
        
        mini_sys = create_single_generator_system(gen.generator)
        
        try
            results = solve_generator_subproblem!(gen, mini_sys)
            @info "Generator $(gen.gen_id) DZ base solved: Pg=$(gen.Pg), θg=$(gen.theta_g)"
        catch e
            @warn "DZ Base solver failed for gen $(gen.gen_id): $e"
            gen.Pg = max(0.0, min(100.0, PgenAPP))
            gen.theta_g = 0.0
            gen.P_gen_next = gen.Pg
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == true # Last interval
        # Similar logic for last interval
        mini_sys = create_single_generator_system(gen.generator)
        
        try
            results = solve_generator_subproblem!(gen, mini_sys)
            @info "Generator $(gen.gen_id) second base solved: Pg=$(gen.Pg), θg=$(gen.theta_g)"
        catch e
            @warn "Second Base solver failed for gen $(gen.gen_id): $e"
            gen.Pg = max(0.0, min(100.0, PgenAPP))
            gen.theta_g = 0.0
        end
    end
end

# Update other handling functions similarly...
function handle_no_dummy_zero_base_case!(
    gen::GeneralizedGenerator,
    # ... same parameters ...
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    # Similar implementation using the new solver infrastructure
    admm_params = Dict(
        "rho" => gsRho,
        "Pg_N_avg" => Pgenavg,
        "ug_N" => Powerprice,
        "thetag_N_avg" => Angavg,
        "vg_N" => Angprice,
        "Vg_N_avg" => Angpriceavg,
        "Pg_nu" => PgenAPP,
        "Pg_nu_inner" => PgenAPPInner,
        "B" => BAPPNew,
        "D" => DAPPExtNew,
        "lambda_1" => LambdaAPPNew,
        "lambda_2" => LambdaAPP2ExtNew
    )
    
    update_generator_admm_parameters!(gen, admm_params)
    
    mini_sys = create_single_generator_system(gen.generator)
    
    try
        results = solve_generator_subproblem!(gen, mini_sys)
        @info "Generator $(gen.gen_id) no-DZ solved: Pg=$(gen.Pg), θg=$(gen.theta_g)"
    catch e
        @warn "No-DZ solver failed for gen $(gen.gen_id): $e"
        gen.Pg = max(0.0, min(100.0, PgenAPP))
        gen.theta_g = 0.0
    end
end

function handle_contingency_scenarios!(
    gen::GeneralizedGenerator,
    # ... same parameters as base case ...
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    # Switch to contingency interval type
    contingency_params = Dict(
        "rho" => gsRho,
        "lambda_1_sc" => get(LambdaAPP1ExtNew, 1, 0.0),
        "BSC" => get(BAPPExtNew, 1, 0.0)
    )
    
    switch_generator_interval_type!(gen, GenFirstContInterval, contingency_params)
    
    # Update with contingency-specific parameters
    admm_params = Dict(
        "rho" => gsRho,
        "Pg_N_avg" => Pgenavg,
        "ug_N" => Powerprice,
        "B" => BAPPNew,
        "D" => DAPPExtNew,
        "lambda_1" => LambdaAPPNew,
        "lambda_2" => LambdaAPP2ExtNew
    )
    
    update_generator_admm_parameters!(gen, admm_params)
    
    mini_sys = create_single_generator_system(gen.generator)
    
    try
        results = solve_generator_subproblem!(gen, mini_sys)
        @info "Generator $(gen.gen_id) contingency solved: Pg=$(gen.Pg), θg=$(gen.theta_g)"
    catch e
        @warn "Contingency solver failed for gen $(gen.gen_id): $e"
        gen.Pg = max(0.0, min(100.0, PgenAPP))
        gen.theta_g = 0.0
    end
end

"""
Create a minimal system containing only the specified generator for isolated solving
"""
function create_single_generator_system(generator::PSY.Generator)
    # Create a minimal system with just this generator and a reference bus
    sys = PSY.System(100.0)  # 100 MW base power
    
    # Add a reference bus
    bus = PSY.ACBus(1, "ref_bus", "REF", 0, 1.0, (min=0.9, max=1.1), 230, nothing, nothing)
    PSY.add_component!(sys, bus)
    
    # Create a copy of the generator connected to the reference bus
    gen_copy = deepcopy(generator)
    PSY.set_bus!(gen_copy, bus)
    PSY.add_component!(sys, gen_copy)
    
    return sys
end

# Updated utility functions that now use the extended cost models

function objective_gen(gen::GeneralizedGenerator)
    if is_regularization_active(gen.cost_function)
        # Use the sophisticated cost computation with regularization
        if isa(gen.cost_function, ExtendedThermalGenerationCost)
            return build_thermal_cost_expression(gen.cost_function, gen.Pg, 1.0, gen.P_gen_next, gen.theta_g)
        elseif isa(gen.cost_function, ExtendedRenewableGenerationCost)
            return build_renewable_cost_expression(gen.cost_function, gen.Pg, 0.0, 1.0, gen.P_gen_next, gen.theta_g)
        elseif isa(gen.cost_function, ExtendedHydroGenerationCost)
            return build_hydro_cost_expression(gen.cost_function, gen.Pg, gen.P_gen_next, gen.theta_g)
        end
    else
        # Fallback to simple cost computation
        core_cost = get_cost_core(gen.cost_function)
        if isa(core_cost, PSY.ThermalGenerationCost)
            var_cost = PSY.get_variable(core_cost)
            return isa(var_cost, PSY.QuadraticCurve) ? 
                   var_cost.quadratic_term * gen.Pg^2 + var_cost.linear_term * gen.Pg + var_cost.constant_term :
                   var_cost * gen.Pg
        else
            return PSY.get_variable(core_cost) * gen.Pg
        end
    end
    
    return 0.0
end

function get_gen_node_id(gen::GeneralizedGenerator)
    return PSY.get_number(gen.conn_nodeg_ptr)
end

# ===== UNIFIED GENERATOR WRAPPER =====

"""
UnifiedGeneratorWrapper

A wrapper that provides a common interface for all 5 generator types to use
the APP+ADMM-PMP messaging functionality from ExtendedThermalGenerator.jl
"""
mutable struct UnifiedGeneratorWrapper{T} <: UnifiedGenerator
    # Core generator (one of the 5 specialized types)
    generator::T
    
    # Common APP+ADMM messaging interface
    messaging_framework::ExtendedThermalGenerator
    
    # Generator type identification
    generator_type::Symbol  # :thermal, :hydro, :storage, :renewable, :storage_gen
    
    # Unified interface properties
    gen_id::Int
    node_connection::Int
    scenario_count::Int
    
    # APP-ADMM specific properties
    lambda_dual::Vector{Float64}     # Dual variables for power balance
    rho_penalty::Float64             # ADMM penalty parameter
    power_consensus::Vector{Float64} # Consensus variables
    angle_consensus::Vector{Float64} # Voltage angle consensus
    
    # Message passing state
    incoming_messages::Dict{String, Vector{Float64}}
    outgoing_messages::Dict{String, Vector{Float64}}
    neighbor_list::Vector{Int}
    
    # Performance tracking
    iteration_count::Int
    convergence_history::Vector{Float64}
    objective_value::Float64
    
    function UnifiedGeneratorWrapper{T}(
        generator::T,
        messaging_framework::ExtendedThermalGenerator,
        generator_type::Symbol,
        gen_id::Int,
        node_connection::Int,
        scenario_count::Int
    ) where T
        return new{T}(
            generator,
            messaging_framework,
            generator_type,
            gen_id,
            node_connection,
            scenario_count,
            zeros(scenario_count),  # lambda_dual
            1.0,                    # rho_penalty
            zeros(scenario_count),  # power_consensus
            zeros(scenario_count),  # angle_consensus
            Dict{String, Vector{Float64}}(),  # incoming_messages
            Dict{String, Vector{Float64}}(),  # outgoing_messages
            Int[],                  # neighbor_list
            0,                      # iteration_count
            Float64[],              # convergence_history
            0.0                     # objective_value
        )
    end
end

# ===== CONSTRUCTOR FUNCTIONS =====

"""
Create unified generator wrapper for Thermal Generator
"""
function create_unified_thermal_generator(
    thermal_gen::ExtendedThermalGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # The thermal generator already has the messaging framework
    wrapper = UnifiedGeneratorWrapper{ExtendedThermalGenerator}(
        thermal_gen,
        thermal_gen,  # Self-reference for messaging
        :thermal,
        gen_id,
        node_connection,
        scenario_count
    )
    
    # Initialize messaging
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Hydro Generator
"""
function create_unified_hydro_generator(
    hydro_gen::ExtendedHydroGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_hydro(hydro_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedHydroGenerator}(
        hydro_gen,
        mock_thermal,
        :hydro,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Storage Generator
"""
function create_unified_storage_generator(
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_storage(storage_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedStorageGenerator}(
        storage_gen,
        mock_thermal,
        :storage,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Renewable Generator
"""
function create_unified_renewable_generator(
    renewable_gen::ExtendedRenewableGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_renewable(renewable_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedRenewableGenerator}(
        renewable_gen,
        mock_thermal,
        :renewable,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

"""
Create unified generator wrapper for Storage Generator (Battery)
"""
function create_unified_storage_gen_generator(
    storage_gen_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    # Create mock ExtendedThermalGenerator for messaging interface
    mock_thermal = create_messaging_interface_for_storage_gen(storage_gen_gen, gen_id, scenario_count)
    
    wrapper = UnifiedGeneratorWrapper{ExtendedStorageGenerator}(
        storage_gen_gen,
        mock_thermal,
        :storage_gen,
        gen_id,
        node_connection,
        scenario_count
    )
    
    initialize_messaging!(wrapper)
    return wrapper
end

# ===== MESSAGING INTERFACE CREATION =====

"""
Create messaging interface for hydro generator
"""
function create_messaging_interface_for_hydro(
    hydro::ExtendedHydroGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert hydro to thermal-like interface
    # Create a mock thermal generator with equivalent parameters
    
    # Extract relevant parameters from hydro generator
    name = hydro.name
    bus = hydro.bus
    rating = hydro.rating
    min_power = hydro.active_power_limits.min
    max_power = hydro.active_power_limits.max
    
    # Create mock thermal generator cost function
    # For hydro, use water value as fuel cost
    fuel_cost = hydro.water_value / 1000.0  # Convert from $/acre-foot to $/MMBtu equivalent
    
    # Create thermal generation cost with hydro characteristics
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(fuel_cost),
        fixed = 0.0,
        start_up = hydro.start_stop_cost,
        shut_down = hydro.start_stop_cost * 0.5
    )
    
    # Create mock thermal generator for messaging
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = hydro.available,
        status = true,
        bus = bus,
        active_power = hydro.active_power,
        reactive_power = hydro.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.HY,  # Hydro prime mover
        fuel = ThermalFuels.HYDRO,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = hydro.reactive_power_limits,
        ramp_limits = (up = hydro.ramping_rate, down = hydro.ramping_rate),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    # Create mock node connection
    mock_node = Node(bus, 1, scenario_count)
    
    # Create mock solver (simplified)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    # Create ExtendedThermalGenerator for messaging
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0,    # interval
        false, # last_flag
        scenario_count,
        mock_solver,
        0,    # pc_scenario_count
        0,    # base_cont
        0,    # dummy_zero
        1,    # accuracy
        mock_node,
        scenario_count,
        1     # gen_total
    )
    
    return extended_thermal
end

"""
Create messaging interface for storage generator
"""
function create_messaging_interface_for_storage(
    storage::ExtendedStorageGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert storage to thermal-like interface
    
    name = PowerSystems.get_name(storage)
    bus = PowerSystems.get_bus(storage)
    rating = storage.rating
    min_power = storage.active_power_limits.min
    max_power = storage.active_power_limits.max
    
    # For storage, use cycle degradation cost as equivalent fuel cost
    cycle_cost = storage.degradation_factor * storage.energy_capacity * 0.1  # $/MWh
    
    # Create thermal generation cost with storage characteristics
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(cycle_cost),
        fixed = 0.0,
        start_up = 0.0,  # Storage has no startup cost
        shut_down = 0.0
    )
    
    # Create mock thermal generator
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(storage),
        status = true,
        bus = bus,
        active_power = storage.active_power,
        reactive_power = storage.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.BA,  # Battery storage
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = storage.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),  # Fast ramping for storage
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    # Create components for ExtendedThermalGenerator
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create messaging interface for renewable generator
"""
function create_messaging_interface_for_renewable(
    renewable::ExtendedRenewableGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Convert renewable to thermal-like interface
    
    name = PowerSystems.get_name(renewable)
    bus = PowerSystems.get_bus(renewable)
    rating = renewable.rating
    min_power = renewable.active_power_limits.min
    max_power = renewable.max_active_power  # Use renewable max capacity
    
    # For renewables, use marginal cost + curtailment cost
    fuel_cost = renewable.marginal_cost + renewable.curtailment_cost
    
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(fuel_cost),
        fixed = 0.0,
        start_up = 0.0,  # Renewables have no startup cost
        shut_down = 0.0
    )
    
    # Determine prime mover based on renewable type
    prime_mover = renewable.prime_mover_type
    
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(renewable),
        status = true,
        bus = bus,
        active_power = renewable.active_power,
        reactive_power = renewable.reactive_power,
        rating = rating,
        prime_mover = prime_mover,
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = renewable.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),  # Fast changes for renewables
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create messaging interface for storage generator (battery type)
"""
function create_messaging_interface_for_storage_gen(
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    scenario_count::Int
)
    # Similar to storage but for the battery generator type
    
    name = PowerSystems.get_name(storage_gen)
    bus = PowerSystems.get_bus(storage_gen)
    rating = storage_gen.rating
    min_power = storage_gen.active_power_limits.min
    max_power = storage_gen.active_power_limits.max
    
    # Use degradation cost for battery
    battery_cost = storage_gen.degradation_factor * 100.0  # $/MWh equivalent
    
    thermal_cost = ExtendedThermalGenerationCost(
        variable = LinearCurve(battery_cost),
        fixed = 0.0,
        start_up = 0.0,
        shut_down = 0.0
    )
    
    mock_thermal_gen = ThermalStandard(
        name = "$(name)_messaging",
        available = PowerSystems.get_available(storage_gen),
        status = true,
        bus = bus,
        active_power = storage_gen.active_power,
        reactive_power = storage_gen.reactive_power,
        rating = rating,
        prime_mover = PrimeMovers.BA,
        fuel = ThermalFuels.OTHER,
        active_power_limits = (min = min_power, max = max_power),
        reactive_power_limits = storage_gen.reactive_power_limits,
        ramp_limits = (up = rating, down = rating),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = thermal_cost
    )
    
    mock_node = Node(bus, 1, scenario_count)
    mock_solver = create_mock_gen_solver(gen_id, scenario_count)
    
    extended_thermal = ExtendedThermalGenerator(
        mock_thermal_gen,
        thermal_cost,
        gen_id,
        0, false, scenario_count, mock_solver,
        0, 0, 0, 1, mock_node, scenario_count, 1
    )
    
    return extended_thermal
end

"""
Create mock generator solver for messaging interface
"""
function create_mock_gen_solver(gen_id::Int, scenario_count::Int)
    # Create a simplified mock solver that satisfies the interface
    # In practice, each generator type would use its specialized solver
    
    return GenSolver(
        gen_id = gen_id,
        scenario_count = scenario_count,
        # Add other required fields with default values
        p_solution = 0.0,
        p_next_solution = 0.0,
        p_prev_solution = 0.0,
        theta_solution = 0.0,
        objective_value = 0.0
    )
end

# ===== UNIFIED INTERFACE FUNCTIONS =====

"""
Initialize messaging for unified generator
"""
function initialize_messaging!(wrapper::UnifiedGeneratorWrapper)
    # Initialize message containers
    wrapper.incoming_messages["power"] = zeros(wrapper.scenario_count)
    wrapper.incoming_messages["voltage_angle"] = zeros(wrapper.scenario_count)
    wrapper.incoming_messages["lambda"] = zeros(wrapper.scenario_count)
    
    wrapper.outgoing_messages["power"] = zeros(wrapper.scenario_count)
    wrapper.outgoing_messages["voltage_angle"] = zeros(wrapper.scenario_count)
    wrapper.outgoing_messages["cost"] = zeros(wrapper.scenario_count)
    
    # Initialize dual variables
    wrapper.lambda_dual = zeros(wrapper.scenario_count)
    wrapper.power_consensus = zeros(wrapper.scenario_count)
    wrapper.angle_consensus = zeros(wrapper.scenario_count)
    
    return nothing
end

"""
Unified power angle message passing function
Uses the common messaging framework from ExtendedThermalGenerator
"""
function unified_power_angle_message!(
    wrapper::UnifiedGeneratorWrapper,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    Pgenavg::Float64,
    Powerprice::Float64,
    Angpriceavg::Float64,
    Angavg::Float64,
    Angprice::Float64,
    scenario_args...  # Additional scenario-specific arguments
)
    # Delegate to the common messaging framework
    result = gpower_angle_message!(
        wrapper.messaging_framework,
        outerAPPIt,
        APPItCount,
        gsRho,
        Pgenavg,
        Powerprice,
        Angpriceavg,
        Angavg,
        Angprice,
        scenario_args...
    )
    
    # Update wrapper state
    wrapper.iteration_count = outerAPPIt
    wrapper.rho_penalty = gsRho
    
    # Extract results and update generator-specific properties
    update_generator_from_messaging_result!(wrapper, result)
    
    return result
end

"""
Update generator-specific properties based on messaging result
"""
function update_generator_from_messaging_result!(
    wrapper::UnifiedGeneratorWrapper{T},
    result
) where T
    # Extract common results
    power_output = wrapper.messaging_framework.Pg
    voltage_angle = wrapper.messaging_framework.theta_g
    
    # Update based on generator type
    if wrapper.generator_type == :thermal
        # Thermal generator - direct update
        wrapper.generator.Pg = power_output
        wrapper.generator.theta_g = voltage_angle
        
    elseif wrapper.generator_type == :hydro
        # Hydro generator - update flow rate and power
        wrapper.generator.active_power = power_output
        flow_rate = calculate_required_flow(wrapper.generator, power_output)
        wrapper.generator.flow_rate = flow_rate
        
        # Update reservoir level if time step is available
        # update_reservoir_level!(wrapper.generator, flow_rate, wrapper.generator.inflow, 1.0)
        
    elseif wrapper.generator_type == :storage
        # Storage generator - update SOC and power
        wrapper.generator.active_power = power_output
        
        # Update SOC based on power dispatch (positive = discharge, negative = charge)
        dt = 1.0  # 1 hour time step
        update_soc!(wrapper.generator, power_output, dt)
        
    elseif wrapper.generator_type == :renewable
        # Renewable generator - update within available capacity
        available_power = get_available_power(wrapper.generator)
        wrapper.generator.power_output = min(power_output, available_power)
        
    elseif wrapper.generator_type == :storage_gen
        # Storage generator (battery) - update SOC and power
        wrapper.generator.active_power = power_output
        wrapper.generator.power_output = power_output
        
        # Update state of charge
        dt = 1.0
        if power_output > 0  # Discharging
            energy_change = -power_output * dt / wrapper.generator.discharging_efficiency
        else  # Charging
            energy_change = -power_output * dt * wrapper.generator.charging_efficiency
        end
        
        new_soc = wrapper.generator.state_of_charge + energy_change / wrapper.generator.energy_capacity
        set_state_of_charge!(wrapper.generator, new_soc)
    end
    
    # Update common wrapper properties
    wrapper.outgoing_messages["power"][1] = power_output
    wrapper.outgoing_messages["voltage_angle"][1] = voltage_angle
    
    return nothing
end

"""
Get generator power output
"""
function get_unified_power_output(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return wrapper.generator.Pg
    elseif wrapper.generator_type == :hydro
        return wrapper.generator.active_power
    elseif wrapper.generator_type == :storage
        return wrapper.generator.active_power
    elseif wrapper.generator_type == :renewable
        return wrapper.generator.power_output
    elseif wrapper.generator_type == :storage_gen
        return wrapper.generator.power_output
    else
        return 0.0
    end
end

"""
Get generator marginal cost
"""
function get_unified_marginal_cost(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return calculate_marginal_cost(wrapper.generator, wrapper.generator.Pg)
    elseif wrapper.generator_type == :hydro
        return calculate_water_value(wrapper.generator)
    elseif wrapper.generator_type == :storage
        return get_storage_cost(wrapper.generator, wrapper.generator.active_power)
    elseif wrapper.generator_type == :renewable
        return get_effective_cost(wrapper.generator)
    elseif wrapper.generator_type == :storage_gen
        return wrapper.generator.marginal_cost_discharge
    else
        return 0.0
    end
end

"""
Check if generator is available and online
"""
function is_unified_generator_available(wrapper::UnifiedGeneratorWrapper)
    if wrapper.generator_type == :thermal
        return wrapper.generator.generator.available && wrapper.generator.gen_solver.commitment_status
    elseif wrapper.generator_type == :hydro
        return wrapper.generator.available
    elseif wrapper.generator_type == :storage
        return wrapper.generator.available
    elseif wrapper.generator_type == :renewable
        return is_available(wrapper.generator)
    elseif wrapper.generator_type == :storage_gen
        return PowerSystems.get_available(wrapper.generator)
    else
        return false
    end
end

# ===== EXPORT FUNCTIONS =====

export UnifiedGeneratorWrapper, UnifiedGenerator
export create_unified_thermal_generator, create_unified_hydro_generator
export create_unified_storage_generator, create_unified_renewable_generator
export create_unified_storage_gen_generator
export unified_power_angle_message!, initialize_messaging!
export get_unified_power_output, get_unified_marginal_cost, is_unified_generator_available
export update_generator_from_messaging_result!

# Generator Integration Module for PowerLASCOPF System
# This module integrates the unified generator framework with the PowerLASCOPF system

include("unified_generator_framework.jl")
include("../extensions/extended_system.jl")  # Your PSY.System extension

# ===== POWERLASCOPF SYSTEM INTEGRATION =====

"""
Add unified generator to PowerLASCOPF system
"""
function add_unified_generator!(
    system::PowerLASCOPFSystem,
    generator_wrapper::UnifiedGeneratorWrapper
)
    # Add to the PowerLASCOPF system's generator collection
    if !haskey(system.extended_data, "unified_generators")
        system.extended_data["unified_generators"] = Dict{Int, UnifiedGeneratorWrapper}()
    end
    
    # Store the unified generator
    system.extended_data["unified_generators"][generator_wrapper.gen_id] = generator_wrapper
    
    # Add to PSY system based on generator type
    if generator_wrapper.generator_type == :thermal
        add_component!(system, generator_wrapper.generator.generator)
    elseif generator_wrapper.generator_type == :hydro
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :storage
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :renewable
        add_component!(system, generator_wrapper.generator)
    elseif generator_wrapper.generator_type == :storage_gen
        add_component!(system, generator_wrapper.generator)
    end
    
    println("Added $(generator_wrapper.generator_type) generator (ID: $(generator_wrapper.gen_id)) to PowerLASCOPF system")
    return nothing
end

"""
Create and add thermal generator to system
"""
function add_thermal_generator!(
    system::PowerLASCOPFSystem,
    thermal_gen::ExtendedThermalGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_thermal_generator(thermal_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add hydro generator to system
"""
function add_hydro_generator!(
    system::PowerLASCOPFSystem,
    hydro_gen::ExtendedHydroGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_hydro_generator(hydro_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add storage generator to system
"""
function add_storage_generator!(
    system::PowerLASCOPFSystem,
    storage_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_storage_generator(storage_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add renewable generator to system
"""
function add_renewable_generator!(
    system::PowerLASCOPFSystem,
    renewable_gen::ExtendedRenewableGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_renewable_generator(renewable_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

"""
Create and add storage generator (battery) to system
"""
function add_storage_gen_generator!(
    system::PowerLASCOPFSystem,
    storage_gen_gen::ExtendedStorageGenerator,
    gen_id::Int,
    node_connection::Int,
    scenario_count::Int = 1
)
    wrapper = create_unified_storage_gen_generator(storage_gen_gen, gen_id, node_connection, scenario_count)
    add_unified_generator!(system, wrapper)
    return wrapper
end

# ===== SYSTEM-WIDE OPERATIONS =====

"""
Run APP+ADMM messaging for all generators in the system
"""
function run_unified_messaging!(
    system::PowerLASCOPFSystem,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    power_prices::Dict{Int, Float64},
    angle_prices::Dict{Int, Float64},
    power_averages::Dict{Int, Float64},
    angle_averages::Dict{Int, Float64}
)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Any}()
    end
    
    results = Dict{Int, Any}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        # Get prices and averages for this generator's node
        node_id = generator_wrapper.node_connection
        
        power_price = get(power_prices, node_id, 0.0)
        angle_price = get(angle_prices, node_id, 0.0)
        power_avg = get(power_averages, node_id, 0.0)
        angle_avg = get(angle_averages, node_id, 0.0)
        
        # Run unified messaging
        result = unified_power_angle_message!(
            generator_wrapper,
            outerAPPIt,
            APPItCount,
            gsRho,
            power_avg,
            power_price,
            angle_price,  # Angpriceavg
            angle_avg,    # Angavg
            angle_price   # Angprice
        )
        
        results[gen_id] = result
    end
    
    return results
end

"""
Get all generator power outputs
"""
function get_all_generator_outputs(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Float64}()
    end
    
    outputs = Dict{Int, Float64}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        outputs[gen_id] = get_unified_power_output(generator_wrapper)
    end
    
    return outputs
end

"""
Get all generator marginal costs
"""
function get_all_generator_costs(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        return Dict{Int, Float64}()
    end
    
    costs = Dict{Int, Float64}()
    unified_generators = system.extended_data["unified_generators"]
    
    for (gen_id, generator_wrapper) in unified_generators
        costs[gen_id] = get_unified_marginal_cost(generator_wrapper)
    end
    
    return costs
end

"""
Get system-wide generator summary
"""
function get_generator_summary(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        println("No unified generators found in system")
        return nothing
    end
    
    unified_generators = system.extended_data["unified_generators"]
    println("=== PowerLASCOPF Generator Summary ===")
    println("Total generators: $(length(unified_generators))")
    
    # Count by type
    type_counts = Dict{Symbol, Int}()
    total_power = 0.0
    total_cost = 0.0
    
    for (gen_id, generator_wrapper) in unified_generators
        gen_type = generator_wrapper.generator_type
        type_counts[gen_type] = get(type_counts, gen_type, 0) + 1
        
        power = get_unified_power_output(generator_wrapper)
        cost = get_unified_marginal_cost(generator_wrapper)
        available = is_unified_generator_available(generator_wrapper)
        
        total_power += power
        total_cost += cost
        
        println("Gen $gen_id ($(gen_type)): Power = $(round(power, digits=2)) MW, Cost = \$(round(cost, digits=2))/MWh, Available = $available")
    end
    
    println("\n=== Summary by Type ===")
    for (gen_type, count) in type_counts
        println("$gen_type: $count generators")
    end
    
    println("\nTotal Power Output: $(round(total_power, digits=2)) MW")
    println("Average Marginal Cost: \$(round(total_cost/length(unified_generators), digits=2))/MWh")
    
    return (
        total_generators = length(unified_generators),
        type_counts = type_counts,
        total_power = total_power,
        average_cost = total_cost / length(unified_generators)
    )
end

"""
Validate all generators in system
"""
function validate_unified_generators(system::PowerLASCOPFSystem)
    if !haskey(system.extended_data, "unified_generators")
        println("No unified generators to validate")
        return true
    end
    
    unified_generators = system.extended_data["unified_generators"]
    all_valid = true
    
    println("=== Validating Unified Generators ===")
    
    for (gen_id, generator_wrapper) in unified_generators
        valid = true
        issues = String[]
        
        # Check basic properties
        if generator_wrapper.gen_id != gen_id
            push!(issues, "ID mismatch")
            valid = false
        end
        
        # Check messaging framework
        if isnothing(generator_wrapper.messaging_framework)
            push!(issues, "Missing messaging framework")
            valid = false
        end
        
        # Check generator availability
        if !is_unified_generator_available(generator_wrapper)
            push!(issues, "Generator not available")
        end
        
        # Type-specific validation
        if generator_wrapper.generator_type == :hydro
            hydro = generator_wrapper.generator
            if hydro.reservoir_capacity <= 0
                push!(issues, "Invalid reservoir capacity")
                valid = false
            end
        elseif generator_wrapper.generator_type == :storage
            storage = generator_wrapper.generator
            if storage.energy_capacity <= 0
                push!(issues, "Invalid energy capacity")
                valid = false
            end
        end
        
        status = valid ? "✓ VALID" : "✗ INVALID"
        issue_str = isempty(issues) ? "" : " ($(join(issues, ", ")))"
        println("Gen $gen_id ($(generator_wrapper.generator_type)): $status$issue_str")
        
        all_valid = all_valid && valid
    end
    
    if all_valid
        println("\n✓ All generators are valid")
    else
        println("\n✗ Some generators have issues")
    end
    
    return all_valid
end

# ===== EXPORT FUNCTIONS =====

export add_unified_generator!, add_thermal_generator!, add_hydro_generator!
export add_storage_generator!, add_renewable_generator!, add_storage_gen_generator!
export run_unified_messaging!, get_all_generator_outputs, get_all_generator_costs
export get_generator_summary, validate_unified_generators
