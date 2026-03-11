# PowerLASCOPF Data Reader System

## 📋 Overview

This system **replaces hardcoded data arrays** with a **file-based data reading architecture**. Instead of modifying Julia code to change test cases, you can now:

1. ✅ Store data in **CSV or JSON files**
2. ✅ Use **one generic runner** for any case
3. ✅ Add new test cases by **adding data files** (no code changes)

---

## 🎯 Problem Solved

### **Before** (Old Approach):
```julia
# data_5bus_pu.jl - Hardcoded arrays
nodes5() = [
    PSY.ACBus(1, "nodeA", "REF", 0.0, 1.0, ...)
    PSY.ACBus(2, "nodeB", "PV", 0.0, 1.0, ...)
    # ... 50 more lines of hardcoded data
]

# Separate file for 14-bus
# data_14bus_pu.jl - Different hardcoded arrays
nodes14() = [
    # ... 100 more lines of hardcoded data
]
```

**Problems:**
- ❌ Data mixed with code (hard to maintain)
- ❌ Separate file needed for each test case
- ❌ Difficult to modify data (requires Julia knowledge)
- ❌ No standard format for sharing data

### **After** (New Approach):
```csv
# Nodes5_sahar.csv - Data in spreadsheet
BusNumber,BusName,BusType,Angle,Voltage,VoltageMin,VoltageMax,BaseVoltage
1,nodeA,REF,0.0,1.0,0.95,1.05,230.0
2,nodeB,PV,0.0,1.0,0.95,1.05,230.0
3,nodeC,PQ,0.0,1.0,0.95,1.05,230.0
```

```julia
# Generic runner - works for ANY case
julia run_reader.jl --case 5bus --format CSV
julia run_reader.jl --case 14bus --format JSON
julia run_reader.jl --case my_custom_grid --path /my/data --format CSV
```

**Benefits:**
- ✅ Data separated from code (easier to maintain)
- ✅ One runner works for all cases
- ✅ Edit data in Excel/text editor (no Julia needed)
- ✅ Industry-standard formats (CSV/JSON)

---

## 🏗️ Architecture

### **Component Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│                      User Input                              │
│  (Command line: julia run_reader.jl --case 5bus)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  run_reader.jl                               │
│  • Parses command-line arguments                            │
│  • Orchestrates simulation workflow                         │
│  • Calls data_reader.jl functions                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  data_reader.jl                              │
│  • read_timeseries_data()   → Load hourly profiles          │
│  • read_nodes_data()         → Load bus parameters          │
│  • read_branches_data()      → Load transmission lines      │
│  • read_thermal_generators_data()  → Load thermal plants    │
│  • read_renewable_generators_data() → Load solar/wind       │
│  • read_hydro_generators_data()    → Load hydro plants      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Data Files (CSV or JSON)                        │
│  • Nodes5_sahar.csv         • Trans5_sahar.csv              │
│  • ThermalGenerators5_sahar.csv                             │
│  • RenewableGenerators5_sahar.csv                           │
│  • HydroGenerators5_sahar.csv                               │
│  • Storage5_sahar.csv       • Loads5_sahar.csv              │
│  • TimeSeries_DA_sahar.csv                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│            PowerSystems.jl Objects                           │
│  • PSY.ACBus (buses/nodes)                                  │
│  • PSY.Line, PSY.HVDCLine (transmission)                    │
│  • PSY.ThermalStandard (thermal generators)                 │
│  • PSY.RenewableDispatch (solar/wind)                       │
│  • PSY.HydroEnergyReservoir (hydro plants)                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         PowerLASCOPF System                                  │
│  • PowerLASCOPF.Node (wrapped buses)                        │
│  • PowerLASCOPF.transmissionLine (wrapped lines)            │
│  • ADMM/APP algorithm execution                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│           Results (JSON file)                                │
│  • Generator dispatch schedules                             │
│  • Line power flows                                         │
│  • Convergence metrics                                      │
│  • System costs                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

