"""
	@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    		storage_cost_core::ExtendedStorageCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended storage cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended storage cost model.
        - storage_cost_core::StorageCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    storage_cost_core::ThermalGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""Get [`ExtendedStorageCost`](@ref) `charge_variable_cost`."""
get_charge_variable_cost(value::ExtendedStorageCost) = get_charge_variable_cost(value.storage_cost_core.charge_variable_cost)
"""Get [`ExtendedStorageCost`](@ref) `discharge_variable_cost`."""
get_discharge_variable_cost(value::ExtendedStorageCost) = get_discharge_variable_cost(value.storage_cost_core.discharge_variable_cost)
"""Get [`ExtendedStorageCost`](@ref) `fixed`."""
get_fixed(value::ExtendedStorageCost) = get_fixed(value.storage_cost_core.fixed)
"""Get [`ExtendedStorageCost`](@ref) `start_up`."""
get_start_up(value::ExtendedStorageCost) = get_start_up(value.storage_cost_core.start_up)
"""Get [`ExtendedStorageCost`](@ref) `shut_down`."""
get_shut_down(value::ExtendedStorageCost) = get_shut_down(value.storage_cost_core.shut_down)
"""Get [`ExtendedStorageCost`](@ref) `energy_shortage_cost`."""
get_energy_shortage_cost(value::ExtendedStorageCost) = get_energy_shortage_cost(value.storage_cost_core.energy_shortage_cost)
"""Get [`ExtendedStorageCost`](@ref) `energy_surplus_cost`."""
get_energy_surplus_cost(value::ExtendedStorageCost) = get_energy_surplus_cost(value.storage_cost_core.energy_surplus_cost)
get_regularization(value::ExtendedStorageCost) = value.regularization_term
"""Get [`ExtendedStorageCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedStorageCost) = value.storage_cost_core



"""Set [`ExtendedStorageCost`](@ref) `charge_variable_cost`."""
set_charge_variable_cost!(value::ExtendedStorageCost, val) = value.storage_cost_core.charge_variable_cost = val
"""Set [`ExtendedStorageCost`](@ref) `discharge_variable_cost`."""
set_discharge_variable_cost!(value::ExtendedStorageCost, val) = value.storage_cost_core.discharge_variable_cost = val
"""Set [`ExtendedStorageCost`](@ref) `fixed`."""
set_fixed!(value::ExtendedStorageCost, val) = value.storage_cost_core.fixed = val
"""Set [`ExtendedStorageCost`](@ref) `start_up`."""
set_start_up!(value::ExtendedStorageCost, val) = value.storage_cost_core.start_up = val
"""Set [`ExtendedStorageCost`](@ref) `shut_down`."""
set_shut_down!(value::ExtendedStorageCost, val) = value.storage_cost_core.shut_down = val
"""Set [`ExtendedStorageCost`](@ref) `energy_shortage_cost`."""
set_energy_shortage_cost!(value::ExtendedStorageCost, val) =
    value.storage_cost_core.energy_shortage_cost = val
"""Set [`ExtendedStorageCost`](@ref) `energy_surplus_cost`."""
set_energy_surplus_cost!(value::ExtendedStorageCost, val) =
    value.storage_cost_core.energy_surplus_cost = val
set_regularization!(value::ExtendedStorageCost, val) = value.regularization_term = val
"""Set ExtendedStorageCost cost_core."""
set_cost_core(value::ExtendedStorageCost, cost_core) = value.storage_cost_core = cost_core
