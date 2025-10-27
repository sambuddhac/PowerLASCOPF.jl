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

"""
    GeneralizedGenerator{T<:PSY.Generator, U<:GenIntervals}

A generalized generator component that extends PowerSystems generators for LASCOPF optimization.
Supports thermal, renewable, hydro, and storage generators with ADMM/APP state variables,
timeseries handling, and stochastic scenarios.
"""
mutable struct GeneralizedGenerator{T<:PSY.Generator,U<:GenIntervals} <: PowerGenerator
    # Core generator properties
    generator::T # PowerSystems Generator (ThermalGen, RenewableGen, HydroGen, etc.)
    cost_function::Union{ExtendedThermalGenerationCost{U}, ExtendedRenewableGenerationCost{U}, 
                        ExtendedHydroGenerationCost{U}, ExtendedStorageCost{U}}
    
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
        gen_total::Int64;
        config::GenSolverConfig = GenSolverConfig()
    ) where {T<:PSY.Generator, U<:GenIntervals}
        
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
        self.number_of_generators = gen_total
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
        self.gen_total = gen_total
        
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
        set_gen_data!(self)
        
        return self
    end
end

"""
    create_extended_cost_for_generator(generator::PSY.Generator, interval_type::GenIntervals)

Factory function to create the appropriate extended cost model based on generator type.
"""
function create_extended_cost_for_generator(generator::T, interval_type::U) where {T<:PSY.Generator, U<:GenIntervals}
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
    
    # Extract available timeseries from PSY generator
    time_series_names = PSY.get_time_series_names(psy_gen)
    
    if isempty(time_series_names)
        # No timeseries available, create single deterministic scenario
        scenario = GeneratorScenario(
            scenario_id = 1,
            probability = 1.0,
            current_active_power = PSY.get_active_power(psy_gen),
            current_reactive_power = PSY.get_reactive_power(psy_gen),
            current_availability = PSY.get_available(psy_gen)
        )
        
        # For renewable generators, set renewable power
        if isa(psy_gen, PSY.RenewableGen)
            scenario.current_renewable_power = PSY.get_rating(psy_gen)
        end
        
        push!(gen.scenarios, scenario)
        return
    end
    
    # Extract timeseries data
    for (idx, ts_name) in enumerate(time_series_names)
        try
            ts_data = PSY.get_time_series(psy_gen, ts_name)
            
            scenario = GeneratorScenario(
                scenario_id = idx,
                probability = 1.0 / length(time_series_names)  # Equal probability for now
            )
            
            # Map timeseries based on type and name
            if occursin("ActivePower", string(ts_name)) || occursin("P", string(ts_name))
                scenario.active_power_series = ts_data
            elseif occursin("ReactivePower", string(ts_name)) || occursin("Q", string(ts_name))
                scenario.reactive_power_series = ts_data
            elseif occursin("Availability", string(ts_name)) || occursin("Available", string(ts_name))
                scenario.availability_series = ts_data
            elseif occursin("Renewable", string(ts_name)) || occursin("Wind", string(ts_name)) || occursin("Solar", string(ts_name))
                scenario.renewable_power_series = ts_data
            else
                # Default to active power for unknown series
                scenario.active_power_series = ts_data
            end
            
            # Set initial values
            if !isnothing(scenario.active_power_series)
                scenario.current_active_power = first(PSY.get_data(scenario.active_power_series))
            else
                scenario.current_active_power = PSY.get_active_power(psy_gen)
            end
            
            if !isnothing(scenario.renewable_power_series)
                scenario.current_renewable_power = first(PSY.get_data(scenario.renewable_power_series))
            elseif isa(psy_gen, PSY.RenewableGen)
                scenario.current_renewable_power = PSY.get_rating(psy_gen)
            end
            
            push!(gen.scenarios, scenario)
            
        catch e
            @warn "Failed to extract timeseries $ts_name for generator $(PSY.get_name(psy_gen)): $e"
        end
    end
    
    # If no scenarios were created, create default
    if isempty(gen.scenarios)
        push!(gen.scenarios, GeneratorScenario(
            scenario_id = 1,
            probability = 1.0,
            current_active_power = PSY.get_active_power(psy_gen),
            current_availability = PSY.get_available(psy_gen)
        ))
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
                scenario.current_active_power = PSY.get_value_at_time(scenario.active_power_series, current_time)
            catch e
                @debug "Could not get active power at time $current_time: $e"
            end
        end
        
        if !isnothing(scenario.renewable_power_series)
            try
                scenario.current_renewable_power = PSY.get_value_at_time(scenario.renewable_power_series, current_time)
            catch e
                @debug "Could not get renewable power at time $current_time: $e"
            end
        end
        
        if !isnothing(scenario.availability_series)
            try
                scenario.current_availability = PSY.get_value_at_time(scenario.availability_series, current_time) > 0.5
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