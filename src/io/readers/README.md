# PowerLASCOPF Data Readers

This directory contains data readers for converting various power system data formats into PowerSystems.jl-compatible objects for use with PowerLASCOPF.

## Overview

The readers are integrated into the main PowerLASCOPF module and provide a unified interface for loading power system data from different sources and formats, automatically detecting the format when possible and filling in missing fields with sensible defaults.

## Supported Formats

### CSV Formats

The CSV reader (`csv_reader.jl`) supports multiple CSV-based formats:

1. **RTS-GMLC Format**: The standard format used by PowerSystems.jl and other NREL tools
   - Files: `bus.csv`, `gen.csv`, `branch.csv`, `dc_branch.csv`, etc.
   - Location: `example_cases/RTS_GMLC/`

2. **csv_118 Custom Format**: A custom format with simplified structure
   - Files: `Buses.csv`, `Generators.csv`, `Lines.csv`
   - Location: `example_cases/csv_118/`

3. **Extensible**: Easy to add support for other CSV formats by implementing format-specific parsers

### Future Formats (Planned)

- **MATPOWER**: `.m` format files
- **PSSE**: `.raw` format files
- **JSON**: Various JSON-based formats

## Usage

### Basic Usage

```julia
using PowerLASCOPF

# Read a system from CSV directory (auto-detects format)
system = read_csv_system("path/to/csv/directory")
```

### Advanced Usage with Configuration

```julia
using PowerLASCOPF
using PowerSystems
const PSY = PowerSystems

# Create custom configuration
config = CSVReaderConfig(
    base_power = 100.0,                          # Base power in MVA
    default_voltage_limits = (0.95, 1.05),       # Voltage limits in p.u.
    default_base_voltage = 138.0,                # Base voltage in kV
    default_ramp_rate = 0.02,                    # Ramp rate as fraction per minute
    default_min_up_time = 1.0,                   # Minimum up time in hours
    default_min_down_time = 1.0,                 # Minimum down time in hours
    default_thermal_fuel = PSY.ThermalFuels.COAL,
    default_prime_mover = PSY.PrimeMovers.ST
)

# Read system with custom configuration
system = read_csv_system("path/to/csv/directory", config=config)
```

### Format Detection

```julia
# Detect CSV format in a directory
format = detect_csv_format("path/to/csv/directory")
# Returns: :rts_gmlc, :csv_118, or :unknown
```

### Reading Specific Components

You can also read individual components:

```julia
using PowerLASCOPF

config = CSVReaderConfig()

# Read buses
buses = read_buses_rts_gmlc("path/to/bus.csv", config)

# Read branches
branches = read_branches_rts_gmlc("path/to/branch.csv", buses, config)

# Read generators
generators = read_generators_rts_gmlc("path/to/gen.csv", buses, config)

# Read loads
loads = read_loads_rts_gmlc("path/to/bus.csv", buses, config)
```

## Configuration Options

The `CSVReaderConfig` struct allows you to customize the reader behavior:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `base_power` | Float64 | 100.0 | Base power in MVA for per-unit calculations |
| `default_voltage_limits` | Tuple{Float64, Float64} | (0.9, 1.1) | Default voltage limits in p.u. |
| `default_base_voltage` | Float64 | 138.0 | Default base voltage in kV |
| `default_ramp_rate` | Float64 | 0.02 | Default ramp rate as fraction of capacity per minute |
| `default_min_up_time` | Float64 | 1.0 | Default minimum up time in hours |
| `default_min_down_time` | Float64 | 1.0 | Default minimum down time in hours |
| `default_thermal_fuel` | PSY.ThermalFuels.ThermalFuel | COAL | Default fuel type |
| `default_prime_mover` | PSY.PrimeMovers.PrimeMover | ST | Default prime mover type |
| `default_horizon` | Int | 24 | Default time series horizon in hours |
| `start_time` | DateTime | 2024-01-01T00:00:00 | Default start time for time series |

## Examples

See `examples/read_csv_example.jl` for comprehensive examples, including:

1. Reading RTS-GMLC format data
2. Reading csv_118 format data
3. Automatic format detection
4. Custom configuration
5. Accessing system components

To run the examples:

```bash
julia examples/read_csv_example.jl
```

## Data Format Specifications

### RTS-GMLC Format

#### bus.csv
Required columns:
- `Bus ID`: Integer bus identifier
- `Bus Name`: String bus name
- `BaseKV`: Base voltage in kV
- `Bus Type`: Type (Ref, PV, or PQ)
- `MW Load`: Active power load in MW
- `MVAR Load`: Reactive power load in MVAR

