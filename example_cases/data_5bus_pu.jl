using Revise
using TimeSeries
using Dates
using Random
Random.seed!(123)
using PowerSystems
using InfrastructureSystems
using Logging
# At the top of the file, add:
#=using .PowerLASCOPF: PowerLASCOPFSystem, SuperNetwork, Node, transmissionLine
# OR if PowerLASCOPF is loaded differently:
const PowerLASCOPFSystem = PowerLASCOPF.PowerLASCOPFSystem
const SuperNetwork = PowerLASCOPF.SuperNetwork=#
const PSY = PowerSystems
const IS = InfrastructureSystems

const LOG_FILE = joinpath(@__DIR__, "execution_run.log")
const LOG_IO = open(LOG_FILE, "w")

"""
    log_both(message)

Prints message to both console and log file with timestamp.
"""
function log_both(message::String)
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    formatted_message = "[$timestamp] $message"
    
    # Print to console
    println(formatted_message)
    
    # Write to log file
    println(LOG_IO, formatted_message)
    flush(LOG_IO)  # Ensure immediate write to file
end

"""
    log_info(message)

Logs an info message to both console and file.
"""
log_info(message::String) = log_both("ℹ️  INFO: $message")

"""
    log_warn(message)

Logs a warning message to both console and file.
"""
log_warn(message::String) = log_both("⚠️  WARN: $message")

"""
    log_error(message)

Logs an error message to both console and file.
"""
log_error(message::String) = log_both("❌ ERROR: $message")

"""
    log_success(message)

Logs a success message to both console and file.
"""
log_success(message::String) = log_both("✅ SUCCESS: $message")

# Ensure log file is closed when Julia exits
atexit(() -> close(LOG_IO))

log_info("Starting PowerLASCOPF execution script")
log_info("Log file: $LOG_FILE")

#=# Include PowerLASCOPF components
include("../src/components/GeneralizedGenerator.jl")
include("../src/components/Node.jl")
include("../src/components/transmission_line.jl")
include("../src/core/solver_model_types.jl")

# Include POMDP components
include("../src/pomdp/PowerLASCOPFPOMDP.jl")
include("../src/pomdp/belief_updater.jl")
include("../src/pomdp/policy_interface.jl")
include("../src/pomdp/utils.jl")=#

import PowerSystems: VariableCost, TwoPartCost, MarketBidCost, PrimeMovers, ThermalFuels, Arc

DayAhead = collect(
    DateTime("1/1/2024  0:00:00", "d/m/y  H:M:S"):Hour(1):DateTime(
        "1/1/2024  23:00:00",
        "d/m/y  H:M:S",
    ),
)
#Dispatch_11am =  collect(DateTime("1/1/2024  0:11:00", "d/m/y  H:M:S"):Minute(15):DateTime("1/1/2024  12::00", "d/m/y  H:M:S"))

nodes5() = [
    PSY.ACBus(1, "nodeA", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    PSY.ACBus(2, "nodeB", "PQ", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    PSY.ACBus(3, "nodeC", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    PSY.ACBus(4, "nodeD", "REF", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
    PSY.ACBus(5, "nodeE", "PV", 0, 1.0, (min = 0.9, max = 1.05), 230, nothing, nothing),
];

branches5_dc(nodes5) = [
    PSY.Line(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    PSY.HVDCLine(
        "DCL2",
        true,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        (min = -3000.0, max = 3000.0),
        (min = -3000, max = 3000),
        (min = -3000.0, max = 3000.0),
        (min = -3000.0, max = 3000.0),
        (l0 = 0.0, l1 = 0.01),
    ),
    PSY.Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

branches5(nodes5) = [
    PSY.Line(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "2",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        0.00304,
        0.0304,
        (from = 0.00329, to = 0.00329),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

branches5_ml(nodes5) = [
    PSY.MonitoredLine(
        "1",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[2]),
        0.00281,
        0.0281,
        (from = 0.00356, to = 0.00356),
        (from_to = 1.0, to_from = 1.0),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "2",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[4]),
        0.00304,
        0.0304,
        (from = 0.00329, to = 0.00329),
        2.0,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "3",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[1], to = nodes5[5]),
        0.00064,
        0.0064,
        (from = 0.01563, to = 0.01563),
        18.8120,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "4",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[2], to = nodes5[3]),
        0.00108,
        0.0108,
        (from = 0.00926, to = 0.00926),
        11.1480,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "5",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[3], to = nodes5[4]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 0.00337),
        40.530,
        (min = -0.7, max = 0.7),
    ),
    PSY.Line(
        "6",
        true,
        0.0,
        0.0,
        Arc(from = nodes5[4], to = nodes5[5]),
        0.00297,
        0.0297,
        (from = 0.00337, to = 00.00337),
        2.00,
        (min = -0.7, max = 0.7),
    ),
];

branches_5_contingency_list() = [
    1,
    2,
    3,
    4,
    5,
    6,
];

solar_ts_DA = [
    0
    0
    0
    0
    0
    0
    0
    0
    0
    0.351105684
    0.632536266
    0.99463925
    1
    0.944237283
    0.396681234
    0.366511428
    0.155125829
    0.040872694
    0
    0
    0
    0
    0
    0
]

wind_ts_DA = [
    0.985205412
    0.991791369
    0.997654144
    1
    0.998663733
    0.995497149
    0.992414567
    0.98252418
    0.957203427
    0.927650911
    0.907181989
    0.889095913
    0.848186718
    0.766813846
    0.654052531
    0.525336131
    0.396098004
    0.281771509
    0.197790004
    0.153241012
    0.131355854
    0.113688144
    0.099302656
    0.069569628
]

hydro_inflow_ts_DA = [
    0.314300
    0.386684
    0.228582
    0.226677
    0.222867
    0.129530
    0.144768
    0.365731
    0.207628
    0.622885
    0.670507
    0.676221
    0.668602
    0.407638
    0.321919
    0.369541
    0.287632
    0.449544
    0.630505
    0.731462
    0.777178
    0.712413
    0.780988
    0.190485
];

thermal_generators5(nodes5) = [
    PSY.ThermalStandard(;
        name = "Alta",
        available = true,
        status = true,
        bus = nodes5[1],
        active_power = 0.40,
        reactive_power = 0.010,
        rating = 0.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 0.40),
        reactive_power_limits = (min = -0.30, max = 0.30),
        ramp_limits = nothing,
        time_limits = nothing,
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.QuadraticCurve(0.5, 14.0, 0.1),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 4.0,
            start_up = 0.0,
            shut_down = 0.0),
            base_power = 100.0,
        ),
    PSY.ThermalStandard(
        name = "Park City",
        available = true,
        status = true,
        bus = nodes5[1],
        active_power = 1.70,
        reactive_power = 0.20,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.QuadraticCurve(0.0, 15.0, 0.05),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 1.5,
            start_up = 0.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Solitude",
        available = true,
        status = true,
        bus = nodes5[3],
        active_power = 5.2,
        reactive_power = 1.00,
        rating = 5.2,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 5.20),
        reactive_power_limits = (min = -3.90, max = 3.90),
        ramp_limits = (up = 0.012 * 5.2, down = 0.012 * 5.2),
        time_limits = (up = 3.0, down = 2.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.QuadraticCurve(0.0, 30.0, 0.02),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 3.0,
            start_up = 0.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Sundance",
        available = true,
        status = true,
        bus = nodes5[4],
        active_power = 2.0,
        reactive_power = 0.40,
        rating = 2.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 2.0),
        reactive_power_limits = (min = -1.5, max = 1.5),
        ramp_limits = (up = 0.015 * 2.5, down = 0.015 * 2.5),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.QuadraticCurve(0.0, 40.0, 0.03),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 4.0,
            start_up = 0.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Brighton",
        available = true,
        status = true,
        bus = nodes5[5],
        active_power = 6.0,
        reactive_power = 1.50,
        rating = 0.75,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 6.0),
        reactive_power_limits = (min = -4.50, max = 4.50),
        ramp_limits = (up = 0.015 * 7.5, down = 0.015 * 7.5),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.QuadraticCurve(0.0, 10.0, 0.01),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 1.5,
            start_up = 0.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
];

thermal_generators5_pwl(nodes5) = [
    PSY.ThermalStandard(
        name = "Test PWL",
        available = true,
        status = true,
        bus = nodes5[1],
        active_power = 1.70,
        reactive_power = 0.20,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = IS.PiecewiseIncrementalCurve([(0.0, 50.0), (190.1, 80.0), (582.72, 120.0), (1094.1, 170.0)]),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 1.5,
            start_up = 0.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
];

thermal_generators5_pwl_nonconvex(nodes5) = [
    PSY.ThermalStandard(
        name = "Test PWL Nonconvex",
        available = true,
        status = true,
        bus = nodes5[1],
        active_power = 1.70,
        reactive_power = 0.20,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.0, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.FuelCurve(
                value_curve = PiecewiseIncrementalData([(0.0, 50.0), (190.1, 80.0), (582.72, 120.0), (825.1, 170.0)]),
                fuel_cost = 5.0, vom_cost = IS.LinearCurve(3.55)),  # a + b*x + c*x^2
            fixed = 1.5,
            start_up = 0.75,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
];

thermal_generators5_uc_testing(nodes) = [
    PSY.ThermalStandard(
        name = "Alta",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 0.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.2, max = 0.40),
        reactive_power_limits = (min = -0.30, max = 0.30),
        ramp_limits = (up = 0.40, down = 0.40),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 14.0, 0.1),
            fixed = 4.0,
            start_up = 2.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Park City",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.65, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 15.0, 0.05),
            fixed = 1.5,
            start_up = 0.75,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Solitude",
        available = true,
        status = true,
        bus = nodes[3],
        active_power = 2.7,
        reactive_power = 0.00,
        rating = 5.20,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 5.20),
        reactive_power_limits = (min = -3.90, max = 3.90),
        ramp_limits = (up = 0.0012 * 5.2, down = 0.0012 * 5.2),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 30.0, 0.02),
            fixed = 3.0,
            start_up = 1.5,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Sundance",
        available = true,
        status = false,
        bus = nodes[4],
        active_power = 0.0,
        reactive_power = 0.00,
        rating = 2.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 2.0),
        reactive_power_limits = (min = -1.5, max = 1.5),
        ramp_limits = (up = 0.015 * 2.5, down = 0.015 * 2.5),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 40.0, 0.03),
            fixed = 4.0,
            start_up = 2.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Brighton",
        available = true,
        status = true,
        bus = nodes[5],
        active_power = 6.0,
        reactive_power = 0.0,
        rating = 7.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 3.0, max = 6.0),
        reactive_power_limits = (min = -4.50, max = 4.50),
        ramp_limits = (up = 0.0015 * 7.5, down = 0.0015 * 7.5),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 10.0, 0.01),
            fixed = 1.5,
            start_up = 0.75,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
];

