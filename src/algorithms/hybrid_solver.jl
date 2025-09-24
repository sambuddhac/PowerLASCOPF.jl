"""
Hybrid solver combining neural policy with ADMM refinement
"""
function solve_hybrid_neural_admm!(
    neural_policy::NeuralNetworkPolicy,
    solver::LASCOPFSolver,
    belief::PowerSystemBelief
)
    # 1. Get initial solution from neural network
    nn_action = POMDPs.action(neural_policy, belief)
    
    # 2. Use neural solution as warm start for ADMM
    initialize_admm_from_neural_solution!(solver, nn_action)
    
    # 3. Refine with few ADMM iterations
    refined_results = solve_lascopf!(solver, max_iterations=10)
    
    # 4. Combine solutions
    return combine_neural_admm_solutions(nn_action, refined_results)
end

"""
Use neural network solution to initialize ADMM variables
"""
function initialize_admm_from_neural_solution!(solver::LASCOPFSolver, action::PowerSystemAction)
    # Set generator setpoints
    for (i, gen) in enumerate(solver.system_data["thermal_generators"])
        if i <= length(action.generator_setpoints)
            gen.Pg = action.generator_setpoints[i]
        end
    end
    
    # Set line switching states
    for (i, line) in enumerate(solver.system_data["branches"])
        if i <= length(action.line_switching_actions)
            # Set line status based on neural decision
        end
    end
    
    println("✅ ADMM initialized with neural network solution")
end

# Updated visualization.jl to work with neural training
module Visualization

using Plots
using Statistics

"""
Plot neural network training progress
"""
function plot_training_progress(training_results::Dict)
    # Create subplot layout
    p1 = plot(training_results["episode_rewards"], 
              title="Episode Rewards", xlabel="Episode", ylabel="Total Reward",
              linewidth=2, color=:blue)
    
    # Add moving average
    if length(training_results["episode_rewards"]) > 10
        moving_avg = [mean(training_results["episode_rewards"][max(1,i-9):i]) 
                     for i in 10:length(training_results["episode_rewards"])]
        plot!(p1, 10:length(training_results["episode_rewards"]), moving_avg, 
              linewidth=3, color=:red, label="Moving Average")
    end
    
    p2 = plot(training_results["actor_losses"], 
              title="Actor Loss", xlabel="Update", ylabel="Loss",
              linewidth=1, color=:green)
    
    p3 = plot(training_results["critic_losses"], 
              title="Critic Loss", xlabel="Update", ylabel="Loss",
              linewidth=1, color=:orange)
    
    # Combine plots
    plot(p1, p2, p3, layout=(3,1), size=(800, 600))
end

"""
Visualize power system state and neural policy decisions
"""
function plot_power_system_state(state::PowerSystemState, action::PowerSystemAction)
    # Generator dispatch
    p1 = bar(action.generator_setpoints, 
             title="Generator Dispatch", xlabel="Generator", ylabel="Power (MW)",
             color=:lightblue)
    
    # Line status
    p2 = bar(Int.(action.line_switching_actions), 
             title="Line Status", xlabel="Line", ylabel="Status (0/1)",
             color=:lightgreen)
    
    # Load shedding
    p3 = bar(action.load_shedding, 
             title="Load Shedding", xlabel="Load", ylabel="Shed (MW)",
             color=:lightcoral)
    
    plot(p1, p2, p3, layout=(3,1), size=(800, 600))
end

end