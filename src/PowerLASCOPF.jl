module PowerLASCOPF
-PACKAGE

using DocStringExtensions

@template (FUNCTIONS, METHODS) = """
                                 $(TYPEDSIGNATURES)
                                 $(DOCSTRING)
                                 """

using PowerModels
using PowerSystems
using PowerSimulations
using InfrastructureSystems
using PowerSystemCaseBuilder
using GenX
import GenX
import PowerDatate
import LazyArtifacts
import PowerSystemCaseBuilder: SystemCategory
import PowerSystems
import PowerSimulations
import PowerModels
import PowerModels: solve_ac_opf, solve_dc_opf, solve_opf, @im_fields, nw_id_default #Need to work further
import InfrastructureSystems
import InfrastructureModels
import InfrastructureModels: optimize_model!, @im_fields, nw_id_default


# Type Alias From other Packages
const _GX = GenX
const _PMod = PowerModels
const _PSys = PowerSystems
const _PSim = PowerSimulations
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