```
PowerLASCOPF.jl/
│
├── example_cases/
│   ├── data_reader.jl          ← NEW: Generic data reading functions
│   │
│   ├── IEEE_Test_Cases/
│   │   ├── IEEE_5_bus/
│   │   │   ├── Nodes5_sahar.csv
│   │   │   ├── Trans5_sahar.csv
│   │   │   ├── ThermalGenerators5_sahar.csv
│   │   │   ├── RenewableGenerators5_sahar.csv
│   │   │   ├── HydroGenerators5_sahar.csv
│   │   │   ├── Storage5_sahar.csv
│   │   │   ├── Loads5_sahar.csv
│   │   │   └── TimeSeries_DA_sahar.csv
│   │   │
│   │   └── IEEE_14_bus/
│   │       ├── Nodes14_sahar.csv
│   │       ├── Trans14_sahar.csv
│   │       └── ... (same structure as 5-bus)
│   │
│   ├── data_5bus_pu.jl         ← OLD: Kept for backward compatibility
│   └── data_14bus_pu.jl        ← OLD: Kept for backward compatibility
│
├── examples/
│   ├── run_reader.jl           ← NEW: Generic simulation runner
│   ├── run_5bus_lascopf.jl     ← OLD: Kept for backward compatibility
│   └── run_14bus_lascopf.jl    ← OLD: Kept for backward compatibility
│
└── src/
    └── PowerLASCOPF.jl         ← Core algorithm (unchanged)
```

---

## 🚀 Usage Guide

### **Basic Usage (Standard Cases)**

```bash
# Run 5-bus system with CSV files (auto-detects path)
julia examples/run_reader.jl --case 5bus --format CSV

# Run 14-bus system with JSON files
julia examples/run_reader.jl --case 14bus --format JSON

# Increase iterations for better convergence
julia examples/run_reader.jl --case 5bus --iterations 20 --tolerance 1e-4

# Enable verbose output to see detailed progress
julia examples/run_reader.jl --case 5bus --verbose

# Specify custom output file
julia examples/run_reader.jl --case 5bus --output my_results.json
```

### **Advanced Usage (Custom Cases)**

```bash
# Use custom data directory
julia examples/run_reader.jl \
    --case my_grid \
    --path /full/path/to/my/data \
    --format CSV \
    --iterations 30 \
    --tolerance 1e-5 \
    --contingencies 3

# Configure ADMM algorithm parameters
julia examples/run_reader.jl \
    --case 5bus \
    --rnd-intervals 8 \
    --contingencies 5 \
    --iterations 50
```

### **Command-Line Arguments Reference**

| Argument | Short | Description | Default |
|----------|-------|-------------|---------|
| `--case` | `-c` | Case name (5bus, 14bus, custom) | `5bus` |
| `--format` | `-f` | File format (CSV or JSON) | `CSV` |
| `--path` | `-p` | Data directory path (auto-detected if standard) | Auto |
| `--iterations` | `-i` | Maximum ADMM iterations | `10` |
| `--tolerance` | `-t` | Convergence tolerance | `1e-3` |
| `--contingencies` | `-n` | Number of N-1 scenarios | `2` |
| `--output` | `-o` | Output JSON filename | `lascopf_results.json` |
| `--rnd-intervals` | | Recourse decision intervals | `6` |
| `--verbose` | `-v` | Enable detailed logging | `false` |

---

## 📊 Data File Formats

### **1. Nodes (Buses)**

**Purpose:** Define electrical buses (connection points)

**CSV Format:**
```csv
BusNumber,BusName,BusType,Angle,Voltage,VoltageMin,VoltageMax,BaseVoltage
1,nodeA,REF,0.0,1.0,0.95,1.05,230.0
2,nodeB,PV,0.0,1.0,0.95,1.05,230.0
3,nodeC,PQ,0.0,1.0,0.95,1.05,230.0
```

**JSON Format:**
```json
[
  {
    "BusNumber": 1,
    "BusName": "nodeA",
    "BusType": "REF",
    "Angle": 0.0,
    "Voltage": 1.0,
    "VoltageMin": 0.95,
    "VoltageMax": 1.05,
    "BaseVoltage": 230.0
  }
]
```

**Field Explanations:**
- **BusNumber**: Unique identifier (integer)
- **BusName**: Human-readable label (string)
- **BusType**: "REF" (slack bus), "PV" (generator bus), "PQ" (load bus)
- **Angle**: Initial voltage angle in radians (usually 0.0)
- **Voltage**: Initial voltage magnitude in per-unit (usually 1.0)
- **VoltageMin/Max**: Operating voltage limits (e.g., 0.95-1.05 pu)
- **BaseVoltage**: Nominal voltage in kV (e.g., 230.0)

---

### **2. Transmission Lines (Branches)**

**Purpose:** Define transmission lines connecting buses

**CSV Format:**
```csv
LineName,LineType,FromNode,ToNode,Resistance,Reactance,SusceptanceFrom,SusceptanceTo,RateLimit,AngleLimitMin,AngleLimitMax
Line1-2,AC,1,2,0.01,0.05,0.02,0.02,2.5,-0.5,0.5
Line2-3,AC,2,3,0.02,0.10,0.01,0.01,1.8,-0.5,0.5
Line1-3,HVDC,1,3,,,,,,,
```

