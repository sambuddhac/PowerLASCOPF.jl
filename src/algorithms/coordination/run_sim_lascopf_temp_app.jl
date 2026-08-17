# run_sim_lascopf_temp_app.jl
#
# Entry point and APP outer-layer coordination for the LASCOPF temperature-
# constrained post-contingency restoration simulation.
#
# Depends on (loaded before this file by the top-level module):
#   src/components/supernetwork.jl   → SuperNetwork, create_supernetwork_object,
#                                      run_simulation!, get_pow_*, index_of_line_out,
#                                      ret_cont_count, get_gen_number, get_trans_number,
#                                      get_virtual_net_exec_time
#   src/components/network.jl        → create_ieee_case_system,
#                                      load_case_to_power_lascopf_system

using Distributed
using Printf
using JSON3
using YAML

# ─────────────────────────────────────────────────────────────────────────────
# Simulation parameter container
# ─────────────────────────────────────────────────────────────────────────────

"""
    LASCOPFSys

Holds all scalar configuration for one LASCOPF simulation run.
Fields are populated either from a YAML settings file or from interactive input.
"""
@kwdef mutable struct LASCOPFSys
    net_id::Int                 = 14
    solver_choice::Int          = 1    # 1=GUROBI-APMP  2=CVXGEN-APMP  3=GUROBI-APP  4=Centralized
    set_rho_tuning::Int         = 0    # 0=adaptive  1=Rho*primTol=dualTol  2=primTol=dualTol
    last::Int                   = 0
    rnd_intervals::Int          = 6    # restoration look-ahead intervals
    rsd_intervals::Int          = 6    # security look-ahead intervals
    next_choice::Int            = 1    # 1=include ramping constraint on last interval
    dummy_interval_choice::Bool = true # include dummy zero-dispatch interval
    cont_solver_accuracy::Int   = 1    # 1=exhaustive  0=simple
end

# ─────────────────────────────────────────────────────────────────────────────
# Settings and cluster helpers
# ─────────────────────────────────────────────────────────────────────────────

"""
    read_settings(case_path) -> Dict{String, Any}

Load the LASCOPF_settings.yml from `case_path`.
"""
function read_settings(case_path::String)::Dict{String, Any}
    settings_path = joinpath(case_path, "LASCOPF_settings.yml")
    println("Configuring Settings from $settings_path")
    return YAML.load(open(settings_path))
end

"""
    init_cluster_workers!()

Add distributed workers when running under Slurm.  No-op if workers are
already present or SLURM_NTASKS is unset.
"""
function init_cluster_workers!()
    nworkers() > 1 && return
    if haskey(ENV, "SLURM_NTASKS")
        n = parse(Int, ENV["SLURM_NTASKS"])
        n > 1 && addprocs(n - 1)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# SuperNetwork construction
# ─────────────────────────────────────────────────────────────────────────────

