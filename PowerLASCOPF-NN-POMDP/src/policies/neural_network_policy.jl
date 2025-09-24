module NeuralNetworkPolicy

using Flux

struct NeuralNetworkPolicy
    model::Chain
end

function NeuralNetworkPolicy(input_size::Int, output_size::Int)
    model = Chain(
        Dense(input_size, 64, relu),
        Dense(64, 64, relu),
        Dense(64, output_size, softmax)
    )
    return NeuralNetworkPolicy(model)
end

function select_action(policy::NeuralNetworkPolicy, state::AbstractVector)
    probabilities = policy.model(state)
    action = sample(1:length(probabilities), Weights(probabilities))
    return action
end

function train!(policy::NeuralNetworkPolicy, states::AbstractMatrix, actions::AbstractVector, learning_rate::Float64)
    loss_function = Flux.Losses.crossentropy
    optimizer = Descent(learning_rate)

    Flux.train!(loss_function, params(policy.model), [(states, actions)], optimizer)
end

end