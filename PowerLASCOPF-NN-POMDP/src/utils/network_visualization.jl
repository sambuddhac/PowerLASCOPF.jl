# Updated visualization.jl to work with neural training
module Visualization

using Plots
using Statistics
using GraphRecipes
using Graphs
using NetworkLayout
using Colors

"""
Visualization utilities for Actor-Critic Neural Networks in PowerLASCOPF POMDP
"""

"""
    visualize_actor_critic_architecture(policy::NeuralNetworkPolicy; save_path::String="")

Create a comprehensive visualization of the Actor-Critic architecture showing:
- Network topology
- Layer dimensions
- Data flow
- Input/output mappings specific to power systems
"""
function visualize_actor_critic_architecture(policy::NeuralNetworkPolicy; save_path::String="")
    # Set up the plot layout
    layout = @layout [a{0.5w} b{0.5w}; c{1.0w}]
    
    # Plot 1: Actor Network Architecture
    p1 = plot_network_architecture(
        policy.actor_network, 
        policy.state_dim, 
        policy.action_dim,
        "Actor Network (Policy π)",
        :lightblue
    )
    
    # Plot 2: Critic Network Architecture  
    p2 = plot_network_architecture(
        policy.critic_network,
        policy.state_dim + policy.action_dim,
        1,
        "Critic Network (Q-function)",
        :lightcoral
    )
    
    # Plot 3: Combined Data Flow Diagram
    p3 = plot_actor_critic_dataflow(policy)
    
    # Combine all plots
    combined_plot = plot(p1, p2, p3, layout=layout, size=(1200, 900))
    
    if !isempty(save_path)
        savefig(combined_plot, save_path)
        println("✅ Actor-Critic visualization saved to: $save_path")
    end
    
    return combined_plot
end

"""
    plot_network_architecture(network::Chain, input_dim::Int, output_dim::Int, 
                             title::String, color_scheme)

Plot individual network architecture with nodes and connections
"""
function plot_network_architecture(network::Chain, input_dim::Int, output_dim::Int, 
                                 title::String, color_scheme)
    
    # Extract layer information
    layers = []
    layer_sizes = [input_dim]
    
    for layer in network.layers
        if layer isa Dense
            push!(layers, "Dense($(size(layer.weight, 2)) → $(size(layer.weight, 1)))")
            push!(layer_sizes, size(layer.weight, 1))
        elseif layer isa BatchNorm
            push!(layers, "BatchNorm")
        elseif layer isa Dropout
            push!(layers, "Dropout($(layer.p))")
        else
            push!(layers, string(typeof(layer)))
        end
    end
    
    # Create network graph
    n_layers = length(layer_sizes)
    
    # Node positions for layered layout
    node_positions = []
    node_colors = []
    node_labels = []
    
    for (i, size) in enumerate(layer_sizes)
        for j in 1:min(size, 10)  # Limit display to 10 nodes per layer
            x = i
            y = j - (min(size, 10) + 1) / 2
            push!(node_positions, (x, y))
            
            # Color coding
            if i == 1
                push!(node_colors, :lightgreen)  # Input layer
                push!(node_labels, "I$j")
            elseif i == n_layers
                push!(node_colors, :orange)      # Output layer  
                push!(node_labels, "O$j")
            else
                push!(node_colors, color_scheme) # Hidden layers
                push!(node_labels, "H$(i-1)_$j")
            end
        end
    end
    
    # Create the plot
    p = scatter([pos[1] for pos in node_positions], 
               [pos[2] for pos in node_positions],
               color=node_colors,
               markersize=8,
               title=title,
               xlabel="Layer",
               ylabel="Neuron",
               legend=false,
               grid=true,
               gridwidth=2)
    
    # Add connections between layers (simplified)
    for i in 1:(n_layers-1)
        # Draw connections between consecutive layers
        start_layer_nodes = findall(pos -> pos[1] == i, node_positions)
        end_layer_nodes = findall(pos -> pos[1] == i+1, node_positions)
        
        for start_idx in start_layer_nodes[1:min(3, length(start_layer_nodes))]
            for end_idx in end_layer_nodes[1:min(3, length(end_layer_nodes))]
                start_pos = node_positions[start_idx]
                end_pos = node_positions[end_idx]
                plot!(p, [start_pos[1], end_pos[1]], [start_pos[2], end_pos[2]], 
                     color=:gray, alpha=0.3, linewidth=0.5)
            end
        end
    end
    
    # Add layer labels
    for (i, layer_name) in enumerate(layers)
        if i <= length(layer_sizes) - 1
            annotate!(p, i + 0.5, maximum([pos[2] for pos in node_positions if pos[1] == i]) + 1, 
                     text(layer_name, 8, :center))
        end
    end
    
    return p
