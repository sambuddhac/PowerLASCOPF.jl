# run_lascopf_hpc.jl — Three-Tier HPC Entry Point for PowerLASCOPF
#
# Hardware / parallelism mapping
# ────────────────────────────────────────────────────────────────────────────
#
#   Tier 1 – Inter-Node Distributed  (Julia Distributed + Slurm)
#     pmap over contingency scenario groups.
#     Each Slurm node runs one Julia process that owns one group.
#     Slurm knobs: --nodes N  (N scenario groups + 1 master)
#                  --ntasks-per-node 1
#
#   Tier 2 – Intra-Node Parallel  (Threads.@spawn / Base.Threads)
#     Within each node: all SuperNetworks in the scenario group are solved
#     concurrently, one Threads.@spawn task per SuperNetwork.
#     Slurm knob: --cpus-per-task C  +  JULIA_NUM_THREADS=C
#
#   Tier 3 – Core-Level Multi-threading  (Threads.@threads / Polyester.@batch)
#     Inside solve_lascopf! (admm_app_solver.jl):
#       solve_generator_subproblems!     → Threads.@threads over gens
#       solve_transmission_subproblems!  → Threads.@threads over branches
#       calculate_residuals              → Threads.@threads over nodes/gens
#     No changes required here — Tier 3 is already implemented.
#
# Integration with the serial path
# ────────────────────────────────────────────────────────────────────────────
#   run_lascopf_hpc!  is a drop-in replacement for  run_app_outer_loop!.
#   execute_simulation (run_reader.jl) is updated to choose between them:
#     nworkers() > 1  →  run_lascopf_hpc!      (HPC path)
#     nworkers() == 1 →  run_app_outer_loop!   (serial / fallback path)
#
# Typical Slurm script
# ────────────────────────────────────────────────────────────────────────────
#   #!/bin/bash
#   #SBATCH --job-name=PowerLASCOPF
#   #SBATCH --nodes=5               # 1 master + 4 contingency-group workers
#   #SBATCH --ntasks-per-node=1     # 1 Julia process per node
#   #SBATCH --cpus-per-task=16      # 16 hardware threads per process
#   #SBATCH --mem=64G
#   export JULIA_NUM_THREADS=$SLURM_CPUS_PER_TASK
#   srun julia --project run_reader_generic.jl case=14bus
#
# State-synchronisation note (read before modifying _update_beliefs_*!)
# ────────────────────────────────────────────────────────────────────────────
#   After a pmap round, each remote worker holds the updated SuperNetwork state
#   in its own serialized copy — the master's future_net_vector is stale.
#   The belief-update helpers (_update_beliefs_with_dummy! etc.) call
#   get_pow_self / get_pow_prev / get_pow_next on the master's SuperNetworks.
#   Until those getters read real solver output (they currently return 0.0),
#   the stale state is harmless.  Once getters are wired to solver outputs,
#   the pmap must return a compact result struct (gen powers + flow values per
#   interval) which the master uses to refresh its SuperNetworks BEFORE calling
#   _update_beliefs_*!  See _ScenarioResult and _apply_group_results! below.

using Distributed
using Base.Threads
using Printf
using JSON3

try
    using ClusterManagers   # only available on Slurm clusters
catch
end

# ─────────────────────────────────────────────────────────────────────────────
# Tier 1 setup: launch inter-node workers
# ─────────────────────────────────────────────────────────────────────────────