thermal_pglib_generators5(nodes5) = [
    PSY.ThermalMultiStart(
        "115_STEAM_1",
        true,
        true,
        nodes5[1],
        0.05,
        0.010,
        0.12,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.05, max = 0.12),
        (min = -0.30, max = 0.30),
        (up = 0.002 * 0.12, down = 0.002 * 0.12),
        (startup = 0.05, shutdown = 0.05),
        (up = 4.0, down = 2.0),
        (hot = 2.0, warm = 4.0, cold = 12.0),
        3,
        PSY.MultiStartCost(
            IS.PiecewiseLinearData([(0.0, 5.0), (290.1, 7.33), (582.72, 9.67), (894.1, 12.0)]),
            897.29,
            0.0,
            (hot = 393.28, warm = 455.37, cold = 703.76),
            0.0,
        ),
        100.0,
    ),
    PSY.ThermalMultiStart(
        "101_CT_1",
        true,
        true,
        nodes5[1],
        0.08,
        0.020,
        0.12,
        PrimeMovers.ST,
        ThermalFuels.COAL,
        (min = 0.08, max = 0.20),
        (min = -0.30, max = 0.30),
        (up = 0.002 * 0.2, down = 0.002 * 0.2),
        (startup = 0.08, shutdown = 0.08),
        (up = 1.0, down = 1.0),
        (hot = 1.0, warm = 999.0, cold = 999.0),
        1,
        PSY.MultiStartCost(
            IS.PiecewiseLinearData([(0.0, 8.0), (391.45, 12.0), (783.74, 16.0), (1212.28, 20.0)]),
            1085.78,
            0.0,
            (hot = 51.75, warm = PSY.START_COST, cold = PSY.START_COST),
            0.0,
        ),
        100.0,
    ),
];

thermal_generators5_uc_testing(nodes) = [
    PSY.ThermalStandard(
        name = "Alta",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 0.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.2, max = 0.40),
        reactive_power_limits = (min = -0.30, max = 0.30),
        ramp_limits = (up = 0.40, down = 0.40),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 14.0, 0.1),
            fixed = 4.0,
            start_up = 2.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Park City",
        available = true,
        status = false,
        bus = nodes[1],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 2.2125,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 0.65, max = 1.70),
        reactive_power_limits = (min = -1.275, max = 1.275),
        ramp_limits = (up = 0.02 * 2.2125, down = 0.02 * 2.2125),
        time_limits = (up = 0.0, down = 0.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 15.0, 0.05),
            fixed = 1.5,
            start_up = 0.75,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Solitude",
        available = true,
        status = true,
        bus = nodes[3],
        active_power = 2.7,
        reactive_power = 0.00,
        rating = 5.20,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 5.20),
        reactive_power_limits = (min = -3.90, max = 3.90),
        ramp_limits = (up = 0.0012 * 5.2, down = 0.0012 * 5.2),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 30.0, 0.02),
            fixed = 3.0,
            start_up = 1.5,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Sundance",
        available = true,
        status = false,
        bus = nodes[4],
        active_power = 0.0,
        reactive_power = 0.00,
        rating = 2.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 1.0, max = 2.0),
        reactive_power_limits = (min = -1.5, max = 1.5),
        ramp_limits = (up = 0.015 * 2.5, down = 0.015 * 2.5),
        time_limits = (up = 2.0, down = 1.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 40.0, 0.03),
            fixed = 4.0,
            start_up = 2.0,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
    PSY.ThermalStandard(
        name = "Brighton",
        available = true,
        status = true,
        bus = nodes[5],
        active_power = 6.0,
        reactive_power = 0.0,
        rating = 7.5,
        prime_mover_type = PrimeMovers.ST,
        fuel = ThermalFuels.COAL,
        active_power_limits = (min = 3.0, max = 6.0),
        reactive_power_limits = (min = -4.50, max = 4.50),
        ramp_limits = (up = 0.0015 * 7.5, down = 0.0015 * 7.5),
        time_limits = (up = 5.0, down = 3.0),
        operation_cost = PSY.ThermalGenerationCost(
            variable = IS.QuadraticCurve(0.0, 10.0, 0.01),
            fixed = 1.5,
            start_up = 0.75,
            shut_down = 0.0
        ),
        base_power = 100.0,
    ),
];

renewable_generators5(nodes5) = [
    PSY.RenewableDispatch(
        "WindBusA",
        true,
        nodes5[5],
        0.0,
        0.0,
        1.200,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        PSY.RenewableGenerationCost(CostCurve(LinearCurve(0.22))),
        100.0,
    ),

    PSY.RenewableDispatch(
        "WindBusB",
        true,
        nodes5[4],
        0.0,
        0.0,
        1.200,
        PrimeMovers.WT,
        (min = 0.0, max = 0.0),
        1.0,
        PSY.RenewableGenerationCost(CostCurve(LinearCurve(0.22))),
        100.0,
    ),
    PSY.RenewableDispatch(
        "WindBusC",
        true,
        nodes5[3],
        0.0,
        0.0,
        1.20,
        PrimeMovers.WT,
        (min = -0.800, max = 0.800),
        1.0,
        PSY.RenewableGenerationCost(CostCurve(LinearCurve(0.22))),
        100.0,
    ),
];

hydro_generators5(nodes5) = [
    PSY.HydroDispatch(
        "HydroDispatch_1",
        true,
        nodes5[2],
        0.0,
        0.0,
        6.0,
        PrimeMovers.HY,
        (min = 0.0, max = 6.0),
        (min = 0.0, max = 6.0),
        nothing,
        nothing,
        100.0,
        PSY.HydroGenerationCost( variable = FuelCurve(
                    value_curve = LinearCurve(10.0),
                    fuel_cost = 0.0
                    ), fixed = 5.0),
        PSY.Device[], 
        nothing, 
        Dict{String, Any}(),
    ),
    PSY.HydroEnergyReservoir(;
        name = "HydroEnergyReservoir_1",
        available = true,
        bus = nodes5[3],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 7.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 7.0),
        reactive_power_limits = (min = 0.0, max = 7.0),
        ramp_limits = (up = 7.0, down = 7.0),
        time_limits = nothing,
        operation_cost = PSY.HydroGenerationCost( variable = FuelCurve(
                    value_curve = LinearCurve(5.0),
                    fuel_cost = 0.0
                    ), fixed = 2.0),
        base_power = 100.0,
        storage_capacity = 50.0,
        inflow = 4.0,
        conversion_factor = 1.0,
        initial_storage = 0.5,
    ),
    PSY.HydroDispatch(;
        name = "HydroDispatch_2 ",
        available = true,
        bus = nodes5[2],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 6.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 6.0),
        reactive_power_limits = (min = 0.0, max = 6.0),
        ramp_limits = nothing,
        time_limits = nothing,
        base_power = 100.0,
        operation_cost =PSY.HydroGenerationCost( variable = FuelCurve(
                    value_curve = LinearCurve(10.0),
                    fuel_cost = 0.0
                    ), fixed = 5.0),
        services = PSY.Device[], 
        dynamic_injector = nothing, 
        ext = Dict{String, Any}(),
    ),
    PSY.HydroEnergyReservoir(;
        name = "HydroEnergyReservoir_2",
        available = true,
        bus = nodes5[3],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 7.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 7.0),
        reactive_power_limits = (min = 0.0, max = 7.0),
        ramp_limits = (up = 7.0, down = 7.0),
        time_limits = nothing,
        operation_cost = PSY.HydroGenerationCost( variable = FuelCurve(
                    value_curve = LinearCurve(2.50),
                    fuel_cost = 0.0
                    ), fixed = 2.5),
        base_power = 100.0,
        storage_capacity = 50.0,
        inflow = 4.0,
        conversion_factor = 1.0,
        initial_storage = 0.5,
    ),
    PSY.HydroPumpedStorage(;
        name = "HydroPumpedStorage",
        available = true,
        bus = nodes5[3],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 5.0,
        base_power = 100.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 5.0),
        reactive_power_limits = (min = 0.0, max = 5.0),
        ramp_limits = (up = 10.0 * 0.5, down = 10.0 * 0.5),
        time_limits = nothing,
        operation_cost = PSY.HydroGenerationCost( variable = FuelCurve(
                    value_curve = LinearCurve(2.50),
                    fuel_cost = 0.0
                    ), fixed = 2.5),
        rating_pump = 0.2,
        active_power_limits_pump = (min = 0.0, max = 10.0),
        reactive_power_limits_pump = (min = 0.0, max = 10.0),
        ramp_limits_pump = (up = 10.0 * 0.6, down = 10.0 * 0.6),
        time_limits_pump = nothing,
        storage_capacity = (up = 25.0, down = 25.0), # 50 pu * hr (i.e. 5 GWh)
        inflow = 3.0,
        outflow = 1.0,
        initial_storage = (up = 0.5, down = 0.5),
        storage_target = (up = 0.5, down = 0.75),
        conversion_factor = 1.0,
        pump_efficiency = 1.0,
    ),
];

#=hydro_generators5_ems(nodes5) = [
    PSY.HydroDispatch(
        name = "HydroDispatch",
        available = true,
        bus = nodes5[2],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 6.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 6.0),
        reactive_power_limits = (min = 0.0, max = 6.0),
        ramp_limits = nothing,
        time_limits = nothing,
        base_power = 100.0,
    ),
    PSY.HydroEnergyReservoir(
        name = "HydroEnergyReservoir",
        available = true,
        bus = nodes5[3],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 7.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 7.0),
        reactive_power_limits = (min = 0.0, max = 7.0),
        ramp_limits = (up = 7.0, down = 7.0),
        time_limits = nothing,
        operation_cost = PSY.StorageManagementCost(
            variable = PSY.VariableCost(0.15),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 0.0,
        ),
        base_power = 100.0,
        storage_capacity = 50.0,
        inflow = 4.0,
        conversion_factor = 1.0,
        initial_storage = 0.5,
    ),
];=#

#=phes5(nodes5) = [
    PSY.HydroPumpedStorage(
        name = "HydroPumpedStorage",
        available = true,
        bus = nodes5[3],
        active_power = 0.0,
        reactive_power = 0.0,
        rating = 5.0,
        base_power = 100.0,
        prime_mover_type = PrimeMovers.HY,
        active_power_limits = (min = 0.0, max = 5.0),
        reactive_power_limits = (min = 0.0, max = 5.0),
        ramp_limits = (up = 10.0 * 0.5, down = 10.0 * 0.5),
        time_limits = nothing,
        operation_cost = PSY.TwoPartCost(0.15, 0.0),
        rating_pump = 0.2,
        active_power_limits_pump = (min = 0.0, max = 10.0),
        reactive_power_limits_pump = (min = 0.0, max = 10.0),
        ramp_limits_pump = (up = 10.0 * 0.6, down = 10.0 * 0.6),
        time_limits_pump = nothing,
        storage_capacity = (up = 25.0, down = 25.0), # 50 pu * hr (i.e. 5 GWh)
        inflow = 3.0,
        outflow = 1.0,
        initial_storage = (up = 0.5, down = 0.5),
        storage_target = (up = 0.5, down = 0.75),
        conversion_factor = 1.0,
        pump_efficiency = 1.0,
    ),
];=#