end

"""
    plot_actor_critic_dataflow(policy::NeuralNetworkPolicy)

Create a high-level data flow diagram showing the Actor-Critic interaction
"""
function plot_actor_critic_dataflow(policy::NeuralNetworkPolicy)
    
    # Create flow diagram using a directed graph
    g = SimpleDiGraph(10)  # 10 nodes for the flow
    
    # Node labels and positions
    node_labels = [
        "Belief State\n(Topology + Parameters)",     # 1
        "State Encoder",                              # 2  
        "Actor Network\n(Policy π)",                 # 3
        "Action\n(Gen + Lines + Loads)",             # 4
        "Environment\n(PowerLASCOPF)",               # 5
        "Reward\n(Cost + Reliability)",              # 6
        "Next State",                                 # 7
        "Critic Network\n(Q-function)",              # 8
        "Q-Value",                                    # 9
        "Policy Update"                               # 10
    ]
    
    # Define edges (data flow)
    edges = [
        (1, 2),  # Belief → Encoder
        (2, 3),  # Encoder → Actor
        (3, 4),  # Actor → Action
        (4, 5),  # Action → Environment
        (5, 6),  # Environment → Reward
        (5, 7),  # Environment → Next State
        (2, 8),  # State → Critic
        (4, 8),  # Action → Critic
        (8, 9),  # Critic → Q-Value
        (6, 10), # Reward → Update
        (9, 10), # Q-Value → Update
        (10, 3)  # Update → Actor
    ]
    
    # Add edges to graph
    for (src, dst) in edges
        add_edge!(g, src, dst)
    end
    
    # Node positions for better layout
    node_positions = [
        (1.0, 3.0),   # Belief State
        (2.0, 3.0),   # State Encoder
        (3.0, 4.0),   # Actor
        (4.0, 4.0),   # Action
        (5.0, 3.0),   # Environment
        (6.0, 2.0),   # Reward
        (6.0, 4.0),   # Next State
        (3.0, 2.0),   # Critic
        (4.0, 1.0),   # Q-Value
        (2.0, 1.0)    # Policy Update
    ]
    
    # Color scheme for different types of nodes
    node_colors = [
        :lightgreen,  # Input (Belief)
        :lightblue,   # Processing (Encoder)
        :orange,      # Actor
        :yellow,      # Action
        :purple,      # Environment
        :red,         # Reward
        :lightgreen,  # Next State
        :coral,       # Critic
        :pink,        # Q-Value
        :gray         # Update
    ]
    
    # Create the graph plot
    p = graphplot(g, 
                 names=node_labels,
                 x=[pos[1] for pos in node_positions],
                 y=[pos[2] for pos in node_positions],
                 nodecolor=node_colors,
                 nodesize=0.3,
                 nodestrokealpha=0.8,
                 arrow=arrow(:closed, :head, 0.15, 0.15),
                 curves=false,
                 fontsize=8,
                 title="Actor-Critic Data Flow in PowerLASCOPF POMDP")
    
    return p
end

