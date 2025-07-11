"""
	@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    		storage_cost_core::PSY.StorageCost # Coefficient of the quadratic term
    		regularization_term::T # Regularization Term
	end
	This is the struct for implmenting extended storage cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended storage cost model.
        - storage_cost_core::PSY.StorageCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
"""

@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    storage_cost_core::PSY.StorageCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

ExtendedStorageCost(storage_cost_core, regularization_term) = ExtendedStorageCost(; storage_cost_core, regularization_term)

function ExtendedStorageCost(::Nothing)
    ExtendedStorageCost(StorageCost(nothing), 0.0)
end

"""Get [`ExtendedStorageCost`](@ref) `charge_variable_cost`."""
get_charge_variable_cost(value::ExtendedStorageCost) = PSY.get_charge_variable_cost(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `discharge_variable_cost`."""
get_discharge_variable_cost(value::ExtendedStorageCost) = PSY.get_discharge_variable_cost(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `fixed`."""
get_fixed(value::ExtendedStorageCost) = PSY.get_fixed(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `start_up`."""
get_start_up(value::ExtendedStorageCost) = PSY.get_start_up(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `shut_down`."""
get_shut_down(value::ExtendedStorageCost) = PSY.get_shut_down(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `energy_shortage_cost`."""
get_energy_shortage_cost(value::ExtendedStorageCost) = PSY.get_energy_shortage_cost(value.storage_cost_core)
"""Get [`ExtendedStorageCost`](@ref) `energy_surplus_cost`."""
get_energy_surplus_cost(value::ExtendedStorageCost) = PSY.get_energy_surplus_cost(value.storage_cost_core)
get_regularization(value::ExtendedStorageCost) = value.regularization_term
"""Get [`ExtendedStorageCost`](@ref) `cost_core`."""
get_cost_core(value::ExtendedStorageCost) = PSY.value.storage_cost_core



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
