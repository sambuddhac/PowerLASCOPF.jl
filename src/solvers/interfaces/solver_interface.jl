# PowerLASCOPF.jl/src/solver_interface.jl

function build_lascopf_model(sys::PSY.System, # The PowerSystems System object
                             solver_config::GenSolver, # Your custom solver configuration
                             optimizer_config::PSI.OptimizerFactory # e.g., HiGHS.Optimizer
                            )
    # Define your model options
    model_options = PSI.ModelOptions(
        # Set initial time, horizon, resolution etc.
        # You might need to set `allow_param_change = true` if your ADMM/APP parameters change per iteration
        # You might also want to add your solver_config to the `model_data` field for easy access in your methods
        ext = Dict{String, Any}("LASCOPF_SolverConfig" => solver_config)
    )

    # Define the devices and their formulations
    # This maps device types (from PowerSystems) to your custom formulations
    device_formulations = Dict{Symbol, PSI.AbstractDeviceFormulation}(
        :ThermalGenerators => LASCOPFGeneratorFormulation(), # Your custom formulation
        # ... other device types if needed, using standard PSI formulations
    )

    # Define the services (if any)
    service_formulations = Dict{Symbol, PSI.AbstractServiceFormulation}(
        # :MyLASCOPFService => LASCOPFServiceFormulation() # If you have a custom service
    )

    # Define the custom types for your problem (e.g., custom variables, parameters)
    # This tells PSI how to store and retrieve your specific ADMM/APP parameters.
    # This is critical for getting `Pg_nu`, `lambda_1`, `beta`, etc. into the model.
    custom_parameters = Dict{Symbol, DataType}()
    # Example: custom_parameters[:Pg_nu_param] = MyPgNuParameter # You define MyPgNuParameter <: PSI.ParameterType
    # You would then have to write functions to get these parameters from your `GenSolver`
    # and add them to the container via `PSI.add_param_container!`

    model = PSI.DecisionModel(
        LASCOPFGeneratorFormulation, # A dummy placeholder if you don't have a specific top-level formulation
        sys,
        model_options,
        device_formulations = device_formulations,
        service_formulations = service_formulations,
        # ... other arguments like network_formulation
    )

    # Build the JuMP model
    PSI.build_model!(model, optimizer_config)

    return model
end