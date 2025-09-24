using Flux

"""
    NeuralPolicy

A structure representing the neural network policy for the POMDP framework.
"""
mutable struct NeuralPolicy
    model::Chain
    optimizer::ADAM

    function NeuralPolicy(input_size::Int, output_size::Int, learning_rate::Float64)
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
    select_action(policy::NeuralPolicy, state::AbstractVector)

Select an action based on the current state using the neural network policy.
"""
function select_action(policy::NeuralPolicy, state::AbstractVector)
    action_probs = policy.model(state)
    return rand(Categorical(action_probs))
end

"""
    train_policy!(policy::NeuralPolicy, states::AbstractMatrix, actions::AbstractVector, rewards::AbstractVector)

Train the neural network policy using the collected experiences.
"""
function train_policy!(policy::NeuralPolicy, states::AbstractMatrix, actions::AbstractVector, rewards::AbstractVector)
    loss_function = Flux.Losses.crossentropy

    # Define the loss and gradients
    loss, grads = Flux.withgradient(policy.model) do m
        action_probs = m(states)
        loss_function(action_probs, actions)
    end

    # Update the model parameters
    Flux.Optimise.update!(policy.optimizer, policy.model, grads)

    return loss
end

"""
    save_policy(policy::NeuralPolicy, filename::String)

Save the trained policy model to a file.
"""
function save_policy(policy::NeuralPolicy, filename::String)
    Flux.save(filename, policy.model)
end

"""
    load_policy!(policy::NeuralPolicy, filename::String)

Load a policy model from a file.
"""
function load_policy!(policy::NeuralPolicy, filename::String)
    policy.model = Flux.load(filename)
end