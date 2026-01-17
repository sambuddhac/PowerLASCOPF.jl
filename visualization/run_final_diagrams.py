#!/usr/bin/env python3
"""Run final two system diagrams"""
import subprocess
import sys

scripts = [
    'diagram_time_series.py',
    'diagram_system_embedding.py'
]

print("Generating Final PowerLASCOPF System Diagrams...")
print("=" * 70)

for script in scripts:
    print(f"\nRunning {script}...")
    result = subprocess.run([sys.executable, script], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")

print("\n" + "=" * 70)
print("✓ Final diagrams generated!")
print("\nGenerated files (PDF + PNG):")
print("  12_time_series_embedding     - Time series for loads/renewables")
print("  13_system_embedding          - PSY.System → PowerLASCOPFSystem")
print("\n" + "=" * 70)
print("Complete diagram set:")
print("  01-05: Foundation layers (IS, PSY, costs, intervals, solvers)")
print("  06-11: Component details (thermal, renewable, hydro, node, load, line)")
print("  12-13: System integration (time series, system embedding)")