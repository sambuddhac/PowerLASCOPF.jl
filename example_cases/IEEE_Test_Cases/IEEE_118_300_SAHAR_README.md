# Sahar Format Data Files for IEEE 118 and 300 Bus Test Cases

## Summary

This document describes the Sahar format data files created for the IEEE 118-bus and IEEE 300-bus test cases, completing the data file coverage requested in PR #80.

## Created Files

### IEEE 118 Bus System
Located in: `example_cases/IEEE_Test_Cases/IEEE_118_bus/`

| File | Description | Entries |
|------|-------------|---------|
| `Nodes118_sahar.csv` | Bus/node definitions | 108 nodes |
| `ThermalGenerators118_sahar.csv` | Thermal generator data | 54 generators |
| `Trans118_sahar.csv` | Transmission line data | 186 lines |
| `Loads118_sahar.json` | Load data (JSON format) | 91 loads |

### IEEE 300 Bus System
Located in: `example_cases/IEEE_Test_Cases/IEEE_300_bus/`

| File | Description | Entries |
|------|-------------|---------|
| `Nodes300_sahar.csv` | Bus/node definitions | 233 nodes |
| `ThermalGenerators300_sahar.csv` | Thermal generator data | 69 generators |
| `Trans300_sahar.csv` | Transmission line data | 411 lines |
| `Loads300_sahar.json` | Load data (JSON format) | 196 loads |

## File Format Specifications

All files follow the Sahar format as defined in `ADDING_NEW_CASES.md`, matching the structure of existing test cases (IEEE_57_bus).

### CSV Files

**Nodes<N>_sahar.csv:**
- Columns: BusNumber, BusType, VoltageMin, VoltageMax, BaseVoltage, BasePower
- Bus types: REF (slack), PV (generator), PQ (load)
- Voltage limits: 0.95-1.05 pu

**ThermalGenerators<N>_sahar.csv:**
- Columns: GeneratorName, BusNumber, GeneratorType, Available, ActivePower, ReactivePower, Rating, PrimeMover, ActivePowerMin, ActivePowerMax, ReactivePowerMin, ReactivePowerMax, RampUp, RampDown, CostCurve_a, CostCurve_b, CostCurve_c, FuelCost, FixedCost, BasePower
- Default PrimeMover: ST (Steam Turbine)
- Cost curves mapped from legacy c2/c1/c0 format

**Trans<N>_sahar.csv:**
- Columns: LineID, LineType, fromNode, toNode, Resistance, Reactance, Susceptance_from, Susceptance_to, RateLimit, AngleLimit_min, AngleLimit_max, ContingencyMarked
- Angle limits: -0.7 to 0.7 radians

### JSON Files

**Loads<N>_sahar.json:**
- Fields: LoadName, BusNumber, Available, ActivePower, ReactivePower, MaxActivePower, MaxReactivePower, BasePower
- Reactive power calculated using assumed power factor of ~0.95

## Data Source and Conversion

The Sahar format files were generated from the existing legacy format files:
- Legacy files: `Gen<N>.json`, `Load<N>.json`, `Tran<N>.json`
- Conversion script: `convert_to_sahar.jl`

Key conversion details:
1. **Load data**: Converted negative active power values to positive
2. **Generator costs**: Mapped c2→CostCurve_a, c1→CostCurve_b, c0→CostCurve_c
3. **Bus types**: Derived from generator and load connections
4. **Missing fields**: Filled with standard defaults (e.g., FuelCost=1.5, FixedCost=20.0)

## System Parameters

### IEEE 118 Bus
- Base Power: 100.0 MVA
- Base Voltage: 138 kV
- Total Generation Capacity: ~8,900 MW
- Total Load: ~3,600 MW

### IEEE 300 Bus
- Base Power: 100.0 MVA
- Base Voltage: 230 kV
- Total Generation Capacity: ~5,000 MW
- Total Load: ~2,350 MW

## Usage

### Loading with data_reader_generic.jl

The new Sahar format files are automatically detected by `data_reader_generic.jl`:

```julia
include("example_cases/data_reader_generic.jl")

# Load IEEE 118 bus case
case_data_118 = load_case_data("IEEE_118_bus", "CSV")

# Load IEEE 300 bus case
case_data_300 = load_case_data("IEEE_300_bus", "CSV")
```

### Running Simulations

Use `run_reader_generic.jl` to run simulations:

```bash
# IEEE 118 bus
julia --project=. examples/run_reader_generic.jl case=118bus

# IEEE 300 bus
julia --project=. examples/run_reader_generic.jl case=300bus
```

## Backward Compatibility

The Sahar format files coexist with the legacy format files:
- Legacy files: `Gen118.csv`, `Load118.csv`, `Tran118.csv`
- Sahar format takes priority when both exist
- Legacy format remains accessible for backward compatibility

## Validation

All files have been validated for:
- ✅ Correct file naming convention (*_sahar.csv/json)
- ✅ CSV headers matching IEEE_57_bus reference
- ✅ JSON structure matching IEEE_57_bus reference
- ✅ Consistent BasePower (100.0 MVA)
- ✅ Valid voltage limits and bus types
- ✅ Proper data types and value ranges
- ✅ Automatic format detection by data_reader_generic.jl

## Testing

Test scripts are provided:
- `test_sahar_detection.jl` - Tests format detection
- `test_data_loading.jl` - Tests data loading (requires full environment)

## References

- Template files: `example_cases/IEEE_Test_Cases/IEEE_57_bus/*_sahar.*`
- Format specification: `example_cases/IEEE_Test_Cases/ADDING_NEW_CASES.md`
- Conversion script: `example_cases/IEEE_Test_Cases/convert_to_sahar.jl`
- Data reader: `example_cases/data_reader_generic.jl`

## Notes

1. Hydro generators, renewable generators, and storage files were not created as the legacy data does not include these component types for IEEE 118 and 300 bus cases.

2. The conversion script can be rerun if needed:
   ```bash
   julia example_cases/IEEE_Test_Cases/convert_to_sahar.jl
   ```

3. For adding new test cases, see `ADDING_NEW_CASES.md` for the complete file format specification.

---

*Generated: January 2026*  
*Related PR: #80*