battery5(nodes5) = [PSY.EnergyReservoirStorage(;
    name = "GenericBattery",
    prime_mover_type = PrimeMovers.BA,
    available = true,
    bus = nodes5[1],
    initial_energy = 2.0,
    state_of_charge_limits = (min = 0.05, max = 4.0),
    rating = 4.0,
    active_power = 4.0,
    input_active_power_limits = (min = 0.0, max = 2.0),
    output_active_power_limits = (min = 0.0, max = 2.0),
    efficiency = (in = 0.80, out = 0.90),
    reactive_power = 0.0,
    reactive_power_limits = (min = -2.0, max = 2.0),
    base_power = 100.0,
),
    PSY.EnergyReservoirStorage(;
         name = "BatteryEMS",
         prime_mover_type = PrimeMovers.BA,
         available = true,
         bus = nodes5[1],
         initial_energy = 5.0,
         state_of_charge_limits = (min = .10, max = 7.0),
         rating = 7.0,
         active_power = 2.0,
         input_active_power_limits = (min = 0.0, max = 2.0),
         output_active_power_limits = (min = 0.0, max = 2.0),
         efficiency = (in = 0.80, out = 0.90),
         reactive_power = 0.0,
         reactive_power_limits = (min = -2.0, max = 2.0),
         base_power = 100.0,
         storage_target=0.2,
         operation_cost = PSY.StorageManagementCost(
            variable = PSY.VariableCost(0.0),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 40.0,
         ),
     )
];

#=batteryems5(nodes5) = [
     PSY.BatteryEMS(;
         name = "Bat2",
         prime_mover_type = PrimeMovers.BA,
         available = true,
         bus = nodes5[1],
         initial_energy = 5.0,
         state_of_charge_limits = (min = .10, max = 7.0),
         rating = 7.0,
         active_power = 2.0,
         input_active_power_limits = (min = 0.0, max = 2.0),
         output_active_power_limits = (min = 0.0, max = 2.0),
         efficiency = (in = 0.80, out = 0.90),
         reactive_power = 0.0,
         reactive_power_limits = (min = -2.0, max = 2.0),
         base_power = 100.0,
         storage_target=0.2,
         operation_cost = PSY.StorageManagementCost(
            variable = PSY.VariableCost(0.0),
            fixed = 0.0,
            start_up = 0.0,
            shut_down = 0.0,
            energy_shortage_cost = 50.0,
            energy_surplus_cost = 40.0,
         ),
     )
 ];=#

loadbus2_ts_DA = [
    0.792729978
    0.723201574
    0.710952098
    0.677672816
    0.668249175
    0.67166919
    0.687608809
    0.711821241
    0.756320618
    0.7984057
    0.827836527
    0.840362459
    0.84511032
    0.834592803
    0.822949221
    0.816941743
    0.824079963
    0.905735139
    0.989967048
    1
    0.991227765
    0.960842114
    0.921465115
    0.837001437
]

loadbus3_ts_DA = [
    0.831093782
    0.689863228
    0.666058513
    0.627033103
    0.624901388
    0.62858924
    0.650734211
    0.683424321
    0.750876413
    0.828347191
    0.884248576
    0.888523615
    0.87752169
    0.847534405
    0.8227661
    0.803809323
    0.813282799
    0.907575962
    0.98679848
    1
    0.990489904
    0.952520972
    0.906611479
    0.824307054
]

loadbus4_ts_DA = [
    0.871297342
    0.670489749
    0.642812243
    0.630092987
    0.652991383
    0.671971681
    0.716278493
    0.770885833
    0.810075243
    0.85562361
    0.892440566
    0.910660449
    0.922135467
    0.898416969
    0.879816542
    0.896390855
    0.978598576
    0.96523761
    1
    0.969626503
    0.901212601
    0.81894251
    0.771004923
    0.717847996
]

loads5(nodes5) = [
    PowerLoad(
        "Bus2",
        true,
        nodes5[2],
        3.0,
        0.9861,
        100.0,
        3.0,
        0.9861,
    ),
    PowerLoad(
        "Bus3",
        true,
        nodes5[3],
        3.0,
        0.9861,
        100.0,
        3.0,
        0.9861,
    ),
    PowerLoad(
        "Bus4",
        true,
        nodes5[4],
        4.0,
        1.3147,
        100.0,
        4.0,
        1.3147,
    ),
];

interruptible(nodes5) = [InterruptibleLoad(
    "IloadBus4",
    true,
    nodes5[4],
    LoadModels.ConstantPower,
    1.00,
    0.0,
    1.00,
    0.0,
    100.0,
    TwoPartCost(1.50, 24.0),
)]

ORDC_cost = [(9000.0, 0.0), (6000.0, 0.2), (500.0, 0.4), (10.0, 0.6), (0.0, 0.8)]

reserve5(thermal_generators5) = [
    VariableReserve{ReserveUp}(
        "Reserve1",
        true,
        0.6,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.001,
    ),
    VariableReserve{ReserveDown}(
        "Reserve2",
        true,
        0.3,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.005,
    ),
    VariableReserve{ReserveUp}(
        "Reserve11",
        true,
        0.8,
        maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.001,
    ),
    ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6),
    VariableReserveNonSpinning("NonSpinningReserve", true, 0.5, maximum([gen.active_power_limits[:max] for gen in thermal_generators5]) .* 0.001),
]

reserve5_re(renewable_generators5) = [
    VariableReserve{ReserveUp}("Reserve3", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve4", true, 5, 50),
    ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6),
]
reserve5_hy(hydro_generators5) = [
    VariableReserve{ReserveUp}("Reserve5", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve6", true, 5, 50),
    ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6),
]

reserve5_il(interruptible_loads) = [
    VariableReserve{ReserveUp}("Reserve7", true, 30, 100),
    VariableReserve{ReserveDown}("Reserve8", true, 5, 50),
    ReserveDemandCurve{ReserveUp}(nothing, "ORDC1", true, 0.6),
]

ORDC_cost_ts = [
    TimeSeries.TimeArray(DayAhead, repeat([ORDC_cost], 24)),
    TimeSeries.TimeArray(DayAhead + Day(1), repeat([ORDC_cost], 24)),
]

# TODO: add a sensible cost for hybrid devices
hybrid_cost_ts = [
    TimeSeries.TimeArray(DayAhead, repeat([25.0], 24)),
    TimeSeries.TimeArray(DayAhead + Day(1), repeat([25.0], 24)),
]

Reserve_ts = [TimeSeries.TimeArray(DayAhead, rand(24)), TimeSeries.TimeArray(DayAhead + Day(1), rand(24))]

hydro_timeseries_DA = [
    [TimeSeries.TimeArray(DayAhead, hydro_inflow_ts_DA)],
    [TimeSeries.TimeArray(DayAhead + Day(1), ones(24) * 0.1 + hydro_inflow_ts_DA)],
];

storage_target = zeros(24)
storage_target[end] = 0.1
storage_target_DA = [
   [TimeSeries.TimeArray(DayAhead, storage_target)],
   [TimeSeries.TimeArray(DayAhead + Day(1), storage_target)],
];

hydro_budget_DA = [
    [TimeSeries.TimeArray(DayAhead, hydro_inflow_ts_DA * 0.8)],
    [TimeSeries.TimeArray(DayAhead + Day(1), hydro_inflow_ts_DA * 0.8)],
];

RealTime = collect(
    DateTime("1/1/2024 0:00:00", "d/m/y H:M:S"):Minute(5):DateTime(
        "1/1/2024 23:55:00",
        "d/m/y H:M:S",
    ),
)

hydro_timeseries_RT = [
    [TimeSeries.TimeArray(RealTime, repeat(hydro_inflow_ts_DA, inner = 12))],
    [TimeSeries.TimeArray(RealTime + Day(1), ones(288) * 0.1 + repeat(hydro_inflow_ts_DA, inner = 12))],
];

storage_target_RT = [
    [TimeSeries.TimeArray(RealTime, repeat(storage_target, inner = 12))],
    [TimeSeries.TimeArray(RealTime + Day(1), repeat(storage_target, inner = 12))],
];

hydro_budget_RT = [
    [TimeSeries.TimeArray(RealTime, repeat(hydro_inflow_ts_DA  * 0.8, inner = 12))],
    [TimeSeries.TimeArray(RealTime + Day(1), repeat(hydro_inflow_ts_DA  * 0.8, inner = 12))],
];

hybrid_cost_ts_RT = [
    [TimeSeries.TimeArray(RealTime, repeat([25.0], 288))],
    [TimeSeries.TimeArray(RealTime + Day(1), ones(288) * 0.1 + repeat([25.0], 288))],
];

