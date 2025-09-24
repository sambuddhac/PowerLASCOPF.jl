module Visualization

using Plots

"""
    plot_loss_curve(loss_history::Vector{Float64}, title::String)

Plots the loss curve over training iterations.

# Arguments
- `loss_history`: A vector containing loss values recorded during training.
- `title`: The title of the plot.
"""
function plot_loss_curve(loss_history::Vector{Float64}, title::String)
    plot(loss_history, title=title, xlabel="Iterations", ylabel="Loss", legend=false)
    display(plot!)
end

"""
    plot_policy_performance(performance_data::Dict, title::String)

Visualizes the performance of the policy over episodes.

# Arguments
- `performance_data`: A dictionary containing episode numbers and corresponding performance metrics.
- `title`: The title of the plot.
"""
function plot_policy_performance(performance_data::Dict, title::String)
    episodes = keys(performance_data)
    performance = values(performance_data)
    
    plot(episodes, performance, title=title, xlabel="Episodes", ylabel="Performance", legend=false)
    display(plot!)
end

end