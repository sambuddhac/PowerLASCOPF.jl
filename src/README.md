# PowerLASCOPF.jl Source Code Organization

This document describes the reorganized source code structure of PowerLASCOPF.jl.

## Directory Structure

```
src/
├── PowerLASCOPF.jl              # Main module file
├── core/                        # Core types, constants, and fundamental components
│   ├── types.jl                 # Abstract type hierarchy
│   ├── constants.jl             # System-wide constants and defaults
│   ├── settings.jl              # Configuration and options
│   ├── solver_model_types.jl    # Solver model type definitions
│   ├── variables.jl             # Optimization variable definitions
│   ├── constraints.jl           # Constraint definitions
│   ├── objective_functions.jl   # Objective function definitions
│   ├── formulations.jl          # Problem formulations
│   ├── parameters.jl            # Parameter definitions
│   └── Extended*Cost.jl         # Cost model definitions
├── components/                  # Power system components
│   ├── node.jl                  # Node/bus components
│   ├── load.jl                  # Load components
│   ├── transmission_line.jl     # Transmission line components
│   ├── network.jl               # Network components
│   ├── supernetwork.jl          # Supernetwork components
│   ├── *_generator.jl           # Generator component types
│   └── generator_integration.jl # Generator integration framework
├── solvers/                     # Optimization solvers and algorithms
│   ├── generator_solvers/       # Generator optimization subproblems
│   │   ├── gensolver_*.jl       # Various generator solver implementations
│   │   └── lascopf_gen_solver.jl
│   ├── line_solvers/            # Line optimization subproblems
│   │   ├── linesolver_base.jl
│   │   └── linesolver_base_dual.jl
│   ├── network_solvers/         # Network-level solvers
│   │   └── sdp_opf_centralized.jl
│   └── interfaces/              # Solver interfaces and abstractions
│       └── solver_interface.jl
├── algorithms/                  # High-level algorithms
│   ├── admm/                    # ADMM algorithm implementations (empty - to be populated)
│   ├── app/                     # Auxiliary Problem Principle implementations (empty - to be populated)
│   └── coordination/            # Coordination algorithms
│       ├── maintwoserialLASCOPF.jl
│       ├── example_unified_generators.jl
│       └── run_sim_lascopf_temp_app.jl
├── io/                          # Input/Output operations
│   ├── readers/                 # Input file readers
│   │   ├── read_csv_inputs.jl
│   │   ├── read_json_inputs.jl
│   │   ├── read_inputs_and_parse.jl
│   │   ├── make_lanl_ansi_pm_compatible.jl
│   │   └── make_nrel_sienna_compatible.jl
│   ├── writers/                 # Output file writers (empty - to be populated)
│   └── formats/                 # File format handlers (empty - to be populated)
├── utils/                       # Utility functions
│   ├── helpers.jl               # Helper functions and utilities
│   ├── validation.jl            # System validation utilities
│   └── conversion.jl            # Unit conversion and data format utilities
└── extensions/                  # External package integrations
    ├── powersystems_integration.jl  # PowerSystems.jl integration
    └── extended_system.jl           # System extensions
```

## Design Principles

### 1. Separation of Concerns
- **Core**: Fundamental types, constants, and basic building blocks
- **Components**: Power system physical components (nodes, lines, generators, loads)
- **Solvers**: Optimization algorithms and solver implementations
- **Algorithms**: High-level coordination and decomposition algorithms
- **I/O**: File reading/writing and data format handling
- **Utils**: Reusable utility functions
- **Extensions**: Integration with external packages

### 2. Modularity
- Each directory contains related functionality
- Clear dependencies between modules
- Easy to test individual components
- Supports incremental development

### 3. Extensibility
- New algorithms can be easily added to `algorithms/`
- New component types can be added to `components/`
- New solver implementations can be added to `solvers/`
- New file formats can be added to `io/formats/`

### 4. Integration
- Seamless integration with PowerSystems.jl ecosystem
- Support for PowerModels.jl compatibility
- Extensions for external solver packages

## Key Improvements

1. **Eliminated Language Mixing**: Removed Python and C++ code from Julia files
2. **Removed Hardcoded Paths**: Replaced with configurable constants
3. **Improved Naming**: Consistent Julia naming conventions
4. **Better Documentation**: Clear module structure and function documentation
5. **Type Safety**: Proper Julia type system usage
6. **Dependency Management**: Clear module dependencies

## Migration Notes

- Old `src/models/subsystems/` → `src/components/`
- Old `src/models/solver_models/` → `src/solvers/` and `src/core/`
- Old `src/read_inputs/` → `src/io/readers/`
- Settings moved from `LASCOPF_settings.jl` → `src/core/settings.jl`
- Utility functions organized in `src/utils/`

## Usage

The main module file `PowerLASCOPF.jl` includes all necessary components:

```julia
using PowerLASCOPF

# Create a system
system = PowerLASCOPFSystem(100.0)  # 100 MVA base power

# Use components, solvers, and algorithms as needed
```

## Testing

Each module can be tested independently, and the modular structure supports:
- Unit testing of individual components
- Integration testing of algorithms
- System-level testing of complete workflows

## Future Development

- Populate empty directories (`algorithms/admm/`, `algorithms/app/`, etc.)
- Add more comprehensive error handling
- Implement additional file format support
- Expand validation capabilities
- Add more utility functions as needed