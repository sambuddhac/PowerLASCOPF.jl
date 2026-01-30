# Adding New IEEE Test Cases to PowerLASCOPF

## Overview

To add a new IEEE test case to PowerLASCOPF, you must provide data files in the **Sahar Format** and place them in the correct folder structure. This document describes the required format and folder organization.

### Available Test Cases with Sahar Format

The following IEEE test cases are currently available with complete Sahar format data:
- **IEEE 2 Bus** - Minimal test system
- **IEEE 3 Bus** - Simple three-bus system
- **IEEE 5 Bus** - Small test system
- **IEEE 14 Bus** - IEEE 14-bus test system
- **IEEE 30 Bus** - IEEE 30-bus test system
- **IEEE 48 Bus** - Medium-sized test system
- **IEEE 57 Bus** - IEEE 57-bus test system (reference example)
- **IEEE 118 Bus** - Large IEEE test system
- **IEEE 300 Bus** - Extra-large IEEE test system

All cases include complete Sahar format files and can be loaded using `data_reader_generic.jl`.

---

## Folder Structure

New test cases must be placed in:
```
example_cases/IEEE_Test_Cases/IEEE_<N>_bus/
```

Where `<N>` is the number of buses in your system (e.g., `IEEE_24_bus`, `IEEE_39_bus`, `IEEE_500_bus`).

---

## Required Files (Sahar Format)

For a complete test case, you need to provide the following CSV files:

| File Name | Description | Required |
|-----------|-------------|----------|
| `Nodes<N>_sahar.csv` | Bus/Node definitions | ✅ Yes |
| `ThermalGenerators<N>_sahar.csv` | Thermal generator data | ✅ Yes |
| `Trans<N>_sahar.csv` | Transmission line/branch data | ✅ Yes |
| `Loads<N>_sahar.csv` | Load data | ✅ Yes |
| `RenewableGenerators<N>_sahar.csv` | Renewable generators (solar, wind) | Optional |
| `HydroGenerators<N>_sahar.csv` | Hydro generators | Optional |
| `Storage<N>_sahar.csv` | Energy storage devices | Optional |

**Example for IEEE 24-bus system:**
```
example_cases/IEEE_Test_Cases/IEEE_24_bus/
├── Nodes24_sahar.csv
├── ThermalGenerators24_sahar.csv
├── Trans24_sahar.csv
├── Loads24_sahar.csv
├── RenewableGenerators24_sahar.csv  (optional)
├── HydroGenerators24_sahar.csv      (optional)
└── Storage24_sahar.csv              (optional)
```

---

## File Format Specifications

All files must be **comma-separated CSV** with headers in the first row.

### 1. Nodes File (`Nodes<N>_sahar.csv`)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| BusNumber | Int | Unique bus identifier | 1 |
| Name | String | Bus name | "Bus_1" |
| BusType | String | PV, PQ, or REF (slack) | "PV" |
| Angle | Float | Initial voltage angle (radians) | 0.0 |
| Magnitude | Float | Voltage magnitude (p.u.) | 1.0 |
| VoltageMin | Float | Minimum voltage (p.u.) | 0.95 |
| VoltageMax | Float | Maximum voltage (p.u.) | 1.05 |
| BaseVoltage | Float | Base voltage (kV) | 230.0 |
| Area | Int | Area number | 1 |
| Zone | Int | Zone number | 1 |
| LoadZone | String | Load zone name | "Zone1" |

**Example:**
```csv
BusNumber,Name,BusType,Angle,Magnitude,VoltageMin,VoltageMax,BaseVoltage,Area,Zone,LoadZone
1,Bus_1,REF,0.0,1.06,0.95,1.05,230.0,1,1,Zone1
2,Bus_2,PV,0.0,1.045,0.95,1.05,230.0,1,1,Zone1
3,Bus_3,PQ,0.0,1.0,0.95,1.05,230.0,1,1,Zone1
```

---

