using POMDPs
using Flux
using Test
include("../src/policies/neural_network_policy.jl")
include("../src/training/train_policy.jl")

# Define a simple environment for testing
struct TestEnv
    state_space::Vector{Float64}
    action_space::Vector{Int}
end

function reset!(env::TestEnv)
    env.state_space = rand(3)  # Random initial state
    return env.state_space
end

function step!(env::TestEnv, action::Int)
    # Simulate the environment's response to an action
    reward = rand()  # Random reward
    env.state_space = rand(3)  # New random state
    return env.state_space, reward
end

# Test the training process
function test_training()
    env = TestEnv([], [])
    policy = NeuralNetworkPolicy()  # Assuming a constructor exists
    optimizer = ADAM(0.001)
    
    # Train the policy
    for epoch in 1:10
        state = reset!(env)
        action = policy(state)
        next_state, reward = step!(env, action)
        
        # Update policy based on the reward
        loss = train_policy!(policy, state, action, reward, next_state, optimizer)
        @test loss >= 0  # Ensure loss is non-negative
    end
end

@testset "Training Tests" begin
    test_training()
end