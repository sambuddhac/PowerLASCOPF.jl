module DataPreprocessing

using Flux
using Statistics

"""
    normalize_data(data::AbstractArray)

Normalize the input data to have zero mean and unit variance.
"""
function normalize_data(data::AbstractArray)
    mean_val = mean(data)
    std_val = std(data)
    return (data .- mean_val) ./ std_val
end

"""
    split_data(data::AbstractArray, labels::AbstractArray, train_ratio::Float64)

Split the dataset into training and testing sets based on the specified ratio.
"""
function split_data(data::AbstractArray, labels::AbstractArray, train_ratio::Float64)
    n_samples = size(data, 1)
    n_train = Int(floor(n_samples * train_ratio))
    
    indices = shuffle(1:n_samples)
    train_indices = indices[1:n_train]
    test_indices = indices[n_train+1:end]
    
    return data[train_indices, :], labels[train_indices], data[test_indices, :], labels[test_indices]
end

"""
    prepare_data_for_training(data::AbstractArray, labels::AbstractArray, train_ratio::Float64)

Preprocess the data by normalizing and splitting it into training and testing sets.
"""
function prepare_data_for_training(data::AbstractArray, labels::AbstractArray, train_ratio::Float64)
    normalized_data = normalize_data(data)
    return split_data(normalized_data, labels, train_ratio)
end

end # module DataPreprocessing