### 2. Thermal Generators File (`ThermalGenerators<N>_sahar.csv`)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| GeneratorID | Int | Unique generator ID | 1 |
| Name | String | Generator name | "Gen_1" |
| BusNumber | Int | Connected bus | 1 |
| Available | Bool | Is unit available | true |
| FuelType | String | Fuel type | "COAL" |
| PrimeType | String | Prime mover type | "ST" |
| ActivePowerMin | Float | Min power output (MW) | 50.0 |
| ActivePowerMax | Float | Max power output (MW) | 200.0 |
| ReactivePowerMin | Float | Min reactive power (MVAr) | -50.0 |
| ReactivePowerMax | Float | Max reactive power (MVAr) | 100.0 |
| RampUp | Float | Ramp up rate (MW/min) | 5.0 |
| RampDown | Float | Ramp down rate (MW/min) | 5.0 |
| MinUpTime | Float | Min up time (hours) | 4.0 |
| MinDownTime | Float | Min down time (hours) | 4.0 |
| CostCurve_a | Float | Quadratic cost coefficient ($/MW²) | 0.01 |
| CostCurve_b | Float | Linear cost coefficient ($/MW) | 20.0 |
| CostCurve_c | Float | Constant cost ($/hr) | 100.0 |
| StartupCost | Float | Startup cost ($) | 500.0 |
| ShutdownCost | Float | Shutdown cost ($) | 100.0 |
| BaseMVA | Float | Base MVA rating | 100.0 |

**Example:**
```csv
GeneratorID,Name,BusNumber,Available,FuelType,PrimeType,ActivePowerMin,ActivePowerMax,ReactivePowerMin,ReactivePowerMax,RampUp,RampDown,MinUpTime,MinDownTime,CostCurve_a,CostCurve_b,CostCurve_c,StartupCost,ShutdownCost,BaseMVA
1,Gen_1,1,true,COAL,ST,50.0,200.0,-50.0,100.0,5.0,5.0,4.0,4.0,0.01,20.0,100.0,500.0,100.0,100.0
2,Gen_2,2,true,NG,CT,20.0,100.0,-30.0,60.0,10.0,10.0,2.0,2.0,0.02,30.0,50.0,200.0,50.0,100.0
```

---

### 3. Transmission Lines File (`Trans<N>_sahar.csv`)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| BranchID | Int | Unique branch ID | 1 |
| Name | String | Branch name | "Line_1_2" |
| FromBus | Int | From bus number | 1 |
| ToBus | Int | To bus number | 2 |
| R | Float | Resistance (p.u.) | 0.01 |
| X | Float | Reactance (p.u.) | 0.05 |
| B | Float | Susceptance (p.u.) | 0.02 |
| RateA | Float | Normal rating (MVA) | 200.0 |
| RateB | Float | Short-term rating (MVA) | 220.0 |
| RateC | Float | Emergency rating (MVA) | 250.0 |
| TapRatio | Float | Transformer tap ratio | 1.0 |
| TapAngle | Float | Phase shift angle (deg) | 0.0 |
| Status | Int | In service (1) or out (0) | 1 |
| AngleMin | Float | Min angle difference (deg) | -360.0 |
| AngleMax | Float | Max angle difference (deg) | 360.0 |

**Example:**
```csv
BranchID,Name,FromBus,ToBus,R,X,B,RateA,RateB,RateC,TapRatio,TapAngle,Status,AngleMin,AngleMax
1,Line_1_2,1,2,0.01938,0.05917,0.0528,200.0,220.0,250.0,1.0,0.0,1,-360.0,360.0
2,Line_1_5,1,5,0.05403,0.22304,0.0492,150.0,165.0,180.0,1.0,0.0,1,-360.0,360.0
```

---

