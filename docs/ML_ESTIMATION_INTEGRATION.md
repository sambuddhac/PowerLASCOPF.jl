# ML-Based Topology and Parameter Estimation Integration Guide

## Overview

This document describes the integration of machine learning-based topology and parameter estimation into the PowerLASCOPF framework. The ML estimators enhance the existing particle filter-based belief updater with deep learning models trained on historical data.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   PowerLASCOPF System                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐      ┌──────────────────┐           │
│  │  PMU/SCADA       │      │  Historical      │           │
│  │  Measurements    │──────│  Database        │           │
│  └──────────────────┘      └──────────────────┘           │
│           │                         │                       │
│           ├─────────┬───────────────┘                      │
│           │         │                                       │
│           ▼         ▼                                       │
│  ┌──────────────────────────────────┐                     │
│  │   ML Topology Estimator          │                     │
│  │   - Neural network classifier    │                     │
│  │   - Hybrid particle filter-ML    │                     │
│  └──────────────────────────────────┘                     │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────────────────────┐                     │
│  │  Joint Topology-Parameter Est.   │                     │
│  │  - Shared feature extractor      │                     │
│  │  - Topology branch (binary)      │                     │
│  │  - Parameter branch (regression) │                     │
│  │  - Ensemble for uncertainty      │                     │
│  └──────────────────────────────────┘                     │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────────────────────┐                     │
│  │    PowerSystemBelief             │                     │
│  │    (Enhanced with ML)            │                     │
│  └──────────────────────────────────┘                     │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────────────────────┐                     │
│  │   SCOPF Solver (ADMM/APP)        │                     │
│  │   - Generator Solvers            │                     │
│  │   - Line Solvers                 │                     │
│  │   - Network Coordinator          │                     │
│  └──────────────────────────────────┘                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## New Modules

### 1. `src/pomdp/ml_topology_estimator.jl`

**Purpose**: ML-based topology (line status) estimation with hybrid particle filter integration.

**Key Components**:
- `MLTopologyEstimator`: Neural network for binary line status prediction
- `predict_topology()`: Inference function
- `train_topology_estimator!()`: Training on historical data
- `hybrid_topology_estimate()`: Combines ML with particle filter
- `integrate_ml_with_particle_filter()`: Main integration function

**Architecture**:
```
Input (Measurements)
    ↓
[Dense(input_dim, 128) + ReLU + BatchNorm + Dropout(0.2)]
    ↓
[Dense(128, 64) + ReLU + BatchNorm + Dropout(0.2)]
    ↓
[Dense(64, 32) + ReLU + BatchNorm + Dropout(0.2)]
    ↓
[Dense(32, n_lines) + Sigmoid]
    ↓
Output (Line Probabilities)
```

**Usage**:
```julia
# Create estimator
estimator = MLTopologyEstimator(n_buses, n_lines)

# Train on historical data
train_topology_estimator!(estimator, training_data, labels, epochs=100)

# Predict topology
topology_probs = predict_topology(estimator, current_measurements)

# Hybrid approach
combined_belief = hybrid_topology_estimate(
    estimator, 
    particle_filter_belief, 
    ml_prediction
)
```

### 2. `src/pomdp/joint_estimation.jl`

**Purpose**: Simultaneous estimation of topology AND parameters (impedances, loads, generation).

**Key Components**:
- `JointTopologyParameterEstimator`: Multi-task neural network
- `predict_joint()`: Joint inference
- `train_joint_estimator!()`: Multi-task training
- `estimate_prediction_uncertainty()`: Ensemble-based uncertainty quantification

**Architecture**:
```
Input (Measurements)
    ↓
Feature Extractor (Shared)
    ├─[Dense(input_dim, 256) + ReLU + BatchNorm + Dropout(0.3)]
    └─[Dense(256, 128) + ReLU + BatchNorm]
           ↓
    ┌──────┴──────┐
    ↓             ↓
Topology      Parameter
Branch        Branch
    ↓             ↓
[Dense + BN]  [Dense + BN]
    ↓             ↓
[Dense→σ]     [Dense]
    ↓             ↓
Line Status   Impedances,
(Binary)      Loads, Gen
```

**Usage**:
```julia
# Create joint estimator
estimator = JointTopologyParameterEstimator(
    n_buses, n_lines, n_generators, n_loads,
    enable_uncertainty=true
)

# Train
train_joint_estimator!(estimator, training_data, epochs=100)

# Predict
result = predict_joint(estimator, measurements)
# result.topology: Line status probabilities
# result.parameters: Estimated impedances, loads, generation
# result.uncertainties: Mean and std from ensemble
```

