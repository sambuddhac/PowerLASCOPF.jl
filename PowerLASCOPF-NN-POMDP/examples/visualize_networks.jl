using Plots
include("../src/pomdp/PowerLASCOPFPOMDP.jl")
include("../src/policies/neural_network_policy.jl") 
include("../src/utils/network_visualization.jl")
include("../example_cases/data_5bus_pu.jl")

"""
Example script demonstrating neural network visualization capabilities
"""
function main()
    println("🎨 PowerLASCOPF Neural Network Visualization Demo")
    
    # Create sample POMDP system
    pomdp_system = create_5bus_pomdp_system()
    pomdp = pomdp_system["pomdp"]
    
    # Create neural network policy
    neural_policy = NeuralNetworkPolicy(pomdp, 
        hidden_dims=[128, 64, 32],
        lr_actor=1e-4, 
        lr_critic=1e-3)
    
    println("📊 Generating visualizations...")
    
    # 1. Complete Actor-Critic Architecture
    arch_plot = visualize_actor_critic_architecture(neural_policy, 
        save_path="actor_critic_architecture.png")
    display(arch_plot)
    
    # 2. Power System Component Mapping
    mapping_plot = visualize_power_system_mapping(neural_policy)
    display(mapping_plot)
    savefig(mapping_plot, "power_system_mapping.png")
    
    # 3. Network Weight Heatmaps
    println("🔥 Creating weight heatmaps...")
    
    actor_weights = plot_network_weights_heatmap(neural_policy.actor_network, 1, 
        title="Actor Network - Layer 1 Weights")
    display(actor_weights)
    savefig(actor_weights, "actor_layer1_weights.png")
    
    critic_weights = plot_network_weights_heatmap(neural_policy.critic_network, 1,
        title="Critic Network - Layer 1 Weights") 
    display(critic_weights)
    savefig(critic_weights, "critic_layer1_weights.png")
    
    # 4. Sample Activation Patterns
    println("⚡ Analyzing activation patterns...")
    
    # Create sample input (belief state)
    sample_belief_input = randn(Float32, neural_policy.state_dim)
    
    actor_activations = plot_activation_patterns(neural_policy.actor_network, 
        sample_belief_input, title="Actor Network Activation Patterns")
    display(actor_activations)
    savefig(actor_activations, "actor_activations.png")
    
    # For critic, need state + action input
    sample_action = randn(Float32, neural_policy.action_dim) 
    critic_input = vcat(sample_belief_input, sample_action)
    
    critic_activations = plot_activation_patterns(neural_policy.critic_network,
        critic_input, title="Critic Network Activation Patterns")
    display(critic_activations)
    savefig(critic_activations, "critic_activations.png")
    
    # 5. Interactive Network Explorer
    println("🔍 Creating network explorer...")
    explorer_plot = interactive_network_explorer(neural_policy)
    display(explorer_plot)
    savefig(explorer_plot, "network_explorer.png")
    
    # 6. Simulate some training data for animation demo
    println("🎬 Creating training progress animation...")
    
    # Generate fake training data for demonstration
    n_episodes = 100
    fake_rewards = cumsum(randn(n_episodes) * 10) .+ 500  # Trending upward
    fake_actor_losses = exp.(-0.1 * (1:50)) .+ 0.1 * randn(50)
    fake_critic_losses = exp.(-0.08 * (1:50)) .+ 0.1 * randn(50)
    
    fake_training_results = Dict(
        "episode_rewards" => fake_rewards,
        "actor_losses" => fake_actor_losses, 
        "critic_losses" => fake_critic_losses
    )
    
    training_anim = animate_training_progress(fake_training_results,
        save_path="training_progress.gif")
    
    println("✅ All visualizations completed!")
    println("📁 Files saved:")
    println("   - actor_critic_architecture.png")
    println("   - power_system_mapping.png") 
    println("   - actor_layer1_weights.png")
    println("   - critic_layer1_weights.png")
    println("   - actor_activations.png")
    println("   - critic_activations.png")
    println("   - network_explorer.png")
    println("   - training_progress.gif")
    
    return neural_policy
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end