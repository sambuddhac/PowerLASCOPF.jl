# Running PowerLASCOPF Example Cases

This guide explains how to run any case from the `example_cases/` folder using
`run_reader_generic.jl` — the single entry-point runner that supersedes all
case-specific scripts (`run_5bus_lascopf.jl`, `run_14bus_lascopf.jl`, …).

---

## Table of Contents

1. [Quick start](#1-quick-start)
2. [Available cases and formats](#2-available-cases-and-formats)
3. [Running modes](#3-running-modes)
4. [Command-line arguments](#4-command-line-arguments)
5. [LASCOPF_settings.yml — per-case ADMM configuration](#5-lascopf_settingsyml--per-case-admm-configuration)
6. [How format detection works](#6-how-format-detection-works)
7. [Adding a new case](#7-adding-a-new-case)
8. [File architecture](#8-file-architecture)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Quick start

```bash
# From the repository root — activate the project first
julia --project=. examples/run_reader_generic.jl

# Or from the examples/ folder
cd examples/
julia run_reader_generic.jl          # interactive mode
julia run_reader_generic.jl list     # list all available cases
julia run_reader_generic.jl case=14bus
julia run_reader_generic.jl case=RTS_GMLC
julia run_reader_generic.jl case=ACTIVSg2000
```

From the Julia REPL:

```julia
include("examples/run_reader_generic.jl")

run_case("14bus")                            # IEEE 14-bus (sahar CSV)
run_case("RTS_GMLC")                         # RTS-GMLC CSV format
run_case("ACTIVSg2000")                      # PSS/E RAW / MATPOWER
run_case("SyntheticUSA")                     # PSS/E RAW

list_available_cases()                       # print all cases with format
interactive_mode()                           # guided interactive menu
run_all_cases()                              # run every discovered case
```

---

## 2. Available cases and formats

### IEEE Test Cases  —  `example_cases/IEEE_Test_Cases/IEEE_<N>_bus/`

| Case name (short) | Full folder name   | Format  | Files                              |
|-------------------|--------------------|---------|-------------------------------------|
| `2bus`            | IEEE_2_bus         | Sahar   | `Nodes2_sahar.csv`, `Trans2_sahar.csv`, … |
| `3bus`            | IEEE_3_bus         | Sahar   | same pattern                       |
| `5bus`            | IEEE_5_bus         | Sahar   | same pattern                       |
| `14bus`           | IEEE_14_bus        | Sahar   | same pattern (also has `.json`)    |
| `30bus`           | IEEE_30_bus        | Sahar   | same pattern                       |
| `48bus`           | IEEE_48_bus        | Sahar   | same pattern                       |
| `57bus`           | IEEE_57_bus        | Sahar   | same pattern                       |
| `118bus`          | IEEE_118_bus       | Legacy  | `Gen118.csv`, `Load118.csv`, …     |
| `300bus`          | IEEE_300_bus       | Legacy  | `Gen300.csv`, `Load300.csv`, …     |

Short names (`5bus`, `14bus`, …) and full folder names (`IEEE_14_bus`) are both accepted.

### Non-IEEE Cases  —  `example_cases/<CaseName>/`

All folders at the top level of `example_cases/` that contain a
`LASCOPF_settings.yml` file are discovered automatically.

| Case name      | Format           | Primary files                                     |
|----------------|------------------|---------------------------------------------------|
| `RTS_GMLC`     | RTS-GMLC CSV     | `bus.csv`, `gen.csv`, `branch.csv`, `storage.csv` |
| `5-bus-hydro`  | RTS-GMLC CSV     | `bus.csv`, `branch.csv`                           |
| `ACTIVSg2000`  | PSS/E RAW        | `ACTIVSg2000.RAW` (+ optional `.m`)               |
| `ACTIVSg10k`   | PSS/E RAW        | `ACTIVSg10k.RAW`                                  |
| `ACTIVSg70k`   | PSS/E RAW        | `ACTIVSg70k.RAW`                                  |
| `SyntheticUSA` | PSS/E RAW        | `SyntheticUSA.RAW` (+ optional `.m`)              |

> **PSS/E RAW and MATPOWER cases** require PowerSystems.jl to be fully loaded
> (see [File architecture](#8-file-architecture)).  Until `data_reader.jl` is
> active, they fall back to the DataFrame-stub simulation.

---

## 3. Running modes

### 3a. Interactive mode (recommended for first use)

```bash
julia run_reader_generic.jl
```

The runner will:
1. Display all discovered cases with their format type.
2. Prompt you to select a case by number or name.
3. Ask for optional parameters (iterations, tolerance, verbose).
4. Run the simulation and offer to run another case.

### 3b. Command-line mode

```bash
julia run_reader_generic.jl case=<name> [options]
```

Examples:

```bash
# IEEE cases (sahar format — no extra dependencies)
julia run_reader_generic.jl case=5bus
julia run_reader_generic.jl case=14bus format=JSON verbose=true
julia run_reader_generic.jl case=IEEE_300_bus iterations=50 tolerance=1e-4

# Non-IEEE cases
julia run_reader_generic.jl case=RTS_GMLC
julia run_reader_generic.jl case=ACTIVSg2000 contingencies=10
julia run_reader_generic.jl case=SyntheticUSA output=synusa_results.json
```

### 3c. Special commands

```bash
julia run_reader_generic.jl list    # list all cases with format icons
julia run_reader_generic.jl help    # print argument reference
julia run_reader_generic.jl all     # run every discovered case sequentially
```

---

## 4. Command-line arguments

| Argument               | Default                              | Description                                              |
|------------------------|--------------------------------------|----------------------------------------------------------|
| `case=<name>`          | *(required)*                         | Case name: `5bus`, `14bus`, `RTS_GMLC`, `ACTIVSg2000`, … |
| `format=<CSV\|JSON>`   | `CSV`                                | File format for sahar/legacy cases (ignored for RAW/m)   |
| `iterations=<n>`       | `10`                                 | Maximum ADMM outer iterations                            |
| `tolerance=<x>`        | `1e-3`                               | Convergence tolerance                                    |
| `contingencies=<n>`    | `2`                                  | Number of N-1 contingency scenarios                      |
| `output=<file>`        | `<case>_lascopf_results.json`        | JSON output file path                                    |
| `verbose=<true\|false>`| `false`                              | Print ADMM iteration detail                              |

Arguments without `=` are treated as the case name:
```bash
julia run_reader_generic.jl 14bus verbose=true   # same as case=14bus
```

---

## 5. LASCOPF_settings.yml — per-case ADMM configuration

Every non-IEEE case folder (and optionally IEEE folders) can contain a
`LASCOPF_settings.yml` that controls solver behaviour.  If the file is absent,
built-in defaults are used.

```yaml
# LASCOPF_settings.yml — example
contSolverAccuracy: 0    # 0 = fast contingency solver, 1 = exhaustive
solverChoice: 1          # 1=GUROBI-APMP  2=CVXGEN-APMP  3=GUROBI-Coarse  4=Centralised
nextChoice: 1            # 1 = enforce ramp constraint at last interval
setRhoTuning: 3          # ADMM ρ update mode (3 = adaptive)
dummyIntervalChoice: 1   # 1 = include dummy zero interval (improves convergence)
RNDIntervals: 3          # look-ahead intervals for N-1 line restoration
RSDIntervals: 3          # further look-ahead intervals for N-1-1 security
```

These settings are loaded automatically by `load_case_data()` and passed through
to `execute_simulation()` via the `config` dictionary.

---

## 6. How format detection works

`detect_file_format()` in `data_reader_generic.jl` inspects the case folder and
returns one of five symbols:

| Symbol       | Detection rule                                            | Builder called           |
|--------------|-----------------------------------------------------------|--------------------------|
| `:sahar`     | `ThermalGenerators<N>_sahar.csv` or `Nodes<N>_sahar.csv` present | `powerlascopf_*_from_csv!` |
| `:legacy`    | `Gen<N>.csv` present (no sahar files)                    | `powerlascopf_*_from_csv!` (legacy columns) |
| `:psse_raw`  | any `*.RAW` or `*.raw` file present                       | `PSY.System(file)` → `powerlascopf_from_psy_system!` |
| `:matpower`  | any `*.m` file present (no RAW)                           | `PSY.System(file)` → `powerlascopf_from_psy_system!` |
| `:rts_gmlc`  | `gen.csv` + `bus.csv` + `branch.csv` all present         | `powerlascopf_from_rts_gmlc!` |

Detection is automatic — you do not specify a format for non-CSV cases.

---

## 7. Adding a new case

### Option A — Sahar CSV format (IEEE-style)

1. Create `example_cases/IEEE_Test_Cases/IEEE_<N>_bus/`
2. Add the required CSV files (see `IEEE_Test_Cases/ADDING_NEW_CASES.md`):
   - `Nodes<N>_sahar.csv`
   - `ThermalGenerators<N>_sahar.csv`
   - `Trans<N>_sahar.csv`
   - `Loads<N>_sahar.csv`
3. Optionally add `RenewableGenerators<N>_sahar.csv`, `HydroGenerators<N>_sahar.csv`,
   `Storage<N>_sahar.csv`
4. Run: `julia run_reader_generic.jl case=<N>bus`

### Option B — PSS/E RAW or MATPOWER format

1. Create `example_cases/<CaseName>/`
2. Place your `.RAW` or `.m` file in that folder.
3. Add `LASCOPF_settings.yml` (copy from an existing case and adjust).
4. Run: `julia run_reader_generic.jl case=<CaseName>`

> Requires PowerSystems.jl and PowerLASCOPF loaded — see
> [File architecture](#8-file-architecture).

### Option C — RTS-GMLC CSV format

1. Create `example_cases/<CaseName>/`
2. Add `bus.csv`, `gen.csv`, `branch.csv` in RTS-GMLC column format.
   Optionally add `storage.csv` and `reserves.csv`.
3. Add `LASCOPF_settings.yml`.
4. Run: `julia run_reader_generic.jl case=<CaseName>`

### Registering non-numeric names (optional)

If your case name contains no digits (e.g., `MyGrid`), add it to the
`CASE_NAME_REGISTRY` constant in `data_reader_generic.jl`:

```julia
const CASE_NAME_REGISTRY = Dict{String, Int}(
    "RTS_GMLC"   => 73,
    "MyGrid"     => 42,    # ← add here
    ...
)
```

Cases whose names already contain a number (`ACTIVSg2000`, `5bus`) are resolved
automatically.

---

## 8. File architecture

```
examples/
  run_reader_generic.jl   ← ENTRY POINT  (this is what you run)
  run_reader.jl           ← simulation stub + execute_simulation()
                             + optional include of data_reader.jl

example_cases/
  data_reader_generic.jl  ← format detection, path resolution,
                             raw CSV reading, load_case_data()
  data_reader.jl          ← PowerLASCOPF system builders:
                             powerlascopf_from_psy_system!()   (PSS/E RAW / MATPOWER)
                             powerlascopf_from_rts_gmlc!()     (RTS-GMLC)
                             powerlascopf_*_from_csv!()        (sahar / legacy)
                             apply_lascopf_settings()
```

### Include chain

```
run_reader_generic.jl
  └── includes data_reader_generic.jl   (always — pure CSV/DataFrame, no PowerLASCOPF)
  └── includes run_reader.jl            (always — execute_simulation() stub)
        └── try-includes data_reader.jl (when PowerLASCOPF is in scope)
```

`data_reader.jl` requires both `PowerSystems` and `PowerLASCOPF` to be loaded.
While PowerLASCOPF is still under development (src/ not yet a registered package),
the `data_reader.jl` include in `run_reader.jl` is inside a `try/catch`.

**To enable full system construction** (PSS/E RAW, MATPOWER, RTS-GMLC, sahar):

1. Uncomment the PowerLASCOPF source block in `run_reader.jl`:
   ```julia
   # run_reader.jl — uncomment to load the PowerLASCOPF algorithm:
   include("../src/PowerLASCOPF.jl")
   include("../src/components/supernetwork.jl")
   ```
2. Re-run — `data_reader.jl` will load automatically and Phase 2.5 in
   `run_case()` will build the real `PowerLASCOPFSystem`.

Until then, `run_case()` completes the data-loading phase normally and falls
back to the DataFrame-based economic dispatch stub for the simulation phase.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Could not find data folder for case: X` | Folder doesn't exist or has no `LASCOPF_settings.yml` | Create folder and add settings file |
| `Could not determine bus count from case name: X` | Name has no digits and isn't in CASE_NAME_REGISTRY | Add entry to CASE_NAME_REGISTRY |
| `No .RAW file found in: ...` | RAW case folder is empty | Place `.RAW` file in the folder |
| `data_reader.jl could not be loaded` | PowerLASCOPF not in scope | Uncomment src/ includes in run_reader.jl (see §8) |
| PSS/E RAW case uses stub dispatch | data_reader.jl not loaded | Same as above |
| `gen.csv column not found` | RTS-GMLC column names differ from expected | Check column names against the mapping in data_reader_generic.jl §6.5 |
| Interactive mode shows no cases | `example_cases/` path not found | Run from the `examples/` folder or repository root |
