# Run all diagram scripts
import subprocess
import sys

scripts = [
    'diagram_1_foundation.py',
    'diagram_2_costs.py',
    'diagram_3_intervals.py',
    'diagram_4_extended.py',
    'diagram_5_solvers.py'
]

print("Generating PowerLASCOPF Layer Diagrams...")
print("=" * 60)

for script in scripts:
    print(f"\nRunning {script}...")
    result = subprocess.run([sys.executable, script], capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")

print("\n" + "=" * 60)
print("✓ All diagrams generated!")
print("\nGenerated PDFs:")
print("  01_foundation_layer.pdf")
print("  02_cost_types.pdf")
print("  03_intervals.pdf")
print("  04_extended_costs.pdf")
print("  05_solvers.pdf")
print("\nConvert to PNG/JPEG:")
print("  convert -density 300 *.pdf output.png")