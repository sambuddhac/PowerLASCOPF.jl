# PowerLASCOPF.jl Execution Flow Guide

## Overview

This document describes the restructured execution flow for PowerLASCOPF.jl simulations. The new architecture provides a single entry point (`examples/run_reader_generic.jl`) that can run ANY test case while maintaining modularity and flexibility.

## Quick Start

### Running a Simulation

```bash
# Interactive mode (recommended for first-time users)
julia examples/run_reader_generic.jl

# Command line mode with specific case
julia examples/run_reader_generic.jl case=5bus
julia examples/run_reader_generic.jl case=14bus format=CSV
julia examples/run_reader_generic.jl case=IEEE_30_bus iterations=20 verbose=true

# List all available cases
julia examples/run_reader_generic.jl list

# Run all cases in batch
julia examples/run_reader_generic.jl all
```

### From Julia REPL

```julia
# Include and run directly
include("examples/run_reader_generic.jl")
results = run_case("5bus")
results = run_case("14bus", verbose=true, iterations=15)

# Start interactive mode
interactive_mode()
```

## Architecture

### Execution Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER ENTRY POINT                              │
│              examples/run_reader_generic.jl                      │
│                                                                   │
│  • Parses command line arguments                                 │
│  • Discovers available cases                                     │
│  • Provides interactive mode                                     │
│  • Orchestrates complete simulation                              │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ run_case(case_name, ...)
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DATA LOADING                                  │
│           example_cases/data_reader_generic.jl                   │
│                                                                   │
│  • load_case_data(case_name, format)                            │
│  • Detects case path automatically                              │
│  • Reads CSV/JSON files                                         │
│  • Returns Dict{Symbol, DataFrame}                              │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ Optional: Dispatch to case-specific loader
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│              CASE-SPECIFIC LOADERS (Optional)                    │
│              example_cases/data_reader.jl                        │
│                                                                   │
│  • load_5bus_case(path)                                         │
│  • load_14bus_case(path)                                        │
│  • Can load from Julia files (data_5bus_pu.jl)                 │
│  • Can fall back to CSV/JSON                                    │
│  • Returns (system, system_data) tuple                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ DataFrames → system_data Dict
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                SIMULATION EXECUTION                              │
│              examples/run_reader.jl                              │
│                                                                   │
│  • execute_simulation(case_name, system, system_data, config)   │
│  • Configures ADMM/APP parameters                               │
│  • Runs optimization loop                                       │
│  • Returns simulation results                                   │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  │ results Dict
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  RESULTS & OUTPUT                                │
│              examples/run_reader_generic.jl                      │
│                                                                   │
│  • Receives simulation results                                  │
│  • Saves to JSON file                                           │
│  • Displays summary                                             │
│  • Reports metrics                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Entry Point: `examples/run_reader_generic.jl`

**Purpose:** Single entry point for all simulations

**Key Functions:**
- `parse_arguments()` - Parse command line arguments
- `discover_cases()` - Find all available test cases
- `run_case(case_name, ...)` - Main simulation runner
- `run_all_cases(cases, ...)` - Batch runner
- `interactive_mode()` - Interactive case selection

**Features:**
- ✅ Command line argument parsing
- ✅ Interactive mode
- ✅ Batch execution
- ✅ Case discovery
- ✅ Results management

**Example Usage:**
```julia
# Run with configuration
results = run_case("5bus", 
    format="CSV",
    iterations=10,
    tolerance=1e-3,
    verbose=true,
    output="my_results.json"
)
```

### 2. Simulation Engine: `examples/run_reader.jl`

**Purpose:** Provides reusable simulation functions

**Key Functions:**
- `execute_simulation(case_name, system, system_data, config)` - Main simulation function
- `run_simulation(args)` - Standalone simulation runner (backward compatible)

**Parameters for `execute_simulation()`:**

```julia
execute_simulation(
    case_name::String,      # Name of the test case
    system,                 # PowerLASCOPF system object (can be nothing)
    system_data::Dict,      # System component data
    config::Dict            # Configuration parameters
)
```

**Configuration Dictionary:**
```julia
config = Dict(
    "max_iterations" => 10,      # Maximum ADMM iterations
    "tolerance" => 1e-3,         # Convergence tolerance
    "contingencies" => 2,        # Number of contingency scenarios
    "rnd_intervals" => 6,        # RND intervals
    "verbose" => false,          # Verbose output
    "solver" => "ipopt"          # Solver choice
)
```

**Returns:**
```julia
results = Dict(
    "case_name" => "5bus",
    "status" => "FEASIBLE",
    "iterations" => 8,
    "solve_time" => 12.34,
    "objective_value" => 1234.56,
    "convergence_history" => [...],
    "generator_dispatch" => {...},
    "line_flows" => {...}
)
```

### 3. Data Loading: `example_cases/data_reader_generic.jl`

**Purpose:** Generic data loading from CSV/JSON files

**Key Functions:**
- `load_case_data(case_name, format)` - Main data loader
- `get_case_path(case_name)` - Automatic path detection
- `parse_case_name(case_name)` - Extract bus count
- `detect_file_format(path, bus_count)` - Detect Sahar vs legacy format

**Data Format:**
Returns `Dict{Symbol, DataFrame}` with keys:
- `:nodes` - Bus/node data
- `:thermal` - Thermal generator data
- `:renewable` - Renewable generator data
- `:hydro` - Hydro generator data
- `:storage` - Storage device data
- `:loads` - Load data
- `:branches` - Transmission line data

**Example:**
```julia
data = load_case_data("5bus", "CSV")
println("Nodes: $(nrow(data[:nodes]))")
println("Thermal: $(nrow(data[:thermal]))")
```