"""
    spawn_networks!(future_net_vector, pls_system, params) -> number_of_cont

Build every per-(contingency, interval) SuperNetwork and append it to
`future_net_vector`.  Returns the number of contingency scenarios.

Layout of `future_net_vector` after this call
  [1]            dummy / base-reference SuperNetwork  (interval_class=0)
  [2]            forthcoming dispatch interval        (interval_class=1)
  [3 .. 2+R]     RND intervals for base case (i=0)   (interval_class=2)
  next block      RSD intervals for base case
  repeat for i=1..number_of_cont

This ordering matches the outer APP loop in `run_app_outer_loop!`.
"""
function spawn_networks!(
    future_net_vector::Vector{SuperNetwork},
    pls_system::PowerLASCOPFSystem,
    params::LASCOPFSys
)::Int
    println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")

    rho = Float64(params.set_rho_tuning)

    # ---- base-reference SuperNetwork (index 1) ---------------------------
    sn_base = create_supernetwork_object(;
        powerlascopf_system = pls_system,
        pre_post_scenario   = false,
        network_id          = params.net_id,
        solver_choice       = params.solver_choice,
        set_rho_tuning      = rho,
        post_contingency    = 0,
        interval_count      = 0,
        interval_class      = 0,
        rnd_intervals       = params.rnd_intervals,
        rsd_intervals       = params.rsd_intervals,
        last_interval       = false,
        outaged_line        = 0,
        build_contingencies = true
    )
    number_of_cont = ret_cont_count(sn_base)
    push!(future_net_vector, sn_base)

    # ---- forthcoming dispatch interval (index 2) -------------------------
    sn_forthcoming = create_supernetwork_object(;
        powerlascopf_system = pls_system,
        pre_post_scenario   = false,
        network_id          = params.net_id,
        solver_choice       = params.solver_choice,
        set_rho_tuning      = rho,
        post_contingency    = 0,
        interval_count      = 0,
        interval_class      = 1,
        rnd_intervals       = params.rnd_intervals,
        rsd_intervals       = params.rsd_intervals,
        last_interval       = false,
        outaged_line        = 0,
        build_contingencies = false
    )
    push!(future_net_vector, sn_forthcoming)

    # ---- RND and RSD intervals for each contingency ----------------------
    for i in 0:number_of_cont
        line_outaged = i > 0 ? index_of_line_out(sn_base, i) : 0

        for j in 1:(params.rnd_intervals - 1)
            sn = create_supernetwork_object(;
                powerlascopf_system = pls_system,
                pre_post_scenario   = i > 0,
                network_id          = params.net_id,
                solver_choice       = params.solver_choice,
                set_rho_tuning      = rho,
                post_contingency    = i,
                interval_count      = j,
                interval_class      = 2,
                rnd_intervals       = params.rnd_intervals,
                rsd_intervals       = params.rsd_intervals,
                last_interval       = false,
                outaged_line        = line_outaged,
                build_contingencies = false
            )
            push!(future_net_vector, sn)
        end

        for j in 0:params.rsd_intervals
            is_last = (j == params.rsd_intervals) && (i == number_of_cont)
            sn = create_supernetwork_object(;
                powerlascopf_system = pls_system,
                pre_post_scenario   = i > 0,
                network_id          = params.net_id,
                solver_choice       = params.solver_choice,
                set_rho_tuning      = rho,
                post_contingency    = i,
                interval_count      = j + params.rnd_intervals,
                interval_class      = 2,
                rnd_intervals       = params.rnd_intervals,
                rsd_intervals       = params.rsd_intervals,
                last_interval       = is_last,
                outaged_line        = line_outaged,
                build_contingencies = (j == params.rsd_intervals)
            )
            push!(future_net_vector, sn)
        end
    end

    println("  Created $(length(future_net_vector)) SuperNetwork instances")
    println("\n*** SUPERNETWORK INITIALIZATION STAGE ENDS ***\n")
    return number_of_cont
end

# ─────────────────────────────────────────────────────────────────────────────
# Main entry point
# ─────────────────────────────────────────────────────────────────────────────

"""
    run_sim_lascopf_temp(settings, input_path) -> Dict{String, Any}

Top-level driver for the APP-based LASCOPF temperature-constrained
post-contingency restoration simulation.

`settings` is a Dict loaded from LASCOPF_settings.yml (via `read_settings`).
`input_path` is the directory containing case data files.
"""
function run_sim_lascopf_temp(settings::Dict, input_path::AbstractString)::Dict{String, Any}
    init_cluster_workers!()

    params = LASCOPFSys(
        net_id                = get(settings, "net_id", 14),
        solver_choice         = get(settings, "solver_choice", 1),
        set_rho_tuning        = get(settings, "set_rho_tuning", 0),
        rnd_intervals         = get(settings, "RND_intervals", 6),
        rsd_intervals         = get(settings, "RSD_intervals", 6),
        next_choice           = get(settings, "next_choice", 1),
        dummy_interval_choice = Bool(get(settings, "dummy_interval_choice", 1)),
        cont_solver_accuracy  = get(settings, "cont_solver_accuracy", 1)
    )

    # Load or build the PowerLASCOPFSystem
    pls_system = _load_pls_system(settings, input_path, params.net_id)

    # Construct all per-interval/contingency SuperNetwork instances
    future_net_vector = SuperNetwork[]
    number_of_cont = spawn_networks!(future_net_vector, pls_system, params)

    # Run the APP outer iteration loop
    return run_app_outer_loop!(
        future_net_vector,
        number_of_cont,
        params.rnd_intervals,
        params.rsd_intervals,
        params.dummy_interval_choice,
        params.solver_choice
    )
