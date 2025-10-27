# PowerLASCOPF.jl/src/objective_functions.jl
function PSI.get_objective_expression(
    container::PSI.OptimizationContainer,
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen,
    cost_function::PSY.ThermalGenerationCost, # Or your custom cost type
    model::PSI.DecisionModel
)
    # Access variables and parameters
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen, PSI.get_name(device))
    PgNext = # ... (get your PgNext variable)
    thetag = # ... (get your thetag variable)

    # Access cost parameters from the PowerSystems cost curve
    c2 = PSY.get_quadratic_term(cost_function)
    c1 = PSY.get_linear_term(cost_function)
    c0 = PSY.get_constant_term(cost_function)

    # Access your custom GenFirstBaseInterval parameters. This will be the tricky part.
    # Assuming you've stored them as PSI.ParameterType in the container:
    beta = PSI.get_parameter_container(container, MyBetaParameter, PSY.ThermalGen) # Example
    # ... and so on for all your lambda, beta, gamma, rho, etc.

    # Build the objective function expression
    obj_expr = c2*(Pg^2) + c1*Pg + c0 +
               (beta/2)*((Pg - Pg_nu_param)^2 + (PgNext - Pg_next_nu_param)^2) +
               (beta_inner/2)*((Pg - Pg_nuInner_param)^2) +
               (gammaSC) * sum(Pg * BSC_param[i] for i in 1:cont_count_param) +
               sum(Pg * lambda_1SC_param[i] for i in 1:cont_count_param) +
               (gamma) * (Pg * B_param + PgNext * D_param) +
               lambda_1_param * Pg +
               lambda_2_param * PgNext +
               (rho/2) * ( (Pg - Pg_N_init_param + Pg_N_avg_param + ug_N_param)^2 +
                           (thetag - Vg_N_avg_param - thetag_N_avg_param + vg_N_param)^2 )

    # Add the expression to the objective function in the container
    PSI.add_to_objective_function!(container, obj_expr)
end

# PowerLASCOPF.jl/src/objective_functions.jl

import PowerSimulations as PSI
import PowerSystems as PSY
import JuMP # For JuMP.value (if needed for parameters)
import LinearAlgebra # For sum, dot products

