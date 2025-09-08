using POMDPs
using POMDPTools
using Distributions
using LinearAlgebra

"""
Belief updater for power system parameter estimation
"""
struct PowerSystemBeliefUpdater <: Updater
    pomdp::PowerLASCOPFPOMDP
    
    # Kalman filter parameters for continuous parameters
    process_noise::Dict{String, Float64}
    measurement_noise::Dict{String, Float64}
    
    # Particle filter parameters for discrete topology
    n_particles::Int
    resampling_threshold::Float64
end

"""
Particle-based belief state for topology and parameters
"""
struct PowerSystemBelief
    # Particles for topology uncertainty
    topology_particles::Vector{Vector{Bool}}  # Each particle is a line status vector
    topology_weights::Vector{Float64}
    
    # Gaussian beliefs for continuous parameters
    parameter_means::Dict{String, Vector{Float64}}
    parameter_covariances::Dict{String, Matrix{Float64}}
    
    # Hybrid belief statistics
    n_particles::Int
    effective_particles::Float64
end

function POMDPTools.initialize_belief(updater::PowerSystemBeliefUpdater, d)
    n_lines = length(updater.pomdp.transmission_lines)
    n_particles = updater.n_particles
    
    # Initialize topology particles (all lines operational with high probability)
    topology_particles = Vector{Vector{Bool}}()
    for i in 1:n_particles
        particle = Vector{Bool}()
        for j in 1:n_lines
            # Most lines operational, small chance of failure
            push!(particle, rand() > 0.01)
        end
        push!(topology_particles, particle)
    end
    
    # Uniform weights initially
    topology_weights = ones(n_particles) / n_particles
    
    # Initialize parameter beliefs
    param_means = Dict{String, Vector{Float64}}()
    param_covs = Dict{String, Matrix{Float64}}()
    
    # Load forecast errors
    n_loads = length(updater.pomdp.loads)
    param_means["load_errors"] = zeros(n_loads)
    param_covs["load_errors"] = 0.1 * I(n_loads)
    
    # Renewable forecast errors
    n_renewables = count(g -> isa(g.generator, RenewableDispatch), updater.pomdp.generators)
    param_means["renewable_errors"] = zeros(n_renewables)
    param_covs["renewable_errors"] = 0.15 * I(n_renewables)
    
    return PowerSystemBelief(
        topology_particles,
        topology_weights,
        param_means,
        param_covs,
        n_particles,
        n_particles
    )
end

function POMDPs.update(updater::PowerSystemBeliefUpdater, b::PowerSystemBelief, 
                      a::PowerSystemAction, o::PowerSystemObservation)
    
    # Update topology belief using particle filter
    new_topology_particles, new_weights = update_topology_belief(
        updater, b.topology_particles, b.topology_weights, a, o
    )
    
    # Update parameter beliefs using Kalman filtering
    new_param_means, new_param_covs = update_parameter_belief(
        updater, b.parameter_means, b.parameter_covariances, a, o
    )
    
    # Resample if effective sample size is too low
    effective_particles = 1.0 / sum(new_weights.^2)
    if effective_particles < updater.resampling_threshold * length(new_weights)
        new_topology_particles, new_weights = resample_particles(
            new_topology_particles, new_weights
        )
        effective_particles = length(new_weights)
    end
    
    return PowerSystemBelief(
        new_topology_particles,
        new_weights,
        new_param_means,
        new_param_covs,
        length(new_topology_particles),
        effective_particles
    )
end

"""
Update topology belief using particle filter
"""
function update_topology_belief(updater::PowerSystemBeliefUpdater, 
                               particles::Vector{Vector{Bool}}, weights::Vector{Float64},
                               a::PowerSystemAction, o::PowerSystemObservation)
    
    new_particles = Vector{Vector{Bool}}()
    new_weights = Vector{Float64}()
    
    for (i, particle) in enumerate(particles)
        # Propagate particle through transition model
        new_particle = propagate_topology_particle(updater, particle, a)
        
        # Calculate likelihood of observation given particle
        likelihood = calculate_topology_likelihood(updater, new_particle, o)
        
        push!(new_particles, new_particle)
        push!(new_weights, weights[i] * likelihood)
    end
    
    # Normalize weights
    weight_sum = sum(new_weights)
    if weight_sum > 0
        new_weights = new_weights / weight_sum
    else
        new_weights = ones(length(new_weights)) / length(new_weights)
    end
    
    return new_particles, new_weights
