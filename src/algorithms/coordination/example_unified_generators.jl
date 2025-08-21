# Example Usage of Unified Generator Framework
# This demonstrates how to use the unified generator framework with all 5 generator types

using PowerSystems
include("../extended_system.jl")
include("subsystems/generator_integration.jl")

"""
Example function showing how to create and use the unified generator framework
"""
function example_unified_generator_usage()
    println("=== PowerLASCOPF Unified Generator Framework Example ===\n")
    
    # 1. Create a PowerLASCOPF system
    println("1. Creating PowerLASCOPF system...")
    psy_system = System(100.0)  # Base MVA
    power_lascopf_system = PowerLASCOPFSystem(psy_system)
    
    # 2. Create sample buses for generators
    println("2. Creating sample buses...")
    bus1 = ACBus(number=1, name="Bus1", bustype=BusTypes.REF, angle=0.0, magnitude=1.0, 
                 voltage_limits=(min=0.95, max=1.05), base_voltage=138.0)
    bus2 = ACBus(number=2, name="Bus2", bustype=BusTypes.PQ, angle=0.0, magnitude=1.0, 
                 voltage_limits=(min=0.95, max=1.05), base_voltage=138.0)
    bus3 = ACBus(number=3, name="Bus3", bustype=BusTypes.PQ, angle=0.0, magnitude=1.0, 
                 voltage_limits=(min=0.95, max=1.05), base_voltage=138.0)
    
    add_component!(power_lascopf_system, bus1)
    add_component!(power_lascopf_system, bus2)
    add_component!(power_lascopf_system, bus3)
    
    # 3. Create sample generators of each type
    println("3. Creating sample generators...")
    
    # 3a. Thermal Generator
    println("   Creating thermal generator...")
    thermal_cost = ThermalGenerationCost(
        variable = LinearCurve(25.0),  # $25/MWh
        fixed = 100.0,
        start_up = 500.0,
        shut_down = 250.0
    )
    
    thermal_gen_psy = ThermalStandard(
        name = "ThermalGen1",
        available = true,
        status = true,
        bus = bus1,
        active_power = 100.0,
        reactive_power = 50.0,
        rating = 200.0,
        prime_mover = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 20.0, max = 200.0),
        reactive_power_limits = (min = -50.0, max = 100.0),
        ramp_limits = (up = 30.0, down = 30.0),
        time_limits = (up = 4.0, down = 2.0),
        operation_cost = thermal_cost
    )
    
    # Convert to ExtendedThermalGenerator (simplified - you'd use your actual constructor)
    node1 = Node(bus1, 1, 1)
    gen_solver1 = create_mock_gen_solver(1, 1)
    extended_thermal = ExtendedThermalGenerator(
        thermal_gen_psy, thermal_cost, 1, 0, false, 1, 
        gen_solver1, 0, 0, 0, 1, node1, 1, 1
    )
    
    # 3b. Hydro Generator
    println("   Creating hydro generator...")
    hydro_gen = ExtendedHydroGenerator(
        name = "HydroGen1",
        available = true,
        bus = bus2,
        active_power = 80.0,
        reactive_power = 40.0,
        rating = 150.0,
        active_power_limits = (min = 10.0, max = 150.0),
        reactive_power_limits = (min = -30.0, max = 75.0),
        base_power = 100.0,
        operation_cost = TwoPartCost(0.0, 15.0),
        # Hydro-specific properties
        reservoir_capacity = 1000000.0,  # acre-feet
        current_reservoir_level = 800000.0,
        inflow = 500.0,  # cfs
        flow_rate = 300.0,
        water_value = 50.0,  # $/acre-foot
        ramping_rate = 50.0,
        efficiency = 0.92,
        start_stop_cost = 200.0
    )
    
    # 3c. Storage Generator
    println("   Creating storage generator...")
    storage_gen = ExtendedStorageGenerator(
        name = "StorageGen1",
        available = true,
        bus = bus3,
        energy = 500.0,  # MWh
        capacity = (min = 0.0, max = 500.0),
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 100.0,
        active_power_limits = (min = -100.0, max = 100.0),
        reactive_power_limits = (min = -50.0, max = 50.0),
        base_power = 100.0,
        operation_cost = TwoPartCost(0.0, 5.0),
        # Storage-specific properties
        energy_capacity = 500.0,
        state_of_charge = 0.5,
        charging_efficiency = 0.95,
        discharging_efficiency = 0.92,
        self_discharge = 0.001,  # per hour
        degradation_factor = 0.0001,
        cycle_efficiency = 0.87
    )
    
    # 3d. Renewable Generator
    println("   Creating renewable generator...")
    renewable_gen = ExtendedRenewableGenerator(
        name = "SolarGen1",
        available = true,
        bus = bus1,
        active_power = 60.0,
        reactive_power = 0.0,
        rating = 100.0,
        prime_mover_type = PrimeMovers.PVe,
        reactive_power_limits = (min = -20.0, max = 20.0),
        active_power_limits = (min = 0.0, max = 100.0),
        base_power = 100.0,
        operation_cost = TwoPartCost(0.0, 0.0),
        # Renewable-specific properties
        max_active_power = 100.0,
        power_factor = 1.0,
        forecasted_power = [80.0, 90.0, 95.0, 85.0],
        curtailment_cost = 1.0,
        marginal_cost = 0.0
    )
    
    # 3e. Storage Generator (Battery type)
    println("   Creating battery storage generator...")
    battery_gen = ExtendedStorageGenerator(
        name = "BatteryGen1",
        available = true,
        bus = bus2,
        energy = 200.0,
        capacity = (min = 0.0, max = 200.0),
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 50.0,
        active_power_limits = (min = -50.0, max = 50.0),
        reactive_power_limits = (min = -25.0, max = 25.0),
        base_power = 100.0,
        operation_cost = TwoPartCost(0.0, 10.0),
        # Battery-specific properties
        energy_capacity = 200.0,
        state_of_charge = 0.6,
        charging_efficiency = 0.98,
        discharging_efficiency = 0.95,
        self_discharge = 0.0005,
        degradation_factor = 0.0002,
        cycle_efficiency = 0.93,
        marginal_cost_charge = 5.0,
        marginal_cost_discharge = 12.0
    )
    
    # 4. Add all generators to the unified system
    println("4. Adding generators to unified system...")
    
    thermal_wrapper = add_thermal_generator!(power_lascopf_system, extended_thermal, 1, 1, 1)
    hydro_wrapper = add_hydro_generator!(power_lascopf_system, hydro_gen, 2, 2, 1)
    storage_wrapper = add_storage_generator!(power_lascopf_system, storage_gen, 3, 3, 1)
    renewable_wrapper = add_renewable_generator!(power_lascopf_system, renewable_gen, 4, 1, 1)
    battery_wrapper = add_storage_gen_generator!(power_lascopf_system, battery_gen, 5, 2, 1)
    
    # 5. Display system summary
    println("\n5. System summary:")
    summary = get_generator_summary(power_lascopf_system)
    
    # 6. Validate generators
    println("\n6. Validating generators:")
    is_valid = validate_unified_generators(power_lascopf_system)
    
    # 7. Run a sample APP+ADMM iteration
    println("\n7. Running sample APP+ADMM messaging iteration...")
    
    # Sample price and average data
    power_prices = Dict(1 => 30.0, 2 => 25.0, 3 => 28.0)
    angle_prices = Dict(1 => 0.1, 2 => 0.08, 3 => 0.12)
    power_averages = Dict(1 => 120.0, 2 => 90.0, 3 => 40.0)
    angle_averages = Dict(1 => 0.0, 2 => -0.05, 3 => 0.03)
    
    results = run_unified_messaging!(
        power_lascopf_system,
        1,      # outerAPPIt
        10,     # APPItCount
        0.1,    # gsRho
        power_prices,
        angle_prices,
        power_averages,
        angle_averages
    )
    
    println("Messaging results:")
    for (gen_id, result) in results
        println("  Generator $gen_id: Result = $result")
    end
    
    # 8. Get final generator outputs
    println("\n8. Final generator outputs:")
    outputs = get_all_generator_outputs(power_lascopf_system)
    costs = get_all_generator_costs(power_lascopf_system)
    
    for gen_id in sort(collect(keys(outputs)))
        power = outputs[gen_id]
        cost = costs[gen_id]
        println("  Generator $gen_id: Power = $(round(power, digits=2)) MW, Cost = \$(round(cost, digits=2))/MWh")
    end
    
    println("\n=== Example completed successfully! ===")
    
    return power_lascopf_system
end

"""
Test individual generator functionality
"""
function test_individual_generators()
    println("=== Testing Individual Generator Types ===\n")
    
    # Test each generator type separately
    println("Testing thermal generator messaging...")
    # Add individual tests here
    
    println("Testing hydro generator messaging...")
    # Add individual tests here
    
    println("Testing storage generator messaging...")
    # Add individual tests here
    
    println("Testing renewable generator messaging...")
    # Add individual tests here
    
    println("Testing battery generator messaging...")
    # Add individual tests here
    
    println("Individual generator tests completed!")
end

# Export example functions
export example_unified_generator_usage, test_individual_generators