**Field Explanations:**
- **LineType**: "AC" (normal transmission) or "HVDC" (high-voltage DC)
- **FromNode/ToNode**: Bus numbers this line connects
- **Resistance (R)**: Line resistance in per-unit
- **Reactance (X)**: Line reactance in per-unit
- **Susceptance (B)**: Shunt susceptance in per-unit
- **RateLimit**: Maximum power flow (thermal limit) in per-unit or MW
- **AngleLimitMin/Max**: Voltage angle difference limits (radians)

For HVDC lines, additional fields:
- **ActivePowerMin/Max**: Active power transfer limits
- **ReactivePowerFromMin/Max**: Reactive power at sending end
- **ReactivePowerToMin/Max**: Reactive power at receiving end
- **LossL0, LossL1**: Loss model coefficients (Loss = L0 + L1*Power)

---

### **3. Thermal Generators**

**Purpose:** Define coal, gas, nuclear power plants

**CSV Format:**
```csv
GenName,BusNumber,ActivePower,ReactivePower,Rating,PrimeMover,Fuel,ActivePowerMin,ActivePowerMax,ReactivePowerMin,ReactivePowerMax,RampUp,RampDown,TimeUp,TimeDown,CostC0,CostC1,CostC2,FuelCost,VOMCost,FixedCost,StartUpCost,ShutDownCost,BasePower,Available,Status
Alta,1,0.2,0.0,0.4,ST,COAL,0.0,0.4,-0.3,0.3,0.2,0.2,4.0,2.0,100.0,500.0,10.0,30.0,2.0,50.0,1000.0,500.0,100.0,true,true
```

**Field Explanations:**
- **PrimeMover**: "ST" (steam turbine), "GT" (gas turbine), "CC" (combined cycle)
- **Fuel**: "COAL", "NATURAL_GAS", "NUCLEAR", "OIL"
- **RampUp/Down**: Maximum power change per hour (MW/h)
- **TimeUp/Down**: Minimum up/down time (hours) - can't turn off immediately
- **CostC0, C1, C2**: Cost curve coefficients (Cost = C0 + C1*P + C2*P²)
- **FuelCost**: $/MMBtu fuel cost
- **VOMCost**: Variable O&M cost ($/MWh)
- **FixedCost**: Fixed cost when running ($/h)
- **StartUpCost**: Cost to bring online ($)
- **ShutDownCost**: Cost to take offline ($)

---

### **4. Renewable Generators**

**Purpose:** Define solar PV and wind turbines

**CSV Format:**
```csv
GenName,BusNumber,ActivePower,ReactivePower,Rating,PrimeMover,ReactivePowerMin,ReactivePowerMax,PowerFactor,VariableCost,BasePower,Available
SolarPV1,1,0.0,0.0,0.2,PVe,-0.1,0.1,0.95,0.0,100.0,true
WindTurbine1,3,0.0,0.0,0.5,WT,-0.2,0.2,0.95,0.0,100.0,true
```

**Field Explanations:**
- **PrimeMover**: "PVe" (solar photovoltaic), "WT" (wind turbine)
- **PowerFactor**: Ratio of real to apparent power (0.95 typical)
- **VariableCost**: Usually 0.0 (no fuel cost) or small O&M

---

### **5. Hydro Generators**

**Purpose:** Define hydroelectric dams and pumped storage

**CSV Format:**
```csv
GenName,HydroType,BusNumber,ActivePower,ReactivePower,Rating,PrimeMover,ActivePowerMin,ActivePowerMax,ReactivePowerMin,ReactivePowerMax,RampUp,RampDown,VariableCost,FixedCost,StorageCapacity,Inflow,ConversionFactor,InitialStorage,BasePower,Available
Hydro1,EnergyReservoir,2,0.3,0.0,0.6,HY,0.0,0.6,-0.3,0.3,0.4,0.4,0.0,0.0,50.0,0.5,1.0,25.0,100.0,true
PumpedStorage1,PumpedStorage,4,0.0,0.0,0.8,PS,0.0,0.8,-0.4,0.4,0.6,0.6,0.0,0.0,100.0,0.2,1.0,50.0,100.0,true
```

**Field Explanations:**
- **HydroType**: "Dispatch" (run-of-river), "EnergyReservoir" (dam), "PumpedStorage"
- **StorageCapacity**: Maximum energy stored in reservoir (MWh)
- **Inflow**: Water/energy entering reservoir per hour (MWh/h)
- **ConversionFactor**: Efficiency of water→electricity conversion
- **InitialStorage**: Starting reservoir level (MWh)

