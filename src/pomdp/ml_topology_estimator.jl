# Machine Learning-Based Topology Estimation
# Integrates with existing belief updater for improved accuracy

using Flux
using Statistics
using LinearAlgebra

"""
Neural network-based topology estimator for power systems.
Learns patterns from historical data to predict line status.
"""
mutable struct MLTopologyEstimator
    # Neural network model
    model::Chain
    
    # Training parameters
    input_dim::Int
    hidden_dims::Vector{Int}
    output_dim::Int  # Number of lines in system
    
    # Feature normalization
    feature_means::Vector{Float64}
    feature_stds::Vector{Float64}
    
    # Performance metrics
    training_history::Vector{Float64}
    validation_accuracy::Float64
    
    # Integration with particle filter
    use_hybrid_approach::Bool
    particle_weight::Float64  # Weight for particle filter vs ML prediction
end

"""
    MLTopologyEstimator(n_buses, n_lines; hidden_dims=[128, 64, 32])

Create topology estimator with specified architecture.
"""
function MLTopologyEstimator(n_buses::Int, n_lines::Int; 
                              hidden_dims::Vector{Int}=[128, 64, 32],
                              use_hybrid::Bool=true,
                              particle_weight::Float64=0.5)
    
    # Feature dimension: voltage magnitudes, angles, power injections, flows
    input_dim = 2 * n_buses + 2 * n_lines  # V, θ, P, Q for buses and lines
    
    # Build network: Input → Hidden Layers → Output (line probabilities)
    layers = []
    prev_dim = input_dim
    
    for h_dim in hidden_dims
        push!(layers, Dense(prev_dim, h_dim, relu))
        push!(layers, BatchNorm(h_dim))
        push!(layers, Dropout(0.2))
        prev_dim = h_dim
    end
    
    # Output layer: sigmoid for binary line status probabilities
    push!(layers, Dense(prev_dim, n_lines, σ))
    
    model = Chain(layers...)
    
    return MLTopologyEstimator(
        model,
        input_dim,
        hidden_dims,
        n_lines,
        zeros(input_dim),
        ones(input_dim),
        Float64[],
        0.0,
        use_hybrid,
        particle_weight
    )
end

"""
    extract_features(measurements, system_data)

Extract relevant features from power system measurements for ML model.
"""
function extract_features(measurements::Dict, system_data)
    features = Float64[]
    
    # Voltage magnitudes and angles at all buses
    append!(features, get(measurements, "voltage_magnitudes", Float64[]))
    append!(features, get(measurements, "voltage_angles", Float64[]))
    
    # Power injections (active and reactive)
    append!(features, get(measurements, "active_power", Float64[]))
    append!(features, get(measurements, "reactive_power", Float64[]))
    
    # Line flows (if available)
    append!(features, get(measurements, "line_active_flows", Float64[]))
    append!(features, get(measurements, "line_reactive_flows", Float64[]))
    
    return features
end

"""
    predict_topology(estimator, features)

Predict line status using trained ML model.
Returns probability vector for each line being operational.
"""
function predict_topology(estimator::MLTopologyEstimator, features::Vector{Float64})
    # Normalize features
    normalized = (features .- estimator.feature_means) ./ (estimator.feature_stds .+ 1e-8)
    
    # Forward pass through network
    probabilities = estimator.model(normalized)
    
    return probabilities
end

"""
    hybrid_topology_estimate(estimator, particle_belief, ml_prediction)

Combine particle filter belief with ML prediction using weighted average.
"""
function hybrid_topology_estimate(
    estimator::MLTopologyEstimator,
    particle_belief::Vector{Float64},  # Probability from particle filter
    ml_prediction::Vector{Float64}     # Probability from ML model
)
    
    if !estimator.use_hybrid_approach
        return ml_prediction
    end
    
    w_particle = estimator.particle_weight
    w_ml = 1.0 - w_particle
    
    combined = w_particle .* particle_belief .+ w_ml .* ml_prediction
    
    return combined
end

