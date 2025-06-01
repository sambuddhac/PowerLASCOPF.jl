# Defining Pg variable for formulation
function _PSim.add_variable!(
    container::_PSim.OptimizationContainer,
    ::Type{_PSim.ActivePowerVariable}, # This is the type of variable you're adding
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen # Assuming you're targeting PowerSystems ThermalGenerators
)
    # This function is called by PSI.jl when it's building the model
    # for a ThermalGen with your LASCOPFGeneratorFormulation.
    # You'll need to create the JuMP variable 'Pg' here.

    # Refer to PowerSimulations.jl's add_variable! implementations for examples.
    # You will likely call PSI._add_variable_container! and then create the JuMP variable.
    # The container will store the variable, and you'll access it later.

    _PSim._add_variable_container!(container, _PSim.ActivePowerVariable, PSY.ThermalGen) # This prepares storage for the variable
    # Then iterate over time steps and create the variable
    for t in _PSim.get_time_steps(container)
        var_name = _PSim.variable_name(PSI.ActivePowerVariable, PSY.ThermalGen, _PSim.get_name(device))
        container.variables[var_name][t] = JuMP.@variable(_PSim.get_jump_model(container), base_name="$(var_name)_$(t)")
        # You'll need to get PgMax/PgMin from the device here.
        # This is where your custom GenSolver data might come into play,
        # but typically device data comes from the PowerSystems model.
    end
end

# You'd do similar for PgNext and thetag
# Note: thetag for a generator might need a custom variable type,
# or you might tie it to the bus angle if that's what's meant.