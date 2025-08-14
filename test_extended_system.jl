# Test script for PowerLASCOPF Extended System Integration
# This demonstrates how to create and use the extended PSY.System with PowerLASCOPF types

using PowerSystems
using InfrastructureSystems
using Dates

# Include our extended system
include("src/models/system_extensions/extended_system.jl")
include("src/models/solver_models/linesolver_base.jl")

println("🚀 PowerLASCOPF Extended System Integration Test")
println("=" ^ 60)

# Test 1: Create a basic PowerLASCOPF System
println("\n📊 Test 1: Creating PowerLASCOPF System")
println("-" ^ 40)

try
    # Create a basic PowerLASCOPF system
    system = PowerLASCOPFSystem(
        100.0;  # Base power in MVA
        name = "Test_PowerLASCOPF_System",
        network_id = 14,
        post_contingency_scenario = 0,
        contingency_count = 3,
        interval_id = 1,
        solver_choice = 1,
        rho_tuning = 1.0,
        rnd_intervals = 6,
        rsd_intervals = 6
    )
    
    println("✅ PowerLASCOPF System created successfully")
    println("   - Name: $(PSY.get_name(system))")
    println("   - Base Power: $(PSY.get_base_power(system)) MVA")
    println("   - Network ID: $(system.network_id)")
    println("   - Contingency Count: $(system.contingency_count)")
    
catch e
    println("❌ Test 1 failed: $e")
    return
end

# Test 2: Add PSY components to the system
println("\n📊 Test 2: Adding PSY Components")
println("-" ^ 40)

try
    # Create PSY buses
    bus1 = PSY.Bus(
        number = 1,
        name = "Bus_1",
        bustype = PSY.BusTypes.REF,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.1),
        base_voltage = 138.0,
        area = PSY.Area("Area_1"),
        load_zone = PSY.LoadZone("Zone_1")
    )
    
    bus2 = PSY.Bus(
        number = 2,
        name = "Bus_2", 
        bustype = PSY.BusTypes.PV,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.1),
        base_voltage = 138.0,
        area = PSY.Area("Area_1"),
        load_zone = PSY.LoadZone("Zone_1")
    )
    
    bus3 = PSY.Bus(
        number = 3,
        name = "Bus_3",
        bustype = PSY.BusTypes.PQ,
        angle = 0.0,
        magnitude = 1.0,
        voltage_limits = (min = 0.9, max = 1.1),
        base_voltage = 138.0,
        area = PSY.Area("Area_1"),
        load_zone = PSY.LoadZone("Zone_1")
    )
    
    # Add buses to PSY system
    PSY.add_component!(system.psy_system, bus1)
    PSY.add_component!(system.psy_system, bus2)
    PSY.add_component!(system.psy_system, bus3)
    
    println("✅ Added 3 PSY buses to system")
    
    # Create PSY branches
    branch12 = PSY.Line(
        name = "Line_1_2",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = PSY.Arc(from = bus1, to = bus2),
        r = 0.01,
        x = 0.05,
        b = (from = 0.0, to = 0.0),
        rate = 100.0,
        angle_limits = (min = -π/2, max = π/2)
    )
    
    branch23 = PSY.Line(
        name = "Line_2_3",
        available = true,
        active_power_flow = 0.0,
        reactive_power_flow = 0.0,
        arc = PSY.Arc(from = bus2, to = bus3),
        r = 0.02,
        x = 0.08,
        b = (from = 0.0, to = 0.0),
        rate = 80.0,
        angle_limits = (min = -π/2, max = π/2)
    )
    
    # Add branches to PSY system
    PSY.add_component!(system.psy_system, branch12)
    PSY.add_component!(system.psy_system, branch23)
    
    println("✅ Added 2 PSY branches to system")
    
    # Create PSY thermal generator
    thermal_gen = PSY.ThermalStandard(
        name = "ThermalGen_1",
        available = true,
        status = true,
        bus = bus1,
        active_power = 0.5,
        reactive_power = 0.1,
        rating = 1.0,
        prime_mover = PSY.PrimeMovers.ST,
        fuel = PSY.ThermalFuels.COAL,
        active_power_limits = (min = 0.1, max = 1.0),
        reactive_power_limits = (min = -0.3, max = 0.3),
        ramp_limits = (up = 0.02, down = 0.02),
        time_limits = (up = 1.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = PSY.CostCurve(PSY.LinearCurve(10.0)),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0
        )
    )
    
    PSY.add_component!(system.psy_system, thermal_gen)
    
    println("✅ Added 1 PSY thermal generator to system")
    
catch e
    println("❌ Test 2 failed: $e")
    return
end

# Test 3: Convert PSY system to PowerLASCOPF
println("\n📊 Test 3: Converting PSY System to PowerLASCOPF")
println("-" ^ 50)

try
    # Convert the PSY system to PowerLASCOPF equivalents
    convert_psy_system_to_powerlas_copf!(system; number_of_scenarios = 3)
    
    println("✅ Conversion completed successfully")
    println("   - PowerLASCOPF Nodes: $(get_node_count(system))")
    println("   - PowerLASCOPF Transmission Lines: $(get_transmission_line_count(system))")
    
catch e
    println("❌ Test 3 failed: $e")
    return
end

# Test 4: Validate the system
println("\n📊 Test 4: Validating PowerLASCOPF System")
println("-" ^ 45)

