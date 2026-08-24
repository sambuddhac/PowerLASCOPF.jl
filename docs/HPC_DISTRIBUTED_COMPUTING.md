# HPC Distributed Computing — PowerLASCOPF Three-Tier Architecture

This document is the technical reference for running PowerLASCOPF across multiple
compute nodes, cores, and threads using the three-tier decomposition implemented in:

- `src/algorithms/coordination/run_lascopf_hpc.jl` — Tier 1 entry point
- `src/algorithms/coordination/run_sim_lascopf_temp_app.jl` — serial APP outer loop (Tiers 2+3)
- `src/algorithms/admm_app_solver.jl` — Tier 3 (already threaded)
- `examples/run_hpc.jl` — HPC entry script
- `slurm_powerlascopf.sh` — annotated Slurm job script

---

## Table of Contents

1. [Architecture overview](#1-architecture-overview)
2. [Execution modes](#2-execution-modes)
3. [Running serially](#3-running-serially)
4. [Running with threads only (Tier 3)](#4-running-with-threads-only-tier-3)
5. [Running locally with multiple workers (Tiers 2+3)](#5-running-locally-with-multiple-workers-tiers-23)
6. [Running on a Slurm cluster (all 3 tiers)](#6-running-on-a-slurm-cluster-all-3-tiers)
7. [Slurm resource sizing](#7-slurm-resource-sizing)
8. [APP algorithm and convergence](#8-app-algorithm-and-convergence)
9. [Key data structures](#9-key-data-structures)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Architecture Overview

PowerLASCOPF decomposes the LASCOPF problem into three nested levels of
parallelism:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Tier 1 — Inter-node (Distributed.pmap)                                  │
│                                                                          │
│  Master process groups SuperNetworks by contingency scenario.           │
│  Each Slurm node receives one group and runs its share of the           │
│  APP outer loop iteration in parallel with all other nodes.             │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Tier 2 — Intra-node (Threads.@spawn)                             │   │
│  │                                                                   │   │
│  │  Each node spawns one Julia Task per time interval in its group. │   │
│  │  All tasks share the node's OS thread pool (Tier 3 threads).     │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐    │   │
│  │  │ Tier 3 — Core-level (Threads.@threads)                   │    │   │
│  │  │                                                           │    │   │
│  │  │  Inside solve_lascopf!, generator subproblems and        │    │   │
│  │  │  transmission subproblems are solved in parallel across  │    │   │
│  │  │  Julia threads (admm_app_solver.jl lines 141, 378, 503). │    │   │
│  │  └──────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Call chain

```
run_reader_generic.jl
  └─ run_case()
       └─ execute_simulation()                       [run_reader.jl]
            ├─ (nworkers > 1) → run_lascopf_hpc!()  [run_lascopf_hpc.jl]   ← Tier 1
            │     └─ pmap(_run_group_tier2!, groups)
            │           └─ Threads.@spawn per interval                      ← Tier 2
            │                 └─ run_simulation! → solve_lascopf!           ← Tier 3
            └─ (nworkers == 1) → run_app_outer_loop!()  [run_sim_lascopf_temp_app.jl]
                  └─ run_simulation! → solve_lascopf!                       ← Tier 3
```

---

## 2. Execution Modes

| Mode | Entry | Tier 1 | Tier 2 | Tier 3 |
|------|-------|--------|--------|--------|
| Serial | `run_reader_generic.jl` | — | — | single thread |
| Threaded only | `run_reader_generic.jl --threads=auto` | — | — | `Threads.@threads` |
| Local multi-worker | `run_hpc.jl workers=N` | local pmap | `Threads.@spawn` | `Threads.@threads` |
| Slurm cluster | `sbatch slurm_powerlascopf.sh` | Slurm pmap | `Threads.@spawn` | `Threads.@threads` |

---

## 3. Running Serially

```bash
# From the repository root
julia --project=. examples/run_reader_generic.jl case=14bus

# With extra solver options
julia --project=. examples/run_reader_generic.jl \
    case=14bus \
    iterations=50 \
    contingencies=4 \
    verbose=true
```

`nworkers() == 1`, so `execute_simulation` routes to `run_app_outer_loop!` which
iterates through all SuperNetworks sequentially.  Tier-3 threading is inactive
because Julia was started with the default of 1 thread.

**Use for:** initial debugging, checking correctness, profiling algorithm logic.

---

## 4. Running with Threads Only (Tier 3)

```bash
julia --project=. --threads=auto examples/run_reader_generic.jl case=14bus

# Explicit count
julia --project=. --threads=8 examples/run_reader_generic.jl \
    case=RTS_GMLC iterations=100 contingencies=4
```

`--threads=auto` tells Julia to use all logical CPU cores.  `nworkers()` is still
1 so the serial APP outer loop runs, but each call to `solve_lascopf!` runs
generator and transmission subproblems concurrently across the available threads.

**Use for:** single workstation runs; no MPI or Distributed overhead.

---

## 5. Running Locally with Multiple Workers (Tiers 2+3)

This mode simulates the full three-tier path without a cluster.

```bash
julia --project=. --threads=auto examples/run_hpc.jl case=14bus workers=4

# Larger test
julia --project=. --threads=4 examples/run_hpc.jl \
    case=RTS_GMLC \
    workers=8 \
    contingencies=8 \
    iterations=100
```

`run_hpc.jl` passes `workers=N` to `setup_hpc_workers!(local_fallback_procs=N)`,
which adds N-1 local Distributed workers via `Distributed.addprocs`.  Once
`nworkers() > 1`, `execute_simulation` routes to `run_lascopf_hpc!`.

Inside `run_lascopf_hpc!`:
1. `group_supernetworks` partitions SuperNetworks by `post_contingency` index.
2. `pmap(_run_group_tier2!, groups, ...)` sends each group to a worker (Tier 1).
3. On the worker, `_run_group_tier2!` spawns one `Threads.@spawn` task per
   SuperNetwork (Tier 2) and waits for all to finish.
4. Each task calls `run_simulation! → run_network_simulation! → solve_lascopf!`
   (Tier 3).
5. Results are returned as a compact `_ScenarioResult` (serialisable over the
   network) and collected on the master.

**Use for:** local correctness testing of the distributed code path before
submitting a Slurm job.

---

## 6. Running on a Slurm Cluster (All 3 Tiers)

### 6.1 Edit the Slurm script

Open `slurm_powerlascopf.sh` and set:

```bash
#SBATCH --nodes=5          # 1 master + 4 workers (n_contingencies + 2)
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=04:00:00

CASE=14bus
ITERATIONS=100
CONTINGENCIES=4            # must be ≤ --nodes - 1
```

### 6.2 Submit

```bash
sbatch slurm_powerlascopf.sh
```

### 6.3 What happens on the cluster

1. Slurm allocates `--nodes` nodes.  The first node runs the master Julia process
   (`srun julia ... run_hpc.jl`).
2. `setup_hpc_workers!` detects the Slurm environment (`SLURM_NTASKS > 1`) and
   calls `ClusterManagers.addprocs_slurm(n_tasks - 1)` to spawn one Distributed
   worker per remaining node.
3. `_broadcast_solver_stack!` loads `supernetwork.jl` and
   `run_sim_lascopf_temp_app.jl` on every worker so all necessary code is
   available remotely.
4. Each worker inherits `JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK` (set in the
   script), enabling Tiers 2 and 3 on each node's full core count.
5. The APP outer loop iterates:
   - `pmap` sends one contingency group per worker (Tier 1).
   - Workers run `_run_group_tier2!` with `Threads.@spawn` (Tier 2).
   - Each spawned task calls `solve_lascopf!` with `Threads.@threads` (Tier 3).
   - `_ScenarioResult` objects are serialised back to the master.
   - Master updates beliefs and checks convergence (`fin_tol < 0.005`).

### 6.4 Monitoring

```bash
squeue -u $USER                     # check job status
tail -f logs/slurm_<jobid>.out      # live stdout
tail -f logs/hpc_<timestamp>.log    # detailed log (written by run_hpc.jl TeeIO)
```

---

## 7. Slurm Resource Sizing

### Nodes

```
--nodes = n_contingencies + 2
```

- 1 node: master process (does no pmap work itself)
- n_contingencies nodes: one per contingency scenario group
- 1 spare: absorbs the base-case (contingency 0) group if present

Examples:
- 4 contingencies → `--nodes=6`
- 8 contingencies → `--nodes=10`

If the cluster has a maximum node limit, reduce `CONTINGENCIES` accordingly (the
solver still converges; some workers handle more than one group).

### Threads per node

```
--cpus-per-task = (node core count)
```

Typical values: 16, 32, 64.  Julia will use all of them for Tiers 2 and 3.
Setting `--cpus-per-task` higher than available cores wastes allocation without
benefit.

### Memory per node

| Case size | Recommended `--mem` |
|-----------|---------------------|
| 2–30 bus | 8 GB |
| 57–118 bus | 16–32 GB |
| 300 bus / RTS-GMLC | 32–64 GB |
| ACTIVSg2000+ | 64–128 GB |

### Wall-clock time

Start with `--time=02:00:00` for small cases.  The APP outer loop runs until
`fin_tol < 0.005` or `max_app_iterations` is reached (default: unlimited).
Set `ITERATIONS=N` in the script to cap iteration count and therefore runtime.

---

## 8. APP Algorithm and Convergence

### Outer loop (cross-interval consensus)

Convergence criterion: `fin_tol < 0.005`

`fin_tol` measures the maximum absolute generator power disagreement between
consecutive belief updates across all SuperNetworks and generator indices.

### Inner loop (per-SuperNetwork, base + contingency consensus)

Each call to `run_simulation!` runs an inner APP loop with `fin_tol < 0.5`
and at most 10 inner iterations.

### Alpha schedule

The APP step length `α` (path-length parameter) is scheduled by `tune_alpha_app`:

| Outer iteration range | α |
|-----------------------|---|
| 1–5 | 100.0 |
| 6–10 | 75.0 |
| 11–15 | 50.0 |
| 16–20 | 25.0 |
| > 20 | 10.0 |

A large initial `α` drives fast belief alignment; smaller `α` as convergence
approaches prevents overshooting.

### Belief arrays

| Array | Shape | Meaning |
|-------|-------|---------|
| `power_self_gen` | `[n_gen]` | generator's own dispatch in this SuperNetwork |
| `power_next_bel` | `[n_gen]` | belief of the next-interval SuperNetwork |
| `power_prev_bel` | `[n_gen]` | belief of the previous-interval SuperNetwork |
| `power_self_flow_bel` | `[n_lines]` | this SuperNetwork's line flow belief |
| `power_next_flow_bel` | `[n_lines]` | next-interval line flow belief |

### Lagrange arrays

| Array | Shape | Meaning |
|-------|-------|---------|
| `lambda_app` | `[n_gen]` | generator dual variable for power consensus |
| `pow_diff` | `[n_gen]` | generator primal residual |
| `lambda_app_line` | `[n_lines]` | line dual variable |
| `pow_diff_line` | `[n_lines]` | line primal residual |

---

## 9. Key Data Structures

### `SuperNetwork` (`src/components/supernetwork.jl`)

One `SuperNetwork` instance corresponds to one `(contingency, time_interval)` pair.
Key fields used by the coordination layer:

```julia
sn.post_contingency    # Int — contingency index (0 = base case)
sn.interval            # Int — time interval index
```

### `_ScenarioResult` (`src/algorithms/coordination/run_lascopf_hpc.jl`)

Compact, serialisable return value from `pmap` workers:

```julia
struct _ScenarioResult
    group_indices::Vector{Int}      # indices into future_net_vector
    exec_times::Vector{Float64}     # wall time per SuperNetwork (seconds)
    gen_powers::Matrix{Float64}     # [n_gen × n_supernetworks_in_group]
    flow_powers::Matrix{Float64}    # [n_lines × n_supernetworks_in_group]
end
```

After each `pmap` round-trip, master processes `_ScenarioResult` objects to
update global belief arrays before the next APP outer iteration.

### `LASCOPFSolver` (`src/algorithms/admm_app_solver.jl`)

Dict-based solver wrapper accepted by `solve_lascopf!`:

```julia
solver = LASCOPFSolver(
    Dict("nodes" => ..., "branches" => ..., "thermal_generators" => ..., ...),
    Dict("max_iterations" => 30, "tolerance" => 1e-4, "rho" => rho_tuning,
         "beta" => 1.0, "gamma" => 1.0, "inner_iterations" => 5)
)
solve_lascopf!(solver)
```

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `ClusterManagers not found` | Package not installed | `Pkg.add("ClusterManagers")` |
| Workers added but `nworkers() == 1` | `addprocs` returned 0 (Slurm not detected) | Check `SLURM_NTASKS` env var; use `workers=N` for local fallback |
| `Could not include supernetwork.jl on worker` | Path resolution failed on remote node | Ensure all nodes mount the same filesystem at the same path |
| Convergence extremely slow | Alpha too large for this case | Reduce starting alpha in `tune_alpha_app`; increase `max_app_iterations` |
| Out of memory on worker | Case too large for allocated `--mem` | Double `--mem`; reduce `CONTINGENCIES` per node |
| `pmap` hangs indefinitely | Worker exception swallowed | Add `on_error=identity` to pmap call for debugging; check `.err` log |
| Tier-3 threads idle | `--threads` not set | Always pass `--threads=auto` or `--threads=N` to Julia |
| `JULIA_NUM_THREADS` not propagated | Slurm `--export` missing | Add `#SBATCH --export=ALL` or explicitly export the variable before `srun` |

---

*See also:*
- [EXECUTION_FLOW_GUIDE.md](EXECUTION_FLOW_GUIDE.md) — full call chain from `run_reader_generic.jl` to `solve_lascopf!`
- [DUAL_APPROACH_GUIDE.md](DUAL_APPROACH_GUIDE.md) — ADMM vs APP algorithm selection
- [README.md](../README.md) — quick-start and case reference
