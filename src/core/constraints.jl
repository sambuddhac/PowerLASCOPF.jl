# PowerLASCOPF.jl/src/constraints.jl
function PSI.add_constraints!(
    container::PSI.OptimizationContainer,
    ::Type{<:PSI.PowerFlowConstraint}, # Or a new custom constraint type like PSI.LASCOPFPowerConstraint
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen,
    model::PSI.DecisionModel # Pass the DecisionModel to access parameters/data
)
    # Access your variables from the container
    pg_var = PSI.get_variable(container, PSI.ActivePowerVariable, PSY.ThermalGen, PSI.get_name(device))
    # You'll need to get PgMax, PgMin, RgMax, RgMin from the device struct or its internal components.
    # This is where you'd link to the PowerSystems.ThermalGen parameters.

    # Access your custom GenSolver data: This is tricky.
    # How does your GenSolver struct get passed into this context?
    # Option 1: It's part of your custom `LASCOPFGeneratorFormulation` (less common for a solver parameter)
    # Option 2: It's a `Parameter` added to the OptimizationContainer (more common for dynamic data)
    # Option 3: It's stored in the `aux_variables` or `parameters` field of the device in PowerSystems (if you extended PowerSystems structs)
    # Option 4: You pass your GenSolver instance through the `model_data` field of the PSI.DecisionModel.

    # Let's assume for now PgMax, PgMin, etc. come directly from the PSY.ThermalGen
    PgMax = PSY.get_max_active_power(device) # Example of getting data from PSY device
    PgMin = PSY.get_min_active_power(device)
    RgMax = PSY.get_ramplimit_up(device) # Example
    RgMin = PSY.get_ramplimit_down(device) # Example

    # You'll likely need to create a `constraint_container` for each constraint type
    PSI._add_cons_container!(container, PSI.ActivePowerLimitConstraint, PSY.ThermalGen, axes = (PSI.get_name(device), PSI.get_time_steps(container)))
    con_limit = PSI.get_constraint(container, PSI.ActivePowerLimitConstraint, PSY.ThermalGen)

    for t in PSI.get_time_steps(container)
        JuMP.@constraint(PSI.get_jump_model(container), con_limit[PSI.get_name(device), t], pg_var[t] <= PgMax)
        JuMP.@constraint(PSI.get_jump_model(container), con_limit[PSI.get_name(device), t], pg_var[t] >= PgMin)

        # For ramp rates, you'd need the Pg_prev variable, which needs to be handled
        # either as another variable from the previous time step/interval, or a parameter.
        # This is where your custom interval logic comes in.
        # This will require custom logic to get Pg_prev from the previous interval/iteration.
        # You might need to add a custom parameter or auxiliary variable to the container for this.
    end
end