### 4. Case-Specific Loaders: `example_cases/data_reader.jl`

**Purpose:** Flexible loading from multiple data sources

**Available Loaders:**
- `load_5bus_case(path)` - 5-bus system
- `load_14bus_case(path)` - 14-bus system
- `load_118bus_case(path)` - 118-bus system
- `load_300bus_case(path)` - 300-bus system
- `load_from_csv_json(path)` - Generic CSV/JSON loader

**Loading Strategy:**
1. Check for Julia data file (e.g., `data_5bus_pu.jl`)
2. If found, include it and call `create_*_powerlascopf_system()`
3. If not found, look for CSV/JSON files
4. Use generic readers to load data
5. Return `(system, system_data)` tuple

**Example:**
```julia
# Load from Julia file
system, system_data = load_5bus_case("example_cases/data_5bus_pu.jl")

# Load from CSV directory
system, system_data = load_5bus_case("example_cases/IEEE_Test_Cases/IEEE_5_bus/")
```

## Data Sources

### Julia Data Files

Located in `example_cases/`:
- `data_5bus_pu.jl` - 5-bus test system
- `data_14bus_pu.jl` - 14-bus test system

These files contain:
- Hardcoded system parameters
- Component definitions
- Time series data
- `create_*_powerlascopf_system()` functions

### CSV/JSON Files

Located in `example_cases/IEEE_Test_Cases/` and other folders:

**Sahar Format (Standard):**
- `Nodes<N>_sahar.csv` - Node/bus definitions
- `ThermalGenerators<N>_sahar.csv` - Thermal generators
- `Trans<N>_sahar.csv` - Transmission lines
- `Loads<N>_sahar.csv` - Load data
- `RenewableGenerators<N>_sahar.csv` - Solar/wind (optional)
- `HydroGenerators<N>_sahar.csv` - Hydro (optional)
- `Storage<N>_sahar.csv` - Battery storage (optional)

**Legacy Format (Deprecated):**
- `Gen<N>.csv` - Generator data
- `Load<N>.csv` - Load data
- `Trans<N>.csv` - Transmission lines

## Adding New Test Cases

### Option 1: CSV/JSON Files (Recommended)

1. Create folder: `example_cases/IEEE_Test_Cases/IEEE_<N>_bus/`
2. Add CSV files in Sahar format (see `ADDING_NEW_CASES.md`)
3. Case automatically appears in `run_reader_generic.jl`

### Option 2: Julia Data File

1. Create file: `example_cases/data_<N>bus_pu.jl`
2. Define `create_<N>bus_powerlascopf_system()` function
3. Add loader in `data_reader.jl`: `load_<N>bus_case(path)`
4. Update dispatcher in `data_reader_generic.jl`

## Testing

### Run Tests

```bash
# Test execution flow
julia test/test_execution_flow.jl

# Run all tests
julia test/runtests.jl
```

### Demonstration

```bash
# See execution flow demonstration
julia examples/demo_execution_flow.jl
```

## Backward Compatibility

All existing scripts remain functional:

```bash
# Still works - uses data_5bus_pu.jl directly
julia examples/run_5bus_lascopf.jl

# Still works - uses data_14bus_pu.jl directly
julia examples/run_14bus_lascopf.jl

# Standalone run_reader.jl
julia examples/run_reader.jl --case 5bus --format CSV
```

## Advanced Usage

### Programmatic Simulation

```julia
# Include the runner
include("examples/run_reader_generic.jl")

# Load data manually
data = load_case_data("5bus", "CSV")

# Prepare configuration
config = Dict(
    "max_iterations" => 20,
    "tolerance" => 1e-4,
    "contingencies" => 3,
    "verbose" => true
)

# Convert to system_data
system_data = Dict(
    "name" => "5bus",
    "thermal_generators" => data[:thermal],
    # ... other components
)

# Run simulation
include("examples/run_reader.jl")
results = execute_simulation("5bus", nothing, system_data, config)

# Process results
println("Status: $(results["status"])")
println("Iterations: $(results["iterations"])")
println("Cost: $(results["objective_value"])")
```

### Custom Data Processing

```julia
# Load data
data = load_case_data("30bus", "CSV")

# Modify data (e.g., scale loads)
data[:loads].ActivePower .*= 1.2

# Run simulation with modified data
results = run_case_with_data("30bus", data, iterations=15)
```

## Troubleshooting

### Common Issues

**Issue:** "Package not installed" error
```bash
# Solution: Install dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

**Issue:** "Case not found" error
```bash
# Solution: List available cases
julia examples/run_reader_generic.jl list
```

**Issue:** "Data file not found" error
```bash
# Solution: Check case path
ls example_cases/IEEE_Test_Cases/IEEE_5_bus/
```

## References

- [Data Reader README](../example_cases/DATA_READER_README.md)
- [Adding New Cases Guide](../example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md)
- [REORGANIZATION SUMMARY](../REORGANIZATION_SUMMARY.md)
- [Dual Approach Guide](DUAL_APPROACH_GUIDE.md)
- [GenSolver Integration Guide](GENSOLVER_INTEGRATION_GUIDE.md)

## Summary

The restructured execution flow provides:

✅ **Single Entry Point** - Run any case from `run_reader_generic.jl`  
✅ **Modular Design** - Clear separation of concerns  
✅ **Flexible Data Loading** - Support for multiple data sources  
✅ **Reusable Functions** - `execute_simulation()` can be called by any script  
✅ **Backward Compatible** - Existing scripts still work  
✅ **Well Tested** - Comprehensive test coverage  
✅ **Documented** - Clear guides and examples  

The new architecture makes it easy to:
- Add new test cases
- Run batch simulations
- Integrate with other tools
- Customize simulation parameters
- Process results programmatically
