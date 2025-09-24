using POMDPs
using Flux
using PowerLASCOPF
using JSON

# Load the trained policy
function load_policy(filename::String)
    return Flux.load(filename)
end

# Evaluate the policy in the environment
function evaluate_policy(policy, environment, num_episodes::Int)
    total_rewards = 0.0

    for episode in 1:num_episodes
        state = reset!(environment)
        done = false
        episode_reward = 0.0

        while !done
            action = policy(state)
            state, reward, done = step!(environment, action)
            episode_reward += reward
        end

        total_rewards += episode_reward
        println("Episode $episode: Total Reward = $episode_reward")
    end

    return total_rewards / num_episodes
end

# Main function to evaluate the policy
function main()
    # Load the trained policy
    policy = load_policy("path/to/trained_policy.jl")

    # Initialize the environment
    environment = create_environment()

    # Evaluate the policy
    average_reward = evaluate_policy(policy, environment, 100)
    println("Average Reward over 100 episodes: $average_reward")
end

main()