load_timeseries_RT = [
    [
        TimeSeries.TimeArray(RealTime, repeat(loadbus2_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime, repeat(loadbus3_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime, repeat(loadbus4_ts_DA, inner = 12)),
    ],
    [
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.01 + repeat(loadbus2_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.01 + repeat(loadbus3_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.01 + repeat(loadbus4_ts_DA, inner = 12)),
    ],
]

ren_timeseries_RT = [
    [
        TimeSeries.TimeArray(RealTime, repeat(solar_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime, repeat(wind_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime, repeat(wind_ts_DA, inner = 12)),
    ],
    [
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(solar_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(wind_ts_DA, inner = 12)),
        TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(wind_ts_DA, inner = 12)),
    ],
]

Iload_timeseries_RT = [
    [TimeSeries.TimeArray(RealTime, repeat(loadbus4_ts_DA, inner = 12))],
    [TimeSeries.TimeArray(RealTime + Day(1), rand(288) * 0.1 + repeat(loadbus4_ts_DA, inner = 12))],
]

load_timeseries_DA = [
    [
        TimeSeries.TimeArray(DayAhead, loadbus2_ts_DA),
        TimeSeries.TimeArray(DayAhead, loadbus3_ts_DA),
        TimeSeries.TimeArray(DayAhead, loadbus4_ts_DA),
    ],
    [
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus2_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus3_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + loadbus4_ts_DA),
    ],
];

ren_timeseries_DA = [
    [
        TimeSeries.TimeArray(DayAhead, solar_ts_DA),
        TimeSeries.TimeArray(DayAhead, wind_ts_DA),
        TimeSeries.TimeArray(DayAhead, wind_ts_DA),
    ],
    [
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + solar_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + wind_ts_DA),
        TimeSeries.TimeArray(DayAhead + Day(1), rand(24) * 0.1 + wind_ts_DA),
    ],
];

Iload_timeseries_DA = [
    [TimeSeries.TimeArray(DayAhead, loadbus4_ts_DA)],
    [TimeSeries.TimeArray(DayAhead + Day(1), loadbus4_ts_DA + 0.1 * rand(24))],
]

"""
Create PowerLASCOPF System from PSY System
"""
function power_lascopf_system5()
    println("Creating PowerLASCOPF System from PSY System...")
    log_info("Creating PowerLASCOPF System from PSY System...")
    system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
    
    println("Created PowerLASCOPF System ")
    log_info("Created PowerLASCOPF System ")
    return system
end

"""
Create PowerLASCOPF Nodes from PSY Buses
"""
function powerlascopf_nodes5!(system::PowerLASCOPF.PowerLASCOPFSystem)
    println("Creating PowerLASCOPF Nodes from PSY Buses...")
    log_info("Creating PowerLASCOPF Nodes from PSY Buses...")
    psy_buses = nodes5()
    nodes = PowerLASCOPF.Node{PSY.Bus}[]

    for (i, bus) in enumerate(psy_buses)
        println("PSY bus name", PSY.get_name(bus))  # just to suppress unused variable warning
        log_info("PSY bus name: $(PSY.get_name(bus))")
        # Create PowerLASCOPF.Node parameterized on PSY.Bus
        node = PowerLASCOPF.Node{PSY.Bus}(bus, i, 0,)
        PSY.add_component!(system.psy_system, bus)
        PowerLASCOPF.add_node!(system, node)
        push!(nodes, node)
    end
    println("=" ^ 50)
    println("PSY System after adding nodes: ", system.psy_system)
    log_info("PSY System after adding nodes: $(system.psy_system)")
    println("PowerLASCOPF System after adding nodes: ", system)
    log_info("PowerLASCOPF System after adding nodes: $(system)")
    println("Node vector from 5 bus file", nodes)
    log_info("Node vector from 5 bus file: $(nodes)")
    println("Node vector from PowerLASCOPF struct", system.nodes)
    log_info("Node vector from PowerLASCOPF struct: $(system.nodes)")
    PSY.show_components(system.psy_system, PSY.ACBus)
    log_info("Showing PSY ACBus components in the system.")
    println("Created $(length(nodes)) PowerLASCOPF Nodes from PSY Buses.")
    log_info("Created $(length(nodes)) PowerLASCOPF Nodes from PSY Buses.")
    println("=" ^ 50)
    return nodes
end

"""
Create PowerLASCOPF transmission lines from PSY Branches
"""
function powerlascopf_branches5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}}, cont_count::Int, RND_int::Int)
    println("Creating PowerLASCOPF Transmission Lines from PSY Branches...")
    log_info("Creating PowerLASCOPF Transmission Lines from PSY Branches...")
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_branches = branches5(existing_buses)
    contingency_list = branches_5_contingency_list()
    transmission_lines = PowerLASCOPF.transmissionLine[]
    contingency_tracker = 0
    
    for (i, branch) in enumerate(psy_branches)
        if isa(branch, PSY.Line)
            # Find corresponding nodes
            from_bus_name = PSY.get_name(PSY.get_from(PSY.get_arc(branch)))
            to_bus_name = PSY.get_name(PSY.get_to(PSY.get_arc(branch)))
            
            from_node = findfirst(n -> PSY.get_name(n.node_type) == from_bus_name, nodes)
            to_node = findfirst(n -> PSY.get_name(n.node_type) == to_bus_name, nodes)

            if i in contingency_list
                println("Branch $(i) is in the contingency list.")
                log_info("Branch $(i) is in the contingency list.")
                contingency_tracker += 1
                temp_tracker = contingency_tracker
            else
                temp_tracker = 0
            end

            # Create PowerLASCOPF.LineSolverBase for the line
            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr = randn(cont_count * (RND_int-1)),
                interval_type = PowerLASCOPF.LineBaseInterval(),
                E_coeff = [0.9^i for i in 1:RND_int],
                Pt_next_nu = zeros(cont_count * (RND_int-1)),
                BSC = 0.1 * randn(cont_count * (RND_int-1)),
                E_temp_coeff = 0.01 * randn(RND_int, RND_int),
                alpha_factor = 0.05,
                beta_factor = 0.1,
                beta = 0.1,
                gamma = 0.2,
                Pt_max = 1000.0,
                temp_init = 340.0,
                temp_amb = 300.0,
                max_temp = 473.0,
                RND_int = 1,
                cont_count = cont_count
            )
            
            # Create PowerLASCOPF.transmissionLine parameterized on PSY.Line
            trans_line = PowerLASCOPF.transmissionLine{PSY.Line}(
                transl_type = branch,
                solver_line_base = solver_base,
                transl_id = i,
                conn_nodet1_ptr = nodes[from_node],
                conn_nodet2_ptr = nodes[to_node],
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0,
                thetat2 = 0.0,
                pt1 = 0.0,
                pt2 = 0.0,
                v1 = 0.0,
                v2 = 0.0
            )
            
            # Assign connection nodes
            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)
            
        elseif isa(branch, PSY.HVDCLine)
            # Handle HVDC lines similarly
            from_bus_name = PSY.get_name(PSY.get_from(PSY.get_arc(branch)))
            to_bus_name = PSY.get_name(PSY.get_to(PSY.get_arc(branch)))
            
            from_node = findfirst(n -> PSY.get_name(n.bus_data) == from_bus_name, nodes)
            to_node = findfirst(n -> PSY.get_name(n.bus_data) == to_bus_name, nodes)

            if i in contingency_list
                println("Branch $(i) is in the contingency list.")
                log_info("Branch $(i) is in the contingency list.")
                contingency_tracker += 1
                temp_tracker = contingency_tracker
            else
                temp_tracker = 0
            end
            
            solver_base = PowerLASCOPF.LineSolverBase(
                lambda_txr = [0.0],
                interval_type = MockLineInterval(),
                E_coeff = [1.0],
                Pt_next_nu = [0.0],
                BSC = [0.0],
                E_temp_coeff = reshape([0.1], 1, 1),
                RND_int = 1,
                cont_count = 1
            )
            
            # Create PowerLASCOPF.transmissionLine parameterized on PSY.HVDCLine
            trans_line = PowerLASCOPF.transmissionLine{PSY.HVDCLine}(
                transl_type = branch,
                solver_line_base = solver_base,
                transl_id = i,
                conn_nodet1_ptr = nodes[from_node],
                conn_nodet2_ptr = nodes[to_node],
                cont_scen_tracker = temp_tracker,
                thetat1 = 0.0,
                thetat2 = 0.0,
                pt1 = 0.0,
                pt2 = 0.0,
                v1 = 0.0,
                v2 = 0.0
            )
            
            PowerLASCOPF.assign_conn_nodes(trans_line)
            PowerLASCOPF.add_transmission_line!(system, trans_line)
            push!(transmission_lines, trans_line)
        end
    end
    println("=" ^ 50)
    println("PSY System after adding branches: ", system.psy_system)
    log_info("PSY System after adding branches: $(system.psy_system)")
    println("PowerLASCOPF System after adding branches: ", system)
    log_info("PowerLASCOPF System after adding branches: $(system)")
    #println("Transmission Lines vector from 5 bus file", transmission_lines)
    #println("Transmission Lines vector from PowerLASCOPF struct", system.transmission_lines)
    PSY.show_components(system.psy_system, PSY.Line)
    #PSY.show_components(system.psy_system, PSY.HVDCLine)
    println("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from PSY Branches.")
    log_info("Created $(length(transmission_lines)) PowerLASCOPF Transmission Lines from PSY Branches.")
    println("=" ^ 50)
    return transmission_lines
end

"""
Create PowerLASCOPF GeneralizedGenerators from PSY Thermal Generators
"""
function powerlascopf_thermal_generators5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}})
    println("Creating PowerLASCOPF Thermal Generators from PSY Thermal Generators...")
    log_info("Creating PowerLASCOPF Thermal Generators from PSY Thermal Generators...")
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_gens = thermal_generators5(existing_buses)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    
    for (i, gen) in enumerate(psy_gens)
        # Find corresponding node
        bus_name = PSY.get_name(PSY.get_bus(gen))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        
        if node_idx === nothing
            error("Could not find node for generator $(PSY.get_name(gen))")
            log_error("Could not find node for generator $(PSY.get_name(gen))")
        end
        
        # Create proper GenFirstBaseInterval with all required parameters
        gen_interval = PowerLASCOPF.GenFirstBaseInterval(
            zeros(7),    # lambda_1
            zeros(7),    # lambda_2
            zeros(7),    # B
            zeros(7),    # D
            zeros(6),    # BSC
            6,      # cont_count
            0.1,    # rho
            0.1,    # beta
            0.1,    # beta_inner
            0.2,    # gamma
            0.2,    # gamma_sc
            zeros(6), # lambda_1_sc
            0.0,    # Pg_N_init
            0.0,    # Pg_N_avg
            0.0,    # thetag_N_avg
            0.0,    # ug_N
            1.0,    # vg_N
            1.0,    # Vg_N_avg
            0.0,    # Pg_nu
            0.0,    # Pg_nu_inner
            zeros(6), # Pg_next_nu
            0.0     # Pg_prev
        )
        
        # Create thermal cost function with proper interval
        extended_cost_first_base = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            gen_interval
        )
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_first_base)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstBaseIntervalDZ(nothing)
        )
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContInterval(nothing)
        )
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContIntervalDZ(nothing)
        )
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastBaseInterval(nothing)
        )
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRNDInterval(nothing)
        )
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRSDInterval(nothing)
        )
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedThermalGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastContInterval(nothing)
        )
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_thermal_gen = PowerLASCOPF.ExtendedThermalGenerator(
            gen, extended_cost_first_base, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )
        
        
        # Create GeneralizedGenerator parameterized on ThermalStandard
        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )
        PowerLASCOPF.add_extended_thermal_generator!(system, extended_thermal_gen)
        push!(generators, lascopf_gen)
    end
    println("=" ^ 50)
    println("PSY System after adding Thermal Generators: ", system.psy_system)
    log_info("PSY System after adding Thermal Generators: $(system.psy_system)")
    println("PowerLASCOPF System after adding Thermal Generators: ", system)
    log_info("PowerLASCOPF System after adding Thermal Generators: $(system)")
    #println("Thermal Generator vector from 5 bus file", generators)
    #println("Thermal Generator vector from PowerLASCOPF struct", system.extended_thermal_generators)
    PSY.show_components(system.psy_system, PSY.ThermalStandard)
    println("Created $(length(generators)) PowerLASCOPF Generators from PSY Thermal Generators.")
    log_info("Created $(length(generators)) PowerLASCOPF Generators from PSY Thermal Generators.")
    println("=" ^ 50)
    return generators
end

