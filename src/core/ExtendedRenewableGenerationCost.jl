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

# @kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel
#     renewable_cost_core::PSY.RenewableGenerationCost # Coefficient of the quadratic term
#     regularization_term::Union{T, Float64} # Regularization Term
# end

# This outer constructor is fine for cases where regularization_term is a GenIntervals subtype
# but will cause a TypeError if regularization_term is a Float64, as it will try to infer T as Float64.
# We'll discuss a more robust version for this below.

ExtendedRenewableGenerationCost(renewable_cost_core, regularization_term) = ExtendedRenewableGenerationCost(; renewable_cost_core, regularization_term)

# FIX IS HERE: Make this constructor parametric.
# It now explicitly states that it's a constructor for ExtendedRenewableGenerationCost{T}
# where T is any subtype of GenIntervals.

function ExtendedRenewableGenerationCost{T}(::Nothing) where {T<:GenIntervals}
    # When this constructor is called, `T` is already known.
    # We then call the keyword argument constructor for `ExtendedRenewableGenerationCost{T}`.
    # The `0.0` is a `Float64`, which is allowed for `regularization_term` because of `Union{T, Float64}`.
    ExtendedRenewableGenerationCost{T}(; renewable_cost_core=PSY.RenewableGenerationCost(nothing), regularization_term=0.0)
end

"""Get [`ExtendedRenewbleGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedRenewableGenerationCost) = PSY.get_variable(value.renewable_cost_core)
"""Get [`ExtendedRenewbleGenerationCost`](@ref) `fixed`."""
get_fixed(value::ExtendedRenewbleGenerationCost) = PSY.get_fixed(value.renewable_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
get_start_up(value::ExtendedRenewableGenerationCost) = PSY.get_start_up(value.renewable_cost_core)
"""Get [`ExtendedRenewableGenerationCost`](@ref) `shut_down`."""
get_shut_down(value::ExtendedRenewableGenerationCost) = PSY.get_shut_down(value.renewable_cost_core)
"""Get [`ExtendedRenewableGenerationCost`](@ref) `regularization_term`."""
get_regularization(value::ExtendedRenewableGenerationCost) = value.regularization_term
"""Get [`ExtendedRenewableGenerationCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedRenewableGenerationCost) = value.renewable_cost_core
"""Get [`ExtendedRenewableGenerationCost`](@ref) `curtailment_cost`."""
get_curtailment_cost(value::ExtendedRenewableGenerationCost) = PSY.get_curtailment_cost(value.renewable_cost_core)

"""Set [`ExtendedRenewableGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.variable = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `curtailment_cost`."""
set_curtailment_cost!(value::ExtendedRenewableGenerationCost, val) = value.renewable_core_cost.curtailment_cost = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `regularization`."""
set_regularization!(value::ExtendedRenewaableGenerationCost, val) = value.regularization_term = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `cost_core`."""
set_cost_core(value::ExtendedRenewableGenerationCost, cost_core) = value.renewable_cost_core = cost_core
