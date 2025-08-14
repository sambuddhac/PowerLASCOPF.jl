#Sahar's working branch
#Sahar's branch modified by SamChakra
module PowerLASCOPF

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

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
import GenX
import PowerData
import LazyArtifacts
import PowerSystemCaseBuilder: SystemCategory
import PowerSystems as PSY # For System and components
import PowerSystems: get_variable, get_fixed, get_start_up, get_shut_down
import PowerSystems: set_variable!, set_fixed!, set_start_up!, set_shut_down!
import PowerSimulations: PSI, OptimizationContainer, DecisionModel, build_model
import PowerModels
import PowerModels: solve_ac_opf, solve_dc_opf, solve_opf, @im_fields, nw_id_default #Need to work further
import InfrastructureSystems
import InfrastructureModels
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default
import JuMP
using Ipopt  # Added for LineSolver integration

# Type Alias From other Packages
const _GX = GenX
const _PMod = PowerModels
const PSY = PowerSystems
const _PSim = PowerSimulations
const _PG = PowerGraphics
const _PA = PowerAnalytics
const _SSim = StorageSystemsSimulations
const _Plots = Plots
const _ISys = InfrastructureSystems
const _IM = InfrastructureModels
const MOI = MathOptInterface
const MOIU = MathOptInterface.Utilities
const MOPFM = MOI.FileFormats.Model
const PNM = PowerNetworkMatrices
const TS = TimeSeries
const _PSYCB = PowerSystemCaseBuilder

struct ERCOTSystem <: _PSYCB.SystemCategory end
struct IEEESystem <: _PSYCB.SystemCategory end

# ===== POWERLAS COPF PSY.SYSTEM EXTENSION =====
# Export PSY functions for convenience
export System, get_name, get_base_power, add_component!

# Export PowerLASCOPF types and functions
export PowerLASCOPFComponent, Subsystem, Device, PowerGenerator
export Node, transmissionLine, ExtendedThermalGenerator
export PowerLASCOPFSystem, Network, SuperNetwork
export add_node!, add_transmission_line!, add_generator!
export convert_psy_system_to_powerlas_copf!, validate_powerlas_copf_system

# Abstract type hierarchy for PowerLASCOPF components
"""
Abstract base type for all PowerLASCOPF components.
"""
abstract type PowerLASCOPFComponent end

"""
Abstract type for power system subsystems (e.g., nodes, areas).
"""
abstract type Subsystem <: PowerLASCOPFComponent end

"""
Abstract type for power system devices (e.g., lines, transformers).
"""
abstract type Device <: PowerLASCOPFComponent end

"""
Abstract type for power generators with optimization capabilities.
"""
abstract type PowerGenerator <: Device end

"""
    PowerLASCOPFSystem

Extended power system that wraps PSY.System and adds PowerLASCOPF-specific components.
Provides seamless integration between PowerSystems.jl and PowerLASCOPF.jl.
"""
mutable struct PowerLASCOPFSystem
    psy_system::PSY.System
    
    # PowerLASCOPF components
    nodes::Vector{Any}  # Will contain Node objects
    lines::Vector{Any}  # Will contain transmissionLine objects  
    generators::Vector{Any}  # Will contain ExtendedThermalGenerator objects
    
    # System properties
    network_id::Int
    contingency_count::Int
    interval_id::Int
    solver_choice::Int  # 1=IPOPT, 2=Gurobi, etc.
    
    # APMP algorithm parameters
    consensus_tolerance::Float64
    max_iterations::Int
    current_iteration::Int
    
    function PowerLASCOPFSystem(base_power::Float64; name::String = "PowerLASCOPF_System")
        psy_sys = PSY.System(base_power)
        PSY.set_name!(psy_sys, name)
        return new(psy_sys, Any[], Any[], Any[],
                  0, 0, 0, 1, 1e-6, 100, 0)
    end
    
    function PowerLASCOPFSystem(psy_system::PSY.System)
        return new(psy_system, Any[], Any[], Any[],
                  0, 0, 0, 1, 1e-6, 100, 0)
    end
end

# Forward PSY.System methods for seamless integration
PSY.get_name(sys::PowerLASCOPFSystem) = PSY.get_name(sys.psy_system)
PSY.get_base_power(sys::PowerLASCOPFSystem) = PSY.get_base_power(sys.psy_system)
PSY.set_name!(sys::PowerLASCOPFSystem, name::String) = PSY.set_name!(sys.psy_system, name)

"""
    convert_psy_system_to_powerlas_copf!(psy_system::PSY.System, powerlas_copf_system::PowerLASCOPFSystem)

Convert components from a PSY.System to PowerLASCOPF components in the extended system.
This function provides the bridge between PowerSystems.jl and PowerLASCOPF.jl.
"""
function convert_psy_system_to_powerlas_copf!(psy_system::PSY.System, 
                                             powerlas_copf_system::PowerLASCOPFSystem)
    # Set system properties from PSY system
    powerlas_copf_system.network_id = hash(PSY.get_name(psy_system)) % 1000
    powerlas_copf_system.contingency_count = 3  # Default contingency scenarios
    
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
    validate_powerlas_copf_system(system::PowerLASCOPFSystem)

Validate the PowerLASCOPF system for consistency and completeness.
"""
function validate_powerlas_copf_system(sys::PowerLASCOPFSystem)
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

#=
include("models/solver_models/gensolver_cont.jl")
include("models/solver_models/gensolver_first_base.jl")
include("models/solver_models/gensolver_first_cont.jl")
include("models/solver_models/gensolver_first_dz_cont.jl")
include("models/solver_models/gensolver_first_dz.jl")
include("models/solver_models/gensolver_first.jl")
include("models/solver_models/gensolver_second_base.jl")
include("models/solver_models/gensolver_second_cont.jl")
include("models/solver_models/linesolver_base.jl")
include("models/solver_models/sdp_opf_centralized.jl")
include("models/subsystems/generator.jl")
include("models/subsystems/load.jl")
include("models/subsystems/transmission_line.jl")
include("models/subsystems/node.jl")
include("models/subsystems/network.jl")
include("models/subsystems/supernetwork.jl")
include("models/run_sim_lascopf_temp_app.jl")=#
end
