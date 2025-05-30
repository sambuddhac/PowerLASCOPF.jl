"""
	@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    		thermal_cost_core::ThermalGenerationCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended thermal generation cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended thermal generation cost model.
        - thermal_cost_core::ThermalGenerationCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedThermalGenerationCost{T<:GenIntervals}<:AbstractModel
    thermal_cost_core::ThermalGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""Get [`ExtendedThermalGenerationCost`](@ref) `variable`."""
get_variable(value::ExtendedThermalGenerationCost) = get_variable(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `fixed`."""
get_fixed(value::ExtendedThermalGenerationCost) = get_fixed(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
get_start_up(value::ExtendedThermalGenerationCost) = get_start_up(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
get_shut_down(value::ExtendedThermalGenerationCost) = get_shut_down(value.thermal_cost_core)
"""Get [`ExtendedThermalGenerationCost`](@ref) `regularization_term`."""
get_regularization(value::ExtendedThermalGenerationCost) = value.regularization_term
"""Get [`ExtendedThermalGenerationCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedThermalGenerationCost) = value.thermal_cost_core

"""Set [`ExtendedThermalGenerationCost`](@ref) `variable`."""
set_variable!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.variable = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.fixed = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `start_up`."""
set_start_up!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.start_up = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
set_shut_down!(value::ExtendedThermalGenerationCost, val) = value.thermal_cost_core.shut_down = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `shut_down`."""
set_regularization!(value::ExtendedThermalGenerationCost, val) = value.regularization_term = val
"""Set [`ExtendedThermalGenerationCost`](@ref) `cost_core`."""
set_cost_core(value::ExtendedThermalGenerationCost, cost_core) = value.thermal_cost_core = cost_core