#!/usr/bin/env python3
"""ExtendedThermalGenerator diagram"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

COLORS = {
    'psy': '#FFEBEE', 'psy_border': '#D32F2F',
    'lascopf_core': '#E8F5E9', 'lascopf_border': '#388E3C',
    'interval': '#F3E5F5', 'interval_border': '#7B1FA2',
    'component': '#FFF9C4', 'component_border': '#F9A825'
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
        mid_x, mid_y = (x1+x2)/2, (y1+y2)/2
        ax.text(mid_x, mid_y, label, fontsize=9, fontweight='bold',
               bbox=dict(boxstyle='round,pad=0.4', facecolor='white', 
                        edgecolor=color, linewidth=2))

fig, ax = plt.subplots(figsize=(18, 14))
ax.set_xlim(0, 18)
ax.set_ylim(0, 14)
ax.axis('off')

# Title
ax.text(9, 13.5, 'ExtendedThermalGenerator', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 13, 'Parameterized wrapper around PSY.ThermalStandard',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.ThermalStandard
psy_text = '''PSY.ThermalStandard
═══════════════════════════════════
Component Properties:
  • name: String
  • available: Bool
  • bus: PSY.Bus
  • active_power: Float64
  • reactive_power: Float64
  
Physical Limits:
  • active_power_limits: (min, max)
  • reactive_power_limits: (min, max)
  • ramp_limits: (up, down)
  • time_limits: (up, down)
  
Economic Data:
  • operation_cost: ThermalGenerationCost
  • base_power: Float64'''

create_box(ax, 1, 8, 7, 4.5, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=9)

# ExtendedThermalGenerator
extended_text = '''ExtendedThermalGenerator{T <: PSY.ThermalStandard}
═══════════════════════════════════════════════════════
Parameterized Fields:
  • thermal_gen::T              ← PSY.ThermalStandard
  • interval_type::GenIntervals ← ADMM/APP parameters
  • extended_cost::ExtendedThermalGenerationCost
  
Additional Solver Context:
  • optimization_status::OptimizationStatus
  • primal_values::Dict{Symbol, Float64}
      - Pg_optimal
      - PgNext_optimal  
      - thetag_optimal
      - commitment_optimal (u, v, w)
  • dual_values::Dict{Symbol, Float64}
      - lambda_power_balance
      - lambda_angle_balance
  • solver_stats::SolverStatistics
      - iterations::Int
      - solve_time::Float64
      - objective_value::Float64'''

create_box(ax, 10, 7, 7.5, 6, extended_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=9, fw='bold')

create_arrow(ax, 8, 10.5, 10, 10.5, 
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# ExtendedThermalGenerationCost
cost_text = '''ExtendedThermalGenerationCost
═══════════════════════════════
- thermal_cost_core:
    ThermalGenerationCost
    (from PSY)
    
- regularization_term:
    GenFirstBaseInterval
    - ADMM: λ, ρ, Pg_N_avg
    - APP: β, γ, Pg_nu
    - Security: BSC, γ_sc'''

create_box(ax, 10.5, 3.5, 6.5, 3, cost_text,
          COLORS['component'], COLORS['component_border'], fs=8)

create_arrow(ax, 13.75, 7, 13.75, 6.5,
            label='embeds', color=COLORS['component_border'], lw=2.5)

# GenIntervals
interval_text = '''GenFirstBaseInterval
═══════════════════════
ADMM Parameters:
  • lambda_1, lambda_2
  • rho: Float64
  • Pg_N_avg, thetag_N_avg
  
APP Parameters:  
  • B, D: Array{Float64}
  • beta, gamma: Float64
  • Pg_nu, Pg_prev
  
Security Constraints:
  • BSC: Array{Float64}[N]
  • gamma_sc: Float64
  • cont_count: Int64'''

create_box(ax, 1, 0.5, 7, 3, interval_text,
          COLORS['interval'], COLORS['interval_border'], fs=8)

create_arrow(ax, 4.5, 3.5, 10.5, 7,
            label='embeds', color=COLORS['interval_border'], lw=2.5)

# Usage
usage_text = '''Usage Pattern:
──────────────────────────────────────────────
psy_gen = PSY.get_component(ThermalStandard, sys, "Alta")
interval = GenFirstBaseInterval(ρ=1.0, β=1.0, γ=1.0, ...)
ext_cost = ExtendedThermalGenerationCost(psy_gen.operation_cost, interval)
ext_gen = ExtendedThermalGenerator(psy_gen, interval, ext_cost)
solver = GenSolver(ext_gen)
optimize!(solver)'''

ax.text(9, 0.3, usage_text, ha='center', va='bottom',
       fontsize=10, family='monospace',
       bbox=dict(boxstyle='round,pad=0.6', facecolor='#E8EAF6', 
                edgecolor='#3F51B5', linewidth=2))

plt.tight_layout()
plt.savefig('06_extended_thermal_generator.pdf', dpi=300, bbox_inches='tight')
plt.savefig('06_extended_thermal_generator.png', dpi=300, bbox_inches='tight')
print("✓ Created 06_extended_thermal_generator")
plt.close()