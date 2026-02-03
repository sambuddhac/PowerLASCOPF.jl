"""Datacenter Load Modeling Approaches
1. As Standard Loads (Simplest)
Use the existing Load component from components/load.jl:
"""
# Create a datacenter as a standard load
datacenter_load = Load(
    name = "Datacenter_Austin",
    bus_id = 1,
    active_power = 50.0,  # MW
    reactive_power = 10.0, # MVAr
    priority = "critical"  # Optional classification
)

add_component!(power_lascopf_system, datacenter_load)

"""2. With Time-Varying Demand (Recommended)
Leverage components/load_timeseries_integration.jl for realistic datacenter load patterns:
"""
# Define datacenter load profile (24-hour pattern)
hours = 1:24
base_load = 45.0  # MW base load
peak_load = 65.0  # MW peak during business hours

# Datacenter typically has flatter profile than residential
load_profile = [
    base_load + (peak_load - base_load) * 
    (0.2 + 0.8 * (9 <= h <= 18)) for h in hours
]

# Create load with time series
datacenter = create_load_with_timeseries(
    name = "AWS_Datacenter_1",
    bus_id = 5,
    power_profile = load_profile,
    reactive_profile = load_profile .* 0.2  # Power factor ~0.98
)
"""3. As Flexible/Controllable Load (Advanced)
Model datacenter with demand response capabilities:
"""
# Extend the Load type for datacenter-specific features
struct DatacenterLoad <: PowerLASCOPFComponent
    name::String
    bus_id::Int
    base_load::Float64        # Minimum load (MW)
    max_load::Float64         # Maximum load (MW)
    flexibility::Float64      # % that can be shifted/curtailed
    backup_generation::Bool   # Has on-site generators
    cooling_load_ratio::Float64  # Fraction for cooling (IT vs cooling)
end

# Add constraints for datacenter flexibility
function add_datacenter_constraints!(model, datacenter::DatacenterLoad)
    # Minimum uptime requirement
    # Backup generation availability
    # Cooling load coupling with IT load
end

"""Key Datacenter Load Characteristics to Model
High Load Factor: 70-90% (very flat load profile)
Power Quality: Need stable voltage/frequency
Redundancy: Often dual-feed from different substations
Cooling Load: 30-40% of total load is HVAC
Backup Power: Diesel generators + UPS systems
Demand Response: Some workload shifting capability
Integration with PowerSystems.jl
Since PowerLASCOPF uses PowerSystems.jl underneath, you can also leverage:
"""

# Create PSY load first, then convert
psy_datacenter = PSY.PowerLoad(
    name = "Datacenter_Metro",
    available = true,
    bus = psy_bus,
    active_power = 50.0,
    reactive_power = 10.0,
    max_active_power = 75.0,  # For curtailment studies
    max_reactive_power = 15.0
)

# Convert to PowerLASCOPF
convert_psy_system_to_power_lascopf!(psy_system, power_lascopf_system)

"""The existing load modeling infrastructure in PowerLASCOPF (especially load_timeseries_integration.jl) provides a solid foundation for datacenter loads. For specialized datacenter features like backup generation coordination or cooling optimization, you'd extend the base Load type."""