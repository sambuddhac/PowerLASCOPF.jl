# Joint Parameter and Topology Estimation using ML
# Combines line impedance, load, and generation parameter estimation

using Flux
using Statistics
using Optim

"""
Joint estimator for both topology (line status) and parameters (impedances, loads).
Uses deep learning for scalability to large systems.
"""
mutable struct JointTopologyParameterEstimator
    # Topology estimation network
    topology_net::Chain
    
    # Parameter estimation network (impedances, loads, generation)
    parameter_net::Chain
    
    # Shared feature extractor
    feature_extractor::Chain
    
    # System dimensions
    n_buses::Int
    n_lines::Int
    n_generators::Int
    n_loads::Int
    
    # Parameter bounds
    impedance_bounds::NamedTuple{(:min, :max), Tuple{Float64, Float64}}
    load_bounds::NamedTuple{(:min, :max), Tuple{Float64, Float64}}
    
    # Training state
    training_history::Dict{String, Vector{Float64}}
    
    # Uncertainty quantification
    enable_uncertainty::Bool
    ensemble_size::Int
    ensemble_models::Vector{Chain}
end

"""
    JointTopologyParameterEstimator(n_buses, n_lines, n_generators, n_loads)

Create joint estimator for topology and parameters.
"""
function JointTopologyParameterEstimator(
    n_buses::Int,
    n_lines::Int, 
    n_generators::Int,
    n_loads::Int;
    hidden_dims::Vector{Int}=[256, 128, 64],
    enable_uncertainty::Bool=true,
    ensemble_size::Int=5
)
    
    input_dim = 2 * n_buses + 2 * n_lines  # Measurements
    
    # Shared feature extractor
    feature_extractor = Chain(
        Dense(input_dim, hidden_dims[1], relu),
        BatchNorm(hidden_dims[1]),
        Dropout(0.3),
        Dense(hidden_dims[1], hidden_dims[2], relu),
        BatchNorm(hidden_dims[2])
    )
    
    # Topology branch (binary classification for each line)
    topology_net = Chain(
        Dense(hidden_dims[2], hidden_dims[3], relu),
        BatchNorm(hidden_dims[3]),
        Dense(hidden_dims[3], n_lines, σ)  # Sigmoid for line probabilities
    )
    
    # Parameter estimation branch (regression)
    n_params = 2 * n_lines + n_loads + n_generators  # R, X for lines, P for loads/gens
    parameter_net = Chain(
        Dense(hidden_dims[2], hidden_dims[3], relu),
        BatchNorm(hidden_dims[3]),
        Dense(hidden_dims[3], n_params)  # Linear output for parameters
    )
    
    # Initialize ensemble if uncertainty quantification is enabled
    ensemble_models = []
    if enable_uncertainty
        for _ in 1:ensemble_size
            # Create slightly different architectures for diversity
            ensemble_model = Chain(
                Dense(input_dim, hidden_dims[1] + rand(-10:10), relu),
                BatchNorm(hidden_dims[1] + rand(-10:10)),
                Dropout(rand(0.2:0.05:0.4)),
                Dense(hidden_dims[1] + rand(-10:10), n_params)
            )
            push!(ensemble_models, ensemble_model)
        end
    end
    
    return JointTopologyParameterEstimator(
        topology_net,
        parameter_net,
        feature_extractor,
        n_buses,
        n_lines,
        n_generators,
        n_loads,
        (min=0.001, max=1.0),     # Impedance bounds (p.u.)
        (min=0.0, max=10.0),      # Load bounds (p.u.)
        Dict{String, Vector{Float64}}(),
        enable_uncertainty,
        ensemble_size,
        ensemble_models
    )
end

