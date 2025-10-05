"""
Example: RL Backend Comparison
Demonstrates usage and performance comparison of different RL policy backends
"""

using Pkg
using Random
using Statistics

# Include the RL interface modules
include("../src/julia_interface/rl_policy_interface.jl")
include("../src/julia_interface/julia_backend_impl.jl")
include("../src/julia_interface/performance_benchmarks.jl")

function main()
    println("RL Backend Comparison Demo")
    println("=" * "="^40)
    
    # Set random seed for reproducibility
    Random.seed!(42)
    
    # Problem configuration
    state_dim = 20    # Power system state dimension
    action_dim = 5    # Control actions (generator dispatch, etc.)
    
    # 1. Initialize policies with different backends
    println("\n1. Initializing RL policies with different backends...")
    
    # Julia native backend
    julia_policy = initialize_rl_policy(
        :julia, state_dim, action_dim,
        hidden_dims=[64, 32],
        learning_rate=0.001
    )
    println("✓ Julia backend initialized")
    
    # TensorFlow backend (if available)
    try
        tf_policy = initialize_rl_policy(
            :tensorflow, state_dim, action_dim,
            model_path="models/tf_actor_critic"
        )
        println("✓ TensorFlow backend initialized")
    catch e
        println("⚠ TensorFlow backend not available: $e")
    end
    
    # PyTorch backend (if available)
    try
        torch_policy = initialize_rl_policy(
            :pytorch, state_dim, action_dim,
            device="cpu",
            model_path="models/torch_actor_critic"
        )
        println("✓ PyTorch backend initialized")
    catch e
        println("⚠ PyTorch backend not available: $e")
    end
    
    # 2. Test basic functionality
    println("\n2. Testing basic policy operations...")
    
    # Generate sample state
    test_state = randn(state_dim)
    
    # Test action generation
    action = get_action(julia_policy, test_state)
    println("✓ Action generated: [$(join(round.(action, digits=3), ", "))]")
    
    # Test value estimation
    value = get_state_value(julia_policy, test_state)
    println("✓ State value estimated: $(round(value, digits=3))")
    
    # 3. Demonstrate training
    println("\n3. Demonstrating policy training...")
    
    # Generate training batch
    batch_size = 32
    states = randn(state_dim, batch_size)
    actions = randn(action_dim, batch_size)
    rewards = randn(batch_size)
    next_states = randn(state_dim, batch_size)
    dones = rand(Bool, batch_size)
    
    # Train Julia policy
    initial_loss = update_policy!(julia_policy, states, actions, rewards, next_states, dones)
    println("✓ Policy updated, loss: $(round(initial_loss, digits=4))")
    
    # Train for multiple iterations
    losses = Float64[]
    for epoch in 1:10
        loss = update_policy!(julia_policy, states, actions, rewards, next_states, dones)
        push!(losses, loss)
    end
    
    final_loss = losses[end]
    improvement = ((initial_loss - final_loss) / initial_loss) * 100
    println("✓ Training completed. Loss improvement: $(round(improvement, digits=2))%")
    
    # 4. Performance benchmarking
    println("\n4. Running performance benchmarks...")
    
    # Run comprehensive benchmark
    benchmark_results = benchmark_policies(
        state_dim, action_dim,
        batch_sizes=[16, 32, 64],
        num_trials=50
    )
    
    # Save results
    save_benchmark_results(benchmark_results, "benchmark_results.json")
    
    # Generate plots
    try
        plot_results = plot_benchmark_results(benchmark_results, 
                                            save_path="benchmark_plots.png")
        println("✓ Benchmark plots generated")
    catch e
        println("⚠ Could not generate plots: $e")
    end
    
    # 5. Save and load demonstration
    println("\n5. Demonstrating save/load functionality...")
    
    # Save Julia policy
    save_julia_policy(julia_policy, "saved_julia_policy.json")
    println("✓ Julia policy saved")
    
    # Load policy
    loaded_policy = load_julia_policy("saved_julia_policy.json", [64, 32])
    println("✓ Julia policy loaded")
    
    # Verify loaded policy works
    loaded_action = get_action(loaded_policy, test_state)
    action_diff = norm(action - loaded_action)
    println("✓ Action difference after reload: $(round(action_diff, digits=6))")
    
    # 6. Usage recommendations
    println("\n6. Usage Recommendations:")
    println("-" * "-"^40)
    
    # Analyze benchmark results for recommendations
    if haskey(benchmark_results, :julia) && !all(isnan.(benchmark_results[:julia]["inference_times"]))
        julia_inference = mean(benchmark_results[:julia]["inference_times"])
        julia_training = mean(benchmark_results[:julia]["training_times"])
        julia_memory = mean(benchmark_results[:julia]["memory_usage"])
        
        println("Julia Backend:")
        println("  • Average inference time: $(round(julia_inference, digits=3)) ms")
        println("  • Average training time: $(round(julia_training, digits=3)) ms")
        println("  • Average memory usage: $(round(julia_memory, digits=2)) MB")
        println("  • Best for: Pure Julia environments, custom research, transparency")
        println()
    end
    
    println("TensorFlow Backend:")
    println("  • Best for: Production environments, distributed training")
    println("  • Pros: Mature ecosystem, TensorBoard integration, deployment tools")
    println("  • Cons: Additional dependency, potential version conflicts")
    println()
    
    println("PyTorch Backend:")
    println("  • Best for: Research, dynamic networks, debugging")
    println("  • Pros: Pythonic interface, dynamic graphs, active community")
    println("  • Cons: Additional dependency, memory overhead")
    println()
    
    println("Recommendation: Start with Julia backend for prototyping,")
    println("then consider TensorFlow/PyTorch for production or specific needs.")
    
    println("\n✅ Demo completed successfully!")
end

# Example usage patterns
function demonstrate_advanced_usage()
    println("\nAdvanced Usage Patterns:")
    println("-" * "-"^30)
    
    # Custom network architectures
    println("1. Custom Network Architecture:")
    custom_policy = initialize_rl_policy(
        :julia, 50, 10,
        hidden_dims=[128, 64, 32],  # Deeper network
        learning_rate=0.0005
    )
    
    # Hyperparameter tuning
    println("2. Hyperparameter Comparison:")
    learning_rates = [0.001, 0.005, 0.01]
    
    for lr in learning_rates
        policy = initialize_rl_policy(:julia, 20, 5, learning_rate=lr)
        # ... training and evaluation code ...
        println("   Learning rate $lr: [evaluation metrics would go here]")
    end
    
    # Performance monitoring
    println("3. Performance Monitoring:")
    policy = initialize_rl_policy(:julia, 20, 5)
    
    # Access performance metrics
    metrics = policy.performance_metrics
    println("   Total updates: $(get(metrics, "total_updates", 0))")
    println("   Average loss: $(round(get(metrics, "average_loss", 0.0), digits=4))")
    
    if haskey(metrics, "inference_times")
        avg_inference = mean(metrics["inference_times"]) * 1000
        println("   Average inference time: $(round(avg_inference, digits=3)) ms")
    end
end

# Run the main demo
if abspath(PROGRAM_FILE) == @__FILE__
    main()
    demonstrate_advanced_usage()
end
