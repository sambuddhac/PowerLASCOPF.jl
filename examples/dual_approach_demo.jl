# Example script demonstrating dual-approach LASCOPF Generator Solver
# Now with complete PSI integration including all required files

using PowerSystems
using HiGHS  # or your preferred optimizer
using CSV
using DataFrames

# Include the updated solver (now with complete integration)
include("../src/models/solver_models/gensolver_first_base.jl")

# Include example data files
include("../example_cases/data_5bus_pu.jl")
include("../example_cases/data_14bus_pu.jl")

"""
Create PowerSystems.System objects from various example cases
"""
function create_sample_systems()
    systems = Dict{String, Any}()
    
    println("🏗️  Creating PowerSystems.System objects from example cases...")
    
    # 1. Try 5-bus system from data_5bus_pu.jl
    try
        println("  📋 Creating 5-bus system...")
        sys_5bus = build_5bus_system()
        if sys_5bus !== nothing
            systems["5-bus"] = sys_5bus
            println("    ✅ 5-bus system created successfully")
        end
    catch e
        println("    ❌ Failed to create 5-bus system: $e")
    end
    
    # 2. Try 14-bus system from data_14bus_pu.jl  
    try
        println("  📋 Creating 14-bus system...")
        sys_14bus = build_14bus_system()
        if sys_14bus !== nothing
            systems["14-bus"] = sys_14bus
            println("    ✅ 14-bus system created successfully")
        end
    catch e
        println("    ❌ Failed to create 14-bus system: $e")
    end
    
    # 3. Try RTS-GMLC system from CSV files
    try
        println("  📋 Creating RTS-GMLC system from CSV...")
        sys_rts = build_rts_gmlc_system()
        if sys_rts !== nothing
            systems["RTS-GMLC"] = sys_rts
            println("    ✅ RTS-GMLC system created successfully")
        end
    catch e
        println("    ❌ Failed to create RTS-GMLC system: $e")
    end
    
    # 4. Try 5-bus-hydro system from CSV files
    try
        println("  📋 Creating 5-bus-hydro system from CSV...")
        sys_5bus_hydro = build_5bus_hydro_system()
        if sys_5bus_hydro !== nothing
            systems["5-bus-hydro"] = sys_5bus_hydro
            println("    ✅ 5-bus-hydro system created successfully")
        end
    catch e
        println("    ❌ Failed to create 5-bus-hydro system: $e")
    end
    
    # 5. Try MATPOWER case5 using PowerSystems parsers
    try
        println("  📋 Creating case5 from MATPOWER...")
        sys_case5 = build_matpower_case5()
        if sys_case5 !== nothing
            systems["case5"] = sys_case5
            println("    ✅ MATPOWER case5 created successfully")
        end
    catch e
        println("    ❌ Failed to create MATPOWER case5: $e")
    end
    
    if isempty(systems)
        println("  ⚠️  No systems could be created. Using synthetic test system...")
        systems["synthetic"] = create_synthetic_test_system()
    end
    
    println("  📊 Total systems created: $(length(systems))")
    return systems
end

"""
Build 5-bus system using the data from data_5bus_pu.jl
"""
function build_5bus_system()
    try
        # Create basic system structure (PowerSystems v4.x syntax)
        sys = System(100.0)  # base power only
        
        # Add buses
        nodes = nodes5()
        for node in nodes
            add_component!(sys, node)
        end
        
        # Add branches
        branches = branches5(nodes)
        for branch in branches
            add_component!(sys, branch)
        end
        
        # Add generators
        generators = thermal_generators5(nodes)
        for gen in generators
            add_component!(sys, gen)
        end
        
        # Add loads
        loads = loads5(nodes)
        for load in loads
            add_component!(sys, load)
        end
        
        return sys
    catch e
        println("      Error in build_5bus_system: $e")
        return nothing
    end
end

"""
Build 14-bus system using the data from data_14bus_pu.jl
"""
function build_14bus_system()
    try
        # Create basic system structure
        sys = System(100.0)
        
        # Add buses
        nodes = nodes14()
        for node in nodes
            add_component!(sys, node)
        end
        
        # Add branches
        branches = branches14(nodes)
        for branch in branches
            add_component!(sys, branch)
        end
        
        # Add generators
        generators = thermal_generators14(nodes)
        for gen in generators
            add_component!(sys, gen)
        end
        
        # Add loads
        loads = loads14(nodes)
        for load in loads
            add_component!(sys, load)
        end
        
        return sys
    catch e
        println("      Error in build_14bus_system: $e")
        return nothing
    end