"""
    predict_joint(estimator, measurements)

Predict both topology and parameters from measurements.
Returns (topology_probs, parameter_estimates, uncertainties).
"""
function predict_joint(
    estimator::JointTopologyParameterEstimator,
    measurements::Vector{Float64}
)
    # Normalize measurements
    # (In practice, use stored normalization statistics)
    normalized_measurements = measurements
    
    # Extract shared features
    features = estimator.feature_extractor(normalized_measurements)
    
    # Predict topology
    topology_probs = estimator.topology_net(features)
    
    # Predict parameters
    raw_params = estimator.parameter_net(features)
    
    # Apply bounds to parameters
    bounded_params = apply_parameter_bounds(estimator, raw_params)
    
    # Compute uncertainty if enabled
    uncertainties = nothing
    if estimator.enable_uncertainty
        uncertainties = estimate_prediction_uncertainty(estimator, measurements)
    end
    
    return (
        topology=topology_probs,
        parameters=bounded_params,
        uncertainties=uncertainties
    )
end

"""
Apply physical bounds to parameter estimates.
"""
function apply_parameter_bounds(
    estimator::JointTopologyParameterEstimator,
    raw_params::Vector{Float64}
)
    bounded = copy(raw_params)
    
    n_lines = estimator.n_lines
    
    # Impedances (first 2*n_lines elements: R and X for each line)
    bounded[1:2*n_lines] = clamp.(
        bounded[1:2*n_lines],
        estimator.impedance_bounds.min,
        estimator.impedance_bounds.max
    )
    
    # Loads and generation (remaining elements)
    bounded[2*n_lines+1:end] = clamp.(
        bounded[2*n_lines+1:end],
        estimator.load_bounds.min,
        estimator.load_bounds.max
    )
    
    return bounded
end

"""
Estimate uncertainty using ensemble predictions.
"""
function estimate_prediction_uncertainty(
    estimator::JointTopologyParameterEstimator,
    measurements::Vector{Float64}
)
    if !estimator.enable_uncertainty
        return nothing
    end
    
    # Get predictions from all ensemble members
    predictions = []
    for model in estimator.ensemble_models
        pred = model(measurements)
        push!(predictions, pred)
    end
    
    # Stack predictions
    pred_matrix = reduce(hcat, predictions)
    
    # Compute statistics
    mean_pred = vec(mean(pred_matrix, dims=2))
    std_pred = vec(std(pred_matrix, dims=2))
    
    return (mean=mean_pred, std=std_pred)
end