end

"""
Load a `PowerLASCOPFSystem` from settings/path.

Supports IEEE standard cases (by numeric `net_id`) and custom file formats
(matpower / psse / ieee_cdf) identified by a `case_file` key in settings.
"""
function _load_pls_system(settings::Dict, input_path::AbstractString,
                           net_id::Int)::PowerLASCOPFSystem
    if haskey(settings, "case_file")
        case_file   = joinpath(input_path, settings["case_file"])
        case_format = Symbol(get(settings, "case_format", "matpower"))
        return load_case_to_power_lascopf_system(case_file, case_format)
    else
        data_path = isempty(input_path) ? "data" : input_path
        return create_ieee_case_system(net_id, data_path)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# APP outer iteration loop
# ─────────────────────────────────────────────────────────────────────────────

"""
    tune_alpha_app(iter_count) -> Float64

Return the APP path-length parameter for the given outer iteration.
"""
function tune_alpha_app(iter_count::Int)::Float64
    iter_count > 20 && return 10.0
    iter_count > 15 && return 25.0
    iter_count > 10 && return 50.0
    iter_count > 5  && return 75.0
    return 100.0
end

"""
    run_app_outer_loop!(future_net_vector, number_of_cont, rnd_intervals,
                        rsd_intervals, dummy_interval_choice, solver_choice;
                        max_app_iterations, output_dir) -> Dict{String, Any}

APP coarse-grained outer iteration loop for the LASCOPF post-contingency
restoration problem.

Manages the Lagrange multiplier (λ) arrays and power/flow belief vectors across
all dispatch-interval × contingency-scenario SuperNetworks until the consensus
disagreement (`fin_tol`) drops below 0.005 or `max_app_iterations` is reached.

`future_net_vector` is built by `spawn_networks!`, with one entry per
(contingency scenario, dispatch interval) pair.  The dummy zero-interval entry,
when used, is always at index 1.

Returns the result log as a `Dict{String, Any}`.
"""
function run_app_outer_loop!(
    future_net_vector::Vector{SuperNetwork},
    number_of_cont::Int,
    rnd_intervals::Int,
    rsd_intervals::Int,
    dummy_interval_choice::Bool,
    solver_choice::Int;
    max_app_iterations::Int = typemax(Int),
    output_dir::String      = "results"
)::Dict{String, Any}

    # ------------------------------------------------------------------
    # Consensus array dimensions
    # ------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # Lagrange multiplier and disagreement arrays
    # ------------------------------------------------------------------
    lambda_app      = zeros(cons_lag_dim)
    pow_diff        = zeros(cons_lag_dim)
    lambda_app_line = zeros(cons_line_lag_dim)
    pow_diff_line   = zeros(cons_line_lag_dim)

    # ------------------------------------------------------------------
    # Power and line-flow belief arrays
    # ------------------------------------------------------------------
    power_self_gen      = zeros(supernet_num * n_gen)
    power_next_bel      = zeros(supernet_num_next * n_gen)
    power_prev_bel      = zeros(supernet_num * n_gen)
    power_next_flow_bel = zeros(supernet_line_num_next)
    power_self_flow_bel = zeros(supernet_line_num_next)

    # Warm-start: seed all generation beliefs with the last realised dispatch.
    # get_pow_prev(sn, gen_idx) returns a scalar per supernetwork.jl.
    # Both if/else branches in the original source did the same thing, so we
    # write it once. Flow beliefs have no reliable warm start and stay at zero.
    for i in 0:(supernet_num - 1), j in 0:(n_gen - 1)
        prev_j = get_pow_prev(future_net_vector[1], j + 1)
        power_self_gen[i * n_gen + j + 1] = prev_j
        power_prev_bel[i * n_gen + j + 1] = prev_j
    end
    for i in 0:(supernet_num_next - 1), j in 0:(n_gen - 1)
        power_next_bel[i * n_gen + j + 1] = get_pow_prev(future_net_vector[1], j + 1)
    end

    # ------------------------------------------------------------------
    # APP iteration state
    # ------------------------------------------------------------------
    fin_tol        = 1000.0
    fin_tol_delayed = 1000.0
    iter_count_app  = 1

    result_log = Dict{String, Any}("initial_tolerance" => fin_tol)

    println("\n*** APMP LASCOPF SUPERNETWORK LAYER BEGINS ***")
    println("*** SIMULATION IN PROGRESS ***\n")

    largest_supernet_time_vec = Float64[]
    actual_supernet_time      = 0.0
    start_time                = time()

    # ==================================================================
    # Main APP outer iteration loop
    # ==================================================================
    while fin_tol >= 0.005 && iter_count_app <= max_app_iterations
        single_supernet_time_vec = Float64[]

        # ---- Phase 1: solve each SuperNetwork for the current λ ------
        if dummy_interval_choice
            n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
            for nsc in 0:(n_nets - 1)
                _log_app_iteration(iter_count_app, nsc; dummy=true)
                sn = future_net_vector[nsc + 1]
                run_simulation!(sn, iter_count_app,
                                lambda_app, pow_diff,
                                power_self_gen, power_next_bel, power_prev_bel,
                                lambda_app_line, pow_diff_line,
                                power_self_flow_bel, power_next_flow_bel)
                t = get_virtual_net_exec_time(sn)
                actual_supernet_time += t
                push!(single_supernet_time_vec, t)
            end
        else
            n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
            for nsc in 0:(n_nets - 1)
                _log_app_iteration(iter_count_app, nsc; dummy=false)
                # Python accessed futureNetVector[nsc+1] (0-based); +1 more for Julia 1-based
                sn = future_net_vector[nsc + 2]
                run_simulation!(sn, iter_count_app,
                                lambda_app, pow_diff,
                                power_self_gen, power_next_bel, power_prev_bel,
                                lambda_app_line, pow_diff_line,
                                power_self_flow_bel, power_next_flow_bel)
                t = get_virtual_net_exec_time(sn)
                actual_supernet_time += t
                push!(single_supernet_time_vec, t)
            end
        end

        push!(largest_supernet_time_vec, maximum(single_supernet_time_vec))

        # ---- Phase 2: update beliefs and disagreements ---------------
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

        # ---- Phase 3: update λ and check convergence -----------------
        alpha_app = tune_alpha_app(iter_count_app)
        lambda_app      .+= alpha_app .* pow_diff
        lambda_app_line .+= alpha_app .* pow_diff_line

        tol_app = sum(abs2, pow_diff) + sum(abs2, pow_diff_line)

        if dummy_interval_choice
            # Delayed tolerance excludes the dummy interval's 2*n_gen contributions.
            # (Original: `if i >= 2*numberOfGenerators` skips the first block of powDiff.)
            tol_app_delayed = sum(abs2, @view pow_diff[(2 * n_gen + 1):end]) +
                              sum(abs2, pow_diff_line)
            fin_tol         = sqrt(tol_app)
            fin_tol_delayed = sqrt(tol_app_delayed)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance"         => fin_tol,
                "Delayed_APP_Tolerance" => fin_tol_delayed,
                "alpha_app"             => alpha_app
            )
            @printf("APP iter %d: tol = %.6f, delayed = %.6f, α = %.1f\n",
                    iter_count_app, fin_tol, fin_tol_delayed, alpha_app)
            # Convergence is tested on the delayed tolerance (excludes dummy interval)
            fin_tol = fin_tol_delayed
        else
            fin_tol = sqrt(tol_app)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance" => fin_tol,
                "alpha_app"     => alpha_app
            )
            @printf("APP iter %d: tol = %.6f, α = %.1f\n", iter_count_app, fin_tol, alpha_app)
        end

        iter_count_app += 1
    end

    # ------------------------------------------------------------------
    # Wrap-up
    # ------------------------------------------------------------------
    stop_s       = time() - start_time
    virtual_time = stop_s - actual_supernet_time + sum(largest_supernet_time_vec)

    println("\n*** LASCOPF SUPERNETWORK LAYER ENDS ***")
    @printf("Execution time:         %.2f s\n", stop_s)
    @printf("Virtual execution time: %.2f s\n", virtual_time)

    result_log["timing"] = Dict{String, Any}(
        "execution_s"         => stop_s,
        "virtual_execution_s" => virtual_time
    )

    _save_app_results(result_log, solver_choice; output_dir)
    return result_log
