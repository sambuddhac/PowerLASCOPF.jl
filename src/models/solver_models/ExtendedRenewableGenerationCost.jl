"""
	@kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel
    		renewable_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended renewable generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended renewable generation cost model.
        - thermal_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    thermal_cost_core::ThermalGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""Get [`ExtendedRenewbleGenerationCost`](@ref) `variable`."""
PSY.get_variable(value::ExtendedRenewableGenerationCost) = get_variable(value.renewable_cost_core)
"""Get [`ExtendedRenewbleGenerationCost`](@ref) `fixed`."""
PSY.get_fixed(value::ExtendedRenewbleGenerationCost) = get_fixed(value.renewable_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
PSY.get_start_up(value::ExtendedRenewableGenerationCost) = get_start_up(value.renewable_cost_core)
"""Get [`ExtendedRenewableGenerationCost`](@ref) `shut_down`."""
PSY.get_shut_down(value::ExtendedRenewableGenerationCost) = get_shut_down(value.renewable_cost_core)
"""Get [`ExtendedRenewableGenerationCost`](@ref) `regularization_term`."""
PSY.get_regularization(value::ExtendedRenewableGenerationCost) = value.regularization_term
"""Get [`ExtendedRenewableGenerationCost`](@ref) `cost_core`."""
PSY.get_cost_core(value::ExtendedRenewableGenerationCost) = value.renewable_cost_core

"""Set [`ExtendedRenewableGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.variable = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.fixed = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `start_up`."""
set_start_up!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.start_up = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `shut_down`."""
set_shut_down!(value::ExtendedRenewableGenerationCost, val) = value.renewable_cost_core.shut_down = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `shut_down`."""
set_regularization!(value::ExtendedThermalGenerationCost, val) = value.regularization_term = val
"""Set [`ExtendedRenewableGenerationCost`](@ref) `cost_core`."""
set_cost_core(value::ExtendedRenewableGenerationCost, cost_core) = value.renewable_cost_core = cost_core