"""
    setup_hpc_workers!(; local_fallback_procs)

Launch Distributed workers for Tier-1 inter-node parallelism.

On a Slurm cluster (SLURM_NTASKS is set): launches n-1 workers via
`addprocs_slurm`, keeping the current process as master.

On a workstation (SLURM_NTASKS absent): launches `local_fallback_procs - 1`
local workers for testing (default = 0 → no extra workers).

No-op if workers are already running.  After adding workers, broadcasts the
full solver stack to all workers so they can call `run_simulation!` etc.
"""
function setup_hpc_workers!(; local_fallback_procs::Int = 0)
    nworkers() > 1 && return   # already configured

    if haskey(ENV, "SLURM_NTASKS")
        n = parse(Int, ENV["SLURM_NTASKS"])
        if n > 1
            @info "Slurm: launching $(n-1) inter-node workers (SLURM_NTASKS=$n)"
            addprocs_slurm(n - 1)
        end
    elseif local_fallback_procs > 1
        @info "No Slurm env: launching $(local_fallback_procs-1) local workers for testing"
        addprocs(local_fallback_procs - 1)
    end

    nworkers() > 1 && _broadcast_solver_stack!()
end

"""
    _broadcast_solver_stack!()

Use `@everywhere` to load the solver stack on every worker process so that
`run_simulation!`, `solve_lascopf!`, `tune_alpha_app`, etc. are callable
without re-instantiating the module on each worker.
"""
function _broadcast_solver_stack!()
    src = joinpath(@__DIR__, "..", "..")   # …/src/
    @everywhere begin
        using Base.Threads, Printf, JSON3
        try using Polyester catch end
        # Include in dependency order; try/catch prevents errors when the module
        # image is already loaded (e.g., sysimage, PackageCompiler).
        for f in [
            joinpath($src, "components", "supernetwork.jl"),
            joinpath($src, "algorithms", "coordination",
                     "run_sim_lascopf_temp_app.jl"),
        ]
            try
                include(f)
            catch e
                @warn "Worker $(myid()): could not include $(basename(f)): $e"
            end
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Scenario-group classification
# ─────────────────────────────────────────────────────────────────────────────

"""
    belongs_to_scenario(sn, scenario_idx) -> Bool

True when SuperNetwork `sn` belongs to contingency scenario group `scenario_idx`.
  - scenario_idx == 0  →  base-case group (dummy, forthcoming, base RND/RSD)
  - scenario_idx >= 1  →  post-contingency group i (RND+RSD intervals for outage i)
"""
belongs_to_scenario(sn::SuperNetwork, scenario_idx::Int) =
    sn.post_contingency == scenario_idx

"""
    group_supernetworks(future_net_vector, number_of_cont, rnd_intervals,
                        rsd_intervals, dummy_interval_choice)
    -> Vector{Vector{Int}}

Partition the 1-based indices of `future_net_vector` into `number_of_cont + 1`
scenario groups by reading each SuperNetwork's `post_contingency` field.

  groups[1]          → indices for contingency scenario 0 (base case)
                        includes dummy (if dummy_interval_choice) and forthcoming
  groups[i+1], i≥1  → indices for contingency scenario i

This is used by the Tier-1 `pmap` to assign one group per inter-node worker.
"""
function group_supernetworks(
    future_net_vector::Vector{SuperNetwork},
    number_of_cont::Int,
    rnd_intervals::Int,
    rsd_intervals::Int,
    dummy_interval_choice::Bool
)::Vector{Vector{Int}}
    groups = [Int[] for _ in 0:number_of_cont]

    for (idx, sn) in enumerate(future_net_vector)
        grp = sn.post_contingency + 1   # 1-based group index
        if 1 <= grp <= length(groups)
            push!(groups[grp], idx)
        end
    end

    return groups
end

# ─────────────────────────────────────────────────────────────────────────────
# Compact result struct for pmap return (future state-sync hook)
# ─────────────────────────────────────────────────────────────────────────────