"""
    train_topology_estimator!(estimator, training_data, labels; epochs=100)

Train the ML topology estimator on historical data.

# Arguments
- `training_data`: Matrix where each row is a feature vector
- `labels`: Matrix where each row is binary line status (1=operational, 0=outage)
- `epochs`: Number of training epochs
"""
function train_topology_estimator!(
    estimator::MLTopologyEstimator,
    training_data::Matrix{Float64},
    labels::Matrix{Float64};
    epochs::Int=100,
    batch_size::Int=32,
    learning_rate::Float64=1e-3,
    validation_split::Float64=0.2
)
    
    # Compute normalization statistics
    estimator.feature_means = vec(mean(training_data, dims=1))
    estimator.feature_stds = vec(std(training_data, dims=1))
    
    # Normalize data
    normalized_data = (training_data .- estimator.feature_means') ./ (estimator.feature_stds' .+ 1e-8)
    
    # Split into training and validation
    n_samples = size(normalized_data, 1)
    n_val = Int(floor(validation_split * n_samples))
    n_train = n_samples - n_val
    
    indices = randperm(n_samples)
    train_idx = indices[1:n_train]
    val_idx = indices[n_train+1:end]
    
    train_X = normalized_data[train_idx, :]'
    train_Y = labels[train_idx, :]'
    val_X = normalized_data[val_idx, :]'
    val_Y = labels[val_idx, :]'
    
    # Training loop
    opt = Adam(learning_rate)
    
    println("Training topology estimator...")
    for epoch in 1:epochs
        # Mini-batch training
        loss_sum = 0.0
        n_batches = 0
        
        for i in 1:batch_size:n_train
            batch_end = min(i + batch_size - 1, n_train)
            X_batch = train_X[:, i:batch_end]
            Y_batch = train_Y[:, i:batch_end]
            
            # Compute loss and gradients
            loss, grads = Flux.withgradient(estimator.model) do m
                ŷ = m(X_batch)
                Flux.binarycrossentropy(ŷ, Y_batch)
            end
            
            # Update parameters
            Flux.update!(opt, estimator.model, grads[1])
            
            loss_sum += loss
            n_batches += 1
        end
        
        avg_loss = loss_sum / n_batches
        push!(estimator.training_history, avg_loss)
        
        # Validation accuracy
        if epoch % 10 == 0
            val_pred = estimator.model(val_X)
            val_pred_binary = val_pred .> 0.5
            accuracy = mean(val_pred_binary .== val_Y)
            estimator.validation_accuracy = accuracy
            
            println("Epoch $epoch: Loss = $(round(avg_loss, digits=4)), Val Acc = $(round(accuracy*100, digits=2))%")
        end
    end
    
    println("Training complete!")
end

"""
    integrate_ml_with_particle_filter(estimator, updater, belief, measurements)

Integrate ML predictions with existing particle filter belief updater.
"""
function integrate_ml_with_particle_filter(
    estimator::MLTopologyEstimator,
    updater,  # Existing ParticleFilterUpdater
    belief,   # Current PowerSystemBelief
    measurements::Dict
)
    
    # Extract features from measurements
    features = extract_features(measurements, nothing)
    
    # Get ML prediction
    ml_topology_probs = predict_topology(estimator, features)
    
    # Get particle filter belief (convert particles to probability distribution)
    particle_probs = compute_particle_topology_distribution(belief)
    
    # Combine predictions
    combined_probs = hybrid_topology_estimate(estimator, particle_probs, ml_topology_probs)
    
    # Update belief state with combined information
    # This would integrate with your existing PowerSystemBelief structure
    updated_belief = update_belief_with_ml_prediction(belief, combined_probs)
    
    return updated_belief
end

"""
Helper function to compute probability distribution from particles
"""
function compute_particle_topology_distribution(belief)
    n_lines = length(belief.topology_particles[1])
    probs = zeros(n_lines)
    
    for (particle, weight) in zip(belief.topology_particles, belief.topology_weights)
        probs .+= weight .* particle
    end
    
    return probs
end

"""
Helper function to update belief with ML prediction
"""
function update_belief_with_ml_prediction(belief, ml_probs)
    # Create new particles weighted by ML prediction
    # This is a placeholder - integrate with your actual belief structure
    return belief
end

# Export functions
export MLTopologyEstimator
export predict_topology, train_topology_estimator!
export integrate_ml_with_particle_filter
export hybrid_topology_estimate