For pumped storage, additional fields:
- **RatingPump**: Pumping capacity (MW)
- **PumpEfficiency**: Round-trip efficiency (typically 0.75-0.85)
- **StorageCapacityUp/Down**: Upper and lower reservoir capacities

---

### **6. Time Series**

**Purpose:** Hourly profiles for renewable generation and loads

**CSV Format:**
```csv
Hour,Solar,Wind,HydroInflow,LoadBus2,LoadBus3,LoadBus4
0,0.0,0.4,0.5,0.6,0.8,0.7
1,0.0,0.3,0.5,0.5,0.7,0.6
2,0.0,0.3,0.5,0.5,0.7,0.6
...
12,0.9,0.5,0.6,1.0,1.2,1.1
...
23,0.0,0.6,0.5,0.7,0.9,0.8
```

**Field Explanations:**
- **Solar**: Solar PV capacity factor (0.0-1.0, peak at noon)
- **Wind**: Wind capacity factor (0.0-1.0, varies with weather)
- **HydroInflow**: Normalized water inflow to hydro reservoirs
- **LoadBusX**: Load demand multiplier at each bus

---

## 🔍 How It Works (Technical Details)

### **1. Data Reading (data_reader.jl)**

**Design Pattern:** Factory Functions with Closures

```julia
# Instead of returning objects directly...
function read_nodes_data(filepath, format)
    df = CSV.read(filepath, DataFrame)
    
    # Return a FUNCTION that creates objects
    # WHY: Matches existing codebase pattern (nodes5(), nodes14())
    # BENEFIT: Lazy evaluation - objects created only when needed
    return function()
        buses = PSY.ACBus[]
        for row in eachrow(df)
            push!(buses, PSY.ACBus(row.BusNumber, row.BusName, ...))
        end
        return buses
    end
end
```

**Key Design Decisions:**

1. **Why return functions instead of objects?**
   - Original codebase has `nodes5()` and `nodes14()` as **functions**
   - Functions allow lazy evaluation (create fresh objects each time)
   - Avoids keeping large objects in memory when not needed
   - Enables multiple independent system instances

2. **Why use closures?**
   - Closure captures the DataFrame `df` in its scope
   - Data persists but objects are created fresh each call
   - Clean separation: data loading vs. object creation

3. **Why support both CSV and JSON?**
   - CSV: Easy to edit in Excel, good for tabular data
   - JSON: Better for nested structures, widely supported
   - Different users have different preferences

---

### **2. System Creation Workflow**

```julia
# PHASE 1: Load data from files
ts_data = read_timeseries_data("TimeSeries_DA_sahar.csv", "CSV")
nodes_func = read_nodes_data("Nodes5_sahar.csv", "CSV")
branches_func = read_branches_data("Trans5_sahar.csv", "CSV")

# PHASE 2: Create PowerSystems objects
nodes = nodes_func()  # Call function to get PSY.ACBus objects
branches = branches_func(nodes)  # Pass nodes so lines can reference them

# PHASE 3: Wrap in PowerLASCOPF objects
lascopf_system = PowerLASCOPF.PowerLASCOPFSystem(PSY.System(100.0))
for node in nodes
    lascopf_node = PowerLASCOPF.Node{PSY.Bus}(node, id, zone)
    PowerLASCOPF.add_node!(lascopf_system, lascopf_node)
end

# PHASE 4: Run ADMM/APP algorithm
results = run_lascopf(lascopf_system, admm_params)
```

---

### **3. ADMM/APP Algorithm (Conceptual)**

**Problem:** Optimize generator dispatch + line flows subject to:
- Generator limits (min/max power, ramp rates, costs)
- Line limits (thermal capacity, voltage angles)
- Power balance (generation = load + losses)
- N-1 security (system survives any single line outage)

**Challenge:** Too large to solve as one problem (combinatorial explosion with contingencies)

**Solution:** Alternate Direction Method of Multipliers (ADMM)

```
ADMM Iteration Loop:
┌─────────────────────────────────────────────────────────────┐
│ 1. Generator Subproblems (Parallel)                         │
│    Each generator optimizes: min Cost(P_g)                  │
│    subject to: P_min ≤ P_g ≤ P_max, ramp limits, etc.      │
│    Fixed: Line flows from previous iteration                │
│                                                              │
│ 2. Line Subproblems (Parallel)                              │
│    Each line checks: Is flow within thermal limit?          │
│    For N-1: Check all contingencies (line outages)          │
│    Fixed: Generator dispatch from step 1                    │
│                                                              │
│ 3. Update Dual Variables (Lagrange Multipliers)             │
│    λ^{k+1} = λ^k + ρ(P_gen - P_line)                       │
│    Enforces coupling: generator output must match line flow │
│                                                              │
│ 4. Check Convergence                                         │
│    If ||P_gen - P_line|| < tolerance: STOP                  │
│    Else: Repeat from step 1                                 │
└─────────────────────────────────────────────────────────────┘
```

