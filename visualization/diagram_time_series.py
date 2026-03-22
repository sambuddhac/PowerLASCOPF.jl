#!/usr/bin/env python3
"""Time Series Embedding for Loads and Renewables"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle
import numpy as np

COLORS = {
    'is': '#E3F2FD', 'is_border': '#1976D2',
    'psy': '#FFEBEE', 'psy_border': '#D32F2F',
    'lascopf_core': '#E8F5E9', 'lascopf_border': '#388E3C',
    'timeseries': '#FFF3E0', 'timeseries_border': '#F57C00',
    'forecast': '#E1BEE7', 'forecast_border': '#7B1FA2'
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

fig, ax = plt.subplots(figsize=(20, 14))
ax.set_xlim(0, 20)
ax.set_ylim(0, 14)
ax.axis('off')

# Title
ax.text(10, 13.5, 'Time Series Embedding in PowerLASCOPF', 
       ha='center', fontsize=28, fontweight='bold', color=COLORS['lascopf_border'])
ax.text(10, 13, 'Load Forecasts, Renewable Generation, and Temporal Coupling',
       ha='center', fontsize=16, style='italic', color='#666')

# IS.TimeSeriesContainer
is_text = '''IS.TimeSeriesContainer
════════════════════════════════════
Storage Types:
  • SingleTimeSeries{T}
      - Deterministic forecast
      - data: TimeSeries.TimeArray
      
  • Scenarios{T}
      - Probabilistic (multiple scenarios)
      - scenarios: Vector{TimeArray}
      
  • Deterministic{T}
      - Look-ahead forecast
      - initial_timestamp: DateTime
      - resolution: Dates.Period
      - horizon: Int
      - count: Int (number of forecasts)
      
Metadata:
  • name: String
  • resolution: Dates.Period (e.g., Hour(1))
  • initial_timestamp: DateTime
  • interval: Dates.Period'''

create_box(ax, 0.5, 9, 6, 4, is_text,
          COLORS['is'], COLORS['is_border'], fs=8)

# Time series data illustration
t = np.linspace(0, 23, 24)
load_base = 100 + 40*np.sin((t-6)*np.pi/12)  # Daily load curve
wind_profile = 50 + 30*np.sin(t*np.pi/6) + 10*np.random.randn(24)
wind_profile = np.clip(wind_profile, 0, 80)

# Load time series plot
ax_load = plt.axes([0.05, 0.58, 0.25, 0.12])
ax_load.plot(t, load_base, 'b-', linewidth=2, label='Load Forecast')
ax_load.fill_between(t, load_base*0.95, load_base*1.05, alpha=0.3, color='blue')
ax_load.set_xlabel('Hour', fontsize=9)
ax_load.set_ylabel('MW', fontsize=9)
ax_load.set_title('Load Time Series (24h)', fontsize=10, fontweight='bold')
ax_load.grid(True, alpha=0.3)
ax_load.legend(fontsize=8)

# Wind time series plot
ax_wind = plt.axes([0.05, 0.42, 0.25, 0.12])
ax_wind.plot(t, wind_profile, 'g-', linewidth=2, label='Wind Available')
ax_wind.fill_between(t, wind_profile, alpha=0.3, color='green')
ax_wind.set_xlabel('Hour', fontsize=9)
ax_wind.set_ylabel('MW', fontsize=9)
ax_wind.set_title('Wind Forecast (Uncertain)', fontsize=10, fontweight='bold')
ax_wind.grid(True, alpha=0.3)
ax_wind.legend(fontsize=8)

# Back to main axes
plt.sca(ax)

# PSY Component with Time Series
psy_load_text = '''PSY.PowerLoad + Time Series
════════════════════════════════════
load = PowerLoad(
    name = "Load_1",
    bus = bus1,
    active_power = 100.0,  # base value
    ...
)

# Add time series forecast
ts_data = TimeArray(
    timestamps,
    load_forecast_MW
)

ts = SingleTimeSeries(
    name = "max_active_power",
    data = ts_data,
    resolution = Hour(1)
)

add_time_series!(sys, load, ts)

# Access in LASCOPF:
forecast = get_time_series_values(
    SingleTimeSeries,
    load,
    "max_active_power";
    start_time = t0,
    len = 24  # optimization horizon
)'''

create_box(ax, 7, 8, 6.5, 5, psy_load_text,
          COLORS['psy'], COLORS['psy_border'], fs=7.5)

create_arrow(ax, 6.5, 11, 7, 11,
            label='embeds', color=COLORS['is_border'], lw=2.5)

# Extended component with intervals
extended_text = '''ExtendedLoad with Time-Coupled Intervals
════════════════════════════════════════════════
For t = 1:T (optimization horizon)
    
    interval[t] = LoadIntervals(
        time_step = t,
        Pd_forecast = forecast[t],  ← from time series
        Pd_prev = forecast[t-1],
        ...
    )
    
    ext_load[t] = ExtendedLoad(
        load,
        interval[t],
        forecast_values[t]
    )

Time Coupling:
    • Pd[t] depends on forecast[t]
    • If curtailable:
        Pd_actual[t] ≤ forecast[t]
    • APP may couple across intervals
        via regularization terms'''

create_box(ax, 14, 8, 5.5, 5, extended_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=7.5, fw='bold')

create_arrow(ax, 13.5, 10.5, 14, 10.5,
            label='creates', color=COLORS['lascopf_border'], lw=2.5)

# Renewable time series
renewable_text = '''PSY.RenewableDispatch + Time Series
════════════════════════════════════════════
wind_gen = RenewableDispatch(
    name = "Wind_Farm_1",
    bus = bus2,
    rating = 100.0,
    tech = TechRenewable.WIND,
    ...
)

# Add hourly availability forecast
ts_wind = Deterministic(
    name = "max_active_power",
    data = wind_forecast_MW,
    resolution = Hour(1),
    horizon = 24,
    ...
)

add_time_series!(sys, wind_gen, ts_wind)

# With uncertainty (scenarios):
ts_scenarios = Scenarios(
    name = "max_active_power",
    resolution = Hour(1),
    scenario_count = 100,
    data = Dict(
        1 => scenario_1_data,
        2 => scenario_2_data,
        ...
    )
)'''

create_box(ax, 7, 2, 6.5, 5.5, renewable_text,
          COLORS['forecast'], COLORS['forecast_border'], fs=7.5)

# Extended renewable with curtailment
extended_renew_text = '''ExtendedRenewable with Curtailment
════════════════════════════════════════
For each t:
    available[t] = get_time_series_values(...)
    
    ext_renewable[t] = ExtendedRenewable(
        renewable_gen,
        interval[t],
        available[t]
    )
    
Decision Variables:
    • Pg[t]: Actual generation
    • Curtailed[t]: Foregone generation
    
Constraint:
    Pg[t] + Curtailed[t] = available[t]
    0 ≤ Pg[t] ≤ available[t]
    
Objective Penalty:
    curtailment_cost × Curtailed[t]'''

create_box(ax, 14, 2, 5.5, 5.5, extended_renew_text,
          COLORS['lascopf_core'], COLORS['lascopf_border'], fs=7.5, fw='bold')

create_arrow(ax, 13.5, 4.75, 14, 4.75,
            label='creates', color=COLORS['lascopf_border'], lw=2.5)

# Time horizon illustration
horizon_text = '''Optimization Horizon and Rolling Window
═══════════════════════════════════════════════════
Time Step Structure:
    t=0 (current)    t=1           t=2           t=3    ...    t=T
    │────────────────│─────────────│─────────────│──────────│
    ↑                ↑                                       ↑
    Known state      Optimize                                Horizon
    
For Look-Ahead SCOPF:
    • T = optimization horizon (e.g., 24 hours)
    • Forecast: available[1:T]
    • APP couples intervals: (β/2)||Pg[t] - Pg_nu[t+1]||²
    • Security constraints checked at each t
    
Rolling Window (online operation):
    1. Solve for t ∈ [t0, t0+T]
    2. Implement decision at t0
    3. Observe actual load/generation
    4. Roll forward: t0 ← t0+1
    5. Update forecasts and resolve'''

ax.text(10, 0.5, horizon_text, ha='center', va='bottom',
       fontsize=8.5, family='monospace',
       bbox=dict(boxstyle='round,pad=0.6', facecolor='#E8EAF6',
                edgecolor='#3F51B5', linewidth=2.5))

plt.tight_layout()
plt.savefig('12_time_series_embedding.pdf', dpi=300, bbox_inches='tight')
plt.savefig('12_time_series_embedding.png', dpi=300, bbox_inches='tight')
print("✓ Created 12_time_series_embedding")
plt.close()