using Flux

"""
    PolicyNetwork

A neural network policy for the POMDP framework.
"""
mutable struct PolicyNetwork
    model::Chain
    optimizer::ADAM

    function PolicyNetwork(input_size::Int, output_size::Int, learning_rate::Float64)
        model = Chain(
            Dense(input_size, 64, relu),
            Dense(64, 64, relu),
            Dense(64, output_size, softmax)
        )
        optimizer = ADAM(learning_rate)
        return new(model, optimizer)
    end
end

"""
    predict_action(policy::PolicyNetwork, state::AbstractVector)

Predict the action probabilities given the current state.
"""
function predict_action(policy::PolicyNetwork, state::AbstractVector)
    return policy.model(state)
end

"""
    train_policy!(policy::PolicyNetwork, states::AbstractMatrix, actions::AbstractMatrix, 
                   rewards::AbstractVector)

Train the policy network using the provided states, actions, and rewards.
"""
function train_policy!(policy::PolicyNetwork, states::AbstractMatrix, actions::AbstractMatrix, rewards::AbstractVector)
    Flux.train!(loss_function, params(policy.model), [(states, actions)], policy.optimizer)
end

"""
    loss_function(states::AbstractMatrix, actions::AbstractMatrix)

Calculate the loss for the policy network based on the states and actions.
"""
function loss_function(states::AbstractMatrix, actions::AbstractMatrix)
    action_probs = policy.model(states)
    return Flux.crossentropy(action_probs, actions)
end

"""
    save_policy(policy::PolicyNetwork, filename::String)

Save the policy network to a file.
"""
function save_policy(policy::PolicyNetwork, filename::String)
    open(filename, "w") do io
        serialize(io, policy)
    end
end

"""
    load_policy(filename::String)

Load a policy network from a file.
"""
function load_policy(filename::String)
    open(filename, "r") do io
        return deserialize(io)
    end
end