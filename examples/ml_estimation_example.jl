# Example: Integrating ML-based Topology and Parameter Estimation
# Demonstrates how to use the new ML estimators with existing PowerLASCOPF infrastructure

using PowerSystems
using Dates

# Include the new ML estimation modules
include(joinpath(@__DIR__, "..", "src", "pomdp", "ml_topology_estimator.jl"))
include(joinpath(@__DIR__, "..", "src", "pomdp", "joint_estimation.jl"))
include(joinpath(@__DIR__, "..", "src", "pomdp", "belief_updater.jl"))

"""
Example 1: Training ML Topology Estimator on Historical Data
"""
function example_train_topology_estimator()
    println("=" ^ 60)
    println("Example 1: Training ML Topology Estimator")
    println("=" ^ 60)
    
    # System dimensions (IEEE 14-bus example)
    n_buses = 14
    n_lines = 20
    
    # Create estimator
    estimator = MLTopologyEstimator(
        n_buses, 
        n_lines,
        hidden_dims=[128, 64, 32],
        use_hybrid=true,
        particle_weight=0.5
    )
    
    println("✓ Created ML topology estimator")
    println("  - Input dimension: $(estimator.input_dim)")
    println("  - Output dimension: $(estimator.output_dim)")
    println("  - Hidden layers: $(estimator.hidden_dims)")
    
    # Generate synthetic training data
    # In practice, this would come from historical PMU/SCADA data
    n_samples = 1000
    input_dim = 2 * n_buses + 2 * n_lines
    
    training_data = randn(n_samples, input_dim) .+ 1.0
    
    # Generate labels: random line outages (mostly operational)
    labels = Float64.(rand(n_samples, n_lines) .> 0.1)  # 90% lines operational
    
    println("\n✓ Generated synthetic training data")
    println("  - Training samples: $n_samples")
    println("  - Average line availability: $(round(mean(labels)*100, digits=1))%")
    
    # Train the estimator
    println("\n🎯 Training topology estimator...")
    train_topology_estimator!(
        estimator,
        training_data,
        labels,
        epochs=50,
        batch_size=32,
        learning_rate=1e-3
    )
    
    println("\n✓ Training complete!")
    println("  - Final validation accuracy: $(round(estimator.validation_accuracy*100, digits=2))%")
    
    # Test prediction
    test_measurement = randn(input_dim) .+ 1.0
    topology_pred = predict_topology(estimator, test_measurement)
    
    println("\n📊 Example prediction:")
    println("  - Lines predicted operational: $(sum(topology_pred .> 0.5))/$(n_lines)")
    println("  - Average confidence: $(round(mean(topology_pred), digits=3))")
    
    return estimator
end

"""
Example 2: Training Joint Topology-Parameter Estimator
"""
function example_train_joint_estimator()
    println("\n" * "=" ^ 60)
    println("Example 2: Training Joint Topology-Parameter Estimator")
    println("=" ^ 60)
    
    # System dimensions
    n_buses = 14
    n_lines = 20
    n_generators = 5
    n_loads = 11
    
    # Create joint estimator
    estimator = JointTopologyParameterEstimator(
        n_buses,
        n_lines,
        n_generators,
        n_loads,
        hidden_dims=[256, 128, 64],
        enable_uncertainty=true,
        ensemble_size=5
    )
    
    println("✓ Created joint topology-parameter estimator")
    println("  - Topology output dimension: $n_lines")
    println("  - Parameter output dimension: $(2*n_lines + n_generators + n_loads)")
    println("  - Uncertainty estimation: enabled (ensemble size: 5)")
    
    # Generate synthetic training data
    n_samples = 1500
    input_dim = 2 * n_buses + 2 * n_lines
    
    training_data = Dict(
        "measurements" => randn(n_samples, input_dim) .+ 1.0,
        "topology_labels" => Float64.(rand(n_samples, n_lines) .> 0.1),
        "parameter_labels" => rand(n_samples, 2*n_lines + n_generators + n_loads) .* 0.5 .+ 0.1
    )
    
    println("\n✓ Generated synthetic training data")
    println("  - Training samples: $n_samples")
    
    # Train the joint estimator
    println("\n🎯 Training joint estimator...")
    train_joint_estimator!(
        estimator,
        training_data,
        epochs=50,
        batch_size=32,
        learning_rate=1e-3,
        topology_weight=0.5
    )
    
    println("\n✓ Training complete!")
    
    # Test prediction
    test_measurement = randn(input_dim) .+ 1.0
    prediction = predict_joint(estimator, test_measurement)
    
    println("\n📊 Example joint prediction:")
    println("  - Topology: $(sum(prediction.topology .> 0.5))/$n_lines lines operational")
    println("  - Parameters predicted: $(length(prediction.parameters))")
    
    if prediction.uncertainties !== nothing
        println("  - Average parameter uncertainty (std): $(round(mean(prediction.uncertainties.std), digits=4))")
    end
    
    return estimator
