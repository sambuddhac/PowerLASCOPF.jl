#!/bin/bash
#SBATCH --nodes=4                  # Level 1: 4 nodes, 1 per contingency scenario group
#SBATCH --ntasks-per-node=2        # Level 2: 2 intra-node Julia workers (1 per CPU socket)
#SBATCH --cpus-per-task=16         # Level 3: 16 cores per worker for Threads.@threads
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=4G

export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK   # threads available to each Level-2 worker
export JULIA_WORKER_TIMEOUT=120

# ClusterManagers reads SLURM_NTASKS = nodes × ntasks-per-node = 8 workers total
julia --project run_lascopf_hpc.jl
