#!/usr/bin/env python3
"""ExtendedHydroGenerator diagram"""
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
        ax.text((x1+x2)/2, (y1+y2)/2, label, fontsize=9, fontweight='bold',
               bbox=dict(boxstyle='round,pad=0.4', facecolor='white', 
                        edgecolor=color, linewidth=2))

fig, ax = plt.subplots(figsize=(18, 14))
ax.set_xlim(0, 18)
ax.set_ylim(0, 14)
ax.axis('off')

ax.text(9, 13.5, 'ExtendedHydroGenerator', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 13, 'Parameterized wrapper around PSY.HydroEnergyReservoir',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.HydroEnergyReservoir
psy_text = '''PSY.HydroEnergyReservoir
═══════════════════════════════════
Component Properties:
  • name: String
  • available: Bool
  • bus: PSY.Bus
  • rating: Float64
  
Hydraulic Properties:
  • storage_capacity: Float64
  • inflow: Float64
  • initial_storage: Float64
  • storage_target: Float64
  • conversion_factor: Float64
  
Operating Constraints:
  • active_power_limits: (min, max)
  • storage_level_limits: (min, max)
  
Economic Data:
  • operation_cost: HydroGenerationCost
      - variable cost (usually low)
      - water_value: Float64'''

create_box(ax, 1, 6.5, 7, 6, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=9)

# ExtendedHydroGenerator
extended_text = '''ExtendedHydroGenerator{T <: PSY.HydroGen}
═════════════════════════════════════════════════
Parameterized Fields:
  • hydro_gen::T                ← PSY.HydroEnergyReservoir
  • interval_type::GenIntervals ← ADMM/APP parameters
  • extended_cost::ExtendedHydroGenerationCost
  
Hydro-Specific State Variables:
  • storage_level::Dict{Int, Float64}
      - E[t] for each time step t
      - E[t+1] = E[t] + inflow[t] - discharge[t]
  • spill::Dict{Int, Float64}
      - excess water released
  • water_value_shadow::Float64
      - marginal value of stored water
  
Intertemporal Coupling:
  • storage_initial::Float64 (from t-1)
  • storage_target::Float64 (for t+T)
  • inflow_forecast::Vector{Float64}[T]
  
Optimization Results:
  • Pg[t]: Power generation
  • E[t]: Storage trajectory
  • spill[t]: Spillage decisions'''

create_box(ax, 10, 5.5, 7.5, 7, extended_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=8.5, fw='bold')

create_arrow(ax, 8, 9.5, 10, 9.5,
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# ExtendedHydroGenerationCost
cost_text = '''ExtendedHydroGenerationCost
═══════════════════════════════
- hydro_cost_core:
    HydroGenerationCost
    - variable: VariableCost (often 0)
    - water_value: Float64
    
- regularization_term:
    GenIntervals (ADMM/APP)
    
Objective Components:
  1. Variable cost: variable(Pg)
  2. Water value penalty:
     water_value × E[T]
  3. Spillage penalty
  4. ADMM regularization
  
Storage Dynamics:
  E[t+1] = E[t] + inflow[t]×Δt 
           - Pg[t]×Δt/efficiency
           - spill[t]×Δt'''

create_box(ax, 10.5, 1, 6.5, 4, cost_text,
          COLORS['component'], COLORS['component_border'], fs=8)

create_arrow(ax, 13.75, 5.5, 13.75, 5,
            label='embeds', color=COLORS['component_border'], lw=2.5)

# Key features
char_text = '''Hydro Unique Features:
──────────────────────────────────
✓ Intertemporal energy storage
✓ Storage state variable E[t]
✓ Water value optimization
✓ Inflow uncertainty
✓ Environmental constraints'''

ax.text(4.5, 5, char_text, ha='center', va='top',
       fontsize=10, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#E3F2FD',
                edgecolor='#1976D2', linewidth=2))

# Cascade note
cascade_text = '''Cascaded hydro systems:
Multiple ExtendedHydroGenerators
linked via inflow coupling'''

ax.text(4.5, 3, cascade_text, ha='center', va='top',
       fontsize=9, style='italic',
       bbox=dict(boxstyle='round,pad=0.4', facecolor='#FFF9C4',
                edgecolor='#F9A825', linewidth=1.5))

plt.tight_layout()
plt.savefig('08_extended_hydro_generator.pdf', dpi=300, bbox_inches='tight')
plt.savefig('08_extended_hydro_generator.png', dpi=300, bbox_inches='tight')
print("✓ Created 08_extended_hydro_generator")
plt.close()