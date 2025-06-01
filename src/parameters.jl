# PowerLASCOPF.jl/src/parameters.jl

# Define custom parameter types for each field in GenFirstBaseInterval that acts as a parameter
# These will be stored in the OptimizationContainer and updated between ADMM/APP iterations.

struct Lambda1Parameter <: PSI.ParameterType end
struct Lambda2Parameter <: PSI.ParameterType end
struct BParameter <: PSI.ParameterType end
struct DParameter <: PSI.ParameterType end
struct BSCParameter <: PSI.ParameterType end
struct ContCountParameter <: PSI.ParameterType end
struct RhoParameter <: PSI.ParameterType end
struct BetaParameter <: PSI.ParameterType end
struct BetaInnerParameter <: PSI.ParameterType end
struct GammaParameter <: PSI.ParameterType end
struct GammaSCParameter <: PSI.ParameterType end
struct Lambda1SCParameter <: PSI.ParameterType end
struct PgNInitParameter <: PSI.ParameterType end
struct PgNAvgParameter <: PSI.ParameterType end
struct ThetagNAvgParameter <: PSI.ParameterType end
struct UgNParameter <: PSI.ParameterType end
struct VgNParameter <: PSI.ParameterType end
struct VgNAvgParameter <: PSI.ParameterType end
struct PgNuParameter <: PSI.ParameterType end
struct PgNuInnerParameter <: PSI.ParameterType end
struct PgNextNuParameter <: PSI.ParameterType end
struct PgPrevParameter <: PSI.ParameterType end

# Method to add these parameters to the OptimizationContainer
# This will be called by PSI.jl when building the model.
# You need to decide how the `GenFirstBaseInterval` instance is passed.
# A common way is to pass it through the `ext` field of `ModelOptions` or `DecisionModel`.

function PSI.add_parameters!(
    container::PSI.OptimizationContainer,
    ::Type{Lambda1Parameter},
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen,
    model::PSI.DecisionModel # The model object contains the ext field
)
    # Retrieve your GenFirstBaseInterval instance from the model's extension data
    gen_interval_data = get(model.internal.ext, "LASCOPF_GenIntervalData", nothing)
    if isnothing(gen_interval_data)
        @error "GenFirstBaseInterval data not found in model extension."
        return
    end

    # Add the parameter container for this specific parameter type
    PSI._add_param_container!(container, Lambda1Parameter, PSY.ThermalGen, axes=(PSI.get_name(device),)) # Assuming lambda_1 is per-generator
    param_container = PSI.get_parameter_container(container, Lambda1Parameter, PSY.ThermalGen)

    # Set the initial value of the parameter
    # Assuming lambda_1 is an array, and you need to index it per generator.
    # This requires a mapping from device to index in lambda_1.
    # For simplicity, let's assume Pg_nu, Pg_prev, etc. are specific to *this* generator instance.
    # If lambda_1 is shared across generators, you'll need different indexing.
    # For now, let's assume Pg_nu, Pg_prev, etc. are unique to each generator.
    # And lambda_1, lambda_2, etc. are global or indexed by something else.
    # This is a critical design decision for your ADMM/APP algorithm.

    # For simplicity, let's assume scalar parameters for now if they are truly global.
    # If they are per-generator, you need to index them.
    # For array parameters like lambda_1_sc, BSC, you'll need to handle their dimensions.

    # Example for a scalar parameter (e.g., rho, beta):
    PSI.add_parameter!(param_container, gen_interval_data.rho, PSI.get_name(device)) # If rho is per-generator

    # Example for an array parameter (e.g., lambda_1_sc, BSC, which are indexed by contingency)
    # This needs to be indexed by (device_name, contingency_index)
    # You'll need to define axes for the parameter container.
    # PSI._add_param_container!(container, BSCParameter, PSY.ThermalGen, axes=(PSI.get_name(device), 1:gen_interval_data.cont_count))
    # for i in 1:gen_interval_data.cont_count
    #     PSI.add_parameter!(PSI.get_parameter_container(container, BSCParameter, PSY.ThermalGen), gen_interval_data.BSC[i], PSI.get_name(device), i)
    # end

    # This part requires careful design based on how your ADMM/APP parameters are structured:
    # Are lambda_1, lambda_2, B, D, BSC, lambda_1_sc global or indexed by generator?
    # If they are global, they might be added once to the container, not per device.
    # If they are per-generator, they need to be indexed by device name.
    # If they are indexed by contingency, they need to be indexed by contingency and device.

    # Let's assume for now that Pg_nu, Pg_prev, etc. are per-generator.
    # And the ADMM/APP tuning parameters (rho, beta, gamma) are global.
    # And lambda_1, lambda_2, B, D, lambda_1_sc, BSC are arrays that need to be indexed.

    # For scalar parameters that are unique to each generator, e.g., Pg_nu, Pg_nu_inner, Pg_prev, Pg_N_init, etc.
    PSI._add_param_container!(container, PgNuParameter, PSY.ThermalGen, axes=(PSI.get_name(device),))
    PSI.add_parameter!(PSI.get_parameter_container(container, PgNuParameter, PSY.ThermalGen), gen_interval_data.Pg_nu, PSI.get_name(device))

    PSI._add_param_container!(container, PgNuInnerParameter, PSY.ThermalGen, axes=(PSI.get_name(device),))
    PSI.add_parameter!(PSI.get_parameter_container(container, PgNuInnerParameter, PSY.ThermalGen), gen_interval_data.Pg_nu_inner, PSI.get_name(device))

    PSI._add_param_container!(container, PgPrevParameter, PSY.ThermalGen, axes=(PSI.get_name(device),))
    PSI.add_parameter!(PSI.get_parameter_container(container, PgPrevParameter, PSY.ThermalGen), gen_interval_data.Pg_prev, PSI.get_name(device))

    PSI._add_param_container!(container, PgNInitParameter, PSY.ThermalGen, axes=(PSI.get_name(device),))
    PSI.add_parameter!(PSI.get_parameter_container(container, PgNInitParameter, PSY.ThermalGen), gen_interval_data.Pg_N_init, PSI.get_name(device))

    # ... and so on for all other scalar parameters (Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg)
