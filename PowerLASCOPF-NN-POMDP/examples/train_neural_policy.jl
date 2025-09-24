using POMDPs
using Flux
using Statistics
using Random

# Load necessary modules
include("../src/policies/neural_network_policy.jl")
include("../src/training/train_policy.jl")
include("../src/utils/data_preprocessing.jl")

# Set random seed for reproducibility
Random.seed!(1234)

# Define the environment and POMDP model
pomdp_model = create_pomdp_model()  # Function to create the POMDP model
policy = NeuralNetworkPolicy()  # Initialize the neural network policy

# Training parameters
num_episodes = 1000
max_steps = 200
learning_rate = 0.001
batch_size = 32

# Initialize training data storage
experience_replay = []

# Training loop
for episode in 1:num_episodes
    state = reset_environment(pomdp_model)  # Reset the environment for a new episode
    total_reward = 0.0

    for step in 1:max_steps
        action = policy(state)  # Get action from the policy
        next_state, reward, done = step_environment(pomdp_model, state, action)  # Step the environment
        
        # Store experience in replay buffer
        push!(experience_replay, (state, action, reward, next_state, done))
        
        total_reward += reward
        state = next_state
        
        if done
            break
        end
    end

    # Train the policy using the experience replay
    if length(experience_replay) >= batch_size
        train_policy!(policy, experience_replay, learning_rate, batch_size)
    end

    println("Episode: $episode, Total Reward: $total_reward")
end

# Save the trained policy
save_policy(policy, "trained_policy.jls")  # Function to save the trained policy model

println("Training completed!")