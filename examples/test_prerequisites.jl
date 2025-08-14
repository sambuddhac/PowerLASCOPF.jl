# Quick test script for the updated dual_approach_demo.jl
# This script tests the functionality without running the full demo

using PowerSystems
using HiGHS

# Test basic PowerSystems functionality
function test_basic_powersystems()
    println("🧪 Testing basic PowerSystems functionality...")
    
    try
        # Create a simple system (using PowerSystems v4.x syntax)
        sys = System(100.0)  # Just base power
        
        # Add a bus (using ACBus for PowerSystems v4.x)
        bus = ACBus(1, "TestBus", "REF", 0.0, 1.0, (min=0.95, max=1.05), 138.0, nothing, nothing)
        add_component!(sys, bus)
        
        # Add a generator
        gen = ThermalStandard(
            name="TestGen",
            available=true,
            status=true,
            bus=bus,
            active_power=1.0,
            reactive_power=0.0,
            rating=1.2,
            prime_mover_type=PrimeMovers.ST,
            fuel=ThermalFuels.NATURAL_GAS,
            active_power_limits=(min=0.1, max=1.2),
            reactive_power_limits=(min=-0.5, max=0.5),
            time_limits=nothing,
            ramp_limits=(up=0.12, down=0.12),
            operation_cost=ThermalGenerationCost(nothing),
            base_power=100.0
        )
        add_component!(sys, gen)
        
        println("  ✅ Basic PowerSystems test passed")
        return true
    catch e
        println("  ❌ Basic PowerSystems test failed: $e")
        return false
    end
end

function main()
    println("🚀 Testing dual_approach_demo.jl prerequisites")
    println("=" ^ 50)
    
    # Test 1: Basic PowerSystems
    if !test_basic_powersystems()
        println("❌ Prerequisites not met")
        return
    end
    
    # Test 2: Check if data files exist
    println("\n📁 Checking example data files...")
    
    data_files = [
        "../example_cases/data_5bus_pu.jl",
        "../example_cases/data_14bus_pu.jl"
    ]
    
    for file in data_files
        if isfile(file)
            println("  ✅ Found: $file")
        else
            println("  ❌ Missing: $file")
        end
    end
    
    csv_dirs = [
        "../example_cases/5-bus-hydro",
        "../example_cases/RTS_GMLC"
    ]
    
    for dir in csv_dirs
        if isdir(dir)
            println("  ✅ Found directory: $dir")
            # Check for required CSV files
            required_files = ["bus.csv", "gen.csv", "branch.csv"]
            for req_file in required_files
                full_path = joinpath(dir, req_file)
                if isfile(full_path)
                    println("    ✅ $req_file")
                else
                    println("    ❌ Missing $req_file")
                end
            end
        else
            println("  ❌ Missing directory: $dir")
        end
    end
    
    println("\n✅ Prerequisite check complete!")
    println("\n💡 To run the full demo:")
    println("   julia dual_approach_demo.jl")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
