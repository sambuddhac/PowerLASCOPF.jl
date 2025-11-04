"""
PowerLASCOPFReaders

A module for reading various power system data formats and converting them
to PowerSystems.jl compatible objects for use with PowerLASCOPF.

Supported formats:
- CSV (RTS-GMLC format, csv_118 format, and custom formats)
- MATPOWER (planned for future release)
- JSON (planned for future release)

# Example

```julia
using PowerLASCOPFReaders

# Read a system from CSV files
system = read_csv_system("path/to/csv/directory")

# Or with custom configuration
config = CSVReaderConfig(
    base_power = 100.0,
    default_voltage_limits = (0.95, 1.05)
)
system = read_csv_system("path/to/csv/directory", config=config)
```
"""
module PowerLASCOPFReaders

include("csv_reader.jl")

# Re-export main functions
export CSVReaderConfig, read_csv_system, detect_csv_format
export read_buses_rts_gmlc, read_buses_csv118
export read_branches_rts_gmlc, read_branches_csv118
export read_generators_rts_gmlc, read_generators_csv118
export read_loads_rts_gmlc, read_loads_csv118

end # module
