#!/bin/bash
# slurm_powerlascopf.sh — Slurm job script for PowerLASCOPF HPC runs
#
# Three-tier parallelism:
#   Tier 1: --nodes × --ntasks-per-node Julia processes (inter-node pmap)
#   Tier 2: --cpus-per-task threads per process (Threads.@spawn over intervals)
#   Tier 3: same thread pool, Threads.@threads over generator subproblems
#
# Resource sizing guidelines
#   --nodes:            n_cont + 2  (one per contingency group + base group + 1 master)
#                       Round up to the next available node count if needed.
#   --ntasks-per-node:  1           (one Julia process per node; Tier 1 granularity)
#   --cpus-per-task:    match available cores (16, 32, 64, …)
#   --mem:              ≥ 8 GB per process for mid-size cases (e.g., 14–57 bus)
#                       ≥ 64 GB per process for large cases (RTS-GMLC, ACTIVSg)
#
# Edit the SBATCH lines and CASE / extra arguments below for your run.

#SBATCH --job-name=PowerLASCOPF
#SBATCH --nodes=5                  # 1 master + 4 contingency-group workers
#SBATCH --ntasks-per-node=1        # 1 Julia process per node
#SBATCH --cpus-per-task=16         # threads per process (Tier 2 + Tier 3)
#SBATCH --mem=32G                  # memory per node
#SBATCH --time=04:00:00            # wall-clock limit
#SBATCH --output=logs/slurm_%j.out
#SBATCH --error=logs/slurm_%j.err

# ── Environment ───────────────────────────────────────────────────────────────
module load julia/1.10   # adjust to your cluster's module name

# Tier 2+3: each Julia process uses all CPUs allocated to it
export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Optional: force Polyester to use the same thread count
export POLYESTER_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Julia depot / package cache (set to a fast shared filesystem if available)
# export JULIA_DEPOT_PATH=/scratch/$USER/julia_depot

# ── Case selection ─────────────────────────────────────────────────────────────
CASE=14bus            # e.g., 14bus | 30bus | RTS_GMLC | ACTIVSg2000
ITERATIONS=100        # max APP outer iterations
CONTINGENCIES=4       # must match --nodes - 1 (or fewer)

# ── Run ────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# srun ensures Julia sees the correct Slurm environment variables on each node.
# ClusterManagers.addprocs_slurm() reads SLURM_NTASKS to spawn Distributed workers.
srun julia --project="$SCRIPT_DIR" \
           --threads=$SLURM_CPUS_PER_TASK \
           "$SCRIPT_DIR/examples/run_hpc.jl" \
           case=$CASE \
           iterations=$ITERATIONS \
           contingencies=$CONTINGENCIES