"""
Create PowerLASCOPF GeneralizedGenerators from PSY Renewable Generators
"""
function powerlascopf_renewable_generators5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}})
    println("Creating PowerLASCOPF Variable Renewable Energy (VRE) Generators from PSY Variable Renewable Energy (VRE) Generators...")
    log_info("Creating PowerLASCOPF Variable Renewable Energy (VRE) Generators from PSY Variable Renewable Energy (VRE) Generators...")
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_gens = renewable_generators5(existing_buses)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    
    for (i, gen) in enumerate(psy_gens)
        # Find corresponding node
        bus_name = PSY.get_name(PSY.get_bus(gen))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        
        if node_idx === nothing
            error("Could not find node for generator $(PSY.get_name(gen))")
            log_error("Could not find node for generator $(PSY.get_name(gen))")
        end

        # Create proper GenFirstBaseInterval with all required parameters
        gen_interval = PowerLASCOPF.GenFirstBaseInterval(
            zeros(7),    # lambda_1
            zeros(7),    # lambda_2
            zeros(7),    # B
            zeros(7),    # D
            zeros(6),    # BSC
            6,      # cont_count
            0.1,    # rho
            0.1,    # beta
            0.1,    # beta_inner
            0.2,    # gamma
            0.2,    # gamma_sc
            zeros(6), # lambda_1_sc
            0.0,    # Pg_N_init
            0.0,    # Pg_N_avg
            0.0,    # thetag_N_avg
            0.0,    # ug_N
            1.0,    # vg_N
            1.0,    # Vg_N_avg
            0.0,    # Pg_nu
            0.0,    # Pg_nu_inner
            zeros(6), # Pg_next_nu
            0.0     # Pg_prev
        )
        
        # Create thermal cost function with proper interval
        extended_cost_first_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            gen_interval
        )
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_first_base)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstBaseIntervalDZ(nothing)
        )
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContInterval(nothing)
        )
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContIntervalDZ(nothing)
        )
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastBaseInterval(nothing)
        )
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRNDInterval(nothing)
        )
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRSDInterval(nothing)
        )
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastContInterval(nothing)
        )
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_renewable_gen = PowerLASCOPF.ExtendedRenewableGenerator(
            gen, extended_cost_first_base, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )

        PowerLASCOPF.add_extended_renewable_generator!(system, extended_renewable_gen)

        # Add renewable timeseries data
        if PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.WT
            wind_data = TimeSeries.TimeArray(DayAhead, wind_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("max_active_power", wind_data))
        elseif PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.PV
            solar_data = TimeSeries.TimeArray(DayAhead, solar_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("max_active_power", solar_data))
        end
        
        # Create GeneralizedGenerator parameterized on RenewableDispatch
        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )
        
        push!(generators, lascopf_gen)
    end
    println("=" ^ 50)
    println("PSY System after adding Renewable Generators: ", system.psy_system)
    log_info("PSY System after adding Renewable Generators: $(system.psy_system)")
    println("PowerLASCOPF System after adding Renewable Generators: ", system)
    log_info("PowerLASCOPF System after adding Renewable Generators: $(system)")
    #println("Renewable Generator vector from 5 bus file", generators)
    #println("Renewable Generator vector from PowerLASCOPF struct", system.extended_renewable_generators)
    PSY.show_components(system.psy_system, PSY.RenewableDispatch)
    println("Created $(length(generators)) PowerLASCOPF Generators from PSY Renewable Generators.")
    log_info("Created $(length(generators)) PowerLASCOPF Generators from PSY Renewable Generators.")
    println("=" ^ 50)
    return generators
end

"""
Create PowerLASCOPF GeneralizedGenerators from PSY Hydro Generators
"""
function powerlascopf_hydro_generators5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}})
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_gens = hydro_generators5(existing_buses)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    
    for (i, gen) in enumerate(psy_gens)
        # Find corresponding node
        bus_name = PSY.get_name(PSY.get_bus(gen))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        
        if node_idx === nothing
            error("Could not find node for generator $(PSY.get_name(gen))")
            log_error("Could not find node for generator $(PSY.get_name(gen))")
        end

        # Create proper GenFirstBaseInterval with all required parameters
        gen_interval = PowerLASCOPF.GenFirstBaseInterval(
            zeros(7),    # lambda_1
            zeros(7),    # lambda_2
            zeros(7),    # B
            zeros(7),    # D
            zeros(6),    # BSC
            6,      # cont_count
            0.1,    # rho
            0.1,    # beta
            0.1,    # beta_inner
            0.2,    # gamma
            0.2,    # gamma_sc
            zeros(6), # lambda_1_sc
            0.0,    # Pg_N_init
            0.0,    # Pg_N_avg
            0.0,    # thetag_N_avg
            0.0,    # ug_N
            1.0,    # vg_N
            1.0,    # Vg_N_avg
            0.0,    # Pg_nu
            0.0,    # Pg_nu_inner
            zeros(6), # Pg_next_nu
            0.0     # Pg_prev
        )
        
        # Create thermal cost function with proper interval
        extended_cost_first_base = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            gen_interval
        )
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_first_base)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstBaseIntervalDZ(nothing)
        )
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContInterval(nothing)
        )
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContIntervalDZ(nothing)
        )
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastBaseInterval(nothing)
        )
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRNDInterval(nothing)
        )
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRSDInterval(nothing)
        )
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedHydroGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastContInterval(nothing)
        )
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_hydro_gen = PowerLASCOPF.ExtendedHydroGenerator(
            gen, extended_cost_first_base, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )

        PowerLASCOPF.add_extended_hydro_generator!(system, extended_hydro_gen)

        #=# Create hydro cost function
        if isa(gen, PSY.HydroEnergyReservoir)
            cost_function = PowerLASCOPF.ExtendedHydroGenerationCost{StandardGenIntervals}(
                variable_cost = PSY.get_variable(PSY.get_operation_cost(gen)),
                fixed_cost = PSY.get_fixed(PSY.get_operation_cost(gen)),
                storage_cost = 0.0,
                spillage_cost = 10.0,
                base_power = PSY.get_base_power(gen)
            )
        else
            cost_function = PowerLASCOPF.ExtendedHydroGenerationCost{StandardGenIntervals}(
                variable_cost = 0.0,
                fixed_cost = 0.0,
                storage_cost = 0.0,
                spillage_cost = 10.0,
                base_power = PSY.get_base_power(gen)
            )
        end=#
        
        # Create solver
        #gen_solver = PowerLASCOPF.GenSolver{typeof(gen), StandardGenIntervals}()
        # Add hydro timeseries data
        # Add hydro inflow timeseries
        if isa(gen, PSY.HydroEnergyReservoir)
            inflow_data = TimeSeries.TimeArray(DayAhead, hydro_inflow_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("inflow", inflow_data))
        else
            hydro_data = TimeSeries.TimeArray(DayAhead, hydro_inflow_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("max_active_power", hydro_data))
        end

        # Create GeneralizedGenerator parameterized on RenewableDispatch
        lascopf_gen = PowerLASCOPF.GeneralizedGenerator(
            gen, gen_interval, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )
        
        push!(generators, lascopf_gen)
    end
    println("=" ^ 50)
    println("PSY System after adding Hydro Generators: ", system.psy_system)
    log_info("PSY System after adding Hydro Generators: $(system.psy_system)")
    println("PowerLASCOPF System after adding Hydro Generators: ", system)
    log_info("PowerLASCOPF System after adding Hydro Generators: $(system)")
    #println("Hydro Generator vector from 5 bus file", generators)
    #println("Hydro Generator vector from PowerLASCOPF struct", system.extended_hydro_generators)
    PSY.show_components(system.psy_system, PSY.HydroDispatch)
    println("Created $(length(generators)) PowerLASCOPF Generators from PSY Hydro Generators.")
    log_info("Created $(length(generators)) PowerLASCOPF Generators from PSY Hydro Generators.")
    println("=" ^ 50)
    return generators
    
    return generators
end

"""Create PowerLASCOPF GeneralizedGenerators from PSY Storage Generators
"""

function power_lascopf_storage_generators5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}})
    println("Creating PowerLASCOPF Storage Generators from PSY Storage Generators...")
    log_info("Creating PowerLASCOPF Storage Generators from PSY Storage Generators...")
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_gens = storage_generators5(existing_buses)
    generators = PowerLASCOPF.GeneralizedGenerator[]
    
    for (i, gen) in enumerate(psy_gens)
        # Find corresponding node
        bus_name = PSY.get_name(PSY.get_bus(gen))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        
        if node_idx === nothing
            error("Could not find node for generator $(PSY.get_name(gen))")
            log_error("Could not find node for generator $(PSY.get_name(gen))")
        end

        # Create proper GenFirstBaseInterval with all required parameters
        gen_interval = PowerLASCOPF.GenFirstBaseInterval(
            zeros(7),    # lambda_1
            zeros(7),    # lambda_2
            zeros(7),    # B
            zeros(7),    # D
            zeros(6),    # BSC
            6,      # cont_count
            0.1,    # rho
            0.1,    # beta
            0.1,    # beta_inner
            0.2,    # gamma
            0.2,    # gamma_sc
            zeros(6), # lambda_1_sc
            0.0,    # Pg_N_init
            0.0,    # Pg_N_avg
            0.0,    # thetag_N_avg
            0.0,    # ug_N
            1.0,    # vg_N
            1.0,    # Vg_N_avg
            0.0,    # Pg_nu
            0.0,    # Pg_nu_inner
            zeros(6), # Pg_next_nu
            0.0     # Pg_prev
        )
        
        # Create thermal cost function with proper interval
        extended_cost_first_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            gen_interval
        )
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_first_base)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstBaseIntervalDZ(nothing)
        )
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContInterval(nothing)
        )
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContIntervalDZ(nothing)
        )
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastBaseInterval(nothing)
        )
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRNDInterval(nothing)
        )
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRSDInterval(nothing)
        )
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastContInterval(nothing)
        )
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)

        extended_renewable_gen = PowerLASCOPF.ExtendedRenewableGenerator(
            gen, extended_cost_first_base, i, 1, false, 6, 7, 1, 0, 1, nodes[node_idx], 6
        )

        PowerLASCOPF.add_extended_renewable_generator!(system, extended_renewable_gen)

        # Add renewable timeseries data
        if PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.WT
            wind_data = TimeSeries.TimeArray(DayAhead, wind_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("max_active_power", wind_data))
        elseif PSY.get_prime_mover_type(gen) == PSY.PrimeMovers.PV
            solar_data = TimeSeries.TimeArray(DayAhead, solar_ts_DA)
            PSY.add_time_series!(system, gen, PSY.SingleTimeSeries("max_active_power", solar_data))
        end
        
        # Create storage cost function
        cost_function = PowerLASCOPF.ExtendedStorageGenerationCost{StandardGenIntervals}(
            variable_cost = PSY.get_variable(PSY.get_operation_cost(gen)),
            fixed_cost = PSY.get_fixed(PSY.get_operation_cost(gen)),
            base_power = PSY.get_base_power(gen)
        )
        
        # Create solver
        gen_solver = PowerLASCOPF.GenSolver{typeof(gen), StandardGenIntervals}()
        
        # Create GeneralizedGenerator parameterized on StorageGen
        lascopf_gen = PowerLASCOPF.GeneralizedGenerator{typeof(gen), StandardGenIntervals}(
            generator = gen,
            cost_function = cost_function,
            id_of_gen = i,
            interval = 1,
            last_flag = false,
            cont_scenario_count = 2,
            gensolver = gen_solver,
            PC_scenario_count = 1,
            baseCont = 0,
            dummyZero = 0,
            accuracy = 1,
            nodeConng = nodes[node_idx],
            countOfContingency = 2,
            gen_total = length(psy_gens)
        )
        
        push!(generators, lascopf_gen)
    end
    println("Created $(length(generators)) PowerLASCOPF Generators from PSY Storage Generators.")
    log_info("Created $(length(generators)) PowerLASCOPF Generators from PSY Storage Generators.")
    return generators
end

"""
Create PowerLASCOPF Loads from PSY Loads
"""