try
    validation_result = validate_powerlas_copf_system(system)
    
    if validation_result
        println("✅ System validation passed!")
    else
        println("❌ System validation failed!")
        return
    end
    
catch e
    println("❌ Test 4 failed: $e")
    return
end

# Test 5: Create Network from System
println("\n📊 Test 5: Creating Network from PowerLASCOPF System")
println("-" ^ 55)

try
    # Create a Network instance from the PowerLASCOPF system
    network = create_network_from_system(system)
    
    println("✅ Network created successfully")
    println("   - Network ID: $(network.networkID)")
    println("   - Number of Nodes: $(network.nodeNumber)")
    println("   - Number of Transmission Lines: $(network.translNumber)")
    println("   - Number of Generators: $(network.genNumber)")
    println("   - Contingency Count: $(network.contingencyCount)")
    
catch e
    println("❌ Test 5 failed: $e")
    return
end

# Test 6: Create SuperNetwork
println("\n📊 Test 6: Creating SuperNetwork")
println("-" ^ 35)

try
    # Create a SuperNetwork instance
    super_network = SuperNetwork(
        network_id = system.network_id,
        choice_solver = system.solver_choice,
        rho_tuning = system.rho_tuning,
        post_cont_scen = system.post_contingency_scenario,
        disp_interval = system.interval_id,
        disp_interval_class = 1,  # forthcoming
        last_flag = system.last_flag,
        next_choice = false,
        dummy_disp_int = system.dummy_zero_flag,
        contin_sol_accuracy = system.accuracy,
        outaged_line_param = system.outaged_line,
        rnd_intervals = system.rnd_intervals,
        rsd_intervals = system.rsd_intervals
    )
    
    println("✅ SuperNetwork created successfully")
    println("   - Network ID: $(super_network.net_id)")
    println("   - Solver Choice: $(super_network.solver_choice)")
    println("   - Contingency Networks: $(length(super_network.cont_net_vector))")
    println("   - Number of Contingencies: $(super_network.number_of_cont)")
    println("   - RND Intervals: $(super_network.rnd_intervals)")
    println("   - RSD Intervals: $(super_network.rsd_intervals)")
    
catch e
    println("❌ Test 6 failed: $e")
    return
end

# Test 7: System Summary and Analysis
println("\n📊 Test 7: System Summary and Analysis")
println("-" ^ 40)

try
    # Print comprehensive system summary
    system_summary(system)
    
    # Test some getter functions
    println("\n🔍 Testing Getter Functions:")
    println("   - Node count: $(get_node_count(system))")
    println("   - Transmission line count: $(get_transmission_line_count(system))")
    println("   - Extended thermal generator count: $(get_extended_thermal_generator_count(system))")
    
    # Test node access
    if get_node_count(system) > 0
        first_node = get_nodes(system)[1]
        println("   - First node ID: $(get_node_id(first_node))")
        println("   - First node connections: $(get_total_connections(first_node))")
    end
    
    # Test transmission line access
    if get_transmission_line_count(system) > 0
        first_line = get_transmission_lines(system)[1]
        println("   - First line ID: $(get_transl_id(first_line))")
        println("   - First line from node: $(get_transl_node_id1(first_line))")
        println("   - First line to node: $(get_transl_node_id2(first_line))")
    end
    
    println("✅ System analysis completed successfully")
    
catch e
    println("❌ Test 7 failed: $e")
    return
end

# Test 8: Integration with LineSolver
println("\n📊 Test 8: Integration with LineSolver")
println("-" ^ 40)

try
    # Test LineSolver integration with extended system
    if get_transmission_line_count(system) > 0
        first_line = get_transmission_lines(system)[1]
        line_solver = first_line.solver_line_base
        
        println("✅ LineSolver integration working")
        println("   - Line solver RND intervals: $(line_solver.RND_int)")
        println("   - Line solver contingency count: $(line_solver.cont_count)")
        println("   - Line solver temperature limit: $(line_solver.max_temp) K")
    else
        println("⚠️ No transmission lines available for LineSolver test")
    end
    
catch e
    println("❌ Test 8 failed: $e")
    return
end

# Final Success Summary
println("\n🎉 PowerLASCOPF Extended System Integration Test Complete!")
println("=" ^ 60)
println("📝 Summary of Successful Tests:")
println("   ✅ PowerLASCOPF System creation")
println("   ✅ PSY component integration")
println("   ✅ System conversion and validation")
println("   ✅ Network creation from system")
println("   ✅ SuperNetwork creation")
println("   ✅ System summary and analysis")
println("   ✅ LineSolver integration")
println()
println("🚀 The PowerLASCOPF extended PSY.System is ready for use!")
println("🔧 You can now:")
println("   - Create PowerLASCOPF systems with custom types")
println("   - Integrate with existing PSY.System workflows")
println("   - Use Node, transmissionLine, and ExtendedThermalGenerator types")
println("   - Create Network and SuperNetwork instances")
println("   - Run APMP algorithm simulations")
println("   - Integrate with LineSolver for thermal optimization")

println("\n📋 Next Steps:")
println("   1. Implement complete solver integration")
println("   2. Add load and renewable generator support")
println("   3. Implement time series data handling")
println("   4. Add contingency analysis capabilities")
println("   5. Complete APP algorithm implementation")
