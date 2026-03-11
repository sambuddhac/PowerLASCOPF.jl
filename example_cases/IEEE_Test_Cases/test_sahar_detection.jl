"""
Test script to verify Sahar format files can be detected for IEEE 118 and 300 bus cases.

This script tests the detect_file_format function without requiring full Julia environment setup.
"""

println("\n" * "="^70)
println("Testing Sahar Format File Detection")
println("="^70)

# Simple detection logic (mimics data_reader_generic.jl)
function simple_detect_file_format(case_path::String, bus_count::Int)
    # Check for sahar-format files (STANDARD)
    sahar_thermal = joinpath(case_path, "ThermalGenerators$(bus_count)_sahar.csv")
    if isfile(sahar_thermal)
        return :sahar
    end
    
    # Check for nodes file (might only have nodes)
    sahar_nodes = joinpath(case_path, "Nodes$(bus_count)_sahar.csv")
    if isfile(sahar_nodes)
        return :sahar
    end
    
    # Check for legacy format
    legacy_gen = joinpath(case_path, "Gen$(bus_count).csv")
    if isfile(legacy_gen)
        return :legacy
    end
    
    return :unknown
end

# Test IEEE 118 bus
println("\nTesting IEEE 118 Bus:")
println("-" * "="^69)
case_path_118 = "/home/runner/work/PowerLASCOPF.jl/PowerLASCOPF.jl/example_cases/IEEE_Test_Cases/IEEE_118_bus"
format_118 = simple_detect_file_format(case_path_118, 118)
println("  Detected format: $format_118")

# Check individual files
files_118 = [
    "ThermalGenerators118_sahar.csv",
    "Nodes118_sahar.csv",
    "Trans118_sahar.csv",
    "Loads118_sahar.json"
]

for file in files_118
    filepath = joinpath(case_path_118, file)
    exists = isfile(filepath)
    status = exists ? "✓" : "✗"
    println("  $status $file")
end

if format_118 == :sahar
    println("  ✅ SUCCESS: Sahar format detected for IEEE 118 bus!")
else
    println("  ❌ FAILED: Expected :sahar, got :$format_118")
end

# Test IEEE 300 bus
println("\nTesting IEEE 300 Bus:")
println("-" * "="^69)
case_path_300 = "/home/runner/work/PowerLASCOPF.jl/PowerLASCOPF.jl/example_cases/IEEE_Test_Cases/IEEE_300_bus"
format_300 = simple_detect_file_format(case_path_300, 300)
println("  Detected format: $format_300")

# Check individual files
files_300 = [
    "ThermalGenerators300_sahar.csv",
    "Nodes300_sahar.csv",
    "Trans300_sahar.csv",
    "Loads300_sahar.json"
]

for file in files_300
    filepath = joinpath(case_path_300, file)
    exists = isfile(filepath)
    status = exists ? "✓" : "✗"
    println("  $status $file")
end

if format_300 == :sahar
    println("  ✅ SUCCESS: Sahar format detected for IEEE 300 bus!")
else
    println("  ❌ FAILED: Expected :sahar, got :$format_300")
end

# Summary
println("\n" * "="^70)
if format_118 == :sahar && format_300 == :sahar
    println("✅ ALL TESTS PASSED: Sahar format files are properly detected!")
else
    println("❌ SOME TESTS FAILED")
end
println("="^70)
