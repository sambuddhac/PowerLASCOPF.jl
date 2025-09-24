using Flux

"""
    ObservationModel

This struct represents the observation model for the POMDP framework.
It defines how observations are generated from the current state.
"""
mutable struct ObservationModel
    neural_network::Chain

    function ObservationModel(input_size::Int, output_size::Int)
        # Define a simple feedforward neural network for observation modeling
        model = Chain(
            Dense(input_size, 64, relu),
            Dense(64, 64, relu),
            Dense(64, output_size)
        )
        return new(model)
    end
end

"""
    generate_observation(model::ObservationModel, state::AbstractVector)

Generate an observation from the given state using the neural network model.
"""
function generate_observation(model::ObservationModel, state::AbstractVector)
    return model.neural_network(state)
end

"""
    train_observation_model!(model::ObservationModel, states::Matrix, observations::Matrix, epochs::Int)

Train the observation model using the provided states and observations.
"""
function train_observation_model!(model::ObservationModel, states::Matrix, observations::Matrix, epochs::Int)
    loss_function(x, y) = Flux.Losses.mse(model.neural_network(x), y)
    opt = ADAM()

    for epoch in 1:epochs
        Flux.train!(loss_function, params(model.neural_network), [(states, observations)], opt)
        println("Epoch $epoch: Loss = $(loss_function(states, observations))")
    end
end