"""
    _ScenarioResult

Minimal serialisable result returned by each Tier-1 worker.

  group_indices  — which SuperNetwork indices this worker solved
  exec_times     — per-SuperNetwork wall times (s) for virtual-time accounting
  gen_powers     — [sn_local_idx, gen_idx] → solved power output
                   (populated once get_pow_self is wired; currently unused)
  flow_powers    — [sn_local_idx, line_idx] → solved line flow
                   (populated once get_pow_flow_self is wired; currently unused)

Keeping this struct small avoids excessive serialization overhead over MPI/TCP.
"""
struct _ScenarioResult
    group_indices::Vector{Int}
    exec_times::Vector{Float64}
    gen_powers::Matrix{Float64}    # rows = SuperNetworks, cols = generators
    flow_powers::Matrix{Float64}   # rows = SuperNetworks, cols = lines
end

# ─────────────────────────────────────────────────────────────────────────────
# Tier 2: Intra-node parallel solve of a scenario group's intervals
# ─────────────────────────────────────────────────────────────────────────────

"""
    _run_group_tier2!(future_net_vector, group_indices, outer_iter, n_gen, n_lines,
                      lambda_app, pow_diff, power_self_gen, power_next_bel,
                      power_prev_bel, lambda_app_line, pow_diff_line,
                      power_self_flow_bel, power_next_flow_bel)
    -> _ScenarioResult

Tier-2 intra-node parallel execution: one `Threads.@spawn` task per SuperNetwork
in `group_indices`.  Each task calls `run_simulation!` which internally calls
`solve_lascopf!` (via `run_network_simulation!`), which uses `Threads.@threads`
on generators (Tier 3).

Thread safety: each task accesses a disjoint `SuperNetwork` (no shared mutable
state among tasks).  The belief arrays are treated as READ-ONLY during the solve
phase; they are updated by the master in the APP Phase 2 after all tasks finish.
"""
function _run_group_tier2!(
    future_net_vector::Vector{SuperNetwork},
    group_indices::Vector{Int},
    outer_iter::Int,
    n_gen::Int,
    n_lines::Int,
    lambda_app::Vector{Float64},
    pow_diff::Vector{Float64},
    power_self_gen::Vector{Float64},
    power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},
    lambda_app_line::Vector{Float64},
    pow_diff_line::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    power_next_flow_bel::Vector{Float64}
)::_ScenarioResult

    k = length(group_indices)
    exec_times  = zeros(k)
    gen_powers  = zeros(k, n_gen)
    flow_powers = zeros(k, n_lines)
    tasks = Vector{Task}(undef, k)

    for (local_i, idx) in enumerate(group_indices)
        tasks[local_i] = Threads.@spawn begin
            sn = future_net_vector[$idx]
            t0 = time()
            run_simulation!(sn, $outer_iter,
                            $lambda_app, $pow_diff,
                            $power_self_gen, $power_next_bel, $power_prev_bel,
                            $lambda_app_line, $pow_diff_line,
                            $power_self_flow_bel, $power_next_flow_bel)
            elapsed = time() - t0

            # Extract gen/flow outputs for the master's belief update.
            # (Currently get_pow_self returns 0.0 — this is the hook to fill
            # once the solver writes results back to the SuperNetwork state.)
            gp = [get_pow_self(sn, j) for j in 1:$n_gen]
            fp = [get_pow_flow_self(sn, j) for j in 1:$n_lines]
            (elapsed, gp, fp)
        end
    end

    for (local_i, t) in enumerate(tasks)
        elapsed, gp, fp = fetch(t)
        exec_times[local_i]     = elapsed
        gen_powers[local_i, :]  = gp
        flow_powers[local_i, :] = fp
    end

    return _ScenarioResult(group_indices, exec_times, gen_powers, flow_powers)
end

# ─────────────────────────────────────────────────────────────────────────────
# Tier 1 + Tier 2 combined: HPC APP outer loop
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_lascopf_hpc!(future_net_vector, number_of_cont, rnd_intervals,
                     rsd_intervals, dummy_interval_choice, solver_choice;
                     max_app_iterations, output_dir) -> Dict{String, Any}

Three-tier HPC APP outer loop.  Drop-in replacement for `run_app_outer_loop!`
when Distributed workers are available; falls back to the serial loop
automatically when `nworkers() == 1`.