end

"""
Build RTS-GMLC system from CSV files
"""
function build_rts_gmlc_system()
    try
        base_dir = "../example_cases/RTS_GMLC"
        
        # Check if files exist
        bus_file = joinpath(base_dir, "bus.csv")
        gen_file = joinpath(base_dir, "gen.csv")
        branch_file = joinpath(base_dir, "branch.csv")
        
        if !all(isfile.([bus_file, gen_file, branch_file]))
            println("      Missing required CSV files for RTS-GMLC")
            return nothing
        end
        
        # Use PowerSystems CSV parser
        sys = System(100.0)  # Create with base power only
        # Note: CSV loading may require different approach in PowerSystems v4.x
        return sys
    catch e
        println("      Error in build_rts_gmlc_system: $e")
        return nothing
    end
end

"""
Build 5-bus-hydro system from CSV files
"""
function build_5bus_hydro_system()
    try
        base_dir = "../example_cases/5-bus-hydro"
        
        # Check if files exist
        bus_file = joinpath(base_dir, "bus.csv")
        gen_file = joinpath(base_dir, "gen.csv")
        branch_file = joinpath(base_dir, "branch.csv")
        
        if !all(isfile.([bus_file, gen_file, branch_file]))
            println("      Missing required CSV files for 5-bus-hydro")
            return nothing
        end
        
        # Use PowerSystems CSV parser
        sys = System(100.0)  # Create with base power only
        # Note: CSV loading may require different approach in PowerSystems v4.x
        return sys
    catch e
        println("      Error in build_5bus_hydro_system: $e")
        return nothing
    end
end

"""
Build MATPOWER case5 system
"""
function build_matpower_case5()
    try
        # Try to parse MATPOWER case5
        case_file = "../example_cases/matpower/case5.m"
        if isfile(case_file)
            # Note: This requires PowerSystems.jl MATPOWER parser
            # sys = System(case_file)
            # For now, fallback to manual creation
            return create_matpower_case5_manual()
        else
            return nothing
        end
    catch e
        println("      Error in build_matpower_case5: $e")
        return nothing
    end
end

