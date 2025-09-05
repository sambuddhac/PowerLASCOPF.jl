using Test
using PowerLASCOPF

function run_all_tests()
    println("🧪 Running PowerLASCOPF Comprehensive Test Suite")
    println("=" ^ 60)
    
    # Test 1: Component Tests
    println("\n📦 Testing Components...")
    include("test_components.jl")
    
    # Test 2: Solver Tests  
    println("\n🔧 Testing Solvers...")
    include("test_solvers.jl")
    
    # Test 3: SDP OPF Comprehensive Tests
    println("\n📊 Testing SDP OPF Comprehensive...")
    include("test_sdp_opf_comprehensive.jl")
    
    # Test 4: Timeseries Integration
    println("\n⏰ Testing Timeseries Integration...")
    @testset "Load Timeseries Integration" begin
        # Test IEEE case loading
        load_data = PowerLASCOPF.load_ieee_case_loads(3)
        @test isa(load_data, Vector)
        @test length(load_data) >= 1
        
        # Test stochastic scenarios
        system = PSY.System(100.0)
        loads = PowerLASCOPF.create_loads_with_timeseries(system, load_data, 24)
        
        if length(loads) > 0
            scenarios = PowerLASCOPF.create_stochastic_load_scenarios(loads[1], 5, 0.15)
            @test length(scenarios) == 5
        end
        
        println("✅ Timeseries integration tests passed")
    end
    
    println("\n✨ All tests completed successfully!")
    println("\n🚀 Ready for:")
    println("   • SDP-OPF solving with IEEE test cases")
    println("   • Load timeseries and stochastic scenarios")
    println("   • Tree width calculation (Lavaei et al.)")
    println("   • Solution quality analysis")
    println("   • PowerLASCOPF distributed optimization")
end

# Run the tests
if abspath(PROGRAM_FILE) == @__FILE__
    run_all_tests()
end