**Key Parameters:**
- **ρ** (rho): Penalty weight for constraint violations
- **β** (beta): Step size for dual variable updates
- **γ** (gamma): Over-relaxation factor (accelerates convergence)

---

## 🎓 For Task 3: Making It Fully Generic

The current implementation is **90% generic**. To make it **100% case-independent**:

### **Current Limitations:**

```julia
# In run_reader.jl, file names are hardcoded:
nodes_file = joinpath(data_path, "Nodes$(case_name == "5bus" ? "5" : "14")_sahar.$ext")
```

This assumes:
- 5-bus case has "Nodes5_sahar.csv"
- 14-bus case has "Nodes14_sahar.csv"
- Custom cases won't work without modification

### **Fully Generic Solution:**

**Option A: Standard File Naming Convention**
```
ANY case directory must contain:
  - Nodes_sahar.csv (or .json)
  - Trans_sahar.csv
  - ThermalGenerators_sahar.csv
  - RenewableGenerators_sahar.csv
  - HydroGenerators_sahar.csv
  - Storage_sahar.csv
  - Loads_sahar.csv
  - TimeSeries_DA_sahar.csv
```

Update `run_reader.jl`:
```julia
# Instead of case-specific names:
nodes_file = joinpath(data_path, "Nodes_sahar.$ext")  # Remove case-specific logic
branches_file = joinpath(data_path, "Trans_sahar.$ext")
# ... etc for all files
```

**Option B: Configuration File**
```json
// case_config.json in each data directory
{
  "case_name": "My Custom Grid",
  "base_power": 100.0,
  "files": {
    "nodes": "my_buses.csv",
    "branches": "my_lines.csv",
    "thermal_generators": "coal_plants.csv",
    "renewable_generators": "renewables.csv",
    "hydro_generators": "dams.csv",
    "storage": "batteries.csv",
    "loads": "demands.csv",
    "timeseries": "hourly_profiles.csv"
  }
}
```

Then read configuration:
```julia
config = JSON3.read(joinpath(data_path, "case_config.json"))
nodes_file = joinpath(data_path, config["files"]["nodes"])
```

**Recommendation:** Use Option A (standard naming) for simplicity.

---

## 🧪 Testing

```bash
# Test 5-bus CSV
julia examples/run_reader.jl --case 5bus --format CSV --verbose

# Test 14-bus JSON
julia examples/run_reader.jl --case 14bus --format JSON --verbose

# Test with different parameters
julia examples/run_reader.jl --case 5bus --iterations 5 --tolerance 1e-2

# Test custom case (create test data first)
mkdir -p example_cases/test_case
cp example_cases/IEEE_Test_Cases/IEEE_5_bus/*_sahar.csv example_cases/test_case/
julia examples/run_reader.jl --case test_case --path example_cases/test_case
```

---

## 📝 Summary

### **What Was Created:**

1. **data_reader.jl** (example_cases/)
   - Generic data reading functions
   - Supports CSV and JSON
   - Returns factory functions (matches existing pattern)

2. **run_reader.jl** (examples/)
   - Generic simulation runner
   - Command-line interface
   - Works for any case with proper data files

### **Why This Design:**

1. **Separation of Concerns**
   - Data (CSV/JSON files) ≠ Code (Julia files)
   - Easy to modify data without touching code
   
2. **Reusability**
   - One runner for all cases
   - Add new cases by adding data files
   
3. **Maintainability**
   - Changes to data format → update data_reader.jl only
   - Changes to algorithm → update PowerLASCOPF.jl only
   - No cascade of edits across multiple files

4. **Industry Standards**
   - CSV/JSON are universal formats
   - Command-line interface follows Unix philosophy
   - Logging and error handling for production use

### **Next Steps:**

1. ✅ **Created:** data_reader.jl, run_reader.jl
2. ⏳ **TODO:** Make fully case-independent (remove hardcoded "5"/"14" in filenames)
3. ⏳ **TODO:** Add input validation (check file format, required columns)
4. ⏳ **TODO:** Integrate with actual PowerLASCOPF algorithm (currently placeholder)
5. ⏳ **TODO:** Add unit tests for data readers
6. ⏳ **TODO:** Create example custom case to demonstrate genericity
