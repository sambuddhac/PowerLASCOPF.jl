# Example script demonstrating dual-approach LASCOPF Generator Solver
# Now with complete PSI integration including all required files

using PowerLASCOPF
using PowerSystems
using HiGHS  # or your preferred optimizer

# Include the updated solver (now with complete integration)
include("../src/models/solver_models/gensolver_first_base.jl")

# Create a sample PowerSystems System (you'll need to adapt this to your system)
function create_sample_system()
    # This is a placeholder - replace with your actual system creation
    # sys = System(...)
    println("⚠️  Please replace this with your actual PowerSystems.System creation")
    println("   Example: sys = System(\"path/to/your/system.json\")")
    return nothing
end

function main()
    println("🚀 LASCOPF Generator Solver - Dual Approach Demo")
    println("=" * 60)
    
    # Create system (replace with your actual system)
    sys = create_sample_system()
    if sys === nothing
        println("❌ Please update create_sample_system() with your actual system")
        return
    end
    
    # Example 1: Quick comparison
    println("\n📊 Example 1: Quick Performance Comparison")
    println("-" * 40)
    
    # Test preallocated approach
    println("Testing PREALLOCATED approach...")
    results_prealloc = example_lascopf_generator_solve(sys; use_preallocation=true)
    
    # Test direct approach  
    println("Testing DIRECT approach...")
    results_direct = example_lascopf_generator_solve(sys; use_preallocation=false)
    
    # Example 2: Comprehensive benchmark
    println("\n🏆 Example 2: Comprehensive Benchmark")
    println("-" * 40)
    benchmark_results = benchmark_gensolver_approaches(sys, num_runs=3)
    
    # Example 3: ADMM with automatic approach selection
    println("\n🔄 Example 3: ADMM with Approach Selection")
    println("-" * 40)
    results_history, benchmark_data = example_admm_loop(sys, 5; compare_approaches=true)
    
    # Example 4: Full performance test suite
    println("\n🧪 Example 4: Full Performance Test Suite")
    println("-" * 40)
    performance_results = run_performance_tests(sys)
    
    println("\n✅ Demo complete! Check the results above for performance comparisons.")
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