function PSI.get_objective_expression(
    container::PSI.OptimizationContainer,
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen, # This is the device for which we are building the objective
    cost_curve::ExtendedThermalGenerationCost, # Now explicitly ExtendedThermalGenerationCost
    model::PSI.DecisionModel
)
    jump_model = PSI.get_jump_model(container)
    gen_name = PSY.get_name(device)
    time_steps = PSI.get_time_steps(container)

    # Get variables
    Pg = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen, gen_name)
    PgNext = PSI.get_variable(container, PgNextVariable, PSY.ThermalGen, gen_name)
    thetag = PSI.get_variable(container, ThetagVariable, PSY.ThermalGen, gen_name)

    # Get cost parameters from the ExtendedThermalGenerationCost
    # Assumes PSY.PolynomialCost has a `polynomial_coefficients` field.
    # If not, you'd need to define `get_polynomial_coefficients` for `ThermalGenerationCost`.
    cost_coeffs = PSY.get_variable(PSY.get_cost_core(cost_curve)) # Get the variable cost from the core
    c2 = length(cost_coeffs) >= 3 ? cost_coeffs[3] : 0.0 # Quadratic term
    c1 = length(cost_coeffs) >= 2 ? cost_coeffs[2] : 0.0 # Linear term
    c0 = length(cost_coeffs) >= 1 ? cost_coeffs[1] : 0.0 # Constant term (often not explicitly in polynomial array)
    # If ThermalGenerationCost is directly a PSY.PolynomialCost, you can use:
    # poly_cost = cost_curve.thermal_cost_core
    # c2, c1, c0 = poly_cost.polynomial_coefficients[3], poly_cost.polynomial_coefficients[2], poly_cost.polynomial_coefficients[1]

    # Retrieve your GenFirstBaseInterval instance from the model's extension data
    gen_interval_data = get(model.internal.ext, "LASCOPF_GenIntervalData", nothing)
    if isnothing(gen_interval_data)
        @error "GenFirstBaseInterval data not found in model extension. Objective cannot be built."
        return
    end

    # Access tuning parameters directly from GenFirstBaseInterval (assuming they are fixed per iteration)
    rho = gen_interval_data.rho
    beta = gen_interval_data.beta
    beta_inner = gen_interval_data.beta_inner
    gamma = gen_interval_data.gamma
    gamma_sc = gen_interval_data.gamma_sc
    cont_count = gen_interval_data.cont_count

    # Access JuMP Parameters from the container (these are the ones that update iteratively)
    # These parameters are specific to *each generator* and *each time step*.
    Pg_nu_param = PSI.get_parameter(container, PgNuParameter, PSY.ThermalGen, gen_name)
    Pg_nuInner_param = PSI.get_parameter(container, PgNuInnerParameter, PSY.ThermalGen, gen_name)
    Pg_N_init_param = PSI.get_parameter(container, PgNInitParameter, PSY.ThermalGen, gen_name)
    Pg_N_avg_param = PSI.get_parameter(container, PgNAvgParameter, PSY.ThermalGen, gen_name)
    thetag_N_avg_param = PSI.get_parameter(container, ThetagNAvgParameter, PSY.ThermalGen, gen_name)
    ug_N_param = PSI.get_parameter(container, UgNParameter, PSY.ThermalGen, gen_name)
    vg_N_param = PSI.get_parameter(container, VgNParameter, PSY.ThermalGen, gen_name)
    Vg_N_avg_param = PSI.get_parameter(container, VgNAvgParameter, PSY.ThermalGen, gen_name)

    # Access array-based values from GenFirstBaseInterval
    # This assumes that these arrays are globally indexed OR
    # that your ADMM/APP process ensures that `gen_interval_data` contains
    # the correct slice/value for *this specific generator*.
    # If these are meant to be indexed by generator AND time, you'll need to pass
    # the time step and generator name for correct indexing within the `gen_interval_data` arrays.
    # For now, let's assume `lambda_1`, `lambda_2`, `B`, `D`, `BSC`, `lambda_1_sc`, `Pg_next_nu`
    # are either scalars that are implicitly broadcast or arrays indexed by (time, contingency) or (generator_idx, time)
    # The most flexible way is to make them JuMP Parameters indexed by generator and time.

    # REVISED ASSUMPTION FOR ARRAY PARAMETERS:
    # Given that `lambda_1`, `B`, `D`, `BSC`, `lambda_1_sc`, `Pg_next_nu` are `Array{Float64}`
    # and they appear in sums with `cont_count` or are multiplied by `Pg`/`PgNext`,
    # they are highly likely to be indexed by (time_step, contingency_idx) or just (contingency_idx).
    # And then *applied* to each generator.
    # If they are indexed by generator and time step, they would typically be accessed via PSI.get_parameter.
    # If they are global arrays that vary per time step and contingency but are *the same* across all generators
    # for a given time step/contingency, then accessing them directly from `gen_interval_data` and passing indices is fine.

    # Let's adjust for the most common interpretation:
    # lambda_1, lambda_2, B, D, Pg_next_nu are likely indexed by time step, and maybe a "next interval" index if that's what their size represents.
    # BSC, lambda_1_sc are indexed by contingency scenario.

    # To simplify for now, let's assume the array elements in `gen_interval_data` are associated with the current `t` and `gen_name`
    # by some external logic, or that the `gen_interval_data` object itself is specific to this generator and time step.
    # This is a critical point that requires clarification based on your ADMM/APP setup.

    # If lambda_1, lambda_2, B, D, Pg_next_nu should also be JuMP Parameters, you'd add ParameterTypes for them and retrieve them.
    # For example:
    # Lambda1_param = PSI.get_parameter(container, Lambda1Parameter, PSY.ThermalGen, gen_name)
    # Lambda2_param = PSI.get_parameter(container, Lambda2Parameter, PSY.ThermalGen, gen_name)
    # B_param = PSI.get_parameter(container, BParameter, PSY.ThermalGen, gen_name)
    # D_param = PSI.get_parameter(container, DParameter, PSY.ThermalGen, gen_name)
    # PgNextNu_param = PSI.get_parameter(container, PgNextNuParameter, PSY.ThermalGen, gen_name)

    # And for contingency-indexed ones:
    # BSC_param = PSI.get_parameter(container, BSCParameter, PSY.ThermalGen, gen_name) # This would be 2D: (gen_name, contingency_idx)
    # Lambda1SC_param = PSI.get_parameter(container, Lambda1SCParameter, PSY.ThermalGen, gen_name) # This would be 2D: (gen_name, contingency_idx)

    # Given your current structure, let's assume they are directly accessible
    # from the `gen_interval_data` object, possibly implying they are globally shared
    # or that `gen_interval_data` is a specific instance per time step/generator.

    # We need to map `gen_name` to an index for these arrays if they are global.
    # For simplicity in this example, let's assume these `Array{Float64}` fields in `GenFirstBaseInterval`
    # are effectively treated as global arrays and are either 1D (indexed by contingency `i`) or have a single element
    # if not representing contingencies or multiple intervals. This is a simplification.

    # If `lambda_1`, `lambda_2`, `B`, `D`, `Pg_next_nu` are truly just `Array{Float64}` within `GenFirstBaseInterval`,
    # and not specifically indexed by generator or time directly through that array,
    # then the objective function expression needs careful handling.
    # Often, they are `vector[time_index]` or `vector[generator_index]`.

    # Let's adjust based on the current objective function form, assuming:
    # `lambda_1`, `lambda_2`, `B`, `D`, `Pg_next_nu` are single values (or effectively single for this generator/time)
    # `BSC`, `lambda_1SC` are arrays indexed by `i` from `1:cont_count`.

    # Let's assume for simplicity, `lambda_1`, `lambda_2`, `B`, `D`, `Pg_next_nu` are either global values (index 1)
    # or there's a mechanism outside this function to pick the correct value for this generator/time.
    # This is a common pattern for "representative" values in an ADMM-like setup.
    # For a multi-time-step problem, these would typically be indexed by `t`.
    # Let's assume `lambda_1[t_idx]`, `B[t_idx]`, etc. if they vary by time.
    # Since they are `Array{Float64}` and you are using `lambda_1*Pg` (scalar multiplication),
    # it implies `lambda_1` is also scalar for this specific term.

    # Let's re-evaluate the previous assumption: the objective has `lambda_1*Pg` where `lambda_1` is `Array{Float64}`.
    # This means you intend to use `lambda_1[some_index]`. What is `some_index`?
    # It could be `t` (time index), or a generator-specific index.

    # To make it work in PS.jl, these should probably be `PSI.ParameterType`s.
    # So, we'll need to define ParameterTypes for them and ensure they are added to the container.
    # This is a better approach for iteration.

    # For the sake of completing the objective function logic, I will assume
    # `lambda_1`, `lambda_2`, `B`, `D`, `Pg_next_nu` are indexed by the current time step `t`.
    # And `BSC`, `lambda_1SC` are indexed by `i` (contingency index).

    # To make this work, the `PSI.add_parameters!` functions in `src/parameters.jl`
    # would need to be defined for these array parameters, indexed appropriately.

    # Let's modify the objective function directly assuming parameters are available indexed by `(gen_name, t)`
    # for scalar parameters and `(gen_name, t, contingency_idx)` for contingency-indexed ones.

    # If Pg_next_nu, lambda_1, lambda_2, B, D are truly arrays that are NOT indexed by generator or time within the objective:
    # This means `gen_interval_data.lambda_1` is a global array, and you're implicitly taking an element.
    # Example: `lambda_1_val = gen_interval_data.lambda_1[time_step_idx]` or `gen_interval_data.lambda_1[some_other_idx]`.
    # For a robust solution, these should ideally be JuMP parameters if they vary.

    # For now, let's assume `gen_interval_data` is configured such that:
    # `Pg_next_nu` is scalar or `Pg_next_nu[t]`
    # `lambda_1` is scalar or `lambda_1[t]`
    # `lambda_2` is scalar or `lambda_2[t]`
    # `B` is scalar or `B[t]`
    # `D` is scalar or `D[t]`
    # `BSC` and `lambda_1_sc` are arrays, indexed by `i`.

    # A more robust handling of parameters is needed than just `gen_interval_data.lambda_1`.
    # The **best practice** for data that updates per iteration and needs to be part of the JuMP model
    # is to define it as a `PSI.ParameterType` and add it via `PSI.add_parameters!`.
    # This means `src/parameters.jl` would become more extensive.

    # Let's refine the objective function assuming the parameters from `gen_interval_data`
    # are correctly loaded into the JuMP model as `PSI.ParameterType`s, indexed by (generator name, time step).
    # And `BSC` and `lambda_1SC` would be indexed by (generator name, time step, contingency index).

    # Define the ParameterTypes for array parameters in src/parameters.jl
    # For instance:
    # struct Lambda1Parameter <: PSI.ParameterType end # This will be indexed by (gen_name, t)
    # struct Lambda2Parameter <: PSI.ParameterType end # (gen_name, t)
    # struct BParameter <: PSI.ParameterType end       # (gen_name, t)
    # struct DParameter <: PSI.ParameterType end       # (gen_name, t)
    # struct BSCParameter <: PSI.ParameterType end     # (gen_name, t, contingency_idx)
    # struct Lambda1SCParameter <: PSI.ParameterType end # (gen_name, t, contingency_idx)
    # struct PgNextNuParameter <: PSI.ParameterType end # (gen_name, t)

    # And then add them in `src/parameters.jl` for each generator:
    # function PSI.add_parameters!(container, ::Type{Lambda1Parameter}, ::LASCOPFGeneratorFormulation, device::PSY.ThermalGen, model::PSI.DecisionModel)
    #     gen_interval_data = get(model.internal.ext, "LASCOPF_GenIntervalData", nothing)
    #     time_steps = PSI.get_time_steps(container)
    #     PSI._add_param_container!(container, Lambda1Parameter, PSY.ThermalGen, axes=(PSI.get_name(device), time_steps))
    #     param_container = PSI.get_parameter_container(container, Lambda1Parameter, PSY.ThermalGen)
    #     for t in time_steps
    #         # This assumes gen_interval_data.lambda_1 is correctly indexed by some logic
    #         # or a global array where you pick the correct element.
    #         # Example: PSI.add_parameter!(param_container, gen_interval_data.lambda_1[t], PSI.get_name(device), t)
    #     end
    # end

    # Assuming these are all set up as JuMP parameters correctly in `src/parameters.jl`:
    lambda_1_param = PSI.get_parameter(container, Lambda1Parameter, PSY.ThermalGen, gen_name)
    lambda_2_param = PSI.get_parameter(container, Lambda2Parameter, PSY.ThermalGen, gen_name)
    B_param = PSI.get_parameter(container, BParameter, PSY.ThermalGen, gen_name)
    D_param = PSI.get_parameter(container, DParameter, PSY.ThermalGen, gen_name)
    BSC_param = PSI.get_parameter(container, BSCParameter, PSY.ThermalGen, gen_name)
    lambda_1SC_param = PSI.get_parameter(container, Lambda1SCParameter, PSY.ThermalGen, gen_name)
    Pg_next_nu_param = PSI.get_parameter(container, PgNextNuParameter, PSY.ThermalGen, gen_name)

    for t in time_steps
        # Original objective function components
        obj_expr_base = c2 * (Pg[gen_name, t]^2) + c1 * Pg[gen_name, t] + c0

        obj_expr_reg_admm = (beta / 2) * ( (Pg[gen_name, t] - Pg_nu_param[gen_name, t])^2 +
                                           (PgNext[gen_name, t] - Pg_next_nu_param[gen_name, t])^2 ) +
                            (beta_inner / 2) * (Pg[gen_name, t] - Pg_nuInner_param[gen_name, t])^2

        # Contingency terms (assuming BSC_param and lambda_1SC_param are 2D: (gen_name, t, contingency_idx))
        obj_expr_contingency = 0.0
        for i in 1:cont_count
            obj_expr_contingency += gamma_sc * (Pg[gen_name, t] * BSC_param[gen_name, t, i]) +
                                    (Pg[gen_name, t] * lambda_1SC_param[gen_name, t, i])
        end

        obj_expr_app = (gamma) * (Pg[gen_name, t] * B_param[gen_name, t] + PgNext[gen_name, t] * D_param[gen_name, t]) +
                       lambda_1_param[gen_name, t] * Pg[gen_name, t] +
                       lambda_2_param[gen_name, t] * PgNext[gen_name, t]

        obj_expr_admm_penalty = (rho / 2) * ( (Pg[gen_name, t] - Pg_N_init_param[gen_name, t] + Pg_N_avg_param[gen_name, t] + ug_N_param[gen_name, t])^2 +
                                            (thetag[gen_name, t] - Vg_N_avg_param[gen_name, t] - thetag_N_avg_param[gen_name, t] + vg_N_param[gen_name, t])^2 )

        total_obj_expr = obj_expr_base + obj_expr_reg_admm + obj_expr_contingency + obj_expr_app + obj_expr_admm_penalty

        PSI.add_to_objective_function!(container, total_obj_expr)
    end
end