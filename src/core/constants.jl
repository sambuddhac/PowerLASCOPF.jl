"""
Constants for PowerLASCOPF.jl

This module defines system-wide constants and default values
used throughout the PowerLASCOPF.jl package.
"""

# ===== ALGORITHM CONSTANTS =====

# Default ADMM/PMP algorithm parameters
const DEFAULT_MAX_ITERATIONS = 80002
const DEFAULT_TOLERANCE = 1e-6
const DEFAULT_RHO = 1.0
const DEFAULT_BETA = 10.0
const DEFAULT_GAMMA = 5.0

# Default line capacity (MW)
const DEFAULT_LINE_CAPACITY = 100.0

# Default divisor for power unit conversion
const DEFAULT_DIV_CONV_MWPU = 100.0  # Set to 100 for most systems, 1 for two-bus system

# ===== SOLVER CONSTANTS =====

# Solver choice constants
const SOLVER_GUROBI_APMP = 1        # GUROBI-APMP(ADMM/PMP+APP)
const SOLVER_CVXGEN_APMP = 2        # CVXGEN-APMP(ADMM/PMP+APP)
const SOLVER_GUROBI_APP = 3         # GUROBI APP Coarse Grained
const SOLVER_GUROBI_CENTRALIZED = 4 # Centralized GUROBI SCOPF
const SOLVER_IPOPT = 5              # IPOPT solver

# Default solver choice
const DEFAULT_SOLVER_CHOICE = SOLVER_IPOPT

# ===== SYSTEM CONSTANTS =====

# Default contingency scenarios
const DEFAULT_CONTINGENCY_COUNT = 3

# Default intervals for restoration and security
const DEFAULT_RND_INTERVALS = 3  # Look-ahead dispatch intervals for restoring line flows
const DEFAULT_RSD_INTERVALS = 3  # Look-ahead intervals for system security

# Default tuning modes
const RHO_TUNING_MODE_1 = 1  # Maintain Rho * primTol = dualTol
const RHO_TUNING_MODE_2 = 2  # primTol = dualTol
const RHO_TUNING_ADAPTIVE = 3  # Adaptive Rho (default)

const DEFAULT_RHO_TUNING_MODE = RHO_TUNING_ADAPTIVE

# ===== FILE PATH CONSTANTS =====

# Default output directories (configurable, not hardcoded)
const DEFAULT_OUTPUT_DIR = "output"
const DEFAULT_LOG_DIR = "logs"
const DEFAULT_DATA_DIR = "data"

# File extensions
const CSV_EXTENSION = ".csv"
const JSON_EXTENSION = ".json"
const TXT_EXTENSION = ".txt"

# ===== POWER SYSTEM CONSTANTS =====

# Default base power (MVA)
const DEFAULT_BASE_POWER = 100.0

# Default voltage levels
const DEFAULT_VOLTAGE_KV = 138.0

# Default frequency
const DEFAULT_FREQUENCY_HZ = 60.0

# Export all constants
export DEFAULT_MAX_ITERATIONS, DEFAULT_TOLERANCE, DEFAULT_RHO
export DEFAULT_BETA, DEFAULT_GAMMA, DEFAULT_LINE_CAPACITY
export DEFAULT_DIV_CONV_MWPU
export SOLVER_GUROBI_APMP, SOLVER_CVXGEN_APMP, SOLVER_GUROBI_APP
export SOLVER_GUROBI_CENTRALIZED, SOLVER_IPOPT, DEFAULT_SOLVER_CHOICE
export DEFAULT_CONTINGENCY_COUNT, DEFAULT_RND_INTERVALS, DEFAULT_RSD_INTERVALS
export RHO_TUNING_MODE_1, RHO_TUNING_MODE_2, RHO_TUNING_ADAPTIVE
export DEFAULT_RHO_TUNING_MODE
export DEFAULT_OUTPUT_DIR, DEFAULT_LOG_DIR, DEFAULT_DATA_DIR
export CSV_EXTENSION, JSON_EXTENSION, TXT_EXTENSION
export DEFAULT_BASE_POWER, DEFAULT_VOLTAGE_KV, DEFAULT_FREQUENCY_HZ