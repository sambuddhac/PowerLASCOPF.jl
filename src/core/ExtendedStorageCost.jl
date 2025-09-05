"""
	@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    		storage_cost_core::PSY.StorageManagementCost # Core storage cost
    		regularization_term::Union{T, Float64} # Regularization Term
	end
	This is the struct for implmenting extended storage cost model with additional regularization term. This is needed for solving (N-1-1)
	contingency cases in the extended storage cost model.
        - storage_cost_core::PSY.StorageManagementCost # Coefficient of the quadratic term
        - regularization_term::Union{T, Float64} # Regularization Term
"""

@kwdef mutable struct ExtendedStorageCost{T<:GenIntervals}<:AbstractModel
    storage_cost_core::PSY.StorageManagementCost # Core storage cost
    regularization_term::Union{T, Float64} # Regularization Term
    charge_cost::Float64 = 0.0 # Cost of charging storage
    discharge_cost::Float64 = 0.0 # Cost of discharging storage
end

# Constructors
ExtendedStorageCost(storage_cost_core, regularization_term) = ExtendedStorageCost(; storage_cost_core, regularization_term)
# FIX IS HERE: Make this constructor parametric.
# It now explicitly states that it's a constructor for ExtendedStorageCost{T}
# where T is any subtype of GenIntervals.
function ExtendedStorageCost{T}(::Nothing) where {T<:GenIntervals}
    ExtendedStorageCost{T}(; storage_cost_core=PSY.StorageManagementCost(), regularization_term=0.0)
end

# Getter functions
get_variable(value::ExtendedStorageCost) = PSY.get_variable(value.storage_cost_core)
get_fixed(value::ExtendedStorageCost) = PSY.get_fixed(value.storage_cost_core)
get_start_up(value::ExtendedStorageCost) = PSY.get_start_up(value.storage_cost_core)
get_shut_down(value::ExtendedStorageCost) = PSY.get_shut_down(value.storage_cost_core)
get_energy_shortage_cost(value::ExtendedStorageCost) = PSY.get_energy_shortage_cost(value.storage_cost_core)
get_energy_surplus_cost(value::ExtendedStorageCost) = PSY.get_energy_surplus_cost(value.storage_cost_core)
get_charge_cost(value::ExtendedStorageCost) = value.charge_cost
get_discharge_cost(value::ExtendedStorageCost) = value.discharge_cost
get_regularization_term(value::ExtendedStorageCost) = value.regularization_term
get_cost_core(value::ExtendedStorageCost) = value.storage_cost_core

# Setter functions
set_variable!(value::ExtendedStorageCost, val) = value.storage_cost_core.variable = val
set_fixed!(value::ExtendedStorageCost, val) = value.storage_cost_core.fixed = val
set_charge_cost!(value::ExtendedStorageCost, val) = value.charge_cost = val
set_discharge_cost!(value::ExtendedStorageCost, val) = value.discharge_cost = val
set_regularization_term!(value::ExtendedStorageCost, val) = value.regularization_term = val
set_cost_core(value::ExtendedStorageCost, cost_core) = value.storage_cost_core = cost_core

"""
    compute_regularization_cost(cost::ExtendedStorageCost{T}, Pg, args...) where {T<:GenIntervals}

Compute the regularization cost term for storage devices based on the interval type.
"""
function compute_regularization_cost(cost::ExtendedStorageCost{T}, Pg, args...) where {T<:GenIntervals}
    if isa(cost.regularization_term, Float64)
        return cost.regularization_term * Pg^2
    else
        return regularization_term(cost.regularization_term, Pg, args...)
    end
end

"""
    build_storage_cost_expression(cost::ExtendedStorageCost, Pcharge, Pdischarge, energy_level, commitment_var, args...)

Build the complete storage cost expression including charge/discharge costs, energy management, and regularization.
"""
function build_storage_cost_expression(cost::ExtendedStorageCost, Pcharge, Pdischarge, energy_level, commitment_var, args...)
    # Variable cost for operation
    variable_cost = PSY.get_variable(cost.storage_cost_core) * (Pcharge + Pdischarge)
    
    # Fixed cost when committed
    fixed_cost = PSY.get_fixed(cost.storage_cost_core) * commitment_var
    
    # Charge and discharge costs
    charge_cost = cost.charge_cost * Pcharge
    discharge_cost = cost.discharge_cost * Pdischarge
    
    # Energy shortage/surplus costs
    # These would typically be computed based on energy targets
    # energy_shortage_cost = PSY.get_energy_shortage_cost(cost.storage_cost_core) * shortage_var
    # energy_surplus_cost = PSY.get_energy_surplus_cost(cost.storage_cost_core) * surplus_var
    
    # Net power for regularization (discharge - charge)
    net_power = Pdischarge - Pcharge
    regularization_cost = compute_regularization_cost(cost, net_power, args...)
    
    return variable_cost + fixed_cost + charge_cost + discharge_cost + regularization_cost
end

# Common utility functions
update_regularization_parameters!(cost::ExtendedStorageCost{T}, new_params::Dict) where {T<:GenIntervals} = 
    update_regularization_parameters_generic!(cost, new_params, T)

set_regularization_interval!(cost::ExtendedStorageCost, interval::T) where {T<:GenIntervals} = 
    (cost.regularization_term = interval)

get_regularization_type(cost::ExtendedStorageCost{T}) where {T<:GenIntervals} = T

is_regularization_active(cost::ExtendedStorageCost) = !isa(cost.regularization_term, Float64)