## Integration with Existing Code

### Step 1: Modify `belief_updater.jl`

Add ML prediction to existing particle filter:

```julia
# In update function
function POMDPs.update(
    updater::ParticleFilterUpdater, 
    b::PowerSystemBelief, 
    a, 
    o
)
    # Existing particle filter update
    new_topology_particles, new_weights = update_topology_belief(...)
    
    # NEW: Get ML prediction if available
    if updater.use_ml_estimator && updater.ml_estimator !== nothing
        ml_topology = predict_topology(updater.ml_estimator, o.measurements)
        
        # Combine with particle belief
        particle_probs = compute_particle_distribution(
            new_topology_particles, 
            new_weights
        )
        combined_probs = hybrid_topology_estimate(
            updater.ml_estimator,
            particle_probs,
            ml_topology
        )
        
        # Update particles based on combined belief
        new_topology_particles, new_weights = adjust_particles_from_ml(
            new_topology_particles,
            new_weights,
            combined_probs
        )
    end
    
    # Continue with existing code...
end
```

### Step 2: Extend `PowerSystemBelief` struct

```julia
# Add to PowerSystemBelief definition
@kwdef mutable struct PowerSystemBelief
    # ... existing fields ...
    
    # NEW: ML predictions
    ml_topology_estimate::Union{Nothing, Vector{Float64}} = nothing
    ml_parameter_estimate::Union{Nothing, Vector{Float64}} = nothing
    ml_uncertainties::Union{Nothing, NamedTuple} = nothing
    
    # NEW: Confidence metrics
    topology_confidence::Float64 = 0.0
    parameter_confidence::Float64 = 0.0
end
```

### Step 3: Modify `maintwoserialLASCOPF.jl`

Integrate ML estimation into main LASCOPF loop:

```julia
# In main LASCOPF simulation
function run_lascopf_with_ml_estimation(super_net::SuperNetwork; use_ml=true)
    
    # Initialize ML estimators if enabled
    ml_estimator = nothing
    if use_ml
        ml_estimator = JointTopologyParameterEstimator(
            super_net.n_buses,
            super_net.n_lines,
            super_net.n_generators,
            super_net.n_loads
        )
        
        # Load pre-trained model or train if needed
        if isfile("trained_ml_estimator.jld2")
            load_ml_model!(ml_estimator, "trained_ml_estimator.jld2")
        else
            @warn "No pre-trained ML model found. Using particle filter only."
            ml_estimator = nothing
        end
    end
    
    # Main ADMM/APP iteration loop
    for iteration in 1:max_iterations
        
        # Update system state measurements
        measurements = collect_system_measurements(super_net)
        
        # Update belief with ML (if available)
        if ml_estimator !== nothing
            prediction = predict_joint(ml_estimator, measurements)
            
            # Update network topology based on ML prediction
            update_topology_from_ml!(super_net, prediction.topology)
            
            # Update parameters based on ML prediction
            update_parameters_from_ml!(super_net, prediction.parameters)
            
            # Store uncertainty for robust formulation
            if prediction.uncertainties !== nothing
                super_net.parameter_uncertainties = prediction.uncertainties
            end
        end
        
        # Continue with existing ADMM/APP solve
        solve_admm_iteration!(super_net)
        
        # Check convergence
        # ...
    end
end
```

## Training Data Collection

### Required Data Format

Training requires pairs of (measurements, labels):

**Measurements** (input features):
- Voltage magnitudes at all buses: `V = [V₁, V₂, ..., Vₙ]`
- Voltage angles: `θ = [θ₁, θ₂, ..., θₙ]`
- Active power injections/flows: `P`
- Reactive power injections/flows: `Q`

**Labels** (ground truth):
- Line status: `L = [l₁, l₂, ..., lₘ]` where `lᵢ ∈ {0, 1}`
- Line impedances: `Z = [R₁, X₁, R₂, X₂, ..., Rₘ, Xₘ]`
- Load powers: `P_load, Q_load`
- Generation setpoints: `P_gen`

### Data Collection Script