Tier 1 (inter-node): `pmap` sends one scenario group to each Slurm node.
Tier 2 (intra-node): `Threads.@spawn` parallelises intervals within a group.
Tier 3 (core-level): `Threads.@threads` over generators in `solve_lascopf!`.

The APP convergence logic, belief arrays, and λ update are identical to the
serial `run_app_outer_loop!` — only the solve phase (Phase 1) is parallelised.

Integration:
  Call `setup_hpc_workers!()` before this function (typically at program start).
  Pass the same arguments as `run_app_outer_loop!`.
"""
function run_lascopf_hpc!(
    future_net_vector::Vector{SuperNetwork},
    number_of_cont::Int,
    rnd_intervals::Int,
    rsd_intervals::Int,
    dummy_interval_choice::Bool,
    solver_choice::Int;
    max_app_iterations::Int = typemax(Int),
    output_dir::String      = "results"
)::Dict{String, Any}

    # ── Serial fallback ───────────────────────────────────────────────────────
    if nworkers() == 1
        @info "No distributed workers — falling back to serial run_app_outer_loop!"
        return run_app_outer_loop!(
            future_net_vector, number_of_cont, rnd_intervals, rsd_intervals,
            dummy_interval_choice, solver_choice;
            max_app_iterations = max_app_iterations,
            output_dir         = output_dir
        )
    end

    println("\n*** APMP LASCOPF — THREE-TIER HPC DISTRIBUTED LAYER BEGINS ***")
    @printf("  Tier-1 workers : %d  (inter-node scenario groups)\n", nworkers())
    @printf("  Tier-2 threads : %d  (intra-node intervals per worker)\n", Threads.nthreads())
    @printf("  Tier-3 threads : %d  (generator subproblems per interval — same pool)\n",
            Threads.nthreads())
    @printf("  Total parallel capacity: %d concurrent generator-subproblem batches\n",
            nworkers() * Threads.nthreads())

    # ── Consensus array dimensions (identical to run_app_outer_loop!) ─────────
    n_gen   = get_gen_number(future_net_vector[1])
    n_lines = get_trans_number(future_net_vector[1])

    if dummy_interval_choice
        cons_lag_dim      = 2 * ((number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1) * n_gen
        supernet_num      = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1) + 1
    else
        cons_lag_dim      = 2 * (number_of_cont + 1) * (rnd_intervals + rsd_intervals) * n_gen
        supernet_num      = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1)
    end
    cons_line_lag_dim      = (rnd_intervals - 1) * n_lines * (number_of_cont + 1)
    supernet_line_num_next = (number_of_cont + 1) * n_lines * (rnd_intervals - 1)

    # ── Belief and Lagrange multiplier arrays (master-side) ───────────────────
    lambda_app      = zeros(cons_lag_dim)
    pow_diff        = zeros(cons_lag_dim)
    lambda_app_line = zeros(cons_line_lag_dim)
    pow_diff_line   = zeros(cons_line_lag_dim)

    power_self_gen      = zeros(supernet_num * n_gen)
    power_next_bel      = zeros(supernet_num_next * n_gen)
    power_prev_bel      = zeros(supernet_num * n_gen)
    power_next_flow_bel = zeros(supernet_line_num_next)
    power_self_flow_bel = zeros(supernet_line_num_next)

    # Warm-start generation beliefs from the last realised dispatch
    for i in 0:(supernet_num - 1), j in 0:(n_gen - 1)
        prev_j = get_pow_prev(future_net_vector[1], j + 1)
        power_self_gen[i * n_gen + j + 1] = prev_j
        power_prev_bel[i * n_gen + j + 1] = prev_j
    end
    for i in 0:(supernet_num_next - 1), j in 0:(n_gen - 1)
        power_next_bel[i * n_gen + j + 1] = get_pow_prev(future_net_vector[1], j + 1)
    end

    # ── Tier-1 partition: group SuperNetworks by contingency scenario ─────────
    groups = group_supernetworks(future_net_vector, number_of_cont,
                                 rnd_intervals, rsd_intervals, dummy_interval_choice)
    n_groups = length(groups)
    if n_groups > nworkers()
        @warn "$n_groups scenario groups but only $(nworkers()) workers — " *
              "last $(n_groups - nworkers()) groups will share workers (load imbalance)."
    end

    # ── APP iteration state ────────────────────────────────────────────────────
    fin_tol         = 1000.0
    fin_tol_delayed = 1000.0
    iter_count_app  = 1

    result_log = Dict{String, Any}(
        "mode"               => "HPC",
        "tier1_workers"      => nworkers(),
        "tier2_tier3_threads" => Threads.nthreads(),
        "scenario_groups"    => n_groups,
    )

    largest_supernet_time_vec = Float64[]
    actual_supernet_time      = 0.0
    start_time                = time()

    # ══════════════════════════════════════════════════════════════════════════
    # Main APP outer loop
    # ══════════════════════════════════════════════════════════════════════════
    while fin_tol >= 0.005 && iter_count_app <= max_app_iterations

        # ── PHASE 1: Parallel solve ───────────────────────────────────────────
        #
        # Tier 1: pmap sends each scenario group to a Slurm worker node.
        # Tier 2: within each worker, _run_group_tier2! uses Threads.@spawn so
        #         all intervals in the group run concurrently on the node's cores.
        # Tier 3: solve_lascopf! uses Threads.@threads over generators (already
        #         implemented in admm_app_solver.jl, no change needed).
        #
        # The belief arrays are passed as READ-ONLY snapshots (copy) to workers.
        # Workers return _ScenarioResult containing execution times and gen/flow
        # outputs.  The master refreshes power_self_gen / power_self_flow_bel
        # from the returned outputs before calling _update_beliefs_*!
        # (Currently get_pow_self returns 0.0, so the refresh is a no-op that
        # will activate once the getters are wired to solver state.)

        λ_snap    = copy(lambda_app)
        λl_snap   = copy(lambda_app_line)
        pd_snap   = copy(pow_diff)
        pdl_snap  = copy(pow_diff_line)
        psg_snap  = copy(power_self_gen)
        pnb_snap  = copy(power_next_bel)
        ppb_snap  = copy(power_prev_bel)
        pnfb_snap = copy(power_next_flow_bel)
        psfb_snap = copy(power_self_flow_bel)

        # Capture loop variable for @spawn closure correctness
        _iter = iter_count_app

        # Tier-1 pmap: each element of `groups` goes to one worker
        pmap_results::Vector{_ScenarioResult} = pmap(groups) do grp_indices
            _run_group_tier2!(
                future_net_vector, grp_indices, _iter,
                n_gen, n_lines,
                λ_snap, pd_snap, psg_snap, pnb_snap, ppb_snap,
                λl_snap, pdl_snap, psfb_snap, pnfb_snap
            )
        end

        # ── Collect timing and apply gen/flow outputs to master's belief arrays ─
        all_times = Float64[]
        for res in pmap_results
            append!(all_times, res.exec_times)
            actual_supernet_time += sum(res.exec_times)

            # Apply returned gen/flow outputs back to the master's SuperNetworks.
            # Once get_pow_self / get_pow_flow_self are wired to solver outputs,
            # this refreshes the master's belief-query state before _update_beliefs_*!
            for (local_i, idx) in enumerate(res.group_indices)
                sn = future_net_vector[idx]
                # Placeholder: when solver writes outputs to sn.net_object_vec,
                # copy res.gen_powers[local_i, :] and res.flow_powers[local_i, :]
                # into the relevant Network fields so getters return live values.
                # (No-op until getters and network state writes are implemented.)
            end
        end
        !isempty(all_times) && push!(largest_supernet_time_vec, maximum(all_times))

        # ── PHASE 2: Belief update (master, using refreshed SuperNetwork state) ─
        if dummy_interval_choice
            _update_beliefs_with_dummy!(
                future_net_vector, pow_diff, pow_diff_line,
                power_self_gen, power_next_bel, power_prev_bel,
                power_next_flow_bel, power_self_flow_bel,
                number_of_cont, n_gen, n_lines, rnd_intervals, rsd_intervals)
        else
            _update_beliefs_without_dummy!(
                future_net_vector, pow_diff, pow_diff_line,
                power_self_gen, power_next_bel, power_prev_bel,
                power_next_flow_bel, power_self_flow_bel,
                number_of_cont, n_gen, n_lines, rnd_intervals, rsd_intervals)
        end

        # ── PHASE 3: λ update and convergence check ───────────────────────────
        alpha_app = tune_alpha_app(iter_count_app)
        lambda_app      .+= alpha_app .* pow_diff
        lambda_app_line .+= alpha_app .* pow_diff_line

        tol_app = sum(abs2, pow_diff) + sum(abs2, pow_diff_line)
        if dummy_interval_choice
            tol_app_delayed = sum(abs2, @view pow_diff[(2 * n_gen + 1):end]) +
                              sum(abs2, pow_diff_line)
            fin_tol         = sqrt(tol_app)
            fin_tol_delayed = sqrt(tol_app_delayed)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance"         => fin_tol,
                "Delayed_APP_Tolerance" => fin_tol_delayed,
                "alpha_app"             => alpha_app
            )
            @printf("HPC APP iter %d: tol = %.6f, delayed = %.6f, α = %.1f  " *
                    "[max interval time = %.3f s]\n",
                    iter_count_app, fin_tol, fin_tol_delayed, alpha_app,
                    isempty(all_times) ? 0.0 : maximum(all_times))
            fin_tol = fin_tol_delayed
        else
            fin_tol = sqrt(tol_app)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance" => fin_tol,
                "alpha_app"     => alpha_app
            )
            @printf("HPC APP iter %d: tol = %.6f, α = %.1f  [max = %.3f s]\n",
                    iter_count_app, fin_tol, alpha_app,
                    isempty(all_times) ? 0.0 : maximum(all_times))
        end

        iter_count_app += 1
    end

    # ── Wrap-up ────────────────────────────────────────────────────────────────
    stop_s       = time() - start_time
    virtual_time = stop_s - actual_supernet_time +
                   (isempty(largest_supernet_time_vec) ? 0.0 :
                    sum(largest_supernet_time_vec))
    speedup      = stop_s > 0.0 ? virtual_time / stop_s : 1.0

    println("\n*** HPC LASCOPF DISTRIBUTED LAYER ENDS ***")
    @printf("Wall time (clock):      %.2f s\n", stop_s)
    @printf("Virtual parallel time:  %.2f s\n", virtual_time)
    @printf("Estimated speedup:      %.2f×\n", speedup)

    result_log["timing"] = Dict{String, Any}(
        "wall_s"                => stop_s,
        "virtual_execution_s"   => virtual_time,
        "estimated_speedup"     => speedup,
        "actual_compute_s"      => actual_supernet_time,
    )

    isdir(output_dir) || mkdir(output_dir)
    solver_names = Dict(1 => "ADMM_PMP_GUROBI", 2 => "ADMM_PMP_CVXGEN",
                        3 => "APP_Quasi_Decent_GUROBI", 4 => "APP_GUROBI_Centralized_SCOPF")
    fname = joinpath(output_dir,
                     "$(get(solver_names, solver_choice, "Unknown"))_HPC_resultAPP-SCOPF.json")
    open(fname, "w") do f
        JSON3.pretty(f, result_log)
    end
    println("Results saved to $fname")

    return result_log
end
