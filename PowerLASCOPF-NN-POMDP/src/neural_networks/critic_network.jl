using Flux

"""
    CriticNetwork

A neural network that evaluates the actions taken by the actor network.
"""
mutable struct CriticNetwork
    model::Chain

    function CriticNetwork(input_size::Int, output_size::Int)
        # Define the neural network architecture
        model = Chain(
            Dense(input_size, 64, relu),
            Dense(64, 64, relu),
            Dense(64, output_size)
        )
        return new(model)
    end
end

"""
    predict(critic::CriticNetwork, state::AbstractVector)

Evaluate the given state and return the predicted value.
"""
function predict(critic::CriticNetwork, state::AbstractVector)
    return critic.model(state)
end

"""
    train!(critic::CriticNetwork, states::AbstractMatrix, targets::AbstractVector, optimizer)

Train the critic network using the provided states and target values.
"""
function train!(critic::CriticNetwork, states::AbstractMatrix, targets::AbstractVector, optimizer)
    Flux.train!(loss, params(critic.model), [(states, targets)], optimizer)
end

"""
    loss(critic::CriticNetwork, states::AbstractMatrix, targets::AbstractVector)

Calculate the loss for the critic network.
"""
function loss(critic::CriticNetwork, states::AbstractMatrix, targets::AbstractVector)
    predictions = predict(critic, states)
    return Flux.Losses.mse(predictions, targets)
end