function powerlascopf_loads5!(system::PowerLASCOPF.PowerLASCOPFSystem, nodes::Vector{PowerLASCOPF.Node{PSY.Bus}})
    println("Creating PowerLASCOPF Loads from PSY Loads...")
    log_info("Creating PowerLASCOPF Loads from PSY Loads...")
    #Get the buses that are already in the system
    existing_buses = [node.node_type for node in nodes]
    psy_loads = loads5(existing_buses)
    loads = PowerLASCOPF.Load[]

    # Create a mapping of node indices to load timeseries
    load_timeseries_map = Dict(
        2 => loadbus2_ts_DA,
        3 => loadbus3_ts_DA,
        4 => loadbus4_ts_DA
    )
    
    for (i, load) in enumerate(psy_loads)
        # Find corresponding node
        bus_name = PSY.get_name(PSY.get_bus(load))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        
        if node_idx === nothing
            error("Could not find node for load $(PSY.get_name(load))")
            log_error("Could not find node for load $(PSY.get_name(load))") 
        end

        #=WE'LL NEED THIS ONLY FOR DEFERRABLE FLEXIBLE LOAD
        # Create proper GenFirstBaseInterval with all required parameters
        gen_interval = PowerLASCOPF.GenFirstBaseInterval(
            zeros(7),    # lambda_1
            zeros(7),    # lambda_2
            zeros(7),    # B
            zeros(7),    # D
            zeros(6),    # BSC
            6,      # cont_count
            0.1,    # rho
            0.1,    # beta
            0.1,    # beta_inner
            0.2,    # gamma
            0.2,    # gamma_sc
            zeros(6), # lambda_1_sc
            0.0,    # Pg_N_init
            0.0,    # Pg_N_avg
            0.0,    # thetag_N_avg
            0.0,    # ug_N
            1.0,    # vg_N
            1.0,    # Vg_N_avg
            0.0,    # Pg_nu
            0.0,    # Pg_nu_inner
            zeros(6), # Pg_next_nu
            0.0     # Pg_prev
        )
        
        # Create thermal cost function with proper interval
        extended_cost_first_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            gen_interval
        )
        gensolver_first_base = PowerLASCOPF.GenSolver(gen_interval, extended_cost_first_base)

        extended_cost_first_base_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstBaseIntervalDZ(nothing)
        )
        gensolver_first_base_dz = PowerLASCOPF.GenSolver(extended_cost_first_base_dz.regularization_term, extended_cost_first_base_dz)

        extended_cost_first_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContInterval(nothing)
        )
        gensolver_first_cont = PowerLASCOPF.GenSolver(extended_cost_first_cont.regularization_term, extended_cost_first_cont)

        extended_cost_first_cont_dz = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenFirstContIntervalDZ(nothing)
        )
        gensolver_first_cont_dz = PowerLASCOPF.GenSolver(extended_cost_first_cont_dz.regularization_term, extended_cost_first_cont_dz)

        extended_cost_last_base = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastBaseInterval(nothing)
        )
        gensolver_last_base = PowerLASCOPF.GenSolver(extended_cost_last_base.regularization_term, extended_cost_last_base)

        extended_cost_RND = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRNDInterval(nothing)
        )
        gensolver_RND = PowerLASCOPF.GenSolver(extended_cost_RND.regularization_term, extended_cost_RND)

        extended_cost_RSD = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenInterRSDInterval(nothing)
        )
        gensolver_RSD = PowerLASCOPF.GenSolver(extended_cost_RSD.regularization_term, extended_cost_RSD)

        extended_cost_last_cont = PowerLASCOPF.ExtendedRenewableGenerationCost(
            gen.operation_cost,
            PowerLASCOPF.GenLastContInterval(nothing)
        )
        gensolver_last_cont = PowerLASCOPF.GenSolver(extended_cost_last_cont.regularization_term, extended_cost_last_cont)=#

        lascopf_load = PowerLASCOPF.Load(
            load, i, PSY.get_active_power(load)
        )

        PowerLASCOPF.add_extended_load!(system, lascopf_load)

        # Get the correct timeseries data based on node index
        if haskey(load_timeseries_map, node_idx)
            load_data = TimeSeries.TimeArray(DayAhead, load_timeseries_map[node_idx])
            PSY.add_time_series!(system.psy_system, load, PSY.SingleTimeSeries("max_active_power", load_data))
        else
            @warn "No timeseries data found for node $node_idx, using default values"
            log_warn("No timeseries data found for node $node_idx, using default values")
            # Use a default timeseries or handle the missing data case
            default_load_data = TimeSeries.TimeArray(DayAhead, ones(24) * PSY.get_active_power(load))
            PSY.add_time_series!(system.psy_system, load, PSY.SingleTimeSeries("max_active_power", default_load_data))
        end
        
        #=# Create PowerLASCOPF.Load parameterized on PSY.Load
        lascopf_load = PowerLASCOPF.Load{PSY.Load}(
            load_type = load,
            load_id = i,
            conn_nodet_ptr = nodes[node_idx],
            P_load = 0.0,
            Q_load = 0.0
        )=#
        
        push!(loads, lascopf_load)
    end
    println("=" ^ 50)
    println("PSY System after adding Electric Loads: ", system.psy_system)
    log_info("PSY System after adding Electric Loads: $(system.psy_system)")
    println("PowerLASCOPF System after adding Electric Loads: ", system)
    log_info("PowerLASCOPF System after adding Electric Loads: $(system)")
    #println("Electric Load vector from 5 bus file", loads)
    #println("Electric Load vector from PowerLASCOPF struct", system.extended_loads)
    PSY.show_components(system.psy_system, PSY.PowerLoad)
    println("Created $(length(loads)) PowerLASCOPF Loads from PSY Loads.")
    log_info("Created $(length(loads)) PowerLASCOPF Loads from PSY Loads.")
    println("=" ^ 50)
    return loads
end

"""
Create complete PowerLASCOPF system data
"""
function create_5bus_powerlascopf_system()
    print("Creating 5-bus PowerLASCOPF system...")
    log_info("Creating 5-bus PowerLASCOPF system...")
    # Create components using existing PowerLASCOPF structs
    cont_count = 2  # Number of contingencies
    RND_int = 4     # Number of random intervals for line modeling
    system = power_lascopf_system5()
    nodes = powerlascopf_nodes5!(system)
    branches = powerlascopf_branches5!(system, nodes, cont_count, RND_int)
    thermal_gens = powerlascopf_thermal_generators5!(system, nodes)
    renewable_gens = powerlascopf_renewable_generators5!(system, nodes)
    hydro_gens = powerlascopf_hydro_generators5!(system, nodes)
    loads = powerlascopf_loads5!(system, nodes)
    #storage_gens = power_lascopf_storage_generators5!(system, nodes)  # No storage in this example

    # Create system data dictionary (using existing PowerLASCOPF pattern)
    system_data = Dict(
        "name" => "5-Bus Test System",
        "nodes" => nodes,
        "branches" => branches,
        "thermal_generators" => thermal_gens,
        "renewable_generators" => renewable_gens,
        "hydro_generators" => hydro_gens,
        #"storage_generators" => GeneralizedGenerator[],
        "loads" => loads,  # Keep PSY loads for now
        "base_power" => 100.0,
        "time_horizon" => DayAhead,
        "scenarios" => create_scenarios()
    )
    
    return system, system_data
end

"""
Create scenario data for stochastic optimization
"""
function create_scenarios()
    scenarios = Dict[]
    
    # Base case scenario
    base_scenario = Dict(
        "scenario_id" => 1,
        "name" => "Base Case",
        "probability" => 0.8,
        "contingencies" => Dict[],
        "renewable_forecasts" => Dict(
            "wind" => wind_ts_DA,
            "solar" => solar_ts_DA
        ),
        "load_forecasts" => Dict(
            "bus2" => loadbus2_ts_DA,
            "bus3" => loadbus3_ts_DA,
            "bus4" => loadbus4_ts_DA
        ),
        "hydro_inflows" => hydro_inflow_ts_DA
    )
    push!(scenarios, base_scenario)
    
    # Contingency scenarios
    contingency_scenario = Dict(
        "scenario_id" => 2,
        "name" => "Line 1 Outage",
        "probability" => 0.2,
        "contingencies" => [Dict(
            "id" => 1,
            "name" => "Line_1_outage",
            "component_type" => "Line",
            "component_id" => 1,
            "outage_probability" => 1.0
        )],
        "renewable_forecasts" => Dict(
            "wind" => wind_ts_DA * 0.9,
            "solar" => solar_ts_DA * 0.95
        ),
        "load_forecasts" => Dict(
            "bus2" => loadbus2_ts_DA,
            "bus3" => loadbus3_ts_DA,
            "bus4" => loadbus4_ts_DA
        ),
        "hydro_inflows" => hydro_inflow_ts_DA * 0.8
    )
    push!(scenarios, contingency_scenario)
    
    return scenarios
end

"""
Function to create Supernetwork objects for PowerLASCOPF systems
"""