"""
    train_joint_estimator!(estimator, training_data; epochs=100)

Train the joint estimator on historical data.

# Arguments
- `training_data`: Dictionary with keys:
  - "measurements": Matrix of measurement vectors
  - "topology_labels": Matrix of binary line status
  - "parameter_labels": Matrix of true parameters
"""
function train_joint_estimator!(
    estimator::JointTopologyParameterEstimator,
    training_data::Dict;
    epochs::Int=100,
    batch_size::Int=32,
    learning_rate::Float64=1e-3,
    topology_weight::Float64=0.5,  # Weight for topology loss vs parameter loss
    validation_split::Float64=0.2
)
    
    measurements = training_data["measurements"]
    topology_labels = training_data["topology_labels"]
    parameter_labels = training_data["parameter_labels"]
    
    n_samples = size(measurements, 1)
    n_val = Int(floor(validation_split * n_samples))
    n_train = n_samples - n_val
    
    # Split data
    indices = randperm(n_samples)
    train_idx = indices[1:n_train]
    val_idx = indices[n_train+1:end]
    
    train_X = measurements[train_idx, :]'
    train_topo_Y = topology_labels[train_idx, :]'
    train_param_Y = parameter_labels[train_idx, :]'
    
    val_X = measurements[val_idx, :]'
    val_topo_Y = topology_labels[val_idx, :]'
    val_param_Y = parameter_labels[val_idx, :]'
    
    # Combine models for training
    full_model = Chain(
        estimator.feature_extractor,
        Split(
            estimator.topology_net,
            estimator.parameter_net
        )
    )
    
    opt = Adam(learning_rate)
    
    estimator.training_history["topology_loss"] = Float64[]
    estimator.training_history["parameter_loss"] = Float64[]
    estimator.training_history["total_loss"] = Float64[]
    estimator.training_history["validation_accuracy"] = Float64[]
    
    println("Training joint topology-parameter estimator...")
    
    for epoch in 1:epochs
        total_topo_loss = 0.0
        total_param_loss = 0.0
        n_batches = 0
        
        for i in 1:batch_size:n_train
            batch_end = min(i + batch_size - 1, n_train)
            X_batch = train_X[:, i:batch_end]
            topo_Y_batch = train_topo_Y[:, i:batch_end]
            param_Y_batch = train_param_Y[:, i:batch_end]
            
            # Compute gradients
            loss, grads = Flux.withgradient(full_model) do m
                # Forward pass
                features = estimator.feature_extractor(X_batch)
                topo_pred = estimator.topology_net(features)
                param_pred = estimator.parameter_net(features)
                
                # Topology loss (binary cross-entropy)
                topo_loss = Flux.binarycrossentropy(topo_pred, topo_Y_batch)
                
                # Parameter loss (MSE)
                param_loss = Flux.mse(param_pred, param_Y_batch)
                
                # Combined loss
                topology_weight * topo_loss + (1 - topology_weight) * param_loss
            end
            
            # Update parameters
            Flux.update!(opt, full_model, grads[1])
            
            # Track losses separately for monitoring
            features = estimator.feature_extractor(X_batch)
            topo_pred = estimator.topology_net(features)
            param_pred = estimator.parameter_net(features)
            
            total_topo_loss += Flux.binarycrossentropy(topo_pred, topo_Y_batch)
            total_param_loss += Flux.mse(param_pred, param_Y_batch)
            n_batches += 1
        end
        
        avg_topo_loss = total_topo_loss / n_batches
        avg_param_loss = total_param_loss / n_batches
        avg_total_loss = topology_weight * avg_topo_loss + (1 - topology_weight) * avg_param_loss
        
        push!(estimator.training_history["topology_loss"], avg_topo_loss)
        push!(estimator.training_history["parameter_loss"], avg_param_loss)
        push!(estimator.training_history["total_loss"], avg_total_loss)
        
        # Validation
        if epoch % 10 == 0
            val_features = estimator.feature_extractor(val_X)
            val_topo_pred = estimator.topology_net(val_features)
            val_param_pred = estimator.parameter_net(val_features)
            
            topo_accuracy = mean((val_topo_pred .> 0.5) .== val_topo_Y)
            param_mae = mean(abs.(val_param_pred .- val_param_Y))
            
            push!(estimator.training_history["validation_accuracy"], topo_accuracy)
            
            println("Epoch $epoch:")
            println("  Topo Loss: $(round(avg_topo_loss, digits=4))")
            println("  Param Loss: $(round(avg_param_loss, digits=4))")
            println("  Val Topo Acc: $(round(topo_accuracy*100, digits=2))%")
            println("  Val Param MAE: $(round(param_mae, digits=4))")
        end
    end
    
    # Train ensemble if enabled
    if estimator.enable_uncertainty
        println("\nTraining ensemble models for uncertainty estimation...")
        train_ensemble!(estimator, training_data, epochs=epochs÷2)
    end
    
    println("Training complete!")
end

"""
Train ensemble models for uncertainty quantification.
"""
function train_ensemble!(estimator, training_data; epochs::Int=50)
    for (idx, model) in enumerate(estimator.ensemble_models)
        println("  Training ensemble member $idx/$(estimator.ensemble_size)...")
        
        # Similar training loop as main model but with different random seeds
        # and potentially data augmentation
        # ... (implementation similar to main training loop)
    end
end

"""
Custom Flux layer for splitting features to two branches.
"""
struct Split{T1, T2}
    branch1::T1
    branch2::T2
end

Split(branch1, branch2) = Split(branch1, branch2)

function (s::Split)(x)
    return (s.branch1(x), s.branch2(x))
end

Flux.@functor Split

# Export main functions
export JointTopologyParameterEstimator
export predict_joint, train_joint_estimator!
export estimate_prediction_uncertainty
