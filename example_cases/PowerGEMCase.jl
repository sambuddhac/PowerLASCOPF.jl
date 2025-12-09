using PowerSystems
using InfrastructureSystems
using Dates
using TimeSeries
using PowerSimulations
using HiGHS
using StorageSystemsSimulations
const IS = InfrastructureSystems

function create_power_gem_case()
    # Create a new PowerSystem
    sys = System(100.0)
    set_units_base_system!(sys, "NATURAL_UNITS")
    # Define buses
    bus1 = ACBus(;
                  number = 1,
                  name = "bus1",
                  bustype = ACBusTypes.REF,
                  angle = 0.0,
                  magnitude = 1.0,
                  voltage_limits = (min = 0.9, max = 1.05),
                  base_voltage = 230.0,
              );
    add_component!(sys, bus1)

    # Define a generator
    gas = ThermalStandard(;
                         name = "CC",
                         available = true,
                         status = true,
                         bus = bus1,
                         active_power = 0.0, # Per-unitized by device base_power
                         reactive_power = 0.0, # Per-unitized by device base_power
                         rating = 1.0, # 60000 MW per-unitized by device base_power
                         active_power_limits = (min = 0.5, max = 1.0), # 6 MW to 30 MW per-unitized by device base_power
                         reactive_power_limits = nothing, 
                         operation_cost = ThermalGenerationCost(variable = FuelCurve(
                                     value_curve = IS.QuadraticCurve(288000, -2.2, 0.00007),
                                     fuel_cost = 4.0, vom_cost = IS.LinearCurve(0.0)),  # a + b*x + c*x^2
                         fixed = 0.0,
                         start_up = 0.0,
                         shut_down = 0.0), # Per-unitized by device base_power
                         ramp_limits = (up = 30000, down = 30000), # 6 MW/min up or down, per-unitized by device base_power
                         base_power = 60000.0, # MVA
                         time_limits = (up = 800.0, down = 800.0), # Hours
                         must_run = false,
                         prime_mover_type = PrimeMovers.CC,
                         fuel = ThermalFuels.NATURAL_GAS,
       );
    add_component!(sys, gas)

    # Define a load
    load = PowerLoad(;
                  name = "load1",
                  available = true,
                  bus = bus1,
                  active_power = 0.0, # Per-unitized by device base_power
                  reactive_power = 0.0, # Per-unitized by device base_power
                  base_power = 82985.0, # MVA
                  max_active_power = 1.0, # 10 MW per-unitized by device base_power
                  max_reactive_power = 0.0,
              );
    add_component!(sys, load)

    resolution = Dates.Hour(1);
    timestamps = range(DateTime("2020-01-01T08:00:00"); step = resolution, length = 24);
    load_values = [0.71971794,
              0.743549662,
              0.719741438,
              0.713186895,
              0.714308059,
              0.718851038,
              0.682402125,
              0.549909689,
              0.463561269,
              0.402004743,
              0.376544899,
              0.397402356,
              0.44451522,
              0.480080723,
              0.55461101,
              0.5829927,
              0.688881956,
              0.767429224,
              0.86281504,
              0.977534907,
              1,
              0.943910715,
              0.873373068,
              0.761341873];

    load_timearray = TimeArray(timestamps, load_values);
    load_time_series = SingleTimeSeries(;
                  name = "max_active_power",
                  data = load_timearray,
                  scaling_factor_multiplier = get_max_active_power,
              );
    add_time_series!(sys, load, load_time_series);
    
    get_time_series_array(SingleTimeSeries, load, "max_active_power")

    bat1 = EnergyReservoirStorage(;
        name="bat_2_hours",
        available=true,
        bus=bus1,
        prime_mover_type=PrimeMovers.BA,
        storage_technology_type=StorageTech.OTHER_CHEM,
        storage_capacity=10000.0,
        storage_level_limits=(min=0, max=1),
        initial_storage_capacity_level=1.0,
        rating=5000.0,
        active_power=5000.0,
        input_active_power_limits=(min=0.0, max=5000.0),
        output_active_power_limits=(min=0.0, max=5000.0),
        efficiency=(in=1.0, out=1.0),
        reactive_power=0.0,
        reactive_power_limits=(min=0.0, max=0.0),
        base_power=5000.0,
        operation_cost=StorageCost(nothing),
        conversion_factor=1.0,
        storage_target=0.0,
        cycle_limits=0,
        services=Device[],
        dynamic_injector=nothing,
        ext=Dict{String, Any}(),
    );

    bat2 = EnergyReservoirStorage(;
        name="bat_4_hours",
        available=true,
        bus=bus1,
        prime_mover_type=PrimeMovers.BA,
        storage_technology_type=StorageTech.OTHER_CHEM,
        storage_capacity=60000.0,
        storage_level_limits=(min=0, max=1),
        initial_storage_capacity_level=1.0,
        rating=15000.0,
        active_power=15000.0,
        input_active_power_limits=(min=0.0, max=15000.0),
        output_active_power_limits=(min=0.0, max=15000.0),
        efficiency=(in=1.0, out=1.0),
        reactive_power=0.0,
        reactive_power_limits=(min=0.0, max=0.0),
        base_power=15000.0,
        operation_cost=StorageCost(nothing),
        conversion_factor=1.0,
        storage_target=0.0,
        cycle_limits=0,
        services=Device[],
        dynamic_injector=nothing,
        ext=Dict{String, Any}(),
    );

    bat3 = EnergyReservoirStorage(;
        name="bat_8_hours",
        available=true,
        bus=bus1,
        prime_mover_type=PrimeMovers.BA,
        storage_technology_type=StorageTech.OTHER_CHEM,
        storage_capacity=40000.0,
        storage_level_limits=(min=0, max=1),
        initial_storage_capacity_level=1.0,
        rating=5000.0,
        active_power=5000.0,
        input_active_power_limits=(min=0.0, max=5000.0),
        output_active_power_limits=(min=0.0, max=5000.0),
        efficiency=(in=1.0, out=1.0),
        reactive_power=0.0,
        reactive_power_limits=(min=0.0, max=0.0),
        base_power=5000.0,
        operation_cost=StorageCost(nothing),
        conversion_factor=1.0,
        storage_target=0.0,
        cycle_limits=0,
        services=Device[],
        dynamic_injector=nothing,
        ext=Dict{String, Any}(),
    )
    #=# Define a transmission line
    line = TransmissionLine("Line1", from_bus=bus1, to_bus=bus2, capacity=150.0, length=10.0)
    add_component!(ps, line)=#

    add_component!(sys, [bat1, bat2, bat3])

    return sys