### 4. Loads File (`Loads<N>_sahar.csv`)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| LoadID | Int | Unique load ID | 1 |
| Name | String | Load name | "Load_1" |
| BusNumber | Int | Connected bus | 2 |
| Available | Bool | Is load active | true |
| ActivePower | Float | Active power demand (MW) | 50.0 |
| ReactivePower | Float | Reactive power demand (MVAr) | 20.0 |
| MaxActivePower | Float | Maximum active power (MW) | 60.0 |
| MaxReactivePower | Float | Maximum reactive power (MVAr) | 25.0 |
| LoadType | String | Load category | "Industrial" |
| Priority | Int | Load priority (1=highest) | 1 |

**Example:**
```csv
LoadID,Name,BusNumber,Available,ActivePower,ReactivePower,MaxActivePower,MaxReactivePower,LoadType,Priority
1,Load_2,2,true,21.7,12.7,25.0,15.0,Residential,2
2,Load_3,3,true,94.2,19.0,100.0,25.0,Industrial,1
```

---

### 5. Renewable Generators File (`RenewableGenerators<N>_sahar.csv`) - Optional

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| GeneratorID | Int | Unique generator ID | 1 |
| Name | String | Generator name | "Solar_1" |
| BusNumber | Int | Connected bus | 3 |
| Available | Bool | Is unit available | true |
| RenewableType | String | SOLAR or WIND | "SOLAR" |
| ActivePowerMax | Float | Max power output (MW) | 50.0 |
| ReactivePowerMin | Float | Min reactive power (MVAr) | -10.0 |
| ReactivePowerMax | Float | Max reactive power (MVAr) | 10.0 |
| PowerFactor | Float | Power factor | 0.95 |
| CurtailmentCost | Float | Curtailment cost ($/MWh) | 5.0 |
| BaseMVA | Float | Base MVA | 100.0 |

**Example:**
```csv
GeneratorID,Name,BusNumber,Available,RenewableType,ActivePowerMax,ReactivePowerMin,ReactivePowerMax,PowerFactor,CurtailmentCost,BaseMVA
1,Solar_1,3,true,SOLAR,50.0,-10.0,10.0,0.95,5.0,100.0
2,Wind_1,5,true,WIND,75.0,-15.0,15.0,0.90,3.0,100.0
```

---

### 6. Hydro Generators File (`HydroGenerators<N>_sahar.csv`) - Optional

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| GeneratorID | Int | Unique generator ID | 1 |
| Name | String | Generator name | "Hydro_1" |
| BusNumber | Int | Connected bus | 4 |
| Available | Bool | Is unit available | true |
| HydroType | String | ROR, STORAGE, PUMP | "ROR" |
| ActivePowerMin | Float | Min power output (MW) | 10.0 |
| ActivePowerMax | Float | Max power output (MW) | 100.0 |
| ReactivePowerMin | Float | Min reactive power (MVAr) | -30.0 |
| ReactivePowerMax | Float | Max reactive power (MVAr) | 50.0 |
| RampUp | Float | Ramp up rate (MW/min) | 10.0 |
| RampDown | Float | Ramp down rate (MW/min) | 10.0 |
| InitialStorage | Float | Initial storage (MWh) | 500.0 |
| StorageCapacity | Float | Max storage (MWh) | 1000.0 |
| InflowLimit | Float | Max inflow (MW) | 50.0 |
| CostCurve_a | Float | Quadratic cost ($/MW²) | 0.005 |
| CostCurve_b | Float | Linear cost ($/MW) | 5.0 |
| CostCurve_c | Float | Constant cost ($/hr) | 10.0 |
| BaseMVA | Float | Base MVA | 100.0 |

**Example:**
```csv
GeneratorID,Name,BusNumber,Available,HydroType,ActivePowerMin,ActivePowerMax,ReactivePowerMin,ReactivePowerMax,RampUp,RampDown,InitialStorage,StorageCapacity,InflowLimit,CostCurve_a,CostCurve_b,CostCurve_c,BaseMVA
1,Hydro_1,4,true,ROR,10.0,100.0,-30.0,50.0,10.0,10.0,0.0,0.0,50.0,0.005,5.0,10.0,100.0
2,Hydro_2,6,true,STORAGE,20.0,150.0,-40.0,60.0,15.0,15.0,500.0,1000.0,30.0,0.003,4.0,8.0,100.0
```

