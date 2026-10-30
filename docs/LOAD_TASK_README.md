# Load Work Summary

This document summarizes the load-related changes made for the IEEE test-case data path and the supporting runtime components.

## Goal

The objective was to finish the load-data path so that:

- loads are read from the case files
- each load gets a time-series profile when available
- inconsistent or missing bus references do not crash the reader
- the case loader reports data-integrity issues early

## Files Modified

| File | What changed |
|------|--------------|
| [src/components/load.jl](../src/components/load.jl) | Extended the load model to store nominal demand, a full PL profile, and the active interval; added helpers to attach and step through the profile. |
| [src/components/load_timeseries_integration.jl](../src/components/load_timeseries_integration.jl) | Updated the load updater to prefer the attached PL profile, fall back to the PSY time series when needed, and keep the node demand in sync. |
| [src/components/node.jl](../src/components/node.jl) | Added `set_load_val!` so the registered node load can be updated without double-counting the load connection. |
| [example_cases/data_reader.jl](../example_cases/data_reader.jl) | Implemented the shared load CSV path, built PL arrays from nominal demand times the hourly shape, and added safe handling for missing or inconsistent buses. |
| [example_cases/data_reader_generic.jl](../example_cases/data_reader_generic.jl) | Added a case-integrity audit that warns about missing buses, disconnected islands, and obvious generation-vs-load shortfalls. |
| [examples/run_reader_generic.jl](../examples/run_reader_generic.jl) | Added time-series file discovery and passed the loaded time series into the load builder. |
| [5bus_lascopf_results.json](../5bus_lascopf_results.json) | Regenerated during verification/testing. This is a run artifact, not a source change. |
| [57bus_lascopf_results.json](../57bus_lascopf_results.json) | Regenerated during verification/testing. This is a run artifact, not a source change. |

## What Was Implemented

### 1. Load model upgraded for time-varying demand

The load component now keeps:

- the PSY load object
- the nominal demand value
- the active demand for the current interval
- the full PL array
- the currently selected interval

This makes the load behave like a time-varying device instead of a single scalar value.

### 2. PL array construction in the reader

The load reader now:

- reads the Sahar load file
- finds the matching hourly time-series file
- multiplies nominal `ActivePower` by the hourly profile
- stores the resulting PL array on the load
- attaches the same profile to the underlying PSY `PowerLoad`

For the 5-bus case, this uses `Loads5_sahar.csv` and `TimeSeries_DA_sahar.csv`. The same pattern is now shared by the other IEEE load paths that route through the same builder.

### 3. Safe handling of incomplete data

If a load, generator, hydro unit, or storage device references a bus that does not exist in the case, the reader now:

- logs a warning
- skips the bad row
- continues loading the rest of the case

This avoids the hard crash that happened when the 300-bus data had missing nodes.

### 4. Case-integrity audit

After loading a case, the generic reader now checks for:

- component rows that reference missing buses
- disconnected bus groups / islands
- cases where nominal load appears larger than nominal generation capacity

The audit does not replace solver feasibility checks, but it catches obvious data issues earlier.

### 5. Runner now passes time-series data into the load builder

`run_reader_generic.jl` now looks for the time-series file variants used in the IEEE cases and passes the loaded time series into the load builder, so loads can be initialized with the PL profile from the start.

## Current Load Flow

1. `run_reader_generic.jl` selects the case and loads the case time-series data.
2. `data_reader_generic.jl` loads the case data and runs the integrity audit.
3. `data_reader.jl` creates PSY load objects and PowerLASCOPF load wrappers.
4. The nominal demand is scaled by the hourly profile to build the PL array.
5. The load is connected to the node and its demand bookkeeping is updated.
6. The simulation can advance the load interval through the attached profile.

## Validation Performed

- `git diff --check` completed successfully for the edited source files.
- The generic data reader was smoke-tested successfully in Julia and loaded without parse errors.

## Notes

- The JSON files `5bus_lascopf_results.json` and `57bus_lascopf_results.json` changed during verification runs. They are output artifacts from test execution, not logic changes.
- The reader now tolerates incomplete bus sets, but solver-side infeasibility checks are still separate from the data-loading layer.

## What Is Still Open

- End-to-end validation on the larger IEEE cases.
- Additional housekeeping and documentation cleanup requested in the meeting.
- Any deeper feasibility or island-detection logic that belongs in the solver rather than in the reader.
