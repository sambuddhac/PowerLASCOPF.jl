#!/usr/bin/env python3
"""ExtendedRenewableGenerator diagram"""
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

ax.text(9, 13.5, 'ExtendedRenewableGenerator', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 13, 'Parameterized wrapper around PSY.RenewableDispatch',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.RenewableDispatch
psy_text = '''PSY.RenewableDispatch
═══════════════════════════════════
Component Properties:
  • name: String
  • available: Bool  
  • bus: PSY.Bus
  • rating: Float64
  • power_factor: Float64
  
Renewable Specific:
  • max_active_power: Float64
  • tech: TechRenewable
      (WIND, SOLAR, etc.)
  
Forecast/Time Series:
  • time_series_container:
      IS.TimeSeriesContainer
  
Economic Data:
  • operation_cost: RenewableGenerationCost
      - variable cost
      - curtailment_cost: Float64'''

create_box(ax, 1, 7, 7, 5.5, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=9)

# ExtendedRenewableGenerator
extended_text = '''ExtendedRenewableGenerator{T <: PSY.RenewableGen}
════════════════════════════════════════════════════
Parameterized Fields:
  • renewable_gen::T            ← PSY.RenewableDispatch
  • interval_type::GenIntervals ← ADMM/APP parameters
  • extended_cost::ExtendedRenewableGenerationCost
  
Renewable-Specific Context:
  • forecast_values::Vector{Float64}
      - available_capacity[t] for each time step
  • curtailment_penalty::Float64
  • must_run::Bool
  
Optimization Results:
  • primal_values::Dict
      - Pg_optimal (actual output)
      - Pg_available (forecast)
      - Pg_curtailed (= available - optimal)
      - PgNext_optimal
  • dual_values::Dict
      - lambda_curtailment'''

create_box(ax, 10, 6.5, 7.5, 6, extended_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=9, fw='bold')

create_arrow(ax, 8, 10, 10, 10,
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# ExtendedRenewableGenerationCost
cost_text = '''ExtendedRenewableGenerationCost
═══════════════════════════════════
- renewable_cost_core:
    RenewableGenerationCost
    - variable: VariableCost
    - curtailment_cost: Float64
    
- regularization_term:
    GenIntervals
    
Objective Terms:
  1. Generation: variable(Pg)
  2. Curtailment penalty:
     curtailment_cost × (Pg_avail - Pg)
  3. ADMM: (ρ/2)||Pg - Pg_N_avg||²
  4. APP time coupling'''

create_box(ax, 10.5, 2.5, 6.5, 3.5, cost_text,
          COLORS['component'], COLORS['component_border'], fs=8)

create_arrow(ax, 13.75, 6.5, 13.75, 6,
            label='embeds', color=COLORS['component_border'], lw=2.5)

# Key differences
diff_text = '''Key Differences from Thermal:
────────────────────────────────────
✓ Availability varies by time (forecast)
✓ Curtailment decision variable
✓ No startup/shutdown costs
✓ No ramping constraints
✓ Often must-run (VER contracts)'''

ax.text(4.5, 5.5, diff_text, ha='center', va='top',
       fontsize=10, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF3E0',
                edgecolor='#F57C00', linewidth=2))

# Time series
interval_text = '''GenIntervals + Time Series
═══════════════════════════════
For each time step t:
  • Pg_available[t] from forecast
  • Pg[t] ≤ Pg_available[t]
  • Curtailment = Pg_available[t] - Pg[t]
  
APP couples across time:
  • PgNext connects intervals'''

create_box(ax, 1, 0.5, 7, 2, interval_text,
          COLORS['interval'], COLORS['interval_border'], fs=8)

create_arrow(ax, 4.5, 2.5, 10.5, 6.5,
            label='embeds', color=COLORS['interval_border'], lw=2.5)

plt.tight_layout()
plt.savefig('07_extended_renewable_generator.pdf', dpi=300, bbox_inches='tight')
plt.savefig('07_extended_renewable_generator.png', dpi=300, bbox_inches='tight')
print("✓ Created 07_extended_renewable_generator")
plt.close()