---

### 7. Storage File (`Storage<N>_sahar.csv`) - Optional

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| StorageID | Int | Unique storage ID | 1 |
| Name | String | Storage name | "Battery_1" |
| BusNumber | Int | Connected bus | 5 |
| Available | Bool | Is unit available | true |
| StorageType | String | Storage technology | "Li-Ion" |
| EnergyCapacity | Float | Energy capacity (MWh) | 100.0 |
| ChargeRateMax | Float | Max charge rate (MW) | 25.0 |
| DischargeRateMax | Float | Max discharge rate (MW) | 25.0 |
| ChargeEfficiency | Float | Charging efficiency | 0.95 |
| DischargeEfficiency | Float | Discharging efficiency | 0.95 |
| InitialEnergy | Float | Initial SOC (MWh) | 50.0 |
| MinEnergy | Float | Min SOC (MWh) | 10.0 |
| MaxEnergy | Float | Max SOC (MWh) | 90.0 |
| CycleCost | Float | Cycling cost ($/MWh) | 2.0 |
| BaseMVA | Float | Base MVA | 100.0 |

**Example:**
```csv
StorageID,Name,BusNumber,Available,StorageType,EnergyCapacity,ChargeRateMax,DischargeRateMax,ChargeEfficiency,DischargeEfficiency,InitialEnergy,MinEnergy,MaxEnergy,CycleCost,BaseMVA
1,Battery_1,5,true,Li-Ion,100.0,25.0,25.0,0.95,0.95,50.0,10.0,90.0,2.0,100.0
2,Battery_2,8,true,Li-Ion,200.0,50.0,50.0,0.92,0.92,100.0,20.0,180.0,1.5,100.0
```

---

## Per-Unit System

All electrical quantities should follow the per-unit system:

- **Base Power (BaseMVA)**: Typically 100 MVA
- **Impedances (R, X, B)**: In per-unit on system base
- **Voltages**: In per-unit (1.0 = nominal)
- **Power values**: In MW or MVAr (actual values, not per-unit)

---

## Validation Checklist

Before running your test case, verify:

1. ✅ All required files are present
2. ✅ File names follow the `*<N>_sahar.csv` convention
3. ✅ Bus numbers are consistent across all files
4. ✅ Generator and load bus references exist in the Nodes file
5. ✅ Branch FromBus and ToBus references exist in the Nodes file
6. ✅ At least one bus is marked as REF (slack bus)
7. ✅ Generator capacity is sufficient to meet load demand
8. ✅ All numerical values are reasonable (no negative capacities, etc.)

---

## Running Your New Case

Once files are in place, run your case with:

```bash
# From PowerLASCOPF.jl directory
julia --project=. examples/run_reader_generic.jl case=<N>bus

# Examples:
julia --project=. examples/run_reader_generic.jl case=24bus
julia --project=. examples/run_reader_generic.jl case=39bus
julia --project=. examples/run_reader_generic.jl case=500bus

# List all available cases:
julia --project=. examples/run_reader_generic.jl list

# Run all cases:
julia --project=. examples/run_reader_generic.jl all
```

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Case path not found" | Ensure folder is named `IEEE_<N>_bus` |
| "No nodes data found" | Check `Nodes<N>_sahar.csv` exists and is valid |
| "Load not fully satisfied" | Increase generator capacity or reduce load |
| "CSV parsing error" | Check for missing commas, wrong column types |
| "Bus not found" | Ensure all bus references exist in Nodes file |

---

## Contact

For questions about the Sahar data format, contact the PowerLASCOPF development team.

---

*Document Version: 1.0*  
*Last Updated: January 2026*