```julia
# examples/collect_training_data.jl

using PowerSystems
using DataFrames
using CSV

function collect_lascopf_training_data(system::System, n_samples::Int)
    measurements = []
    topology_labels = []
    parameter_labels = []
    
    for i in 1:n_samples
        # Run OPF with random scenarios
        scenario = generate_random_scenario(system)
        results = run_opf(system, scenario)
        
        # Extract measurements
        meas = extract_measurements(results)
        push!(measurements, meas)
        
        # Extract labels
        topo = extract_topology(results)
        params = extract_parameters(results)
        push!(topology_labels, topo)
        push!(parameter_labels, params)
        
        if i % 100 == 0
            println("Collected $i/$n_samples samples")
        end
    end
    
    return (
        measurements = reduce(hcat, measurements)',
        topology_labels = reduce(hcat, topology_labels)',
        parameter_labels = reduce(hcat, parameter_labels)'
    )
end
```

## Testing and Validation

### Unit Tests

Create `test/test_ml_estimation.jl`:

```julia
using Test
using PowerLASCOPF

@testset "ML Topology Estimation" begin
    # Test 1: Model creation
    estimator = MLTopologyEstimator(14, 20)
    @test estimator.n_buses == 14
    @test estimator.n_lines == 20
    
    # Test 2: Prediction shape
    measurements = randn(2*14 + 2*20)
    pred = predict_topology(estimator, measurements)
    @test length(pred) == 20
    @test all(0 .<= pred .<= 1)  # Probabilities
    
    # Test 3: Training
    data = randn(100, 2*14 + 2*20)
    labels = rand(Bool, 100, 20)
    train_topology_estimator!(estimator, data, Float64.(labels), epochs=5)
    @test length(estimator.training_history) == 5
end

@testset "Joint Estimation" begin
    estimator = JointTopologyParameterEstimator(14, 20, 5, 11)
    
    measurements = randn(2*14 + 2*20)
    result = predict_joint(estimator, measurements)
    
    @test length(result.topology) == 20
    @test length(result.parameters) == 2*20 + 5 + 11
end
```

### Integration Tests

Create `test/test_ml_integration.jl`:

```julia
@testset "ML-POMDP Integration" begin
    # Test hybrid estimation
    ml_est = MLTopologyEstimator(5, 7, use_hybrid=true)
    
    particle_belief = rand(7) .* 0.2 .+ 0.8
    ml_prediction = rand(7) .* 0.3 .+ 0.6
    
    combined = hybrid_topology_estimate(ml_est, particle_belief, ml_prediction)
    
    @test length(combined) == 7
    @test all(0 .<= combined .<= 1)
    
    # Should be weighted average
    expected = 0.5 .* particle_belief .+ 0.5 .* ml_prediction
    @test combined ≈ expected atol=1e-6
end
```

## Performance Benchmarks

Expected computational overhead:

| Operation | Time (14-bus) | Time (118-bus) |
|-----------|---------------|----------------|
| ML Topology Prediction | ~1 ms | ~5 ms |
| Joint Prediction | ~2 ms | ~10 ms |
| Ensemble Uncertainty (5 models) | ~10 ms | ~50 ms |
| Particle Filter Update | ~50 ms | ~500 ms |
| **Total Belief Update** | ~50 ms | ~500 ms |

**Note**: ML prediction is significantly faster than particle filter, making hybrid approach attractive.

## References and Further Reading

1. **Topology Estimation**:
   - Deka et al. "Learning for DC-OPF: Classifying active sets using neural nets" (2019)
   - Huang et al. "Physics-informed learning for power system state estimation" (2021)

2. **Joint Estimation**:
   - Zhao et al. "Power system parameter estimation using deep neural networks" (2020)
   - Wang et al. "Joint topology and parameter estimation in distribution systems" (2022)

3. **Uncertainty Quantification**:
   - Gal and Ghahramani "Dropout as a Bayesian Approximation" (2016)
   - Lakshminarayanan et al. "Simple and Scalable Predictive Uncertainty Estimation using Deep Ensembles" (2017)

## Next Steps

1. **Data Collection**: Set up pipeline to collect real PMU/SCADA data
2. **Model Training**: Train on large-scale historical datasets
3. **Validation**: Compare against PowerModels.jl and traditional estimators
4. **Deployment**: Integrate into production LASCOPF workflow
5. **Monitoring**: Track estimation accuracy and update models periodically

## Support

For questions or issues with ML estimation integration:
- Open an issue on GitHub
- See `examples/ml_estimation_example.jl` for working examples
- Consult `.github/copilot-instructions.md` for codebase structure
