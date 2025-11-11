#Entry point module for PowerLASCOPF.jl
module PowerLASCOPF

#=using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """=#

using PowerModels
using PowerSystems
using PowerSimulations
using PowerGraphics
using PowerAnalytics
using StorageSystemsSimulations
using Plots
using InfrastructureSystems
using PowerSystemCaseBuilder
using GenX
using CSV
using DataFrames
using TimeSeries
using Dates
using Statistics
using PowerNetworkMatrices
using MathOptInterface
using MathOptInterface.Utilities
import GenX
import LazyArtifacts
import PowerSystemCaseBuilder: SystemCategory
import PowerSystems as PSY # For System and components
import PowerSystems: get_variable, get_fixed, get_start_up, get_shut_down
import PowerSystems: set_variable!, set_fixed!, set_start_up!, set_shut_down!
#=
import PowerSimulations: PSI, OptimizationContainer, DecisionModel, build_model
import PowerModels
import PowerModels: solve_ac_opf, solve_dc_opf, solve_opf, @im_fields, nw_id_default #Need to work further
import InfrastructureSystems
import InfrastructureModels
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default=#
import JuMP
using Ipopt  # Added for LineSolver integration

# Define required types for PowerLASCOPF
abstract type AbstractModel end
abstract type IntervalType end
abstract type PowerFlowConstraint end
abstract type GenIntervals <: IntervalType end
abstract type LineIntervals <: IntervalType end
abstract type LoadIntervals <: IntervalType end
abstract type PowerLASCOPFComponent end
abstract type Subsystem <: PowerLASCOPFComponent end
abstract type Devices <: PowerLASCOPFComponent end
abstract type PowerGenerator <: Devices end
abstract type MockLineInterval <: LineIntervals end

# Type Alias From other Packages
const _GX = GenX
const _PMod = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const _PG = PowerGraphics
const _PA = PowerAnalytics
const _SSim = StorageSystemsSimulations
const _Plots = Plots
const IS = InfrastructureSystems
#const _IM = InfrastructureModels
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const MOPFM = MOI.FileFormats.Model
const PNM = PowerNetworkMatrices
const TS = TimeSeries
const _PSYCB = PowerSystemCaseBuilder

struct ERCOTSystem <: _PSYCB.SystemCategory end
struct IEEESystem <: _PSYCB.SystemCategory end

export AbstractModel, IntervalType, PowerFlowConstraint, GenIntervals
export LineIntervals, LoadIntervals, PowerLASCOPFComponent
export Subsystem, Devices, PowerGenerator, MockLineInterval

# ===== INCLUDE CORE MODULES =====
include("core/types.jl")
include("core/constants.jl")
include("core/settings.jl")
include("core/formulations.jl")
include("core/constraints.jl")
include("core/cost_utilities.jl")
include("core/optimizer_factory.jl")
include("core/ExtendedHydroGenerationCost.jl")
include("core/ExtendedRenewableGenerationCost.jl")
include("core/ExtendedStorageCost.jl")
include("core/ExtendedThermalGenerationCost.jl")
include("core/objective_functions.jl")
include("core/parameters.jl")
include("core/solver_model_types.jl")
include("core/variables.jl")

# ===== INCLUDE SOLVER MODULES =====
include("solvers/line_solvers/linesolver_base.jl")
include("solvers/line_solvers/linesolver_base_dual.jl")
include("solvers/generator_solvers/gensolver_first_base.jl")
include("solvers/interfaces/solver_interface.jl")

# ===== INCLUDE COMPONENT MODULES =====
# Note: Some components may have circular dependencies, include carefully
include("components/node.jl")
include("components/load.jl")
include("components/transmission_line.jl")
include("components/extended_hydro.jl")
#include("components/extended_thermal_generators.jl")
include("components/extended_storage.jl")
include("components/ExtendedThermalGenerator.jl")
include("components/ExtendedRenewableGenerator.jl")
include("components/ExtendedHydroGenerator.jl")
include("components/ExtendedStorageGenerator.jl")
include("components/GeneralizedGenerator.jl")
include("components/generator_integration.jl")
include("components/PowerLASCOPFTypes.jl")
include("components/renewable_generator.jl")
include("components/storage_generator.jl")
include("components/unified_generator_framework.jl")
include("components/load_timeseries_integration.jl")
# ===== INCLUDE EXTENSION MODULES =====
include("extensions/powersystems_integration.jl")
include("extensions/extended_system.jl")
include("components/network.jl")
include("components/supernetwork.jl")