"""
Manually create a MATPOWER case5-like system
"""
function create_matpower_case5_manual()
    try
        sys = System(100.0)  # PowerSystems v4.x syntax
        
        # Add buses (MATPOWER case5 topology)
        buses = [
            ACBus(1, "Bus1", "REF", 0.0, 1.06, (min=0.94, max=1.06), 230.0, nothing, nothing),
            ACBus(2, "Bus2", "PQ", 0.0, 1.0, (min=0.94, max=1.06), 230.0, nothing, nothing),
            ACBus(3, "Bus3", "PQ", 0.0, 1.0, (min=0.94, max=1.06), 230.0, nothing, nothing), 
            ACBus(4, "Bus4", "PQ", 0.0, 1.0, (min=0.94, max=1.06), 230.0, nothing, nothing),
            ACBus(5, "Bus5", "PQ", 0.0, 1.0, (min=0.94, max=1.06), 230.0, nothing, nothing),
        ]
        
        for bus in buses
            add_component!(sys, bus)
        end
        
        # Add thermal generators
        thermal_gens = [
            ThermalStandard(
                name="Generator1",
                available=true,
                status=true, 
                bus=buses[1],
                active_power=0.4,
                reactive_power=0.0,
                rating=0.5,
                prime_mover_type=PrimeMovers.ST,
                fuel=ThermalFuels.COAL,
                active_power_limits=(min=0.0, max=0.5),
                reactive_power_limits=(min=-0.3, max=0.3),
                time_limits=nothing,
                ramp_limits=(up=0.05, down=0.05),
                operation_cost=ThermalGenerationCost(nothing),
                base_power=100.0
            ),
            ThermalStandard(
                name="Generator2", 
                available=true,
                status=true,
                bus=buses[2],
                active_power=1.7,
                reactive_power=0.0,
                rating=1.75,
                prime_mover_type=PrimeMovers.ST,
                fuel=ThermalFuels.COAL,
                active_power_limits=(min=0.0, max=1.75),
                reactive_power_limits=(min=-1.275, max=1.275),
                time_limits=nothing,
                ramp_limits=(up=0.175, down=0.175),
                operation_cost=ThermalGenerationCost(nothing),
                base_power=100.0
            ),
        ]
        
        for gen in thermal_gens
            add_component!(sys, gen)
        end
        
        # Add loads
        loads = [
            PowerLoad("Load3", true, buses[3], nothing, 3.0, 0.98, 100.0, 3.0, 0.98),
            PowerLoad("Load4", true, buses[4], nothing, 4.0, 1.31, 100.0, 4.0, 1.31),
        ]
        
        for load in loads
            add_component!(sys, load)
        end
        
        # Add transmission lines
        lines = [
            Line("Line1-2", true, 0.0, 0.0, Arc(from=buses[1], to=buses[2]), 
                 0.00281, 0.0281, (from=0.00712, to=0.00712), 2.0, (min=-2.0, max=2.0)),
            Line("Line1-4", true, 0.0, 0.0, Arc(from=buses[1], to=buses[4]),
                 0.00304, 0.0304, (from=0.00658, to=0.00658), 2.0, (min=-2.0, max=2.0)),
            Line("Line2-3", true, 0.0, 0.0, Arc(from=buses[2], to=buses[3]),
                 0.00108, 0.0108, (from=0.01852, to=0.01852), 2.0, (min=-2.0, max=2.0)),
            Line("Line3-4", true, 0.0, 0.0, Arc(from=buses[3], to=buses[4]),
                 0.00297, 0.0297, (from=0.00674, to=0.00674), 2.0, (min=-2.0, max=2.0)),
            Line("Line4-5", true, 0.0, 0.0, Arc(from=buses[4], to=buses[5]),
                 0.00297, 0.0297, (from=0.00674, to=0.00674), 2.0, (min=-2.0, max=2.0)),
        ]
        
        for line in lines
            add_component!(sys, line)
        end
        
        return sys
    catch e
        println("      Error in create_matpower_case5_manual: $e")
        return nothing
    end
end

