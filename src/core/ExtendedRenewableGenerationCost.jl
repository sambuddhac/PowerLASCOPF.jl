"""
	@kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel
    		renewable_cost_core::PSY.RenewableGenerationCost # Coefficient of the quadratic term
    		regularization_term::Union{T, Float64} # Regularization Term
	end
	This is the struct for implmenting extended renewable generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended renewable generation cost model.
        - renewable_cost_core::PSY.RenewableGenerationCost # Coefficient of the quadratic term
        - regularization_term::Union{T, Float64} # Regularization Term
"""

@kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel
    renewable_cost_core::PSY.RenewableGenerationCost # Coefficient of the quadratic term
    regularization_term::Union{T, Float64} # Regularization Term
end

# Constructors
ExtendedRenewableGenerationCost(renewable_cost_core, regularization_term) = ExtendedRenewableGenerationCost(; renewable_cost_core, regularization_term)

# FIX IS HERE: Make this constructor parametric.
# It now explicitly states that it's a constructor for ExtendedRenewableGenerationCost{T}
# where T is any subtype of GenIntervals.

function ExtendedRenewableGenerationCost{T}(::Nothing) where {T<:GenIntervals}
    # When this constructor is called, `T` is already known.
    # We then call the keyword argument constructor for `ExtendedRenewableGenerationCost{T}`.
    # The `0.0` is a `Float64`, which is allowed for `regularization_term` because of `Union{T, Float64}`.
    ExtendedRenewableGenerationCost{T}(; renewable_cost_core=PSY.RenewableGenerationCost(0.0), regularization_term=0.0)
end

# Getter functions
get_variable(value::ExtendedRenewableGenerationCost) = PSY.get_variable(value.renewable_cost_core)
get_curtailment_cost(value::ExtendedRenewableGenerationCost) = PSY.get_curtailment_cost(value.renewable_cost_core)
get_regularization_term(value::ExtendedRenewableGenerationCost) = value.regularization_term
get_cost_core(value::ExtendedRenewableGenerationCost) = value.renewable_cost_core

"""Set [`ExtendedRenewableGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedRenewableGenerationCost, val) = PSY.set_variable!(value.renewable_cost_core, val)
set_curtailment_cost!(value::ExtendedRenewableGenerationCost, val) = PSY.set_curtailment_cost!(value.renewable_cost_core, val)
set_regularization_term!(value::ExtendedRenewableGenerationCost, val) = value.regularization_term = val
set_cost_core(value::ExtendedRenewableGenerationCost, cost_core) = value.renewable_cost_core = cost_core

"""
    compute_regularization_cost(cost::ExtendedRenewableGenerationCost{T}, Pg, args...) where {T<:GenIntervals}

Compute the regularization cost term for renewable generators based on the interval type.
"""
function compute_regularization_cost(cost::ExtendedRenewableGenerationCost{T}, Pg, args...) where {T<:GenIntervals}
    if isa(cost.regularization_term, Float64)
        return cost.regularization_term * Pg^2
    else
        return regularization_term(cost.regularization_term, Pg, args...)
    end
end

"""
    build_renewable_cost_expression(cost::ExtendedRenewableGenerationCost, Pg, Pcurt, renewable_forecast, args...)

Build the complete renewable cost expression including variable cost, curtailment cost, and regularization.
"""
function build_renewable_cost_expression(cost::ExtendedRenewableGenerationCost, Pg, Pcurt, renewable_forecast, args...)
    # Variable cost for generation
    variable_cost = PSY.get_variable(cost.renewable_cost_core) * Pg
    
    # Curtailment cost (cost of not using available renewable energy)
    curtailment_cost = cost.curtailment_cost * Pcurt
    
    # Add regularization cost
    regularization_cost = compute_regularization_cost(cost, Pg, args...)
    
    return variable_cost + curtailment_cost + regularization_cost
end

# Common utility functions
update_regularization_parameters!(cost::ExtendedRenewableGenerationCost{T}, new_params::Dict) where {T<:GenIntervals} = 
    update_regularization_parameters_generic!(cost, new_params, T)

set_regularization_interval!(cost::ExtendedRenewableGenerationCost, interval::T) where {T<:GenIntervals} = 
    (cost.regularization_term = interval)

get_regularization_type(cost::ExtendedRenewableGenerationCost{T}) where {T<:GenIntervals} = T

is_regularization_active(cost::ExtendedRenewableGenerationCost) = !isa(cost.regularization_term, Float64)
