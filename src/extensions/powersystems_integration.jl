# ============================================================================
# PowerLASCOPF/src/models/solver_models/formulations.jl
# ============================================================================

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

# Add PgPrev variable for next interval power output
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
    
    PSI._add_param_container!(
        container,
        T,
        PSY.ThermalGen,
        device_names,
        time_steps
    )
    
    # Initialize parameters with default values
    # These will be updated during ADMM/APP iterations
    param_container = PSI.get_parameter_container(container, T, PSY.ThermalGen)
    jump_model = PSI.get_jump_model(container)
    
    for name in device_names, t in time_steps
        param_container[name, t] = JuMP.@parameter(jump_model, 0.0)
    end
    
    return
end

# 
# Add contingency-indexed parameters (BSC, Lambda1SC)
# 
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
        
        PSI._add_param_container!(
            container,
            T,
            PSY.ThermalGen,
            device_names,
            time_steps,
            contingency_indices
        )
        
        param_container = PSI.get_parameter_container(container, T, PSY.ThermalGen)
        jump_model = PSI.get_jump_model(container)
        
        for name in device_names, t in time_steps, c in contingency_indices
            param_container[name, t, c] = JuMP.@parameter(jump_model, 0.0)
        end
    end
    
    return
end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/constraints.jl
# ============================================================================

# 
# Add ramping constraints for LASCOPF Generator Formulation
# 
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
        
        # Inter-temporal ramping constraints would go here
        # if you have Pg_prev from previous time step
    end
    
    return
end

# ============================================================================
# PowerLASCOPF/src/models/solver_models/objective_functions.jl
# ============================================================================

# 
# Add objective function for LASCOPF Generator Formulation
# 
function PSI.add_objective_function!(
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
    if isa(cost_curve, ExtendedThermalGenerationCost)
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
    cost_curve::ExtendedThermalGenerationCost,
    model::PSI.DecisionModel
)
    time_steps = PSI.get_time_steps(container)
    device_name = PSY.get_name(device)
    
    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen)
    thetag = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen)
    
    # Get cost parameters
    thermal_cost = get_cost_core(cost_curve)
    cost_coeffs = PSY.get_cost(thermal_cost)
    
    # Extract coefficients (assuming polynomial cost)
    c0 = length(cost_coeffs) >= 1 ? cost_coeffs[1] : 0.0
    c1 = length(cost_coeffs) >= 2 ? cost_coeffs[2] : 0.0
    c2 = length(cost_coeffs) >= 3 ? cost_coeffs[3] : 0.0
    
    # Get regularization parameters
    reg_term = get_regularization(cost_curve)
    
    if isa(reg_term, GenFirstBaseInterval)
        # Get tuning parameters
        beta = reg_term.beta
        beta_inner = reg_term.beta_inner
        gamma = reg_term.gamma
        gamma_sc = reg_term.gamma_sc
        rho = reg_term.rho
        cont_count = reg_term.cont_count
        
        # Get parameters
        Pg_nu = PSI.get_parameter(container, PgNuParameter, PSY.ThermalGen)
        Pg_nu_inner = PSI.get_parameter(container, PgNuInnerParameter, PSY.ThermalGen)
        PgNext_nu = PSI.get_parameter(container, PgNextNuParameter, PSY.ThermalGen)
        
        # Network parameters
        Pg_N_init = PSI.get_parameter(container, PgNInitParameter, PSY.ThermalGen)
        Pg_N_avg = PSI.get_parameter(container, PgNAvgParameter, PSY.ThermalGen)
        thetag_N_avg = PSI.get_parameter(container, ThetagNAvgParameter, PSY.ThermalGen)
        ug_N = PSI.get_parameter(container, UgNParameter, PSY.ThermalGen)
        vg_N = PSI.get_parameter(container, VgNParameter, PSY.ThermalGen)
        Vg_N_avg = PSI.get_parameter(container, VgNAvgParameter, PSY.ThermalGen)
        
        # APP parameters
        lambda_1 = PSI.get_parameter(container, Lambda1Parameter, PSY.ThermalGen)
        lambda_2 = PSI.get_parameter(container, Lambda2Parameter, PSY.ThermalGen)
        B = PSI.get_parameter(container, BParameter, PSY.ThermalGen)
        D = PSI.get_parameter(container, DParameter, PSY.ThermalGen)
        
        # Contingency parameters
        if cont_count > 0
            BSC = PSI.get_parameter(container, BSCParameter, PSY.ThermalGen)
            lambda_1_sc = PSI.get_parameter(container, Lambda1SCParameter, PSY.ThermalGen)
        end
        
        # Build objective function for each time step
        for t in time_steps
            # Base generation cost
            cost_expr = c2 * (Pg[device_name, t]^2) + c1 * Pg[device_name, t] + c0
            
            # APP regularization terms
            app_expr = (beta/2) * ((Pg[device_name, t] - Pg_nu[device_name, t])^2 + 
                                  (PgNext[device_name, t] - PgNext_nu[device_name, t])^2) +
                      (beta_inner/2) * (Pg[device_name, t] - Pg_nu_inner[device_name, t])^2
            
            # Interval coupling
            coupling_expr = gamma * (Pg[device_name, t] * B[device_name, t] + 
                                   PgNext[device_name, t] * D[device_name, t]) +
                           lambda_1[device_name, t] * Pg[device_name, t] +
                           lambda_2[device_name, t] * PgNext[device_name, t]
            
            # Security constraints
            security_expr = 0.0
            if cont_count > 0
                for c in 1:cont_count
                    security_expr += gamma_sc * (Pg[device_name, t] * BSC[device_name, t, c]) +
                                   (Pg[device_name, t] * lambda_1_sc[device_name, t, c])
                end
            end
            
            # ADMM penalty terms
            admm_expr = (rho/2) * ((Pg[device_name, t] - Pg_N_init[device_name, t] + 
                                  Pg_N_avg[device_name, t] + ug_N[device_name, t])^2 +
                                 (thetag[device_name, t] - Vg_N_avg[device_name, t] - 
                                  thetag_N_avg[device_name, t] + vg_N[device_name, t])^2)
            
            # Total objective expression
            total_expr = cost_expr + app_expr + coupling_expr + security_expr + admm_expr
            
            PSI.add_to_objective_function!(container, total_expr)
        end
    else
        # Handle case where regularization_term is just a Float64
        for t in time_steps
            cost_expr = c2 * (Pg[device_name, t]^2) + c1 * Pg[device_name, t] + c0 + reg_term
            PSI.add_to_objective_function!(container, cost_expr)
        end
    end
    
    return
end

function add_standard_thermal_cost!(
    container::PSI.OptimizationContainer,
    device::PSY.ThermalGen,
    cost_curve::PSY.ThermalGenerationCost,
    model::PSI.DecisionModel
)
    # Handle standard PowerSystems thermal generation costs
    # This would follow the standard Sienna pattern
    PSI.add_to_objective_function!(container, device, cost_curve)
    return
end