"""
    plot_network_weights_heatmap(network::Chain, layer_idx::Int; title::String="")

Visualize the weights of a specific layer as a heatmap
"""
function plot_network_weights_heatmap(network::Chain, layer_idx::Int; title::String="")
    
    # Find the Dense layer
    dense_layers = [i for (i, layer) in enumerate(network.layers) if layer isa Dense]
    
    if layer_idx > length(dense_layers)
        error("Layer index $layer_idx exceeds number of Dense layers ($(length(dense_layers)))")
    end
    
    actual_layer_idx = dense_layers[layer_idx]
    weights = network.layers[actual_layer_idx].weight
    
    # Create heatmap
    p = heatmap(weights,
               title=isempty(title) ? "Layer $layer_idx Weights" : title,
               xlabel="Input Neurons",
               ylabel="Output Neurons", 
               color=:RdBu,
               aspect_ratio=:auto)
    
    return p
end

"""
    plot_activation_patterns(network::Chain, sample_input::AbstractVector; title::String="")

Visualize activation patterns through the network layers
"""
function plot_activation_patterns(network::Chain, sample_input::AbstractVector; title::String="")
    
    activations = []
    current_input = sample_input
    
    # Forward pass through network, collecting activations
    for (i, layer) in enumerate(network.layers)
        if layer isa Dense
            current_input = layer.weight * current_input .+ layer.bias
            push!(activations, copy(current_input))
        elseif hasfield(typeof(layer), :σ)  # Activation function
            current_input = layer.(current_input)
            activations[end] = copy(current_input)
        end
    end
    
    # Create subplot for each layer's activations
    n_layers = length(activations)
    plots = []
    
    for (i, activation) in enumerate(activations)
        p = bar(1:length(activation), activation,
               title="Layer $i Activations",
               xlabel="Neuron",
               ylabel="Activation",
               color=:lightblue,
               legend=false)
        push!(plots, p)
    end
    
    # Combine into grid
    if n_layers <= 4
        layout = (2, 2)
    else
        layout = (3, 3)
    end
    
    combined_plot = plot(plots[1:min(n_layers, 9)]..., 
                        layout=layout, 
                        size=(800, 600),
                        plot_title=isempty(title) ? "Network Activation Patterns" : title)
    
    return combined_plot
end

"""
    visualize_power_system_mapping(policy::NeuralNetworkPolicy)

Create a specialized visualization showing how power system components 
map to neural network inputs and outputs
"""
function visualize_power_system_mapping(policy::NeuralNetworkPolicy)
    pomdp = policy.pomdp
    
    # Input mapping
    input_components = [
        ("Line Status", length(pomdp.transmission_lines), :lightgreen),
        ("Load Forecast Errors", length(pomdp.loads), :lightblue),
        ("Renewable Forecast Errors", count(g -> isa(g.generator, RenewableDispatch), pomdp.generators), :yellow),
        ("Belief Quality", 2, :lightgray)
    ]
    
    # Output mapping  
    output_components = [
        ("Generator Setpoints", length(pomdp.generators), :orange),
        ("Line Switching", length(pomdp.transmission_lines), :red),
        ("Load Shedding", length(pomdp.loads), :pink),
        ("Reserves", length(pomdp.generators), :purple)
    ]
    
    # Create mapping visualization
    p1 = create_component_mapping_plot(input_components, "Neural Network Inputs\n(Power System State)")
    p2 = create_component_mapping_plot(output_components, "Neural Network Outputs\n(Control Actions)")
    
    # Combine plots
    combined_plot = plot(p1, p2, layout=(1, 2), size=(1000, 400))
    
    return combined_plot
end

"""
    create_component_mapping_plot(components, title)

Helper function to create component mapping plots
"""
function create_component_mapping_plot(components, title)
    
    labels = [comp[1] for comp in components]
    sizes = [comp[2] for comp in components] 
    colors = [comp[3] for comp in components]
    
    # Create pie chart showing relative sizes
    p = pie(sizes, 
           labels=labels,
           colors=colors,
           title=title,
           legend=:outertopright)
    
    # Add size annotations
    for (i, (label, size, _)) in enumerate(components)
        annotate!(p, 0, 0, text("$label: $size", 6))
    end
    
    return p
