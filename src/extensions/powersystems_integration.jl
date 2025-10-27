# ============================================================================
# PowerLASCOPF/src/models/solver_models/formulations.jl
# ============================================================================

# Add required imports at the top
using JuMP
using PowerSystems
using PowerSimulations
using InfrastructureSystems
using PowerModels

const PSY = PowerSystems
const PSI = PowerSimulations
const IS = InfrastructureSystems
const PM = PowerModels

# Formulation for (N-1-1) Look-Ahead Security Constrained Optimal Power Flow
# using APP and ADMM-Proximal Message Passing algorithms
struct LASCOPFGeneratorFormulation <: PSI.AbstractDeviceFormulation end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/variables.jl
# ============================================================================

# Custom variable types for LASCOPF
struct PgNextVariable <: PSI.VariableType end
struct PgPrevVariable <: PSI.VariableType end
struct ThetagVariable <: PSI.VariableType end

# Add ActivePowerVariable for LASCOPF Generator Formulation
function PSI.add_variable!(
    container::PSI.OptimizationContainer,
    ::Type{PSI.ActivePowerVariable},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    variable_name = PSI.make_variable_name(PSI.ActivePowerVariable, PSY.ThermalGen)
    
    # Add variable container
    PSI._add_variable_container!(
        container,
        PSI.ActivePowerVariable,
        PSY.ThermalGen,
        [PSY.get_name(d) for d in devices],
        time_steps
    )
    
    # Create JuMP variables
    variable = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = PSY.get_active_power_limits(device)
        
        variable[name, t] = JuMP.@variable(
            jump_model,
            base_name = "$(variable_name)_$(name)_$(t)",
            lower_bound = limits.min,
            upper_bound = limits.max
        )
    end
    
    return
end

# Add PgNext variable for next interval power output
function PSI.add_variable!(
    container::PSI.OptimizationContainer,
    ::Type{PgNextVariable},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    variable_name = PSI.make_variable_name(PgNextVariable, PSY.ThermalGen)
    
    PSI._add_variable_container!(
        container,
        PgNextVariable,
        PSY.ThermalGen,
        [PSY.get_name(d) for d in devices],
        time_steps
    )
    
    variable = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = PSY.get_active_power_limits(device)
        
        variable[name, t] = JuMP.@variable(
            jump_model,
            base_name = "$(variable_name)_$(name)_$(t)",
            lower_bound = limits.min,
            upper_bound = limits.max
        )
    end
    
    return
end

# Add PgPrev variable for previous interval power output
function PSI.add_variable!(
    container::PSI.OptimizationContainer,
    ::Type{PgPrevVariable},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    variable_name = PSI.make_variable_name(PgPrevVariable, PSY.ThermalGen)

    PSI._add_variable_container!(
        container,
        PgPrevVariable,
        PSY.ThermalGen,
        [PSY.get_name(d) for d in devices],
        time_steps
    )

    variable = PSI.get_variable(container, PgPrevVariable, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)

    for device in devices, t in time_steps
        name = PSY.get_name(device)
        limits = PSY.get_active_power_limits(device)

        variable[name, t] = JuMP.@variable(
            jump_model,
            base_name = "$(variable_name)_$(name)_$(t)",
            lower_bound = limits.min,
            upper_bound = limits.max
        )
    end

    return
end

# Add generator bus angle variable
function PSI.add_variable!(
    container::PSI.OptimizationContainer,
    ::Type{ThetagVariable},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    variable_name = PSI.make_variable_name(ThetagVariable, PSY.ThermalGen)
    
    PSI._add_variable_container!(
        container,
        ThetagVariable,
        PSY.ThermalGen,
        [PSY.get_name(d) for d in devices],
        time_steps
    )
    
    variable = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        
        variable[name, t] = JuMP.@variable(
            jump_model,
            base_name = "$(variable_name)_$(name)_$(t)"
            # Note: No bounds set here - angle variables are typically unbounded
            # or have system-wide angle reference constraints
        )
    end
    
    return
end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/parameters.jl
# ============================================================================

# Define parameter types for LASCOPF
struct PgNuParameter <: PSI.ParameterType end
struct PgNuInnerParameter <: PSI.ParameterType end
struct PgNInitParameter <: PSI.ParameterType end
struct PgNAvgParameter <: PSI.ParameterType end
struct ThetagNAvgParameter <: PSI.ParameterType end
struct UgNParameter <: PSI.ParameterType end
struct VgNParameter <: PSI.ParameterType end
struct VgNAvgParameter <: PSI.ParameterType end
struct Lambda1Parameter <: PSI.ParameterType end
struct Lambda2Parameter <: PSI.ParameterType end
struct BParameter <: PSI.ParameterType end
struct DParameter <: PSI.ParameterType end
struct BSCParameter <: PSI.ParameterType end
struct Lambda1SCParameter <: PSI.ParameterType end
struct PgNextNuParameter <: PSI.ParameterType end

# FIX: Use proper parameter handling instead of @parameter
# Add ADMM/APP parameters for LASCOPF formulation
function PSI.add_parameters!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
) where {T <: Union{PgNuParameter, PgNuInnerParameter, PgNInitParameter, 
                   PgNAvgParameter, ThetagNAvgParameter, UgNParameter, 
                   VgNParameter, VgNAvgParameter, Lambda1Parameter, 
                   Lambda2Parameter, BParameter, DParameter, PgNextNuParameter}}
    
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    
    # Create parameter container as a simple Dict to store parameter values
    param_container = Dict{Tuple{String, Int}, Float64}()
    
    # Initialize parameters with default values
    for name in device_names, t in time_steps
        param_container[(name, t)] = 0.0
    end
    
    # Store parameter container in the optimization container's extension data
    if !haskey(container.ext, "LASCOPF_Parameters")
        container.ext["LASCOPF_Parameters"] = Dict()
    end
    container.ext["LASCOPF_Parameters"][T] = param_container
    
    return
end

# Add contingency-indexed parameters (BSC, Lambda1SC)
function PSI.add_parameters!(
    container::PSI.OptimizationContainer,
    ::Type{T},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel
) where {T <: Union{BSCParameter, Lambda1SCParameter}}
    
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    
    # Get contingency count from model extension data
    gen_interval_data = get(model.internal.ext, "LASCOPF_GenIntervalData", nothing)
    cont_count = isnothing(gen_interval_data) ? 0 : gen_interval_data.cont_count
    
    if cont_count > 0
        contingency_indices = 1:cont_count
        
        # Create parameter container for contingency-indexed parameters
        param_container = Dict{Tuple{String, Int, Int}, Float64}()
        
        for name in device_names, t in time_steps, c in contingency_indices
            param_container[(name, t, c)] = 0.0
        end
        
        # Store parameter container
        if !haskey(container.ext, "LASCOPF_Parameters")
            container.ext["LASCOPF_Parameters"] = Dict()
        end
        container.ext["LASCOPF_Parameters"][T] = param_container
    end
    
    return
end

# Helper functions to get/set parameter values
function get_parameter_value(container::PSI.OptimizationContainer, ::Type{T}, name::String, t::Int) where T
    param_dict = get(container.ext, "LASCOPF_Parameters", Dict())
    param_container = get(param_dict, T, Dict())
    return get(param_container, (name, t), 0.0)
end

function set_parameter_value!(container::PSI.OptimizationContainer, ::Type{T}, name::String, t::Int, value::Float64) where T
    if !haskey(container.ext, "LASCOPF_Parameters")
        container.ext["LASCOPF_Parameters"] = Dict()
    end
    if !haskey(container.ext["LASCOPF_Parameters"], T)
        container.ext["LASCOPF_Parameters"][T] = Dict()
    end
    container.ext["LASCOPF_Parameters"][T][(name, t)] = value
    return
end

function get_parameter_value(container::PSI.OptimizationContainer, ::Type{T}, name::String, t::Int, c::Int) where T
    param_dict = get(container.ext, "LASCOPF_Parameters", Dict())
    param_container = get(param_dict, T, Dict())
    return get(param_container, (name, t, c), 0.0)
end

function set_parameter_value!(container::PSI.OptimizationContainer, ::Type{T}, name::String, t::Int, c::Int, value::Float64) where T
    if !haskey(container.ext, "LASCOPF_Parameters")
        container.ext["LASCOPF_Parameters"] = Dict()
    end
    if !haskey(container.ext["LASCOPF_Parameters"], T)
        container.ext["LASCOPF_Parameters"][T] = Dict()
    end
    container.ext["LASCOPF_Parameters"][T][(name, t, c)] = value
    return
end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/constraints.jl
# ============================================================================

# Add ramping constraints for LASCOPF Generator Formulation
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    ::Type{PSI.RampConstraint},
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel,
    ::PSI.NetworkModel{<:PM.AbstractPowerModel}
)
    time_steps = PSI.get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    
    # Add constraint container
    PSI._add_cons_container!(
        container,
        PSI.RampConstraint,
        PSY.ThermalGen,
        device_names,
        time_steps
    )
    
    constraint = PSI.get_constraint(container, PSI.RampConstraint, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)
    
    for device in devices, t in time_steps
        name = PSY.get_name(device)
        ramp_limits = PSY.get_ramp_limits(device)
        
        # Ramp up constraint: PgNext - Pg <= RampUp
        constraint[name, t] = JuMP.@constraint(
            jump_model,
            PgNext[name, t] - Pg[name, t] <= ramp_limits.up
        )
        
        # Ramp down constraint: Pg - PgNext <= RampDown  
        constraint[name, t] = JuMP.@constraint(
            jump_model,
            Pg[name, t] - PgNext[name, t] <= ramp_limits.down
        )
    end
    
    return
end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/objective_functions.jl
# ============================================================================

# Add objective function for LASCOPF Generator Formulation
function add_objective_function!(
    container::PSI.OptimizationContainer,
    ::LASCOPFGeneratorFormulation,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalGen},
    model::PSI.DecisionModel,
    ::PSI.NetworkModel{<:PM.AbstractPowerModel}
)
    for device in devices
        add_objective_function!(container, device, model)
    end
    return
end

function add_objective_function!(
    container::PSI.OptimizationContainer,
    device::PSY.ThermalGen,
    model::PSI.DecisionModel
)
    # Get cost data
    cost_curve = PSY.get_operation_cost(device)
    
    # Handle different cost types
    if isdefined(Main, :ExtendedThermalGenerationCost) && isa(cost_curve, Main.ExtendedThermalGenerationCost)
        add_extended_thermal_cost!(container, device, cost_curve, model)
    else
        # Handle standard PowerSystems cost curves
        add_standard_thermal_cost!(container, device, cost_curve, model)
    end
    
    return
end

function add_extended_thermal_cost!(
    container::PSI.OptimizationContainer,
    device::PSY.ThermalGen,
    cost_curve,  # ExtendedThermalGenerationCost
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    device_name = PSY.get_name(device)
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    thetag = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen)
    
    # Build simplified objective function
    for t in time_steps
        # Base generation cost (simplified quadratic)
        cost_expr = 0.01 * (Pg[device_name, t]^2) + 10.0 * Pg[device_name, t] + 100.0
        
        # Add parameter-based terms using stored parameter values
        pg_nu_val = get_parameter_value(container, PgNuParameter, device_name, t)
        pg_next_nu_val = get_parameter_value(container, PgNextNuParameter, device_name, t)
        
        # Regularization terms
        reg_expr = 0.5 * ((Pg[device_name, t] - pg_nu_val)^2 + 
                         (PgNext[device_name, t] - pg_next_nu_val)^2)
        
        total_expr = cost_expr + reg_expr
        
        PSI.add_to_objective_function!(container, total_expr)
    end
    
    return
end

function add_standard_thermal_cost!(
    container::PSI.OptimizationContainer,
    device::PSY.ThermalGen,
    cost_curve,
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    device_name = PSY.get_name(device)
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    
    # Extract cost coefficients from PowerSystems cost curve
    if hasmethod(PSY.get_cost, (typeof(cost_curve),))
        cost_coeffs = PSY.get_cost(cost_curve)
        
        # Handle different cost structures
        if isa(cost_coeffs, Vector{Float64}) && length(cost_coeffs) >= 2
            c0 = length(cost_coeffs) >= 1 ? cost_coeffs[1] : 0.0
            c1 = length(cost_coeffs) >= 2 ? cost_coeffs[2] : 0.0
            c2 = length(cost_coeffs) >= 3 ? cost_coeffs[3] : 0.0
            
            for t in time_steps
                cost_expr = c2 * (Pg[device_name, t]^2) + c1 * Pg[device_name, t] + c0
                PSI.add_to_objective_function!(container, cost_expr)
            end
        else
            # Default cost if structure is unknown
            for t in time_steps
                cost_expr = 10.0 * Pg[device_name, t]  # Linear cost
                PSI.add_to_objective_function!(container, cost_expr)
            end
        end
    else
        # Fallback if get_cost method doesn't exist
        for t in time_steps
            cost_expr = 10.0 * Pg[device_name, t]
            PSI.add_to_objective_function!(container, cost_expr)
        end
    end
    
    return
end

# Export the new types and functions
export LASCOPFGeneratorFormulation
export PgNextVariable, PgPrevVariable, ThetagVariable
export PgNuParameter, PgNuInnerParameter, PgNInitParameter, PgNAvgParameter
export ThetagNAvgParameter, UgNParameter, VgNParameter, VgNAvgParameter
export Lambda1Parameter, Lambda2Parameter, BParameter, DParameter
export BSCParameter, Lambda1SCParameter, PgNextNuParameter
export get_parameter_value, set_parameter_value!