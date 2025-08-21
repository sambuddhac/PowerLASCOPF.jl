abstract type AbstractLASCOPFTypes end
"""

LASCOPFOptions

	contSolverAccuracy::Bool #Enter the switch value to select between whether an extensive/exhaustive (and presumably more accurate) solver for contingency scenarios is desired, or just a simpler one is desired; 1 for former, 0 for latter
	solverChoice::Int64 #Enter the choice of the solver for SCOPF of each dispatch interval, 1 for GUROBI-APMP(ADMM/PMP+APP), 2 for CVXGEN-APMP(ADMM/PMP+APP), 3 for GUROBI APP Coarse Grained, 4 for centralized GUROBI SCOPF
	nextChoice::Bool #Enter the choice pertaining to whether you want to consider the ramping constraint to the next interval, for the last interval: 0 for not considering and 1 for considering
	setRhoTuning::Int64 #Enter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant).
	dummyIntervalChoice::Bool #Enter the choice pertaining to whether to include a dummy interval at the start or not (Inclusion of a dummy interval may speed up convergence and/or improve accuracy of solution). Enter 1 to include and 0 to not include
	RNDIntervals::Int64 #Enter the number of look-ahead dispatch intervals for restoring line flows to within normal long-term ratings.
	RSDIntervals::Int64 #Enter the number of furthermore look-ahead dispatch intervals for making the system secure w.r.t. next set of contingencies.

"""

mutable struct LASCOPFOptions <: AbstractLASCOPFTypes
	cont_solver_accuracy::Bool
	solver_choice::Int64
	next_choice::Bool
	set_rho_tuning::Int64
	dummy_interval_choice::Bool
	RND_intervals::Int64
	RSD_intervals::Int64

	function LASCOPFOptions()
		pl_options = new()

		pl_options.cont_solver_accuracy=false
		pl_options.solver_choice = 1
		pl_options.next_choice = true
		pl_options.set_rho_tuning = 3
		pl_options.dummy_interval_choice = true
		pl_options.RND_intervals = 3
		pl_options.RSD_intervals = 3

		return pl_options
	end
end