Optional columns:
- `V Mag`: Voltage magnitude in p.u.
- `V Angle`: Voltage angle in degrees
- `MW Shunt G`: Shunt conductance in MW
- `MVAR Shunt B`: Shunt susceptance in MVAR

#### gen.csv
Required columns:
- `GEN UID`: Unique generator identifier
- `Bus ID`: Bus identifier where generator is connected
- `PMax MW`: Maximum active power in MW
- `PMin MW`: Minimum active power in MW
- `QMax MVAR`: Maximum reactive power in MVAR
- `QMin MVAR`: Minimum reactive power in MVAR
- `Unit Type`: Generator type (CT, CC, STEAM, etc.)

Optional columns:
- `MW Inj`: Current active power injection in MW
- `MVAR Inj`: Current reactive power injection in MVAR
- `Fuel`: Fuel type (NG, Coal, Oil, etc.)
- `Ramp Rate MW/Min`: Ramp rate in MW/min
- `Min Up Time Hr`: Minimum up time in hours
- `Min Down Time Hr`: Minimum down time in hours

#### branch.csv
Required columns:
- `From Bus`: From bus identifier
- `To Bus`: To bus identifier
- `R`: Resistance in p.u.
- `X`: Reactance in p.u.

Optional columns:
- `B`: Total line charging susceptance in p.u.
- `Cont Rating`: Continuous rating in MVA
- `Min Angle Diff`: Minimum angle difference in radians
- `Max Angle Diff`: Maximum angle difference in radians

### csv_118 Format

#### Buses.csv
Required columns:
- `Bus Name`: String bus identifier
- `Region`: Region identifier
- `Load Participation Factor`: Load participation factor (0-1)

#### Generators.csv
Required columns:
- `Generator Name`: String generator identifier
- `bus of connection`: Bus name where generator is connected
- `Max Capacity (MW)`: Maximum capacity in MW

Optional columns:
- `Min Stable Level (MW)`: Minimum stable level in MW
- `Max Ramp Up (MW/min)`: Maximum ramp up rate
- `Max Ramp Down (MW/min)`: Maximum ramp down rate
- `Min Up Time (h)`: Minimum up time in hours
- `Min Down Time (h)`: Minimum down time in hours
- `VO&M Charge ($/MWh)`: Variable O&M charge
- `Start Cost ($)`: Start-up cost

#### Lines.csv
Required columns:
- `Line Name`: String line identifier
- `Bus from `: From bus name (note the space!)
- `Bus to`: To bus name
- `Max Flow (MW)`: Maximum power flow in MW
- `Min Flow (MW)`: Minimum power flow in MW
- `Reactance (p.u.)`: Reactance in p.u.
- `Resistance (p.u.)`: Resistance in p.u.

## Missing Field Handling

The readers intelligently handle missing fields by:

1. Using defaults from `CSVReaderConfig` when available
2. Computing reasonable values based on other fields (e.g., ramp rates from capacity)
3. Inferring values from naming conventions (e.g., fuel type from generator name)
4. Warning the user when critical fields are missing

## Adding Support for New Formats

To add support for a new CSV format:

1. Add format detection logic to `detect_csv_format()`
2. Implement format-specific reader functions:
   - `read_buses_<format>()`
   - `read_branches_<format>()`
   - `read_generators_<format>()`
   - `read_loads_<format>()`
3. Add format handling to `read_csv_system()`
4. Update this README with format specifications

## Integration with PowerLASCOPF

The systems created by these readers are fully compatible with PowerLASCOPF workflows:

```julia
using PowerLASCOPF

# Read system from CSV
system = read_csv_system("example_cases/RTS_GMLC")

# Use with PowerLASCOPF
# ... (add LASCOPF-specific setup code as needed)
```

## Troubleshooting

### Common Issues

1. **"Unknown CSV format" error**
   - Ensure the directory contains the required CSV files
   - Check file names match expected formats (case-sensitive)
   - Try specifying the format manually

2. **"Bus not found" warnings**
   - Check bus identifiers match between files
   - Verify bus names/IDs are consistent

3. **Missing required columns**
   - Check CSV column headers match expected names (case-sensitive)
   - Some formats have spaces in column names (e.g., "Bus from ")

### Debug Tips

```julia
using PowerLASCOPF
using Logging

# Enable detailed logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

# Read system with full output
system = read_csv_system("path/to/data")
```

## Contributing

Contributions are welcome! To add support for new formats or improve existing readers:

1. Follow the existing code structure
2. Add comprehensive error handling
3. Include format detection logic
4. Add examples and documentation
5. Test with real data files

## License

This code is part of the PowerLASCOPF.jl package and follows the same license.

## Contact

For questions or issues, please open an issue on the PowerLASCOPF.jl GitHub repository.