end

function UnitCommitmentSimulation(sys::System; optimizer)
	template_uc = ProblemTemplate()
	set_device_model!(template_uc, ThermalStandard, ThermalBasicDispatch)
	set_device_model!(template_uc, PowerLoad, StaticPowerLoad)

	storage_model = DeviceModel(
    				EnergyReservoirStorage,		
    				StorageDispatchWithReserves;
    				attributes=Dict(
        				"reservation" => false,
        				"cycling_limits" => false,
        				"energy_target" => false,
        				"complete_coverage" => false,
        				"regularization" => true,
    				),
    			use_slacks=false,
	);
	set_device_model!(template_uc, storage_model)

	set_network_model!(template_uc, NetworkModel(CopperPlatePowerModel))

    transform_single_time_series!(
                  sys,
                  Dates.Hour(24), # horizon
                  Dates.Hour(1), # interval
              );
    solver = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.5)
	problem = DecisionModel(template_uc, sys; optimizer = solver, horizon = Hour(24))

    build!(problem; output_dir = mktempdir())
    return sim
end

sys = create_power_gem_case()

optimizer = HiGHS.Optimizer

sim = UnitCommitmentSimulation(sys; optimizer = optimizer)

results = run_simulation!(sim; horizon = Dates.Hour(24))

println("Simulation completed. Results:")
for (t, res) in results
    println("Time: $t, Results: $res")
end
