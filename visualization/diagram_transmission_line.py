#!/usr/bin/env python3
"""ExtendedTransmissionLine diagram"""
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

ax.text(9, 13.5, 'ExtendedTransmissionLine', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 13, 'Parameterized wrapper around PSY.Line',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.Line
psy_text = '''PSY.Line / MonitoredLine
═══════════════════════════════════
Component Properties:
  • name: String
  • available: Bool
  • arc: Arc{PSY.Bus}
      - from::PSY.Bus
      - to::PSY.Bus
  
Electrical Parameters:
  • r: Float64 (resistance, p.u.)
  • x: Float64 (reactance, p.u.)
  • b: (from, to) shunt susceptance
  • rating: Float64 (MVA limit)
  • angle_limits: (min, max) rad
  
Power Flow Model:
  • DC: P_flow = B × (θ_from - θ_to)
      where B = -1/x
  • AC: P_flow = V × V ×
               [G cos(θ) + B sin(θ)]'''

create_box(ax, 1, 7.5, 7, 5, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=8.5)

# ExtendedTransmissionLine
line_text = '''ExtendedTransmissionLine{T <: PSY.Branch}
═══════════════════════════════════════════════════
Parameterized Fields:
  • line::T                      ← PSY.Line
  • interval_type::LineIntervals ← ADMM/APP
  
Power Flow Variables:
  • P_from[t]::Float64  ← power from "from" bus
  • P_to[t]::Float64    ← power to "to" bus
  • P_loss[t]::Float64  ← I²R losses
  • theta_diff[t]::Float64 ← θ_from - θ_to
  
Thermal Constraints:
  • |P_from[t]| ≤ rating
  • |P_to[t]| ≤ rating
  • Typical: -rating ≤ P_flow ≤ rating
  
Angle Stability:
  • angle_min ≤ θ_from - θ_to ≤ angle_max
  • Typical: -30° to 30°
  
N-1 Security:
  • contingency_status::Bool
      - true if OUT in scenario
      - false if IN (base case)'''

create_box(ax, 9.5, 5.5, 8, 7, line_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=8.5, fw='bold')

create_arrow(ax, 8, 10, 9.5, 10,
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# Power flow
flow_text = '''DC Power Flow:
═══════════════════════════════════
P_flow = -B × (θ_from - θ_to)
B = 1/x (susceptance)

Assumptions:
  • Small angle differences
  • V ≈ 1.0 p.u.
  • Ignore reactive power
  
Advantages:
  ✓ Convex (linear)
  ✓ Fast to solve
  ✓ Good for markets'''

create_box(ax, 1, 2.5, 7, 4.5, flow_text,
          COLORS['interval'], COLORS['interval_border'], fs=8.5)

# ADMM
admm_text = '''ADMM Decomposition:
══════════════════════════════════
Each line subproblem:

Minimize: (ρ/2)||P_flow - P_flow_avg||²
Subject to:
  • P_flow = B × θ_diff
  • |P_flow| ≤ rating
  • angle_min ≤ θ_diff ≤ angle_max
  
Dual variables:
  • λ_flow: consensus
  • λ_angle_from, λ_angle_to'''

create_box(ax, 9.5, 2, 8, 3, admm_text,
          COLORS['component'], COLORS['component_border'], fs=8.5)

create_arrow(ax, 13.5, 5.5, 13.5, 5,
            label='decomposes', color=COLORS['component_border'], lw=2.5)

# Contingency
contingency_text = '''N-1 Contingency:
────────────────────────────────
Base: All lines IN
For each line k:
  1. Set P_flow_k = 0 (OUT)
  2. Re-solve
  3. Check others: |P| ≤ rating
  
Security coupling: BSC'''

ax.text(4.5, 0.8, contingency_text, ha='center', va='top',
       fontsize=8.5, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFEBEE',
                edgecolor='#D32F2F', linewidth=2))

plt.tight_layout()
plt.savefig('11_transmission_line.pdf', dpi=300, bbox_inches='tight')
plt.savefig('11_transmission_line.png', dpi=300, bbox_inches='tight')
print("✓ Created 11_transmission_line")
plt.close()