# ===== INCLUDE UTILITY MODULES =====
include("utils/helpers.jl")
include("utils/validation.jl")
include("utils/conversion.jl")

# ===== INCLUDE I/O MODULES =====
include("io/readers/read_csv_inputs.jl")
include("io/readers/read_json_inputs.jl")
include("io/readers/read_inputs_and_parse.jl")
include("io/readers/make_lanl_ansi_pm_compatible.jl")
include("io/readers/make_nrel_sienna_compatible.jl")

# ===== POWERLAS COPF PSY.SYSTEM EXTENSION =====
# Export PSY functions for convenience
export System, get_name, get_base_power, add_component!

# Export GeneratorScenario functionality
export GeneratorScenario
export create_renewable_scenario, create_hydro_scenario, create_thermal_scenario
export create_scenarios_from_psy_timeseries
export update_scenario_at_time!, get_scenario_value_at_time

# Export PowerLASCOPF types and functions
export PowerLASCOPFComponent, Subsystem, Device, PowerGenerator
export Node, transmissionLine, ExtendedThermalGenerator
export PowerLASCOPFSystem, Network, SuperNetwork
export add_node!, add_transmission_line!, add_generator!
export convert_psy_system_to_power_lascopf!, validate_power_lascopf_system

# Export core types
export AbstractSolver, AbstractADMMComponent, AbstractAPPComponent
export IntervalType, GenIntervals, LineIntervals
export AbstractModel, AbstractCost, AbstractConstraints

# Export optimizer factory functionality
export AbstractOptimizerFactory, OptimizerFactory, FunctionOptimizerFactory
export create_optimizer, set_optimizer!
export ipopt_optimizer_factory, highs_optimizer_factory, gurobi_optimizer_factory
export build_lascopf_model

# Export constants
export DEFAULT_MAX_ITERATIONS, DEFAULT_TOLERANCE, DEFAULT_RHO
export DEFAULT_SOLVER_CHOICE, DEFAULT_CONTINGENCY_COUNT

# Export utility functions
export validate_component, validate_system_connectivity
export mw_to_pu, pu_to_mw, degrees_to_radians, radians_to_degrees


"""
    convert_psy_system_to_power_lascopf!(psy_system::PSY.System, power_lascopf_system::PowerLASCOPFSystem)

Convert components from a PSY.System to PowerLASCOPF components in the extended system.
This function provides the bridge between PowerSystems.jl and PowerLASCOPF.jl.
"""
function convert_psy_system_to_power_lascopf!(psy_system::PSY.System, 
                                             power_lascopf_system::PowerLASCOPFSystem)
    # Set system properties from PSY system
    power_lascopf_system.network_id = hash(PSY.get_name(psy_system)) % 1000
    power_lascopf_system.contingency_count = 3  # Default contingency scenarios
    
    println("🔄 Converting PSY.System to PowerLASCOPF system...")
    println("   - Source: $(PSY.get_name(psy_system))")
    println("   - Base Power: $(PSY.get_base_power(psy_system)) MVA")
    
    # Count components for summary
    bus_count = length(PSY.get_components(PSY.Bus, psy_system))
    line_count = length(PSY.get_components(PSY.Line, psy_system))
    gen_count = length(PSY.get_components(PSY.Generator, psy_system))
    
    println("   - PSY Components: $bus_count buses, $line_count lines, $gen_count generators")
    println("✅ Conversion framework ready - connect with specific PowerLASCOPF component types")
    
    return true
end

"""
    validate_power_lascopf_system(system::PowerLASCOPFSystem)

Validate the PowerLASCOPF system for consistency and completeness.
"""
function validate_power_lascopf_system(sys::PowerLASCOPFSystem)
    issues = String[]
    
    # Basic validation
    if isempty(sys.nodes) && isempty(sys.lines) && isempty(sys.generators)
        push!(issues, "System has no PowerLASCOPF components")
    end
    
    # Validate PSY system
    if PSY.get_base_power(sys.psy_system) <= 0
        push!(issues, "Invalid base power in PSY system")
    end
    
    return isempty(issues), issues
end

end # module
