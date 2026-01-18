# PowerLASCOPF.jl AI Coding Agent Guide

## Project Overview
PowerLASCOPF.jl implements Look-Ahead Security-Constrained Optimal Power Flow using **ADMM (Alternating Direction Method of Multipliers)** and **APP (Auxiliary Problem Principle)** decomposition algorithms. Built on NREL's Sienna ecosystem (PowerSystems.jl, PowerSimulations.jl, InfrastructureSystems.jl).

## Critical Architecture Concepts

### Decomposition Hierarchy (3 Levels)
1. **APP (Outer Loop)**: Temporal/scenario coordination across dispatch intervals
2. **ADMM (Inner Loop)**: Spatial decomposition into subproblems (generators, lines, loads)
3. **Subproblem Solvers**: Individual optimization problems solved in parallel

**Key Files**: [src/algorithms/coordination/maintwoserialLASCOPF.jl](src/algorithms/coordination/maintwoserialLASCOPF.jl), [src/solvers/generator_solvers/gensolver_first_base.jl](src/solvers/generator_solvers/gensolver_first_base.jl)

### Type System & Interval Parameters
All solvers use **interval types** to pass ADMM/APP parameters. See [src/core/solver_model_types.jl](src/core/solver_model_types.jl):
- `GenFirstBaseInterval`: Contains `lambda_1`, `lambda_2`, `B`, `D`, `BSC` (APP Lagrange multipliers), `rho`, `beta`, `gamma` (penalty parameters), `Pg_nu`, `Pg_N_avg`, `ug_N`, `vg_N` (dual variables)
- `LineFirstBaseInterval`, `LoadFirstBaseInterval`: Similar structures for line/load solvers

**Critical**: ADMM parameters are passed through interval type constructors, NOT as function arguments.

### PSI Integration Pattern
PowerLASCOPF uses PowerSimulations.jl (PSI) containers for variable preallocation:

```julia
# Add variables to PSI container
PSI.add_variable!(container, PSI.ActivePowerVariable, LASCOPFGeneratorFormulation(), devices, nothing)
PSI.add_variable!(container, PgNextVariable, LASCOPFGeneratorFormulation(), devices, nothing)

# Access via get_variable
Pg_vars = PSI.get_variable(container, PSI.ActivePowerVariable)
```

**Dual Approach**: [gensolver_first_base.jl](src/solvers/generator_solvers/gensolver_first_base.jl) implements BOTH preallocated (PSI) and direct (JuMP) approaches - use `GenSolverConfig(use_preallocation=true/false)` to switch.

## Developer Workflows

### Environment Setup
```powershell
# From repository root
julia --project=.
julia> using Pkg; Pkg.instantiate()

# Quick minimal setup if full fails
julia quick_setup.jl
```

### Running Tests
```julia
# Basic hello world test
julia test/test_hello_world.jl

# Component tests
julia test/test_components.jl

# Full test suite
julia test/runtests.jl

# Benchmark solvers
julia test/benchmark_linesolver.jl
```

### Running Examples
```julia
# Activate environment first
using Pkg; Pkg.activate(".")

# Run 5-bus demo (small system)
include("examples/run_5bus_lascopf.jl")

# Run 14-bus demo (IEEE test case)
include("examples/run_14bus_lascopf.jl")

# Test prerequisites before running demos
include("examples/test_prerequisites.jl")
```

**Important**: Examples use `Pkg.activate(project_dir)` to ensure correct environment. Always activate before including PowerLASCOPF modules.

## Project-Specific Conventions

### File Organization (Post-Reorganization)
- **[src/core/](src/core/)**: Fundamental types, constants, formulations (NO hardcoded paths - use `constants.jl`)
- **[src/components/](src/components/)**: Physical power system components (Node, TransmissionLine, Generators)
- **[src/solvers/](src/solvers/)**: Optimization solvers split by type: `generator_solvers/`, `line_solvers/`, `network_solvers/`
- **[src/algorithms/](src/algorithms/)**: High-level coordination (ADMM/APP implementations in `coordination/`)
- **[src/io/readers/](src/io/readers/)**: CSV/JSON input parsers for different data formats

**Never** place code in `src/models/` - this was the old structure. See [REORGANIZATION_SUMMARY.md](REORGANIZATION_SUMMARY.md).

