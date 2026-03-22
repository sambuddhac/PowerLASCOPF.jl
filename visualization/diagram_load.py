#!/usr/bin/env python3
"""ExtendedLoad diagram"""
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

fig, ax = plt.subplots(figsize=(18, 12))
ax.set_xlim(0, 18)
ax.set_ylim(0, 12)
ax.axis('off')

ax.text(9, 11.5, 'ExtendedLoad', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 11, 'Parameterized wrapper around PSY.PowerLoad',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.PowerLoad
psy_text = '''PSY.PowerLoad
═══════════════════════════════════
Component Properties:
  • name: String
  • available: Bool
  • bus: PSY.Bus
  
Demand Properties:
  • active_power: Float64 (MW)
  • reactive_power: Float64 (MVAr)
  • max_active_power: Float64
  • base_power: Float64
  
Load Type:
  • model: LoadModel
      - ConstantPower
      - ConstantCurrent
      - ConstantImpedance
  
Time Series:
  • time_series: IS.TimeSeriesContainer
      - hourly demand forecast'''

create_box(ax, 1, 5.5, 7, 5, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=9)

# ExtendedLoad
load_text = '''ExtendedLoad{T <: PSY.ElectricLoad}
═══════════════════════════════════════════════
Parameterized Fields:
  • load::T                     ← PSY.PowerLoad
  • interval_type::LoadIntervals ← ADMM/APP
  
Demand Response Capability:
  • curtailable::Bool
  • curtailment_limit::Float64 (max %)
  • curtailment_cost::Float64 ($/MWh)
      - Value of Lost Load (VOLL)
      - typically 1000-10000 $/MWh
  
Optimization Variables:
  • Pd_actual[t]::Float64
  • Pd_curtailed[t]::Float64
  • Pd_forecast[t]::Float64
  
Constraint:
  Pd_actual = Pd_forecast - Pd_curtailed
  0 ≤ Pd_curtailed ≤ limit × Pd_forecast
  
ADMM Coupling:
  P_injection = Σ Pg - Σ Pd_actual'''

create_box(ax, 10, 4, 7.5, 7, load_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=8.5, fw='bold')

create_arrow(ax, 8, 8, 10, 8,
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# Curtailment objective
curtail_text = '''Curtailment in Objective:
═══════════════════════════════════
Minimize:
  Σₜ curtailment_cost × Pd_curtailed[t]

Trade-off:
  • High cost → rarely curtail
  • Lower than gen → curtail before
      expensive generation
  • Typical VOLL: $1000-10000/MWh'''

create_box(ax, 10, 0.5, 7.5, 3, curtail_text,
          COLORS['component'], COLORS['component_border'], fs=8.5)

create_arrow(ax, 13.75, 4, 13.75, 3.5,
            label='objective', color=COLORS['component_border'], lw=2.5)

# Types
types_text = '''Load Categories:
────────────────────────────
1. Fixed (non-curtailable)
   • curtailable = false
   • Pd_actual = Pd_forecast
   
2. Curtailable
   • curtailable = true
   • Price-responsive
   
3. Flexible (advanced)
   • Time-shiftable'''

ax.text(4.5, 4, types_text, ha='center', va='top',
       fontsize=9, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFF3E0',
                edgecolor='#F57C00', linewidth=2))

# VOLL
voll_text = '''Value of Lost Load:
────────────────────────
Residential: $5-15k/MWh
Commercial: $10-50k/MWh  
Industrial: $1-5k/MWh
Critical: $50k+/MWh'''

ax.text(4.5, 1.5, voll_text, ha='center', va='top',
       fontsize=8, style='italic',
       bbox=dict(boxstyle='round,pad=0.4', facecolor='#E3F2FD',
                edgecolor='#1976D2', linewidth=1.5))

plt.tight_layout()
plt.savefig('10_load.pdf', dpi=300, bbox_inches='tight')
plt.savefig('10_load.png', dpi=300, bbox_inches='tight')
print("✓ Created 10_load")
plt.close()