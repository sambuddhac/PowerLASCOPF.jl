# run_lascopf_hpc.jl  — Level 1 entry point
using Distributed
using ClusterManagers

# --- TIER 1 SETUP: Launch inter-node workers ---
if myid() == 1
    n_tasks = parse(Int, get(ENV, "SLURM_NTASKS", "1"))
    addprocs_slurm(n_tasks)
end

@everywhere begin
    using Base.Threads
    using Polyester   # lower-overhead than Threads.@threads for innermost loops
    include("algorithms/admm_app_solver.jl")
    include("algorithms/coordination/maintwoserialLASCOPF.jl")
end

# --- LEVEL 1: Partition contingency scenario groups across inter-node workers ---
function run_lascopf_distributed!(super_net::SuperNetwork)
    n_cont  = get_cont_count(super_net)
    # Group: scenario 0 (base) + scenarios 1..n_cont
    scenario_groups = [findall(net -> belongs_to_scenario(net, i), super_net.networks)
                       for i in 0:n_cont]
    
    # pmap dispatches each scenario group to a separate inter-node worker
    # Each worker runs run_power_lascopf_optimization! for its subset of networks
    # and returns (beliefs, times) to the master for the λ update
    all_results = pmap(scenario_groups) do group_indices
        local_nets = super_net.networks[group_indices]
        run_scenario_group_optimization!(local_nets, super_net, iter_count_app)
    end
    
    # Master aggregates beliefs → updates λ → broadcasts new λ for next iteration
    aggregate_and_update_lambda!(super_net, all_results)
end