### Naming Conventions
- **Generator Variables**: `Pg` (power), `Thetag` (angle), `PgNext` (next interval power)
- **Network Variables**: `Pg_N_avg` (network average), `ug_N`/`vg_N` (dual variables)
- **APP Parameters**: `lambda_1`, `lambda_2` (Lagrange multipliers), `B`, `D` (disagreement terms)
- **Module Aliases**: `PSY = PowerSystems`, `PSI = PowerSimulations`, `IS = InfrastructureSystems`, `MOI = MathOptInterface`

### Cost Functions - Extended Types
Use **Extended Cost** types (not base PowerSystems types) to include ADMM/APP regularization:
- `ExtendedThermalGenerationCost`: Base quadratic cost + APP penalty terms
- `ExtendedRenewableGenerationCost`: Renewable-specific curtailment costs
- `ExtendedHydroGenerationCost`: Hydro with ramping constraints

See [src/core/ExtendedThermalGenerationCost.jl](src/core/ExtendedThermalGenerationCost.jl) for pattern.

### Data Reading Pattern
For new test cases, use [example_cases/data_reader.jl](example_cases/data_reader.jl) instead of hardcoded arrays:

```julia
# Read from CSV/JSON
system_data = read_system_data_from_csv("path/to/case")
system = create_powersystems_from_data(system_data)
```

**Why**: Separates data from code, enables case-independent simulations. See [example_cases/DATA_READER_README.md](example_cases/DATA_READER_README.md).

## Integration Points

### PowerSystems.jl Components
- **Buses**: Use `ACBus(id, name, bustype, angle, magnitude, voltage_limits, base_voltage, ...)` for v4.x
- **Generators**: Must have `ramp_limits`, `time_limits`, and proper `operation_cost` (use Extended types)
- **System Construction**: `System(base_power)` then `add_component!(sys, component)`

### Solver Configuration
Default solver is **Ipopt** for nonlinear problems, **HiGHS** for linear:

```julia
using Ipopt, HiGHS
solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
```

**GPU Support**: [src/gpu/cuda_parallelization.jl](src/gpu/cuda_parallelization.jl) implements CUDA-accelerated ADMM for large systems (requires CUDA.jl).

### POMDP Integration
[PowerLASCOPF-NN-POMDP/](PowerLASCOPF-NN-POMDP/) contains neural network policy integration using POMDPs.jl for reinforcement learning. See [PowerLASCOPF-NN-POMDP/README.md](PowerLASCOPF-NN-POMDP/README.md).

## Common Pitfalls

1. **Hardcoded Paths**: Use `joinpath(@__DIR__, "relative/path")` or constants from [src/core/constants.jl](src/core/constants.jl). See [REORGANIZATION_SUMMARY.md](REORGANIZATION_SUMMARY.md) for why.

2. **Language Mixing**: Files were cleaned of Python (`def __init__`) and C++ (`cout`) syntax. Use pure Julia: `function`, `println`.

3. **ADMM Parameter Updates**: Must use `update_admm_parameters!(solver, new_params)` between iterations - parameters are stateful.

4. **Interval Coupling**: `PgNext` represents generator's belief about next interval power. Must enforce `RgMin ≤ PgNext - Pg ≤ RgMax` for ramping.

5. **Convergence Checking**: Both primal AND dual residuals must be below tolerance. Primal: power balance; Dual: price consensus.

## Documentation References

- [docs/DUAL_APPROACH_GUIDE.md](docs/DUAL_APPROACH_GUIDE.md): Preallocated vs direct solver comparison, benchmarking
- [docs/GENSOLVER_INTEGRATION_GUIDE.md](docs/GENSOLVER_INTEGRATION_GUIDE.md): PSI integration, ADMM loop structure
- [src/README.md](src/README.md): Source code organization details
- [REORGANIZATION_SUMMARY.md](REORGANIZATION_SUMMARY.md): Folder restructuring rationale

## Quick Reference: Typical ADMM Loop

```julia
# 1. Initialize
solver = GenSolver(interval_data, cost_curve, config)

# 2. Iterate
for iter in 1:max_iterations
    # Solve subproblem
    results = build_and_solve_gensolver!(solver, sys)
    
    # Update ADMM parameters (from network coordination)
    update_admm_parameters!(solver, Dict(
        "rho" => new_rho,
        "Pg_N_avg" => network_average_power,
        "lambda_1" => updated_multipliers
    ))
    
    # Check convergence
    if primal_residual < tol && dual_residual < tol
        break
    end
end
```

See [examples/dual_approach_demo.jl](examples/dual_approach_demo.jl) for complete working examples.
