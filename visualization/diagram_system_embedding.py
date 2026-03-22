#!/usr/bin/env python3
"""PSY.System → PowerLASCOPFSystem Embedding"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle

COLORS = {
    'is': '#E3F2FD', 'is_border': '#1976D2',
    'psy': '#FFEBEE', 'psy_border': '#D32F2F',
    'lascopf': '#E8F5E9', 'lascopf_border': '#388E3C',
    'algorithm': '#FFF9C4', 'algorithm_border': '#F9A825',
    'solver': '#F3E5F5', 'solver_border': '#7B1FA2'
}

def create_box(ax, x, y, w, h, text, fc, ec, fs=10, fw='normal'):
    box = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.15",
                         facecolor=fc, edgecolor=ec, linewidth=3)
    ax.add_patch(box)
    ax.text(x+w/2, y+h/2, text, ha='center', va='center',
           fontsize=fs, family='monospace', fontweight=fw)

def create_arrow(ax, x1, y1, x2, y2, label='', color='black', style='-', lw=2.5):
    arrow = FancyArrowPatch((x1,y1), (x2,y2),
                           arrowstyle='->,head_width=0.5,head_length=0.9',
                           color=color, linewidth=lw, linestyle=style)
    ax.add_patch(arrow)
    if label:
        ax.text((x1+x2)/2, (y1+y2)/2, label, fontsize=9, fontweight='bold',
               bbox=dict(boxstyle='round,pad=0.4', facecolor='white', 
                        edgecolor=color, linewidth=2))

fig, ax = plt.subplots(figsize=(20, 16))
ax.set_xlim(0, 20)
ax.set_ylim(0, 16)
ax.axis('off')

# Title
ax.text(10, 15.5, 'PSY.System → PowerLASCOPFSystem Embedding', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(10, 15, 'Complete system transformation for ADMM/APP optimization',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.System
psy_system_text = '''PSY.System (PowerSystems.jl)
═══════════════════════════════════════════════
System Components:
  • buses::Vector{Bus}
      - ACBus, DCBus
  • generators::Vector{Generator}
      - ThermalStandard
      - RenewableDispatch
      - HydroEnergyReservoir
      - GenericBattery
  • branches::Vector{Branch}
      - Line, MonitoredLine
      - Transformer, TapTransformer
  • loads::Vector{Load}
      - PowerLoad, StandardLoad
      
System Metadata:
  • base_power: Float64 (MVA)
  • frequency: Float64 (Hz, typically 60)
  • name: String
  • description: String
  
Time Series Container:
  • time_series_container:
      IS.TimeSeriesContainer
      - Stores all forecasts
      - Links to components via UUID
      
Network Topology:
  • Automatically computed from components
  • Bus adjacency matrix
  • Incidence matrices'''

create_box(ax, 0.5, 10, 7.5, 4.5, psy_system_text,
          COLORS['psy'], COLORS['psy_border'], fs=8)

# PowerLASCOPFSystem
lascopf_system_text = '''PowerLASCOPFSystem{T <: PSY.System}
═══════════════════════════════════════════════════════
Core Fields:
  • base_system::T              ← PSY.System (wrapped)
  • extended_components::Dict   ← Extended wrappers
      - generators: Dict{UUID, ExtendedGenerator}
      - loads: Dict{UUID, ExtendedLoad}
      - buses: Dict{UUID, Node}
      - branches: Dict{UUID, ExtendedTransmissionLine}
  
Algorithm Configuration:
  • optimization_settings::OptimizationSettings
      - horizon: Int (time steps, e.g., 24)
      - resolution: Dates.Period (e.g., Hour(1))
      - num_scenarios: Int (contingencies)
  • admm_settings::ADMMSettings
      - rho: Float64 (penalty parameter)
      - rho_update_scheme: Symbol (:fixed, :adaptive)
      - max_iterations: Int
      - tolerance: Float64
  • app_settings::APPSettings
      - beta: Float64 (time coupling)
      - gamma: Float64 (time coupling)
      - gamma_sc: Float64 (security coupling)
  
Interval Management:
  • intervals::Vector{TimeInterval}
      - interval[t] for t = 1:horizon
      - Contains GenIntervals, NodeIntervals, etc.
  
Solver Infrastructure:
  • gen_solvers::Dict{UUID, GenSolver}
  • line_solvers::Dict{UUID, LineSolver}
  • load_solvers::Dict{UUID, LoadSolver}
  • network_coordinator::NetworkCoordinator'''

create_box(ax, 8.5, 8.5, 11, 6, lascopf_system_text,
          COLORS['lascopf'], COLORS['lascopf_border'], fs=8, fw='bold')

create_arrow(ax, 8, 12.5, 8.5, 12.5,
            label='wraps & extends', 
            color=COLORS['lascopf_border'], style='--', lw=3.5)

# Construction process
construction_text = '''PowerLASCOPFSystem Construction
═══════════════════════════════════════════════════════
# Step 1: Load PSY.System
psy_sys = PSY.System("case5bus.json")

# Step 2: Configure ADMM/APP
admm_config = ADMMSettings(
    rho = 1.0,
    max_iterations = 100,
    tolerance = 1e-4
)

app_config = APPSettings(
    beta = 1.0,
    gamma = 1.0,
    gamma_sc = 1.0
)

opt_config = OptimizationSettings(
    horizon = 24,
    resolution = Hour(1),
    num_scenarios = 10  # N-1 contingencies
)

# Step 3: Build PowerLASCOPFSystem
lascopf_sys = PowerLASCOPFSystem(
    psy_sys,
    admm_config,
    app_config,
    opt_config
)

# This internally:
#   1. Wraps each PSY component
#   2. Creates interval structures
#   3. Builds extended components
#   4. Initializes solvers
#   5. Sets up network coordinator'''

create_box(ax, 0.5, 5, 9, 4.5, construction_text,
          COLORS['algorithm'], COLORS['algorithm_border'], fs=7.5)

# Component transformation
transform_text = '''Component Transformation Process
═══════════════════════════════════════════════
For each PSY component:

1. ThermalStandard → ExtendedThermalGenerator
   • Wrap PSY generator
   • Create GenFirstBaseInterval (t=1)
   • Create GenMiddleBaseInterval (t=2..T-1)
   • Create GenLastBaseInterval (t=T)
   • Build ExtendedThermalGenerationCost
   • Initialize GenSolver with JuMP model

2. RenewableDispatch → ExtendedRenewableGenerator
   • Extract time series forecast
   • Create curtailment variables
   • Build penalty terms

3. Bus → Node
   • Collect connected components
   • Initialize consensus variables
   • Set up power balance

4. Line → ExtendedTransmissionLine
   • Create flow variables
   • Set thermal limits
   • Initialize contingency status

Result: Complete ADMM/APP-ready system!'''

create_box(ax, 10, 5, 9.5, 4.5, transform_text,
          COLORS['solver'], COLORS['solver_border'], fs=7.5)

create_arrow(ax, 5, 6.5, 10, 6.5,
            label='transforms', color=COLORS['solver_border'], lw=2.5)

# Data flow diagram
flow_text = '''Solving Process Data Flow
═══════════════════════════════════════════════════════════════════
1. Initialize:
   lascopf_sys = PowerLASCOPFSystem(psy_sys, ...)
   
2. For each ADMM iteration k:
   a. Solve generator subproblems (parallel):
      for gen in lascopf_sys.gen_solvers
          solve_generator_subproblem!(gen, intervals[t])
      end
      
   b. Solve line subproblems (parallel):
      for line in lascopf_sys.line_solvers
          solve_line_subproblem!(line, intervals[t])
      end
      
   c. Update network consensus:
      update_network_consensus!(network_coordinator)
      # Compute Pg_N_avg, theta_N_avg
      
   d. Update dual variables:
      update_dual_variables!(intervals, rho)
      # lambda ← lambda + rho*(Pg - Pg_N_avg)
      
   e. Check convergence:
      primal_residual = ||Pg - Pg_N_avg||
      dual_residual = ||lambda_new - lambda_old||
      if both < tolerance: break
      
3. For APP time coupling:
   a. Update Pg_nu between intervals
   b. Couple via (beta/2)||Pg[t] - Pg_nu[t+1]||²
   
4. For security (N-1-1):
   a. For each contingency scenario s:
      solve_with_contingency!(lascopf_sys, scenario_s)
   b. Couple via BSC: (gamma_sc/2)||Pg_base - Pg_cont||²
   
5. Extract results:
   results = extract_results(lascopf_sys)
   # Pg[t] for all generators, all t
   # theta[t] for all buses, all t
   # P_flow[t] for all lines, all t
   # Objective value, convergence stats'''

ax.text(10, 2.5, flow_text, ha='center', va='top',
       fontsize=7.5, family='monospace',
       bbox=dict(boxstyle='round,pad=0.6', facecolor='#E3F2FD',
                edgecolor='#1976D2', linewidth=3))

# Key differences box
diff_text = '''Key Extensions from PSY.System:
────────────────────────────────────────────
✓ ADMM/APP algorithm parameters embedded
✓ Interval structures for time coupling
✓ Extended cost models with regularization
✓ Solver infrastructure (JuMP models)
✓ Network coordinator for consensus
✓ Security scenario management
✓ Primal/dual variable storage
✓ Convergence tracking'''

ax.text(5, 9, diff_text, ha='center', va='top',
       fontsize=9, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF3E0',
                edgecolor='#F57C00', linewidth=2.5))

# Access pattern
access_text = '''Accessing Original PSY Components:
──────────────────────────────────────────
# Get wrapped PSY.System
psy_sys = lascopf_sys.base_system

# Get specific component
gen = PSY.get_component(ThermalStandard, psy_sys, "Alta")

# Get extended wrapper
ext_gen = lascopf_sys.extended_components["generators"][PSY.get_uuid(gen)]

# Access both:
psy_rating = PSY.get_rating(gen)  # From PSY
admm_rho = ext_gen.interval_type.rho  # From LASCOPF'''

ax.text(15, 9, access_text, ha='center', va='top',
       fontsize=8, family='monospace', style='italic',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#F3E5F5',
                edgecolor='#7B1FA2', linewidth=2))

plt.tight_layout()
plt.savefig('13_system_embedding.pdf', dpi=300, bbox_inches='tight')
plt.savefig('13_system_embedding.png', dpi=300, bbox_inches='tight')
print("✓ Created 13_system_embedding")
plt.close()