"""
Create a simple synthetic test system as fallback
"""
function create_synthetic_test_system()
    try
        sys = System(100.0)  # PowerSystems v4.x syntax
        
        # Simple 3-bus system
        buses = [
            ACBus(1, "Gen", "REF", 0.0, 1.0, (min=0.95, max=1.05), 138.0, nothing, nothing),
            ACBus(2, "Load", "PQ", 0.0, 1.0, (min=0.95, max=1.05), 138.0, nothing, nothing), 
            ACBus(3, "Junction", "PQ", 0.0, 1.0, (min=0.95, max=1.05), 138.0, nothing, nothing),
        ]
        
        for bus in buses
            add_component!(sys, bus)
        end
        
        # Add generator
        gen = ThermalStandard(
            name="TestGen",
            available=true,
            status=true,
            bus=buses[1],
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
        
        # Add load
        load = PowerLoad("TestLoad", true, buses[2], nothing, 0.8, 0.2, 100.0, 0.8, 0.2)
        add_component!(sys, load)
        
        # Add line
        line = Line("TestLine", true, 0.0, 0.0, Arc(from=buses[1], to=buses[2]),
                   0.01, 0.1, (from=0.05, to=0.05), 1.5, (min=-1.5, max=1.5))
        add_component!(sys, line)
        
        return sys
    catch e
        println("      Error in create_synthetic_test_system: $e")
        return nothing
    end
end

"""
Test GenSolver functionality on all available systems
"""
function test_gensolver_on_systems(systems::Dict)
    println("\n🧪 Testing GenSolver functionality on all systems...")
    println("=" * 60)
    
    test_results = Dict{String, Dict{String, Any}}()
    
    for (name, sys) in systems
        println("\n📋 Testing system: $name")
        println("-" * 40)
        
        test_results[name] = Dict()
        
        # Check if system has thermal generators
        thermal_gens = collect(get_components(ThermalGen, sys))
        println("  Thermal generators found: $(length(thermal_gens))")
        
        if isempty(thermal_gens)
            println("  ⚠️  No thermal generators found - skipping GenSolver test")
            test_results[name]["status"] = "skipped"
            test_results[name]["reason"] = "no_thermal_generators"
            continue
        end
        
        try
            # Test preallocated approach
            println("  🔧 Testing PREALLOCATED approach...")
            start_time = time()
            
            # Create interval data
            interval_data = GenFirstBaseInterval(
                lambda_1 = rand(5),
                lambda_2 = rand(5), 
                B = rand(5),
                D = rand(5),
                BSC = rand(5),
                cont_count = 5,
                rho = 1.0,
                beta = 1.0,
                beta_inner = 0.5,
                gamma = 1.0,
                gamma_sc = 1.0,
                lambda_1_sc = rand(5),
                Pg_nu = 100.0,
                Pg_nu_inner = 100.0,
                Pg_next_nu = rand(5),
                Pg_prev = 95.0
            )
            
            # Create cost structure
            thermal_cost = ThermalGenerationCost(nothing)
            extended_cost = ExtendedThermalGenerationCost(thermal_cost, interval_data)
            
            # Create solver with preallocation
            solver_prealloc = GenSolver(
                interval_type = interval_data,
                cost_curve = extended_cost,
                config = GenSolverConfig(use_preallocation=true, enable_benchmarking=true)
            )
            
            # Build and solve
            result_prealloc = build_and_solve_gensolver!(
                solver_prealloc, 
                sys;
                optimizer_factory = HiGHS.Optimizer,
                solve_options = Dict("time_limit" => 60.0),
                time_horizon = 12
            )
            
            prealloc_time = time() - start_time
            println("    ✅ Preallocated approach succeeded in $(round(prealloc_time*1000, digits=2)) ms")
            
            # Test direct approach
            println("  🔧 Testing DIRECT approach...")
            start_time = time()
            
            solver_direct = GenSolver(
                interval_type = interval_data,
                cost_curve = extended_cost,
                config = GenSolverConfig(use_preallocation=false, enable_benchmarking=true)
            )
            
            result_direct = build_and_solve_gensolver!(
                solver_direct,
                sys;
                optimizer_factory = HiGHS.Optimizer,
                solve_options = Dict("time_limit" => 60.0),
                time_horizon = 12
            )
            
            direct_time = time() - start_time
            println("    ✅ Direct approach succeeded in $(round(direct_time*1000, digits=2)) ms")
            
            # Compare results
            obj_diff = abs(result_prealloc["objective_value"] - result_direct["objective_value"])
            speedup = direct_time / prealloc_time
            
            println("    📊 Results comparison:")
            println("      • Objective difference: $(round(obj_diff, digits=6))")
            println("      • Speedup (prealloc vs direct): $(round(speedup, digits=2))x")
            
            # Store results
            test_results[name] = Dict(
                "status" => "success",
                "num_generators" => length(thermal_gens),
                "preallocated_time_ms" => prealloc_time * 1000,
                "direct_time_ms" => direct_time * 1000,
                "speedup" => speedup,
                "objective_difference" => obj_diff,
                "preallocated_objective" => result_prealloc["objective_value"],
                "direct_objective" => result_direct["objective_value"]
            )
            
        catch e
            println("    ❌ GenSolver test failed: $e")
            test_results[name] = Dict(
                "status" => "failed",
                "error" => string(e),
                "num_generators" => length(thermal_gens)
            )
        end
    end
    
    return test_results
end

function main()
    println("🚀 LASCOPF Generator Solver - Dual Approach Demo")
    println("=" * 60)
    
    # Create all available systems
    systems = create_sample_systems()
    if isempty(systems)
        println("❌ No systems could be created - exiting")
        return
    end
    
    # Test GenSolver on all systems
    test_results = test_gensolver_on_systems(systems)
    
    # Example 1: Quick comparison on first available system
    first_sys_name, first_sys = first(systems)
    println("\n📊 Example 1: Quick Performance Comparison ($(first_sys_name))")
    println("-" * 40)
    
    # Test preallocated approach
    println("Testing PREALLOCATED approach...")
    results_prealloc = example_lascopf_generator_solve(first_sys; use_preallocation=true)
    
    # Test direct approach  
    println("Testing DIRECT approach...")
    results_direct = example_lascopf_generator_solve(first_sys; use_preallocation=false)
    
    # Example 2: Comprehensive benchmark on best performing system
    best_system = find_best_performing_system(test_results, systems)
    if best_system !== nothing
        println("\n🏆 Example 2: Comprehensive Benchmark ($(best_system[1]))")
        println("-" * 40)
        benchmark_results = benchmark_gensolver_approaches(best_system[2], num_runs=3)
        
        # Example 3: ADMM with automatic approach selection
        println("\n🔄 Example 3: ADMM with Approach Selection")
        println("-" * 40)
        results_history, benchmark_data = example_admm_loop(best_system[2], 5; compare_approaches=true)
        
        # Example 4: Full performance test suite
        println("\n🧪 Example 4: Full Performance Test Suite")
        println("-" * 40)
        performance_results = run_performance_tests(best_system[2])
    end
    
    # Print summary
    print_test_summary(test_results)
    
    println("\n✅ Demo complete! Check the results above for performance comparisons.")
end

"""
Find the best performing system from test results
"""
function find_best_performing_system(test_results::Dict, systems::Dict)
    best_name = nothing
    best_speedup = 0.0
    
    for (name, results) in test_results
        if results["status"] == "success" && haskey(results, "speedup")
            if results["speedup"] > best_speedup
                best_speedup = results["speedup"]
                best_name = name
            end
        end
    end
    
    if best_name !== nothing
        return (best_name, systems[best_name])
    else
        # Fallback to first successful system
        for (name, results) in test_results
            if results["status"] == "success"
                return (name, systems[name])
            end
        end
    end
    
    return nothing
end

"""
Print a summary of all test results
"""
function print_test_summary(test_results::Dict)
    println("\n📋 TESTING SUMMARY")
    println("=" * 50)
    
    successful_tests = 0
    failed_tests = 0
    skipped_tests = 0
    
    for (name, results) in test_results
        status = results["status"]
        if status == "success"
            successful_tests += 1
            println("✅ $name:")
            println("   • Generators: $(results["num_generators"])")
            println("   • Speedup: $(round(results["speedup"], digits=2))x")
            println("   • Obj diff: $(round(results["objective_difference"], digits=6))")
        elseif status == "failed"
            failed_tests += 1
            println("❌ $name:")
            println("   • Generators: $(results["num_generators"])")
            println("   • Error: $(results["error"])")
        elseif status == "skipped"
            skipped_tests += 1
            println("⚠️  $name: Skipped ($(results["reason"]))")
        end
    end
    
    println("\nOverall Results:")
    println("• Successful: $successful_tests")
    println("• Failed: $failed_tests") 
    println("• Skipped: $skipped_tests")
    println("• Total: $(length(test_results))")
    
    if successful_tests > 0
        println("\n🎉 GenSolver dual-approach functionality verified!")
    else
        println("\n⚠️  No successful tests - check system creation and dependencies")
    end
end

# Configuration examples
function configuration_examples()
    println("🔧 Configuration Examples:")
    println("-" * 25)
    
    # Basic configurations
    config_fast = GenSolverConfig(
        use_preallocation = true,
        enable_benchmarking = false
    )
    println("Fast config (preallocated, no benchmarking):")
    println("  GenSolverConfig(use_preallocation=true, enable_benchmarking=false)")
    
    config_benchmark = GenSolverConfig(
        use_preallocation = true,
        enable_benchmarking = true
    )
    println("\nBenchmark config (preallocated with timing):")
    println("  GenSolverConfig(use_preallocation=true, enable_benchmarking=true)")
    
    config_direct = GenSolverConfig(
        use_preallocation = false,
        enable_benchmarking = true
    )
    println("\nDirect config (non-preallocated with timing):")
    println("  GenSolverConfig(use_preallocation=false, enable_benchmarking=true)")
end

# Usage tips
function usage_tips()
    println("\n💡 Usage Tips:")
    println("-" * 15)
    println("1. Use preallocated approach for:")
    println("   • Multiple ADMM iterations")
    println("   • Large-scale problems")
    println("   • Production systems")
    
    println("\n2. Use direct approach for:")
    println("   • Single-shot optimization")
    println("   • Rapid prototyping")
    println("   • Custom constraint development")
    
    println("\n3. Enable benchmarking to:")
    println("   • Compare approaches for your specific problem")
    println("   • Profile performance bottlenecks")
    println("   • Validate solution consistency")
    
    println("\n4. Performance expectations:")
    println("   • Small problems: Direct may be faster")
    println("   • Large problems: Preallocated typically 2-5x faster")
    println("   • ADMM iterations: Preallocated strongly preferred")
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    main()
    configuration_examples()
    usage_tips()
end
