using Flux
using POMDPs
using Test
include("../src/policies/neural_network_policy.jl")
include("../src/neural_networks/actor_network.jl")
include("../src/neural_networks/critic_network.jl")

# Define a simple environment for testing
struct SimpleEnv
    state_space::Vector{Float64}
end

function reset(env::SimpleEnv)
    return env.state_space
end

function step(env::SimpleEnv, action::Int)
    # Simulate a step in the environment
    new_state = env.state_space .+ randn(length(env.state_space)) * 0.1
    reward = rand()  # Random reward for testing
    done = false  # Not terminal for this test
    return new_state, reward, done
end

# Test the neural network policy
function test_neural_network_policy()
    println("Testing Neural Network Policy...")

    # Create a simple environment
    env = SimpleEnv([0.0, 0.0])

    # Initialize the neural network policy
    policy = NeuralNetworkPolicy(ActorNetwork(), CriticNetwork())

    # Reset the environment
    state = reset(env)

    # Test action selection
    action = policy(state)
    @test action in 1:2  # Assuming two possible actions

    # Test policy performance
    new_state, reward, done = step(env, action)
    @test length(new_state) == length(state)
    @test reward >= 0  # Reward should be non-negative

    println("✓ Neural Network Policy tests passed!")
end

# Run the tests
test_neural_network_policy()