#="""
Function to create Supernetwork objects for PowerLASCOPF systems
"""
function create_supernetwork(system_data::Dict; kwargs...)
    println("Creating Supernetwork for PowerLASCOPF system...")
    
    # Extract components from system data
    nodes = system_data["nodes"]
    branches = system_data["branches"]
    thermal_generators = system_data["thermal_generators"]
    renewable_generators = system_data["renewable_generators"]
    loads = system_data["loads"]
    
    # Get scenario information
    scenarios = system_data["scenarios"]
    time_horizon = system_data["time_horizon"]
    base_power = system_data["base_power"]
    
    # Combine all generators
    all_generators = vcat(thermal_generators, renewable_generators)
    # Add hydro and storage generators if they exist
    if haskey(system_data, "hydro_generators")
        append!(all_generators, system_data["hydro_generators"])
    end
    if haskey(system_data, "storage_generators")
        append!(all_generators, system_data["storage_generators"])
    end
    
    # Create network topology matrices (adjacency, incidence, etc.)
    n_nodes = length(nodes)
    n_branches = length(branches)
    
    # Create adjacency matrix
    adjacency_matrix = zeros(Int, n_nodes, n_nodes)
    for branch in branches
        from_idx = branch.conn_nodet1_ptr.node_id
        to_idx = branch.conn_nodet2_ptr.node_id
        adjacency_matrix[from_idx, to_idx] = 1
        adjacency_matrix[to_idx, from_idx] = 1
    end
    
    # Create incidence matrix (branches x nodes)
    incidence_matrix = zeros(Int, n_branches, n_nodes)
    for (i, branch) in enumerate(branches)
        from_idx = branch.conn_nodet1_ptr.node_id
        to_idx = branch.conn_nodet2_ptr.node_id
        incidence_matrix[i, from_idx] = 1
        incidence_matrix[i, to_idx] = -1
    end
    
    # Create generator-to-node mapping
    gen_node_map = Dict{Int, Int}()
    for (i, gen) in enumerate(all_generators)
        gen_node_map[i] = gen.nodeConng.node_id
    end
    
    # Create load-to-node mapping
    load_node_map = Dict{Int, Int}()
    for (i, load) in enumerate(loads)
        # Assuming load has a connection to node - adjust based on actual Load struct
        bus_name = PSY.get_name(PSY.get_bus(load.load_type))
        node_idx = findfirst(n -> PSY.get_name(n.node_type) == bus_name, nodes)
        load_node_map[i] = node_idx
    end
    
    # Create contingency scenarios mapping
    contingency_map = Dict{Int, Vector{Int}}()
    for (scenario_idx, scenario) in enumerate(scenarios)
        if haskey(scenario, "contingencies") && !isempty(scenario["contingencies"])
            contingent_components = Int[]
            for contingency in scenario["contingencies"]
                if contingency["component_type"] == "Line"
                    push!(contingent_components, contingency["component_id"])
                end
            end
            contingency_map[scenario_idx] = contingent_components
        else
            contingency_map[scenario_idx] = Int[]  # Base case, no contingencies
        end
    end
    
    # Extract additional parameters from kwargs
    cont_count = get(kwargs, :cont_count, 2)
    RND_int = get(kwargs, :RND_int, 4)
    accuracy = get(kwargs, :accuracy, 1e-6)
    max_iterations = get(kwargs, :max_iterations, 1000)
    
    # Create Supernetwork object
    supernetwork = PowerLASCOPF.Supernetwork(
        # Core network components
        nodes = nodes,
        transmission_lines = branches,
        generators = all_generators,
        loads = loads,
        
        # Network topology
        adjacency_matrix = adjacency_matrix,
        incidence_matrix = incidence_matrix,
        
        # Component mappings
        generator_node_map = gen_node_map,
        load_node_map = load_node_map,
        
        # Scenario and contingency data
        scenarios = scenarios,
        contingency_map = contingency_map,
        n_scenarios = length(scenarios),
        
        # System parameters
        base_power = base_power,
        time_horizon = time_horizon,
        n_time_steps = length(time_horizon),
        
        # Algorithm parameters
        cont_count = cont_count,
        RND_int = RND_int,
        accuracy = accuracy,
        max_iterations = max_iterations,
        
        # Network dimensions
        n_nodes = n_nodes,
        n_branches = n_branches,
        n_generators = length(all_generators),
        n_loads = length(loads),
        
        # ADMM/consensus parameters (if using distributed algorithms)
        rho = get(kwargs, :rho, 0.1),
        beta = get(kwargs, :beta, 0.1),
        gamma = get(kwargs, :gamma, 0.2)
    )
    
    # Initialize network state variables
    initialize_supernetwork_state!(supernetwork)
    
    println("Created Supernetwork with:")
    println("  - $(n_nodes) nodes")
    println("  - $(n_branches) transmission lines") 
    println("  - $(length(all_generators)) generators")
    println("  - $(length(loads)) loads")
    println("  - $(length(scenarios)) scenarios")
    
    return supernetwork
end
=#
"""
Initialize state variables for the supernetwork
"""
#=function initialize_supernetwork_state!(supernetwork::PowerLASCOPF.Supernetwork)
    # Initialize node state variables
    for node in supernetwork.nodes
        node.P_net = 0.0
        node.theta_node = 0.0
        node.v_node = 1.0  # Start at nominal voltage
        node.u = 0.0       # Dual variable
    end
    
    # Initialize transmission line state variables
    for line in supernetwork.transmission_lines
        line.pt1 = 0.0
        line.pt2 = 0.0
        line.thetat1 = 0.0
        line.thetat2 = 0.0
        line.v1 = 1.0
        line.v2 = 1.0
    end
    
    # Initialize generator state variables (if they have state fields)
    for gen in supernetwork.generators
        # Initialize generator-specific state variables
        # This depends on the specific GeneralizedGenerator implementation
    end
    
    println("Initialized supernetwork state variables")
end

"""
Update the create_5bus_powerlascopf_system function to use the improved create_supernetwork
"""
function create_5bus_powerlascopf_system_with_supernetwork()
    println("Creating 5-bus PowerLASCOPF system with Supernetwork...")
    
    # Create base system data
    system, system_data = create_5bus_powerlascopf_system()
    
    # Create supernetwork with additional parameters
    supernetwork = create_supernetwork(
        system_data,
        cont_count = 2,
        RND_int = 4,
        accuracy = 1e-6,
        max_iterations = 1000,
        rho = 0.1,
        beta = 0.1,
        gamma = 0.2
    )
    
    # Add supernetwork to system data
    system_data["supernetwork"] = supernetwork
    
    return system_data
end=#

"""
Function to create SuperNetwork objects for PowerLASCOPF systems
Returns a vector of SuperNetwork objects based on the intervals and contingencies
"""
function create_supernetwork(system::PowerLASCOPF.PowerLASCOPFSystem, system_data::Dict; 
    number_of_cont::Int = 6,
    rnd_intervals::Int = 6,
    rsd_intervals::Int = 6,
    include_dummy_zero::Bool = false,
    choice_solver::Int = 1,
    rho_tuning::Float64 = 1.0,
    contin_sol_accuracy::Int = 1,
    kwargs...)
    
    println("Creating SuperNetwork objects for PowerLASCOPF system...")

    # Validate contingency scenarios before proceeding
    validate_contingency_scenarios(number_of_cont)
    
    # Get all contingency mappings for reference
    contingency_map = get_all_contingency_mappings()
    println("Available contingency scenarios:")
    for (scenario, line) in sort(collect(contingency_map))
        if scenario == 0
            println("  Scenario $scenario: Base case (no outage)")
        else
            println("  Scenario $scenario: Line $line outaged")
        end
    end
    
    # Calculate total number of SuperNetwork objects needed
    total_intervals = rnd_intervals + rsd_intervals
    base_networks = 1 + (total_intervals * (1 + number_of_cont)) # 1 for the no-outage base case
    
    if include_dummy_zero
        total_supernetworks = 1 + base_networks
        start_interval = -1  # Include dummy zero interval
    else
        total_supernetworks = base_networks
        start_interval = 0
    end
    
    println("Creating $total_supernetworks SuperNetwork objects...")
    println("  - RND intervals: $rnd_intervals")
    println("  - RSD intervals: $rsd_intervals") 
    println("  - Number of contingencies: $number_of_cont")
    println("  - Include dummy zero: $include_dummy_zero")
    
    supernetworks = PowerLASCOPF.SuperNetwork[]
    network_id_counter = 1
    
    # Create SuperNetwork objects for each dispatch interval
    for disp_interval in start_interval:(total_intervals)
        
        # Determine interval class
        if disp_interval < 0
            interval_class = 0  # dummy
        elseif disp_interval == 0 || disp_interval == total_intervals
            interval_class = 1  # forthcoming  or last
        else
            interval_class = 2  # subsequent to forthcoming
        end
        
        # Determine if this is the last interval
        last_flag = (disp_interval == total_intervals)
        
        # For dummy interval, create only one network
        if disp_interval < 0
            println("\n  Creating dummy interval network (ID: $network_id_counter)")

            super_net = PowerLASCOPF.create_supernetwork_object(
                powerlascopf_system = system,
                pre_post_scenario = false,        # Indicate dummy interval
                network_id = network_id_counter,
                cont_net_vector = PowerLASCOPFSystem[],  # Initialize empty
                solver_choice = choice_solver,          # ✓ Correct parameter name
                set_rho_tuning = rho_tuning,            # ✓ Correct parameter name
                post_contingency = 0,                   # ✓ Correct parameter name
                interval_count = disp_interval,         # ✓ Correct parameter name
                interval_class = interval_class,        # ✓ Correct parameter name
                rnd_intervals = rnd_intervals,
                rsd_intervals = rsd_intervals,
                last_interval = false,                  # ✓ Correct parameter name
                outaged_line = 0,                       # ✓ Correct parameter name
                number_of_cont = number_of_cont,
                number_of_generators = 0,               # Will be updated later
                number_of_trans_lines = 0,              # Will be updated later
                cons_lag_dim = 0,                       # Will be calculated later
                alpha_app = 100.0,                      # Default value
                iter_count_app = 1,                     # Default value
                fin_tol = 1000.0,                       # Default value
                largest_net_time_vec = Float64[],       # Initialize empty
                single_net_time_vec = Float64[],        # Initialize empty
                virtual_net_exec_time = 0.0,            # Default value
                matrix_result_app_out = Dict{Any,Any}() # Initialize empty
            )
            push!(supernetworks, super_net)
            network_id_counter += 1
            
        elseif disp_interval == 0
            # For regular intervals, create base case network
            # Forthcoming interval - create base case only
            println("\n  Creating forthcoming interval $disp_interval (Base case, ID: $network_id_counter)")
            
            base_super_net = PowerLASCOPF.create_supernetwork_object(
                powerlascopf_system = system,
                pre_post_scenario = false,
                network_id = network_id_counter,
                cont_net_vector = PowerLASCOPFSystem[],
                solver_choice = choice_solver,
                set_rho_tuning = rho_tuning,
                post_contingency = 0,
                interval_count = disp_interval,
                interval_class = interval_class,
                rnd_intervals = rnd_intervals,
                rsd_intervals = rsd_intervals,
                last_interval = last_flag,
                outaged_line = 0,
                number_of_cont = number_of_cont,
                number_of_generators = 0,
                number_of_trans_lines = 0,
                cons_lag_dim = 0,
                alpha_app = 100.0,
                iter_count_app = 1,
                fin_tol = 1000.0,
                largest_net_time_vec = Float64[],
                single_net_time_vec = Float64[],
                virtual_net_exec_time = 0.0,
                matrix_result_app_out = Dict{Any,Any}()
            )
            push!(supernetworks, base_super_net)
            network_id_counter += 1
        else
            # Regular intervals - create base case + contingency scenarios
            println("\n  Creating interval $disp_interval networks:")
            
            # Base case (contingency scenario 0)
            println("    - Base case (ID: $network_id_counter)")
            base_super_net = PowerLASCOPF.create_supernetwork_object(
                powerlascopf_system = system,
                pre_post_scenario = false,
                network_id = network_id_counter,
                solver_choice = choice_solver,
                set_rho_tuning = rho_tuning,
                post_contingency = 0,
                interval_count = disp_interval,
                interval_class = interval_class,
                rnd_intervals = rnd_intervals,
                rsd_intervals = rsd_intervals,
                last_interval = last_flag,
                outaged_line = 0,  # No outage for base case
                number_of_cont = number_of_cont
            )
            push!(supernetworks, base_super_net)
            network_id_counter += 1

            # Create contingency scenario networks for this interval
            for cont_scenario in 1:number_of_cont
                # Determine outaged line for this contingency
                outaged_line = get_outaged_line_for_contingency(cont_scenario)
                
                cont_super_net = PowerLASCOPF.create_supernetwork_object(
                    powerlascopf_system = system,
                    pre_post_scenario = true,
                    network_id = network_id_counter,
                    cont_net_vector = PowerLASCOPFSystem[],
                    solver_choice = choice_solver,
                    set_rho_tuning = rho_tuning,
                    post_contingency = cont_scenario,
                    interval_count = disp_interval,
                    interval_class = interval_class,
                    rnd_intervals = rnd_intervals,
                    rsd_intervals = rsd_intervals,
                    last_interval = last_flag,
                    outaged_line = outaged_line,
                    number_of_cont = number_of_cont,
                    number_of_generators = 0,
                    number_of_trans_lines = 0,
                    cons_lag_dim = 0,
                    alpha_app = 100.0,
                    iter_count_app = 1,
                    fin_tol = 1000.0,
                    largest_net_time_vec = Float64[],
                    single_net_time_vec = Float64[],
                    virtual_net_exec_time = 0.0,
                    matrix_result_app_out = Dict{Any,Any}()
                )
                push!(supernetworks, cont_super_net)
                network_id_counter += 1
            end
        end
    end
    
    println("\n✓ Created $(length(supernetworks)) SuperNetwork objects")
    
    # Print summary
    println("\nSuperNetwork Summary:")
    for (i, snet) in enumerate(supernetworks)
        interval_type = if snet.interval_count < 0
            "Dummy"
        elseif snet.interval_count == 0
            "Forthcoming"
        elseif snet.interval_count == total_intervals
            "Last"
        else
            "Subsequent"
        end
        
        contingency_desc = if snet.post_contingency == 0
            "Base case"
        else
            "Contingency $(snet.post_contingency) (Line $(snet.outaged_line))"
        end
        
        println("  [$i] ID=$(snet.network_id), Interval=$(snet.interval_count) ($interval_type), $contingency_desc")
    end
    
    return supernetworks
end

"""
Helper function to determine outaged line for a given contingency scenario.
Creates the mapping dynamically from the contingency list defined in the system.
Returns 0 for base case (no contingency).
"""
function get_outaged_line_for_contingency(contingency_index::Int)
    # Return 0 for base case (no outage)
    if contingency_index == 0
        return 0
    end
    
    # Get the contingency list from the system definition
    contingency_lines = branches_5_contingency_list()
    
    # Validate contingency index
    if contingency_index < 0 || contingency_index > length(contingency_lines)
        @warn "Invalid contingency index $contingency_index. Valid range: 0-$(length(contingency_lines)). Returning 0 (no outage)."
        return 0
    end
    
    # Return the line ID for this contingency scenario
    outaged_line_id = contingency_lines[contingency_index]
    
    println("  Contingency $contingency_index: Outaging line $outaged_line_id")
    
    return outaged_line_id
end

"""
Alternative version that returns a dictionary mapping for all contingencies at once.
Useful for initialization and validation.
"""
function get_all_contingency_mappings()
    contingency_lines = branches_5_contingency_list()
    
    # Create dictionary: contingency_scenario => outaged_line_id
    contingency_map = Dict{Int, Int}()
    
    # Base case (no contingency)
    contingency_map[0] = 0
    
    # Add all contingency scenarios
    for (idx, line_id) in enumerate(contingency_lines)
        contingency_map[idx] = line_id
    end
    
    return contingency_map
end

"""
Validate that contingency scenarios are consistent with the system definition.
"""
function validate_contingency_scenarios(number_of_cont::Int)
    available_contingencies = length(branches_5_contingency_list())
    
    if number_of_cont > available_contingencies
        error("Requested $number_of_cont contingencies, but only $available_contingencies are defined in branches_5_contingency_list()")
    end
    
    if number_of_cont < 0
        error("Number of contingencies must be non-negative, got $number_of_cont")
    end
    
    println("✓ Contingency validation passed: Using $number_of_cont out of $available_contingencies available contingencies")
    return true
end

"""
Updated create_5bus_powerlascopf_system function to use the new supernetwork creation
"""
#=function create_5bus_powerlascopf_system_with_supernetworks()
    println("Creating 5-bus PowerLASCOPF system with SuperNetworks...")
    
    # Create base system data
    system, system_data = create_5bus_powerlascopf_system()
    
    
    
    return system_data
end=#

"""
Helper function to get SuperNetwork by interval and contingency scenario
"""
function get_supernetwork(supernetworks::Vector{SuperNetwork}, 
                         interval::Int, 
                         contingency::Int = 0)
    for snet in supernetworks
        if snet.interval_count == interval && snet.post_contingency == contingency
            return snet
        end
    end
    return nothing
end

"""
Helper function to get all SuperNetworks for a specific interval
"""
function get_interval_supernetworks(supernetworks::Vector{SuperNetwork}, interval::Int)
    return filter(snet -> snet.interval_count == interval, supernetworks)
end

"""
Validation function to check if the correct number of SuperNetworks were created
"""
function validate_supernetwork_count(supernetworks::Vector{SuperNetwork}, 
                                   rnd_intervals::Int, 
                                   rsd_intervals::Int, 
                                   number_of_cont::Int, 
                                   include_dummy_zero::Bool)
    
    total_intervals = rnd_intervals + rsd_intervals
    expected_count = if include_dummy_zero
        2 + (total_intervals * (1 + number_of_cont))
    else
        1 + (total_intervals * (1 + number_of_cont))
    end
    
    actual_count = length(supernetworks)
    
    if actual_count == expected_count
        println("✓ SuperNetwork count validation passed: $actual_count networks created")
        return true
    else
        println("✗ SuperNetwork count validation failed: expected $expected_count, got $actual_count")
        return false
    end
end

"""
Run validation after creating supernetworks
"""
function create_and_validate_supernetworks(system_data::Dict; kwargs...)
    supernetworks = create_supernetwork(system_data; kwargs...)
    
    # Extract parameters for validation
    rnd_intervals = get(kwargs, :rnd_intervals, 6)
    rsd_intervals = get(kwargs, :rsd_intervals, 6)
    number_of_cont = get(kwargs, :number_of_cont, 2)
    include_dummy_zero = get(kwargs, :include_dummy_zero, false)
    
    # Validate count
    is_valid = validate_supernetwork_count(
        supernetworks, 
        rnd_intervals, 
        rsd_intervals, 
        number_of_cont, 
        include_dummy_zero
    )
    
    if !is_valid
        error("SuperNetwork creation validation failed")
    end
    
    return supernetworks
end

function create_supernetwork(system_data::Dict, kwargs...)
    print("Creating Supernetwork for PowerLASCOPF system...")
    # Extract components from system data
    nodes = system_data["nodes"]
    branches = system_data["branches"]
    generators = vcat(system_data["thermal_generators"], system_data["renewable_generators"])  # Add hydro/storage if present
    loads = system_data["loads"]
    
    # Create Supernetwork
    supernetwork = PowerLASCOPF.Supernetwork(
        nodes,
        branches,
        generators,
        loads
    )
    
    return supernetwork
end

"""
Helper functions for PowerLASCOPF.Node operations (needed for ADMM/APP)
"""

# Add these helper functions to support the simulation
function p_avg_message(node::PowerLASCOPF.Node{PSY.Bus})
    return node.P_net  # Simplified - in full implementation would average connected devices
end

function theta_avg_message(node::PowerLASCOPF.Node{PSY.Bus})
    return node.theta_node
end

function v_avg_message(node::PowerLASCOPF.Node{PSY.Bus})
    return node.v_node
end

function u_message!(node::PowerLASCOPF.Node{PSY.Bus})
    return node.u
end

function get_power_balance(node::PowerLASCOPF.Node{PSY.Bus})
    # Calculate power balance at node (simplified)
    return node.P_net  # In full implementation: generation - load - transmission flows
end

function update_node_averages!(node::PowerLASCOPF.Node{PSY.Bus})
    # Update node average variables from connected devices
    # This is a simplified version - full implementation would average all connected devices
    node.P_net = 0.0  # Placeholder
    node.theta_node = 0.0  # Placeholder
    return node.P_net  # In full implementation: generation - load - transmission flows
end

function update_node_averages!(node::PowerLASCOPF.Node{PSY.Bus})
    # Update node average variables from connected devices
    # This is a simplified version - full implementation would average all connected devices
    node.P_net = 0.0  # Placeholder
    node.theta_node = 0.0  # Placeholder
end

"""
Create POMDP-integrated 5-bus system
"""
function create_5bus_pomdp_system()
    print("Creating 5-bus POMDP system...")
    # Create base system
    system_data = create_5bus_powerlascopf_system()
    
    # Create POMDP
    pomdp = create_pomdp_from_system_data(system_data)
    
    # Create belief updater
    updater = PowerSystemBeliefUpdater(
        pomdp,
        Dict("load" => 0.01, "renewable" => 0.02),  # process noise
        Dict("load" => 0.005, "renewable" => 0.01, "voltage" => 0.01, "flow" => 0.02),  # measurement noise
        100,  # n_particles
        0.5   # resampling threshold
    )
    
    # Create policies
    mpc_policy = MPCPolicy(pomdp, horizon=6, receding=1)
    robust_policy = RobustPolicy(pomdp, conservatism=0.1)
    
    return Dict(
        "pomdp" => pomdp,
        "updater" => updater,
        "mpc_policy" => mpc_policy,
        "robust_policy" => robust_policy,
        "system_data" => system_data
    )
end

"""
Run POMDP simulation for 5-bus system
"""
function run_pomdp_simulation(n_steps::Int = 24)
    println("Starting POMDP simulation for 5-bus system...")
    pritn("Creating the system...")
    # Create system
    pomdp_system = create_5bus_pomdp_system()
    pomdp = pomdp_system["pomdp"]
    updater = pomdp_system["updater"]
    policy = pomdp_system["mpc_policy"]
    
    # Initialize belief
    initial_belief = POMDPTools.initialize_belief(updater, nothing)
    
    # Simulation loop
    belief = initial_belief
    total_reward = 0.0
    states = []
    actions = []
    observations = []
    
    # Create initial state
    current_state = PowerSystemState(
        trues(length(pomdp.transmission_lines)),  # All lines operational
        [3.0, 3.0, 4.0],  # Load demands
        [0.8, 0.6],       # Renewable forecasts
        ones(length(pomdp.transmission_lines)),  # Line capacities
        zeros(length(pomdp.generators)),  # Generator outputs
        ones(length(pomdp.nodes)),       # PowerLASCOPF.Node voltages
        zeros(length(pomdp.nodes)),      # PowerLASCOPF.Node angles
        1, 1,  # Time step, scenario
        Dict{String, Distribution}()
    )
    
    for step in 1:n_steps
        # Select action using policy
        action = POMDPs.action(policy, belief)
        
        # Simulate system response
        next_state_dist = POMDPs.transition(pomdp, current_state, action)
        next_state = rand(next_state_dist)
        
        # Get observation
        obs_dist = POMDPs.observation(pomdp, action, next_state)
        observation = rand(obs_dist)
        
        # Calculate reward
        reward = POMDPs.reward(pomdp, current_state, action, next_state)
        total_reward += reward
        
        # Update belief
        belief = POMDPs.update(updater, belief, action, observation)
        
        # Store results
        push!(states, current_state)
        push!(actions, action)
        push!(observations, observation)
        
        # Move to next state
        current_state = next_state
        
        println("Step $step: Reward = $reward, Total = $total_reward")
    end
    
    return Dict(
        "total_reward" => total_reward,
        "states" => states,
        "actions" => actions,
        "observations" => observations,
        "final_belief" => belief
    )
end
