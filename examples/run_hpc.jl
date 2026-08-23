# run_hpc.jl — HPC cluster entry point for PowerLASCOPF
#
# Usage
# ─────
#   Single node (testing):
#     julia --threads=auto run_hpc.jl case=14bus workers=4
#
#   Slurm cluster (production):
#     sbatch slurm_powerlascopf.sh
#
# Arguments (same as run_reader_generic.jl, plus)
#   workers=N    Local workers to add for testing (ignored on Slurm)
#
# This script is a thin wrapper over run_reader_generic.jl that calls
# setup_hpc_workers!() before the case runs, enabling the three-tier
# distributed path in execute_simulation.
#
# The three tiers (described in run_lascopf_hpc.jl):
#   Tier 1 – pmap over contingency scenario groups     (Slurm nodes)
#   Tier 2 – Threads.@spawn over intervals per group   (node cores)
#   Tier 3 – Threads.@threads over generator subproblems (already in admm_app_solver.jl)

using Pkg
using Dates

const SCRIPT_DIR  = @__DIR__
const PROJECT_ROOT = abspath(joinpath(SCRIPT_DIR, ".."))

# ── Log file (same TeeIO pattern as run_reader_generic.jl) ───────────────────
struct TeeIO <: IO
    primary::IO
    secondary::IO
end
Base.write(t::TeeIO, b::UInt8)               = (write(t.primary, b); write(t.secondary, b); 1)
Base.write(t::TeeIO, b::StridedVector{UInt8}) = (write(t.primary, b); write(t.secondary, b); length(b))
Base.flush(t::TeeIO)  = (flush(t.primary);  flush(t.secondary))
Base.isopen(t::TeeIO) = isopen(t.primary)

const LOG_DIR       = joinpath(PROJECT_ROOT, "logs")
mkpath(LOG_DIR)
const LOG_TIMESTAMP = Dates.format(now(), "yyyymmdd_HHMMSS")
const LOG_FILE      = joinpath(LOG_DIR, "hpc_$(LOG_TIMESTAMP).log")
const LOG_IO        = open(LOG_FILE, "w")
const _ORIG_STDOUT  = stdout
Core.eval(Base, :(stdout = $(TeeIO(_ORIG_STDOUT, LOG_IO))))
atexit() do
    Core.eval(Base, :(stdout = $(_ORIG_STDOUT)))
    flush(LOG_IO); close(LOG_IO)
end

println("HPC log: $LOG_FILE")
Pkg.activate(PROJECT_ROOT)
Pkg.instantiate()

# ── Packages ──────────────────────────────────────────────────────────────────
using Distributed, DataFrames, JSON3, Printf, Dates

# ── Parse --workers argument before loading anything else ─────────────────────
local_workers = 0
hpc_args = String[]
for arg in ARGS
    if startswith(lowercase(arg), "workers=")
        local_workers = parse(Int, split(arg, "=")[2])
    else
        push!(hpc_args, arg)
    end
end

# ── Load data reader and simulation runner ────────────────────────────────────
include(joinpath(PROJECT_ROOT, "example_cases", "data_reader_generic.jl"))
include(joinpath(PROJECT_ROOT, "examples",      "run_reader.jl"))

# ── Load the HPC module on the master BEFORE adding workers ──────────────────
# run_lascopf_hpc.jl defines setup_hpc_workers!, run_lascopf_hpc!, etc.
include(joinpath(PROJECT_ROOT, "src", "algorithms", "coordination",
                 "run_lascopf_hpc.jl"))

# ── Setup workers (Slurm or local) ───────────────────────────────────────────
println("\n=== PowerLASCOPF HPC Runner ===")
println("Julia threads (this process): $(Threads.nthreads())")
setup_hpc_workers!(; local_fallback_procs = local_workers)
println("Distributed workers active:   $(nworkers())")
println("Effective Tier-1 × Tier-2/3 = $(nworkers()) × $(Threads.nthreads())")

# ── Run the case (uses run_reader_generic.jl logic) ───────────────────────────
# parse_arguments is defined in run_reader_generic.jl
# Override ARGS with the filtered list (workers= removed)
Base.eval(Main, :(ARGS = $hpc_args))
main()