end

"""
    animate_training_progress(training_results::Dict; save_path::String="")

Create an animated visualization of the training progress
"""
function animate_training_progress(training_results::Dict; save_path::String="")
    
    rewards = training_results["episode_rewards"]
    actor_losses = get(training_results, "actor_losses", [])
    critic_losses = get(training_results, "critic_losses", [])
    
    # Create animation
    anim = @animate for i in 10:10:length(rewards)
        
        # Episode rewards subplot
        p1 = plot(1:i, rewards[1:i],
                 title="Episode Rewards", 
                 xlabel="Episode", 
                 ylabel="Total Reward",
                 linewidth=2, 
                 color=:blue,
                 legend=false)
        
        # Add moving average
        if i >= 20
            window_size = min(10, i÷2)
            moving_avg = [mean(rewards[max(1,j-window_size+1):j]) for j in window_size:i]
            plot!(p1, window_size:i, moving_avg, linewidth=3, color=:red)
        end
        
        # Loss subplots (if available)
        if !isempty(actor_losses) && !isempty(critic_losses)
            max_loss_idx = min(i, length(actor_losses))
            
            p2 = plot(1:max_loss_idx, actor_losses[1:max_loss_idx],
                     title="Actor Loss", 
                     xlabel="Update", 
                     ylabel="Loss",
                     color=:green,
                     legend=false)
            
            p3 = plot(1:max_loss_idx, critic_losses[1:max_loss_idx],
                     title="Critic Loss", 
                     xlabel="Update", 
                     ylabel="Loss", 
                     color=:orange,
                     legend=false)
            
            plot(p1, p2, p3, layout=(3,1), size=(800, 600))
        else
            plot(p1, size=(800, 200))
        end
    end
    
    if !isempty(save_path)
        gif(anim, save_path, fps=2)
        println("✅ Training animation saved to: $save_path")
    end
    
    return anim
end

"""
    interactive_network_explorer(policy::NeuralNetworkPolicy)

Create an interactive plot for exploring network weights and activations
"""
function interactive_network_explorer(policy::NeuralNetworkPolicy)
    
    # This would require PlotlyJS or similar for full interactivity
    # For now, create a static multi-panel exploration
    
    plots = []
    
    # Actor network layers
    dense_layers_actor = [i for (i, layer) in enumerate(policy.actor_network.layers) if layer isa Dense]
    for (i, layer_idx) in enumerate(dense_layers_actor[1:min(3, end)])
        p = plot_network_weights_heatmap(policy.actor_network, i, title="Actor Layer $i")
        push!(plots, p)
    end
    
    # Critic network layers  
    dense_layers_critic = [i for (i, layer) in enumerate(policy.critic_network.layers) if layer isa Dense]
    for (i, layer_idx) in enumerate(dense_layers_critic[1:min(3, end)])
        p = plot_network_weights_heatmap(policy.critic_network, i, title="Critic Layer $i")
        push!(plots, p)
    end
    
    # Combine all weight visualizations
    combined_plot = plot(plots..., layout=(2, 3), size=(1200, 600))
    
    return combined_plot
end

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

# Export all visualization functions
export visualize_actor_critic_architecture, plot_network_architecture, 
       plot_actor_critic_dataflow, plot_network_weights_heatmap,
       plot_activation_patterns, visualize_power_system_mapping,
       animate_training_progress, interactive_network_explorer

# Create and train neural policy
pomdp_system = create_5bus_pomdp_system()
neural_policy = NeuralNetworkPolicy(pomdp_system["pomdp"])

# Train the policy
training_results = train_neural_policy!(
    neural_policy, pomdp_system["updater"],
    n_episodes=1000, max_steps_per_episode=24
)

# Visualize training progress
plot_training_progress(training_results)

# Use trained policy in simulation
simulation_results = run_pomdp_simulation_with_neural_policy(
    neural_policy, pomdp_system, n_steps=24
)