end

"""
Example 3: Integration with Existing POMDP Belief Updater
"""
function example_integrated_system()
    println("\n" * "=" ^ 60)
    println("Example 3: Integration with POMDP Belief Updater")
    println("=" ^ 60)
    
    # Create estimator
    n_buses = 14
    n_lines = 20
    
    ml_estimator = MLTopologyEstimator(
        n_buses,
        n_lines,
        use_hybrid=true,
        particle_weight=0.6  # 60% particle filter, 40% ML
    )
    
    println("✓ Created ML estimator with hybrid approach")
    println("  - Particle filter weight: 0.6")
    println("  - ML prediction weight: 0.4")
    
    # Create particle filter updater (from existing code)
    # Note: This would use your existing PowerLASCOPFPOMDP and ParticleFilterUpdater
    println("\n✓ Would integrate with existing ParticleFilterUpdater")
    println("  - Combines particle filter beliefs with ML predictions")
    println("  - Provides robust estimation under uncertainty")
    
    # Simulate measurement updates
    println("\n📊 Simulating measurement updates:")
    
    for t in 1:5
        # Generate synthetic measurement
        measurements = Dict(
            "voltage_magnitudes" => randn(n_buses) .+ 1.0,
            "voltage_angles" => randn(n_buses) .* 0.1,
            "active_power" => randn(n_buses + n_lines) .* 0.5,
            "reactive_power" => randn(n_buses + n_lines) .* 0.3,
            "line_active_flows" => randn(n_lines) .* 0.5,
            "line_reactive_flows" => randn(n_lines) .* 0.3
        )
        
        # Extract features
        features = extract_features(measurements, nothing)
        
        # Get ML prediction
        ml_topology = predict_topology(ml_estimator, features)
        
        # Simulate particle filter belief (placeholder)
        particle_topology = rand(n_lines) .* 0.2 .+ 0.8  # High confidence in operational
        
        # Combine predictions
        combined = hybrid_topology_estimate(ml_estimator, particle_topology, ml_topology)
        
        println("  Step $t: $(sum(combined .> 0.5))/$n_lines lines operational " *
                "(confidence: $(round(mean(combined), digits=3)))")
    end
    
    println("\n✓ Hybrid estimation successfully integrates ML with particle filter")
    
    return ml_estimator
end

"""
Example 4: Uncertainty-Aware Decision Making for SCOPF
"""
function example_uncertainty_aware_scopf()
    println("\n" * "=" ^ 60)
    println("Example 4: Uncertainty-Aware SCOPF")
    println("=" ^ 60)
    
    # Create joint estimator with uncertainty
    estimator = JointTopologyParameterEstimator(
        14, 20, 5, 11,
        enable_uncertainty=true
    )
    
    println("✓ Created estimator with uncertainty quantification")
    
    # Simulate prediction with uncertainty
    test_measurement = randn(2*14 + 2*20) .+ 1.0
    
    # Get multiple predictions from ensemble
    println("\n📊 Ensemble predictions for uncertainty quantification:")
    
    if estimator.enable_uncertainty && !isempty(estimator.ensemble_models)
        # Note: Would need to properly train ensemble first
        println("  - Ensemble size: $(estimator.ensemble_size)")
        println("  - Provides prediction confidence intervals")
        println("  - Enables risk-aware OPF formulations")
    end
    
    println("\n💡 Integration with PowerLASCOPF SCOPF:")
    println("  1. Estimate topology and parameters with uncertainty")
    println("  2. Generate scenarios based on prediction confidence")
    println("  3. Formulate robust/chance-constrained OPF")
    println("  4. Solve using ADMM/APP decomposition")
    println("  5. Update belief with new measurements")
    
    return estimator
end

"""
Main function to run all examples
"""
function main()
    println("\n🚀 PowerLASCOPF: ML-Based Topology and Parameter Estimation Examples\n")
    
    try
        # Example 1: Topology estimation
        topo_estimator = example_train_topology_estimator()
        
        # Example 2: Joint estimation
        joint_estimator = example_train_joint_estimator()
        
        # Example 3: Integration with POMDP
        integrated_estimator = example_integrated_system()
        
        # Example 4: Uncertainty-aware SCOPF
        uncertainty_estimator = example_uncertainty_aware_scopf()
        
        println("\n" * "=" ^ 60)
        println("✅ All examples completed successfully!")
        println("=" ^ 60)
        
        println("\n📝 Next Steps:")
        println("  1. Collect real PMU/SCADA data for training")
        println("  2. Integrate with existing maintwoserialLASCOPF.jl")
        println("  3. Test on IEEE test cases (14, 30, 57, 118 bus)")
        println("  4. Validate against PowerModels.jl solutions")
        println("  5. Benchmark computational performance")
        
    catch e
        println("\n❌ Error running examples: $e")
        println("Stack trace:")
        showerror(stdout, e, catch_backtrace())
    end
end

# Run examples if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