end

# ─────────────────────────────────────────────────────────────────────────────
# Private helpers
# ─────────────────────────────────────────────────────────────────────────────

# Loop variables throughout are kept 0-based (matching the Python index formulas);
# +1 is added only at Julia array-access and SuperNetwork-vector-access points.
# get_pow_prev(sn, gen_idx) returns a scalar Float64 per supernetwork.jl.

"""
Belief and disagreement update for the WITH-dummy case.
"""
function _update_beliefs_with_dummy!(
    fv::Vector{SuperNetwork},
    pow_diff::Vector{Float64},         pow_diff_line::Vector{Float64},
    power_self_gen::Vector{Float64},   power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},   power_next_flow_bel::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    number_of_cont::Int, n_gen::Int, n_lines::Int,
    rnd_intervals::Int, rsd_intervals::Int
)
    n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2

    for i in 0:(n_nets - 1)
        sn_i = fv[i + 1]

        if i == 0
            sn_ip1 = fv[2]
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                next_j = get_pow_next(sn_i, 1, 1, j + 1)
                pow_diff[j + 1]         = self_j - get_pow_prev(sn_ip1, j + 1)
                power_self_gen[j + 1]   = self_j
                power_next_bel[j + 1]   = next_j
                power_prev_bel[j + 1]   = get_pow_prev(sn_i, j + 1)
                pow_diff[n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
            end
        else
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                power_self_gen[i * n_gen + j + 1] = self_j

                if i == 1
                    for cc in 0:number_of_cont
                        sn_cc  = fv[i + cc + 2]
                        next_j = get_pow_next(sn_i, cc + 1, i + 1, j + 1)
                        power_next_bel[(i + cc) * n_gen + j + 1]       = next_j
                        pow_diff[2*(i+cc)*n_gen + j + 1]               = self_j - get_pow_prev(sn_cc, j + 1)
                        pow_diff[(2*(i+cc)+1)*n_gen + j + 1]           = next_j - get_pow_self(sn_cc, j + 1)
                    end
                else
                    next_j = get_pow_next(sn_i, 1, i + 1, j + 1)
                    power_next_bel[(i + number_of_cont) * n_gen + j + 1] = next_j
                    for cc in 0:number_of_cont
                        # Skip the last interval of each post-contingency sequence
                        if i != (cc + 1) * (rnd_intervals + rsd_intervals) + 1
                            sn_ip1 = fv[i + 2]
                            pow_diff[2*(i+number_of_cont)*n_gen + j + 1]     = self_j - get_pow_prev(sn_ip1, j + 1)
                            pow_diff[(2*(i+number_of_cont)+1)*n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
                        end
                    end
                end

                power_prev_bel[i * n_gen + j + 1] = get_pow_prev(sn_i, j + 1)
            end

            for j in 0:(n_lines - 1)
                if i == 1
                    for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                        fidx     = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                        # Python: futureNetVector[2+cc*(RND+RSD)+k] → Julia: fv[3+cc*(rnd+rsd)+k]
                        sn_tgt   = fv[3 + cc * (rnd_intervals + rsd_intervals) + k]
                        flo_next = get_pow_flow_next(sn_i, cc + 1, i + 1, k + 1, j + 1)
                        power_next_flow_bel[fidx] = flo_next
                        pow_diff_line[fidx]        = flo_next - get_pow_flow_self(sn_tgt, j + 1)
                    end
                else
                    for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                        if i == 2 + cc * (rnd_intervals + rsd_intervals) + k
                            fidx = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                            power_self_flow_bel[fidx] = get_pow_flow_self(sn_i, j + 1)
                        end
                    end
                end
            end
        end
    end
end

"""
Belief and disagreement update for the WITHOUT-dummy case.
"""
function _update_beliefs_without_dummy!(
    fv::Vector{SuperNetwork},
    pow_diff::Vector{Float64},         pow_diff_line::Vector{Float64},
    power_self_gen::Vector{Float64},   power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},   power_next_flow_bel::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    number_of_cont::Int, n_gen::Int, n_lines::Int,
    rnd_intervals::Int, rsd_intervals::Int
)
    n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1

    for i in 0:(n_nets - 1)
        # Python: futureNetVector[i+1] (0-based i) → Julia: fv[i+2]
        sn_i = fv[i + 2]

        if i == 0
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                power_self_gen[j + 1] = self_j
                for cc in 0:number_of_cont
                    # Python: futureNetVector[i+cc+2] → Julia: fv[cc+3]  (i=0)
                    sn_cc  = fv[cc + 3]
                    next_j = get_pow_next(sn_i, cc + 1, i + 2, j + 1)
                    power_next_bel[cc * n_gen + j + 1]       = next_j
                    pow_diff[2*cc*n_gen + j + 1]             = self_j - get_pow_prev(sn_cc, j + 1)
                    pow_diff[(2*cc+1)*n_gen + j + 1]         = next_j - get_pow_self(sn_cc, j + 1)
                end
                power_prev_bel[j + 1] = get_pow_prev(sn_i, j + 1)
            end
            for j in 0:(n_lines - 1)
                for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                    fidx     = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                    # Python: futureNetVector[2+cc*(RND+RSD)+k] → Julia: fv[3+cc*(rnd+rsd)+k]
                    sn_tgt   = fv[3 + cc * (rnd_intervals + rsd_intervals) + k]
                    flo_next = get_pow_flow_next(sn_i, cc + 1, i + 2, k + 1, j + 1)
                    power_next_flow_bel[fidx] = flo_next
                    pow_diff_line[fidx]        = flo_next - get_pow_flow_self(sn_tgt, j + 1)
                end
            end
        else
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                next_j = get_pow_next(sn_i, 1, i + 2, j + 1)
                power_self_gen[i * n_gen + j + 1]                    = self_j
                power_next_bel[(i + number_of_cont) * n_gen + j + 1] = next_j
                power_prev_bel[i * n_gen + j + 1]                    = get_pow_prev(sn_i, j + 1)
                for cc in 0:number_of_cont
                    # Skip the last interval of each post-contingency sequence
                    if i != (cc + 1) * (rnd_intervals + rsd_intervals)
                        # Python: futureNetVector[i+2] → Julia: fv[i+3]
                        sn_ip1 = fv[i + 3]
                        pow_diff[2*(i+number_of_cont)*n_gen + j + 1]     = self_j - get_pow_prev(sn_ip1, j + 1)
                        pow_diff[(2*(i+number_of_cont)+1)*n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
                    end
                end
            end
            for j in 0:(n_lines - 1)
                for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                    if i == 1 + cc * (rnd_intervals + rsd_intervals) + k
                        fidx = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                        power_self_flow_bel[fidx] = get_pow_flow_self(sn_i, j + 1)
                    end
                end
            end
        end
    end
end

"""
Log the start of an APP network simulation.
"""
function _log_app_iteration(iter_count_app::Int, net_sim_count::Int; dummy::Bool)
    if dummy
        if net_sim_count == 0
            println("Start of $iter_count_app-th APP iteration for dummy zero dispatch interval")
        elseif net_sim_count == 1
            println("Start of $iter_count_app-th APP iteration for $(net_sim_count)-th dispatch interval")
        else
            println("Start of $iter_count_app-th APP iteration for second dispatch interval for $(net_sim_count - 2)-th post-contingency scenario")
        end
    else
        if net_sim_count == 0
            println("Start of $iter_count_app-th APP iteration for $(net_sim_count + 1)-th dispatch interval")
        else
            println("Start of $iter_count_app-th APP iteration for second dispatch interval for $(net_sim_count - 1)-th post-contingency scenario")
        end
    end
end

function _save_app_results(result_log::Dict{String, Any}, solver_choice::Int;
                            output_dir::String = "results")
    solver_names = Dict(1 => "ADMM_PMP_GUROBI",
                        2 => "ADMM_PMP_CVXGEN",
                        3 => "APP_Quasi_Decent_GUROBI",
                        4 => "APP_GUROBI_Centralized_SCOPF")
    isdir(output_dir) || mkdir(output_dir)
    name     = get(solver_names, solver_choice, "Unknown_Solver")
    filename = joinpath(output_dir, "$(name)_resultOuterAPP-SCOPF.json")
    open(filename, "w") do f
        JSON3.pretty(f, result_log)
    end
    println("Results saved to $filename")
end