end

"""
Update parameter beliefs using Extended Kalman Filter
"""
function update_parameter_belief(updater::PowerSystemBeliefUpdater,
                                means::Dict{String, Vector{Float64}},
                                covs::Dict{String, Matrix{Float64}},
                                a::PowerSystemAction, o::PowerSystemObservation)
    
    new_means = Dict{String, Vector{Float64}}()
    new_covs = Dict{String, Matrix{Float64}}()
    
    # Update load error estimates
    if haskey(means, "load_errors")
        load_mean = means["load_errors"]
        load_cov = covs["load_errors"]
        
        # Prediction step
        Q = updater.process_noise["load"] * I(length(load_mean))
        pred_mean = load_mean  # Assume random walk
        pred_cov = load_cov + Q
        
        # Update step
        R = updater.measurement_noise["load"] * I(length(o.measured_loads))
        H = I(length(load_mean))  # Direct observation
        
        innovation = o.measured_loads - o.load_forecasts - pred_mean
        S = H * pred_cov * H' + R
        K = pred_cov * H' / S
        
        new_means["load_errors"] = pred_mean + K * innovation
        new_covs["load_errors"] = (I(length(load_mean)) - K * H) * pred_cov
    end
    
    # Update renewable error estimates
    if haskey(means, "renewable_errors")
        ren_mean = means["renewable_errors"]
        ren_cov = covs["renewable_errors"]
        
        # Similar EKF update for renewable forecasts
        Q = updater.process_noise["renewable"] * I(length(ren_mean))
        pred_mean = ren_mean
        pred_cov = ren_cov + Q
        
        # Extract renewable measurements
        renewable_obs = extract_renewable_observations(updater.pomdp, o)
        R = updater.measurement_noise["renewable"] * I(length(renewable_obs))
        H = I(length(ren_mean))
        
        innovation = renewable_obs - o.renewable_forecasts - pred_mean
        S = H * pred_cov * H' + R
        K = pred_cov * H' / S
        
        new_means["renewable_errors"] = pred_mean + K * innovation
        new_covs["renewable_errors"] = (I(length(ren_mean)) - K * H) * pred_cov
    end
    
    return new_means, new_covs
end

"""
Resample particles using systematic resampling
"""
function resample_particles(particles::Vector{Vector{Bool}}, weights::Vector{Float64})
    n = length(particles)
    new_particles = Vector{Vector{Bool}}()
    
    # Systematic resampling
    u = rand() / n
    c = weights[1]
    i = 1
    
    for j in 1:n
        while u > c && i < n
            i += 1
            c += weights[i]
        end
        push!(new_particles, copy(particles[i]))
        u += 1.0 / n
    end
    
    new_weights = ones(n) / n
    return new_particles, new_weights
end

"""
Calculate likelihood of topology observation
"""
function calculate_topology_likelihood(updater::PowerSystemBeliefUpdater, 
                                     particle::Vector{Bool}, o::PowerSystemObservation)
    likelihood = 1.0
    
    for (i, observed_status) in enumerate(o.line_status_observations)
        if particle[i] == observed_status
            likelihood *= 0.95  # High probability of correct observation
        else
            likelihood *= 0.05  # Low probability of incorrect observation
        end
    end
    
    return likelihood
end

"""
Extract renewable generation observations
"""
function extract_renewable_observations(pomdp::PowerLASCOPFPOMDP, o::PowerSystemObservation)
    renewable_indices = findall(g -> isa(g.generator, RenewableDispatch), pomdp.generators)
    return o.generator_output_measurements[renewable_indices]
end
