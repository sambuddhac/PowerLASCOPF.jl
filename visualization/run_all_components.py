#!/usr/bin/env python3
"""Run all component diagram scripts"""
import subprocess
import sys

scripts = [
    'diagram_thermal_generator.py',
    'diagram_renewable_generator.py',
    'diagram_hydro_generator.py',
    'diagram_node.py',
    'diagram_load.py',
    'diagram_transmission_line.py'
]

print("Generating PowerLASCOPF Component Diagrams...")
print("=" * 70)

for script in scripts:
    print(f"\nRunning {script}...")
    result = subprocess.run([sys.executable, script], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")

print("\n" + "=" * 70)
print("✓ All component diagrams generated!")
print("\nGenerated files (PDF + PNG):")
print("  06_extended_thermal_generator")
print("  07_extended_renewable_generator")
print("  08_extended_hydro_generator")
print("  09_node")
print("  10_load")
print("  11_transmission_line")