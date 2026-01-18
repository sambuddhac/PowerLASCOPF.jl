#!/usr/bin/env python3
"""Node (Bus) diagram"""
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

ax.text(9, 13.5, 'Node (Bus)', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(9, 13, 'Parameterized wrapper around PSY.Bus',
       ha='center', fontsize=16, style='italic', color='#666')

# PSY.Bus
psy_text = '''PSY.Bus (ACBus)
═══════════════════════════════
Component Properties:
  • number: Int (bus ID)
  • name: String
  • bustype: BusType
      - REF (slack/reference)
      - PV (generator bus)
      - PQ (load bus)
  • angle: Float64 (radians)
  • magnitude: Float64 (p.u.)
  
Electrical Properties:
  • voltage_limits: (min, max) p.u.
  • base_voltage: Float64 (kV)
  • area: Area
  • zone: LoadZone'''

create_box(ax, 1, 8, 6.5, 4.5, psy_text, 
          COLORS['psy'], COLORS['psy_border'], fs=9)

# Node
node_text = '''Node{T <: PSY.Bus}
═══════════════════════════════════════════
Parameterized Fields:
  • bus::T                      ← PSY.Bus
  • interval_type::NodeIntervals ← ADMM/APP
  
Network State Variables:
  • theta::Float64              ← voltage angle
  • V::Float64                  ← voltage magnitude
  • P_injection::Float64        ← net active power
  • Q_injection::Float64        ← net reactive power
  
Connected Components:
  • generators::Vector{ExtendedGenerator}
  • loads::Vector{ExtendedLoad}
  • lines_from::Vector{ExtendedTransmissionLine}
  • lines_to::Vector{ExtendedTransmissionLine}
  
ADMM Consensus Variables:
  • theta_N_avg::Float64        ← network average
  • P_N_avg::Float64            ← network average
  • lambda_theta::Float64       ← dual variable
  • lambda_P::Float64           ← dual variable
  
Power Balance:
  P_injection = Σ Pg - Σ Pd + Σ P_flow'''

create_box(ax, 9, 6.5, 8.5, 6.5, node_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=9, fw='bold')

create_arrow(ax, 7.5, 10, 9, 10,
            label='parametrizes\non type T', 
            color=COLORS['lascopf_border'], style='--', lw=3)

# Power balance
balance_text = '''Power Balance (Kirchhoff):
═══════════════════════════════════════
At each node n, for all time t:

Σ Pg_i[t] - Σ Pd_j[t] = Σ P_flow_k[t]
i∈Gₙ        j∈Dₙ         k∈Lₙ

Where:
  Gₙ = generators at node n
  Dₙ = loads at node n  
  Lₙ = lines connected to node n
  
P_flow = B × θ (DC power flow)

ADMM decomposes:
  Each generator optimizes independently
  Network enforces consensus'''

create_box(ax, 1, 3, 7.5, 4.5, balance_text,
          COLORS['interval'], COLORS['interval_border'], fs=8.5)

# Role
role_text = '''Node Roles in ADMM:
─────────────────────────────
1. Collects Pg from generators
2. Collects Pd from loads
3. Calculates P_injection
4. Updates theta via power flow
5. Broadcasts theta_N_avg
6. Updates dual variables λ'''

create_box(ax, 10, 3, 7, 3, role_text,
          COLORS['component'], COLORS['component_border'], fs=9)

create_arrow(ax, 13.5, 6.5, 13.5, 6,
            label='coordinates', color=COLORS['component_border'], lw=2.5)

# Reference bus
ref_text = '''Reference Bus (Slack):
────────────────────────────────
- theta_ref = 0 (by definition)
- Supplies power imbalance
- Pg_slack = residual needed
- No optimization'''

ax.text(4.5, 1.5, ref_text, ha='center', va='top',
       fontsize=9, family='monospace',
       bbox=dict(boxstyle='round,pad=0.5', facecolor='#FFEBEE',
                edgecolor='#D32F2F', linewidth=2))

plt.tight_layout()
plt.savefig('09_node.pdf', dpi=300, bbox_inches='tight')
plt.savefig('09_node.png', dpi=300, bbox_inches='tight')
print("✓ Created 09_node")
plt.close()