end

# You will need to define similar `add_parameters!` methods for all your custom ParameterTypes.
# For array parameters like lambda_1, lambda_2, B, D, BSC, lambda_1_sc, Pg_next_nu:
# These will likely be indexed by generator and potentially by contingency.
# This requires careful thought about how your GenFirstBaseInterval arrays are structured.

# Example for a global ADMM/APP tuning parameter (rho, beta, etc.) if they are truly global
# You would add these once, perhaps to a global parameter container or directly to the model's ext.
# Or, if they are parameters that update per iteration, they should be PSI.ParameterType.
# Let's assume rho, beta, beta_inner, gamma, gamma_sc are global parameters for now.
# They could be stored directly in `model.internal.ext` and accessed directly in objective/constraints.
# If they need to be JuMP parameters for warm-starting/updating, then they need a ParameterType.

# Let's assume for now that the ADMM/APP tuning parameters (rho, beta, etc.)
# are *not* JuMP parameters but are fixed values from `GenFirstBaseInterval`
# that get passed into the objective/constraints directly.
# The `Pg_nu`, `Pg_prev`, `Pg_N_init`, etc. are the ones that need to be JuMP parameters.
# And the array parameters (lambda_1, B, D, BSC, lambda_1_sc, Pg_next_nu) too.

# Let's refine the parameter handling:
# For array parameters like lambda_1, lambda_2, B, D, BSC, lambda_1_sc, Pg_next_nu:
# These are likely indexed by something (e.g., generator index, contingency index).
# You need to define how these map to the JuMP model.

# Example for Lambda1Parameter (assuming it's indexed by generator and time)
function PSI.add_parameters!(
    container::PSI.OptimizationContainer,
    ::Type{Lambda1Parameter},
    ::LASCOPFGeneratorFormulation,
    device::PSY.ThermalGen,
    model::PSI.DecisionModel
)
    gen_interval_data = get(model.internal.ext, "LASCOPF_GenIntervalData", nothing)
    if isnothing(gen_interval_data)
        @error "GenFirstBaseInterval data not found in model extension."
        return
    end
    # Assuming lambda_1 is indexed by generator and time step
    # You'll need a mapping from device name to its index in gen_interval_data.lambda_1
    # For simplicity, let's assume lambda_1 is a global array, and you need to index it by some global index.
    # Or, if it's per-generator, it should be stored in the device itself or passed differently.

    # For complex array parameters, it's often easier to define a custom parameter type
    # that holds the entire array, and then index it in the objective/constraints.
    # Or, if they are truly global, store them in the `ext` field of the container.

    # Let's assume for now that lambda_1, lambda_2, B, D, BSC, lambda_1_sc, Pg_next_nu
    # are global arrays that are accessed directly from `gen_interval_data` in the objective/constraints.
    # This means they are *not* JuMP parameters.
    # Only Pg_nu, Pg_nu_inner, Pg_prev, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg
    # will be JuMP parameters that update.

    # This simplifies things for now, but you'll need to decide if these need to be JuMP parameters
    # that can be updated during ADMM iterations. If so, you need to define ParameterTypes for them.
end