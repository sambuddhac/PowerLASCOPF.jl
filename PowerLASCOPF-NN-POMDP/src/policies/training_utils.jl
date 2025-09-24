using Flux
using Statistics

"""
    calculate_loss(predictions::AbstractArray, targets::AbstractArray)

Calculate the mean squared error loss between predictions and targets.
"""
function calculate_loss(predictions::AbstractArray, targets::AbstractArray)
    return mean((predictions .- targets).^2)
end

"""
    update_weights!(model::Flux.Chain, loss::Float64, optimizer::Flux.Optimiser)

Update the model weights using the optimizer based on the calculated loss.
"""
function update_weights!(model::Flux.Chain, loss::Float64, optimizer::Flux.Optimiser)
    Flux.train!(loss, Flux.params(model), optimizer)
end

"""
    train_epoch!(model::Flux.Chain, data::Tuple, optimizer::Flux.Optimiser)

Train the model for one epoch using the provided data and optimizer.
"""
function train_epoch!(model::Flux.Chain, data::Tuple, optimizer::Flux.Optimiser)
    inputs, targets = data
    predictions = model(inputs)
    loss = calculate_loss(predictions, targets)
    update_weights!(model, loss, optimizer)
    return loss
end

"""
    evaluate_model(model::Flux.Chain, data::Tuple)

Evaluate the model on the provided data and return the loss.
"""
function evaluate_model(model::Flux.Chain, data::Tuple)
    inputs, targets = data
    predictions = model(inputs)
    return calculate_loss(predictions, targets)
end

"""
    save_model(model::Flux.Chain, filename::String)

Save the trained model to a file.
"""
function save_model(model::Flux.Chain, filename::String)
    Flux.save(filename, model)
end

"""
    load_model(filename::String)

Load a model from a file.
"""
function load_model(filename::String)
    return Flux.load(filename)
end