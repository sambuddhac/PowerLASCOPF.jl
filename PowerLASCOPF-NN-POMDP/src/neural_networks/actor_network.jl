using Flux

"""
    ActorNetwork

A neural network that serves as the actor in the reinforcement learning framework.
It takes the state as input and outputs action probabilities.
"""
struct ActorNetwork
    model::Chain

    function ActorNetwork(input_size::Int, output_size::Int)
        # Define the neural network architecture
        model = Chain(
            Dense(input_size, 64, relu),
            Dense(64, 64, relu),
            Dense(64, output_size, softmax)  # Output probabilities for actions
        )
        return new(model)
    end
end

"""
    forward(actor::ActorNetwork, state::AbstractVector)

Perform a forward pass through the actor network to get action probabilities.
"""
function forward(actor::ActorNetwork, state::AbstractVector)
    return actor.model(state)
end

"""
    select_action(actor::ActorNetwork, state::AbstractVector)

Select an action based on the current state using the actor network.
"""
function select_action(actor::ActorNetwork, state::AbstractVector)
    action_probs = forward(actor, state)
    return rand(Categorical(action_probs))  # Sample an action based on probabilities
end

"""
    train!(actor::ActorNetwork, states::AbstractMatrix, actions::AbstractVector, optimizer)

Train the actor network using the provided states and actions.
"""
function train!(actor::ActorNetwork, states::AbstractMatrix, actions::AbstractVector, optimizer)
    Flux.train!(loss_function, params(actor.model), [(states, actions)], optimizer)
end

"""
    loss_function(states::AbstractMatrix, actions::AbstractVector)

Calculate the loss for the actor network based on the states and actions.
"""
function loss_function(states::AbstractMatrix, actions::AbstractVector)
    action_probs = forward(actor, states)
    return crossentropy(action_probs, actions)  # Cross-entropy loss for action probabilities
end