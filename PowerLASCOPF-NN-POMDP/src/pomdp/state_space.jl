module POMDP

using Flux

"""
    StateSpace

Represents the state space for the POMDP, including state variables and their relationships.
"""
struct StateSpace
    state_variables::Vector{String}
    state_bounds::Dict{String, Tuple{Float64, Float64}}
    
    function StateSpace(state_variables::Vector{String}, state_bounds::Dict{String, Tuple{Float64, Float64}})
        new(state_variables, state_bounds)
    end
end

"""
    create_state_space()

Creates a state space for the POMDP with predefined state variables and bounds.
"""
function create_state_space()::StateSpace
    state_variables = ["generator_output", "line_flow", "voltage_angle"]
    state_bounds = Dict(
        "generator_output" => (0.0, 100.0),
        "line_flow" => (-50.0, 50.0),
        "voltage_angle" => (-π, π)
    )
    
    return StateSpace(state_variables, state_bounds)
end

"""
    normalize_state(state::Vector{Float64}, state_space::StateSpace)::Vector{Float64}

Normalizes the state variables based on the defined bounds in the state space.
"""
function normalize_state(state::Vector{Float64}, state_space::StateSpace)::Vector{Float64}
    normalized_state = Float64[]
    
    for (i, var) in enumerate(state_space.state_variables)
        lower_bound, upper_bound = state_space.state_bounds[var]
        normalized_value = (state[i] - lower_bound) / (upper_bound - lower_bound)
        push!(normalized_state, normalized_value)
    end
    
    return normalized_state
end

"""
    denormalize_state(normalized_state::Vector{Float64}, state_space::StateSpace)::Vector{Float64}

Denormalizes the state variables back to their original scale.
"""
function denormalize_state(normalized_state::Vector{Float64}, state_space::StateSpace)::Vector{Float64}
    denormalized_state = Float64[]
    
    for (i, var) in enumerate(state_space.state_variables)
        lower_bound, upper_bound = state_space.state_bounds[var]
        denormalized_value = normalized_state[i] * (upper_bound - lower_bound) + lower_bound
        push!(denormalized_state, denormalized_value)
    end
    
    return denormalized_state
end

end