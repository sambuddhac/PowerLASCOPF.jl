"""
Common utility functions for extended cost models.
"""

"""
    update_regularization_parameters_generic!(cost, new_params::Dict, ::Type{T}) where {T<:GenIntervals}

Generic function to update regularization parameters for any extended cost model.
"""
function update_regularization_parameters_generic!(cost, new_params::Dict, ::Type{T}) where {T<:GenIntervals}
    if !isa(cost.regularization_term, Float64)
        # Update interval parameters
        for (key, value) in new_params
            if hasfield(T, Symbol(key))
                setfield!(cost.regularization_term, Symbol(key), value)
            end
        end
    end
end

"""
    create_regularization_interval(interval_type::Type{T}, params::Dict) where {T<:GenIntervals}

Factory function to create regularization intervals of different types.
"""
function create_regularization_interval(interval_type::Type{T}, params::Dict) where {T<:GenIntervals}
    if interval_type == GenFirstBaseInterval
        return GenFirstBaseInterval(; params...)
    elseif interval_type == GenFirstBaseIntervalDZ
        return GenFirstBaseIntervalDZ(; params...)
    elseif interval_type == GenFirstContInterval
        return GenFirstContInterval(; params...)
    elseif interval_type == GenFirstContIntervalDZ
        return GenFirstContIntervalDZ(; params...)
    elseif interval_type == GenLastBaseInterval
        return GenLastBaseInterval(; params...)
    elseif interval_type == GenLastContInterval
        return GenLastContInterval(; params...)
    elseif interval_type == GenInterRNDInterval
        return GenInterRNDInterval(; params...)
    elseif interval_type == GenInterRSDInterval
        return GenInterRSDInterval(; params...)
    else
        error("Unknown interval type: $interval_type")
    end
end

"""
    switch_regularization_type!(cost, new_interval_type::Type{T}, params::Dict) where {T<:GenIntervals}

Switch the regularization interval type for an extended cost model.
"""
function switch_regularization_type!(cost, new_interval_type::Type{T}, params::Dict) where {T<:GenIntervals}
    new_interval = create_regularization_interval(new_interval_type, params)
    cost.regularization_term = new_interval
end

"""
    get_regularization_parameters(cost)

Extract current regularization parameters from an extended cost model.
"""
function get_regularization_parameters(cost)
    if isa(cost.regularization_term, Float64)
        return Dict("simple_regularization" => cost.regularization_term)
    else
        params = Dict()
        for field in fieldnames(typeof(cost.regularization_term))
            params[string(field)] = getfield(cost.regularization_term, field)
        end
        return params
    end
end
