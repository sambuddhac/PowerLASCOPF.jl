using Flux
using Flux.Optimise
using Statistics
using Random

"""
Experience tuple for replay buffer
"""
struct Experience
    state::Vector{Float32}
    action::Vector{Float32}
    reward::Float32
    next_state::Vector{Float32}
    done::Bool
end

"""
Train neural network policy using DDPG/TD3 algorithm
"""
function train_neural_policy!(
    policy::NeuralNetworkPolicy,
    updater::PowerSystemBeliefUpdater;
    n_episodes::Int = 1000,
    max_steps_per_episode::Int = 100,
    update_frequency::Int = 4,
    save_frequency::Int = 100
)
    
    # Optimizers
    actor_opt = Adam(policy.learning_rate_actor)
    critic_opt = Adam(policy.learning_rate_critic)
    
    # Training statistics
    episode_rewards = Float64[]
    actor_losses = Float64[]
    critic_losses = Float64[]
    
    println("🚀 Starting Neural Policy Training...")
    println("Episodes: $n_episodes, Max steps: $max_steps_per_episode")
    
    for episode in 1:n_episodes
        # Initialize episode
        initial_belief = POMDPTools.initialize_belief(updater, nothing)
        belief = initial_belief
        episode_reward = 0.0
        step_count = 0
        
        # Create initial state
        current_state = create_initial_power_state(policy.pomdp)
        
        for step in 1:max_steps_per_episode
            step_count += 1
            
            # Convert belief to neural input
            state_vec = vec(belief_to_neural_input(policy, belief))
            
            # Select action using current policy
            action = POMDPs.action(policy, belief)
            action_vec = action_to_vector(action)
            
            # Execute action in environment
            next_state_dist = POMDPs.transition(policy.pomdp, current_state, action)
            next_state = rand(next_state_dist)
            
            # Get observation
            obs_dist = POMDPs.observation(policy.pomdp, action, next_state)
            observation = rand(obs_dist)
            
            # Calculate reward
            reward = Float32(POMDPs.reward(policy.pomdp, current_state, action, next_state))
            episode_reward += reward
            
            # Update belief
            next_belief = POMDPs.update(updater, belief, action, observation)
            next_state_vec = vec(belief_to_neural_input(policy, next_belief))
            
            # Store experience in replay buffer
            experience = Experience(state_vec, action_vec, reward, next_state_vec, step == max_steps_per_episode)
            push!(policy.replay_buffer, experience)
            
            # Update networks if enough experience collected
            if length(policy.replay_buffer) >= policy.batch_size && step % update_frequency == 0
                actor_loss, critic_loss = update_networks!(policy, actor_opt, critic_opt)
                push!(actor_losses, actor_loss)
                push!(critic_losses, critic_loss)
            end
            
            # Move to next state
            belief = next_belief
            current_state = next_state
            
            # Check termination
            if POMDPs.isterminal(policy.pomdp, next_state)
                break
            end
        end
        
        push!(episode_rewards, episode_reward)
        
        # Decay exploration noise
        policy.noise_scale *= policy.noise_decay
        
        # Log progress
        if episode % 10 == 0
            avg_reward = mean(episode_rewards[max(1, end-9):end])
            println("Episode $episode: Avg Reward = $(round(avg_reward, digits=2)), Steps = $step_count, Noise = $(round(policy.noise_scale, digits=4))")
        end
        
        # Save model periodically
        if episode % save_frequency == 0
            save_neural_policy(policy, "policy_episode_$episode.bson")
        end
    end
    
    return Dict(
        "episode_rewards" => episode_rewards,
        "actor_losses" => actor_losses,
        "critic_losses" => critic_losses
    )
end

"""
Update actor and critic networks using mini-batch
"""
function update_networks!(policy::NeuralNetworkPolicy, actor_opt, critic_opt)
    # Sample mini-batch from replay buffer
    batch_size = min(policy.batch_size, length(policy.replay_buffer))
    batch_indices = sample(1:length(policy.replay_buffer), batch_size, replace=false)
    batch = [policy.replay_buffer[i] for i in batch_indices]
    
    # Prepare batch data
    states = hcat([exp.state for exp in batch]...)
    actions = hcat([exp.action for exp in batch]...)
    rewards = [exp.reward for exp in batch]
    next_states = hcat([exp.next_state for exp in batch]...)
    dones = [exp.done for exp in batch]
    
    # Move to GPU if available
    if CUDA.functional()
        states = gpu(states)
        actions = gpu(actions)
        rewards = gpu(rewards)
        next_states = gpu(next_states)
    end
    
    # Update Critic Network
    critic_loss = update_critic!(policy, states, actions, rewards, next_states, dones, critic_opt)
    
    # Update Actor Network (less frequently for stability)
    actor_loss = update_actor!(policy, states, actor_opt)
    
    # Soft update target networks
    soft_update_targets!(policy)
    
    return actor_loss, critic_loss
end

"""
Update critic network using Bellman equation
"""
function update_critic!(policy, states, actions, rewards, next_states, dones, critic_opt)
    # Calculate target Q-values using target networks
    next_actions = policy.target_actor(next_states)
    target_q = policy.target_critic(vcat(next_states, next_actions))
    
    # Bellman backup
    targets = rewards .+ policy.discount_factor .* vec(target_q) .* (1 .- dones)
    
    # Critic loss
    loss, grads = Flux.withgradient(policy.critic_network) do model
        q_values = model(vcat(states, actions))
        Flux.mse(vec(q_values), targets)
    end
    
    # Update critic
    Flux.update!(critic_opt, policy.critic_network, grads[1])
    
    return loss
end

"""
Update actor network using policy gradient
"""
function update_actor!(policy, states, actor_opt)
    # Actor loss (policy gradient)
    loss, grads = Flux.withgradient(policy.actor_network) do model
        predicted_actions = model(states)
        q_values = policy.critic_network(vcat(states, predicted_actions))
        -mean(q_values)  # Maximize Q-value
    end
    
    # Update actor
    Flux.update!(actor_opt, policy.actor_network, grads[1])
    
    return loss
end

"""
Soft update target networks
"""
function soft_update_targets!(policy)
    τ = policy.target_update_rate
    
    # Update target actor
    for (target_param, param) in zip(Flux.params(policy.target_actor), Flux.params(policy.actor_network))
        target_param .= τ .* param .+ (1 - τ) .* target_param
    end
    
    # Update target critic
    for (target_param, param) in zip(Flux.params(policy.target_critic), Flux.params(policy.critic_network))
        target_param .= τ .* param .+ (1 - τ) .* target_param
    end
end

"""
Save neural network policy to file
"""
function save_neural_policy(policy::NeuralNetworkPolicy, filename::String)
    model_data = Dict(
        "actor_network" => cpu(policy.actor_network),
        "critic_network" => cpu(policy.critic_network),
        "state_dim" => policy.state_dim,
        "action_dim" => policy.action_dim,
        "hidden_dims" => policy.hidden_dims
    )
    
    BSON.@save filename model_data
    println("✅ Model saved to $filename")
end

"""
Load neural network policy from file
"""
function load_neural_policy(pomdp::PowerLASCOPFPOMDP, filename::String)
    BSON.@load filename model_data
    
    # Reconstruct policy
    policy = NeuralNetworkPolicy(pomdp, 
        hidden_dims=model_data["hidden_dims"])
    
    # Load network weights
    policy.actor_network = model_data["actor_network"]
    policy.critic_network = model_data["critic_network"]
    
    return policy
end