"""
Example: Reading Power System Data from CSV Files

This example demonstrates how to use the PowerLASCOPF CSV readers to load
power system data from various CSV formats.

The readers support:
1. RTS-GMLC format (standard PowerSystems format)
2. csv_118 custom format
3. Other CSV formats with appropriate configuration
"""

using PowerLASCOPF
using PowerSystems
const PSY = PowerSystems

# Example 1: Reading RTS-GMLC format data
function example_rts_gmlc()
    println("\n" * "="^80)
    println("Example 1: Reading RTS-GMLC Format")
    println("="^80)

    data_dir = joinpath(@__DIR__, "..", "example_cases", "RTS_GMLC")

    if !isdir(data_dir)
        @warn "RTS_GMLC directory not found at $data_dir"
        return nothing
    end

    # Create a custom configuration if needed
    config = CSVReaderConfig(
        base_power = 100.0,
        default_voltage_limits = (0.95, 1.05),
        default_ramp_rate = 0.02
    )

    # Read the system
    println("\nReading system from: $data_dir")
    system = read_csv_system(data_dir, config=config)

    # Display system information
    println("\nSystem Information:")
    println("  Name: $(system.name)")
    println("  Base Power: $(system.base_power) MVA")
    println("  Number of Buses: $(length(PSY.get_components(PSY.Bus, system)))")
    println("  Number of Branches: $(length(PSY.get_components(PSY.Branch, system)))")
    println("  Number of Generators: $(length(PSY.get_components(PSY.ThermalStandard, system)))")
    println("  Number of Loads: $(length(PSY.get_components(PSY.PowerLoad, system)))")

    # Show some sample buses
    println("\nSample Buses:")
    for (i, bus) in enumerate(PSY.get_components(PSY.Bus, system))
        if i > 5
            break
        end
        println("  $(bus.name): $(bus.bustype), $(bus.base_voltage) kV")
    end

    # Show some sample generators
    println("\nSample Generators:")
    for (i, gen) in enumerate(PSY.get_components(PSY.ThermalStandard, system))
        if i > 5
            break
        end
        pmax = gen.active_power_limits.max * system.base_power
        println("  $(gen.name): $(gen.fuel), Pmax = $(round(pmax, digits=2)) MW")
    end

    return system
end

# Example 2: Reading csv_118 format data
function example_csv118()
    println("\n" * "="^80)
    println("Example 2: Reading csv_118 Format")
    println("="^80)

    data_dir = joinpath(@__DIR__, "..", "example_cases", "csv_118")

    if !isdir(data_dir)
        @warn "csv_118 directory not found at $data_dir"
        return nothing
    end

    # Read the system with default configuration
    println("\nReading system from: $data_dir")
    system = read_csv_system(data_dir)

    # Display system information
    println("\nSystem Information:")
    println("  Name: $(system.name)")
    println("  Base Power: $(system.base_power) MVA")
    println("  Number of Buses: $(length(PSY.get_components(PSY.Bus, system)))")
    println("  Number of Branches: $(length(PSY.get_components(PSY.Branch, system)))")
    println("  Number of Generators: $(length(PSY.get_components(PSY.ThermalStandard, system)))")
    println("  Number of Loads: $(length(PSY.get_components(PSY.PowerLoad, system)))")

    # Calculate total generation capacity
    total_capacity = sum(
        gen.active_power_limits.max * system.base_power
        for gen in PSY.get_components(PSY.ThermalStandard, system)
    )
    println("  Total Generation Capacity: $(round(total_capacity, digits=2)) MW")

    # Calculate total load
    total_load = sum(
        load.active_power * system.base_power
        for load in PSY.get_components(PSY.PowerLoad, system)
    )
    println("  Total Load: $(round(total_load, digits=2)) MW")

    return system
end

# Example 3: Automatic format detection
function example_auto_detect()
    println("\n" * "="^80)
    println("Example 3: Automatic Format Detection")
    println("="^80)

    # Try different directories
    test_dirs = [
        joinpath(@__DIR__, "..", "example_cases", "RTS_GMLC"),
        joinpath(@__DIR__, "..", "example_cases", "csv_118")
    ]

    for data_dir in test_dirs
        if !isdir(data_dir)
            continue
        end

        format = detect_csv_format(data_dir)
        println("\nDirectory: $(basename(data_dir))")
        println("  Detected format: $format")

        if format != :unknown
            try
                system = read_csv_system(data_dir)
                println("  Successfully loaded system with $(length(PSY.get_components(PSY.Bus, system))) buses")
            catch e
                println("  Error loading system: $e")
            end
        end
    end
end

# Main execution
function main()
    println("\n")
    println("╔" * "="^78 * "╗")
    println("║" * " "^20 * "PowerLASCOPF CSV Reader Examples" * " "^25 * "║")
    println("╚" * "="^78 * "╝")

    # Run examples
    example_rts_gmlc()
    example_csv118()
    example_auto_detect()

    println("\n" * "="^80)
    println("Examples completed!")
    println("="^80 * "\n")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
