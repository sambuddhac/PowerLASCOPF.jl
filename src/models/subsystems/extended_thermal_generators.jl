# APP-ADMM Power Angle Message Passing for Extended Thermal Generators
# This implements the power angle message passing for the Alternating Direction Method of Multipliers (ADMM)
# specifically for thermal generators in the Accelerated Proximal Point (APP) variant

using LinearAlgebra
using JuMP

"""
Power angle message passing for Extended Thermal Generators in APP-ADMM
This function computes the optimal power output and voltage angle for a thermal generator
given the current dual variables and penalty parameters in the ADMM algorithm.

Arguments:
- thermal: ExtendedThermalGenerator object
- voltage_angle: Current voltage angle at the generator bus (radians)
- lambda: Lagrange multiplier for power balance constraint
- rho: Penalty parameter for ADMM
- neighbors: Vector of neighboring generators/buses
- iteration: Current ADMM iteration number

Returns:
- Tuple (power, angle) with optimal power output and updated voltage angle
"""
function gpoweranglemessage(thermal::ExtendedThermalGenerator, 
                          voltage_angle::Float64,
                          lambda::Float64, 
                          rho::Float64;
                          neighbors::Vector{Float64} = Float64[],
                          iteration::Int = 1,
                          temperature::Float64 = 25.0)
    
    # Extract generator parameters
    min_power = get_active_power_limits(thermal).min
    max_power = get_active_power_limits(thermal).max
    
    # Current operating point
    current_power = thermal.active_power
    current_fuel_cost = thermal.fuel_cost
    
    # Temperature derating factor
    temp_derate = calculate_temperature_derating(thermal, temperature)
    effective_max_power = max_power * temp_derate
    
    # Ramp rate constraints
    ramp_up = thermal.ramp_up_rate
    ramp_down = thermal.ramp_down_rate
    
    # Calculate marginal cost at current operating point
    marginal_cost = calculate_marginal_cost(thermal, current_power)
    
    # Heat rate curve evaluation
    heat_rate = evaluate_heat_rate(thermal, current_power)
    
    # Start-up cost consideration
    startup_cost_factor = thermal.is_on ? 0.0 : thermal.startup_cost / max_power
    
    # Emissions cost
    emissions_cost = calculate_emissions_cost(thermal, current_power)
    
    # Total incremental cost
    total_incremental_cost = marginal_cost + startup_cost_factor + emissions_cost
    
    # ADMM optimization step
    # Minimize: (λ - c(p))p + (ρ/2)(p - p_avg)² + startup costs + emissions costs
    # where p_avg is the average power from neighbors
    
    p_avg = length(neighbors) > 0 ? mean(neighbors) : current_power
    
    # Quadratic approximation of cost function around current point
    # Cost function: C(p) = a*p² + b*p + c
    # Marginal cost: C'(p) = 2*a*p + b
    
    # Estimate quadratic coefficients from heat rate curve
    if current_power > min_power + 1.0  # Avoid division by zero
        # Numerical differentiation for second derivative
        delta_p = min(1.0, (max_power - min_power) * 0.01)
        p_test = min(effective_max_power, current_power + delta_p)
        
        mc_high = calculate_marginal_cost(thermal, p_test)
        mc_low = calculate_marginal_cost(thermal, max(min_power, current_power - delta_p))
        
        # Second derivative approximation
        second_derivative = (mc_high - mc_low) / (2 * delta_p)
        second_derivative = max(0.001, second_derivative)  # Ensure positive definiteness
        
        # Quadratic coefficient
        a_quad = second_derivative / 2
        b_quad = marginal_cost - 2 * a_quad * current_power
    else
        # Use default quadratic approximation for small power levels
        a_quad = 0.01
        b_quad = marginal_cost
    end
    
    # ADMM subproblem solution
    # Minimize: (λ - b_quad)p - a_quad*p² + (ρ/2)(p - p_avg)² + startup_costs
    # Taking derivative and setting to zero:
    # λ - b_quad - 2*a_quad*p + ρ(p - p_avg) = 0
    # Solving for p: p = (λ - b_quad + ρ*p_avg) / (2*a_quad + ρ)
    
    denominator = 2 * a_quad + rho
    numerator = lambda - b_quad + rho * p_avg
    
    # Unconstrained optimal power
    p_optimal = numerator / denominator
    
    # Apply operational constraints
    # Ramp rate constraints
    p_min_ramp = current_power - ramp_down
    p_max_ramp = current_power + ramp_up
    
    # Combine all constraints
    p_min_total = max(min_power, p_min_ramp)
    p_max_total = min(effective_max_power, p_max_ramp)
    
    # Unit commitment constraints
    if !thermal.is_on
        # If unit is off, check if it should start up
        startup_benefit = lambda - total_incremental_cost
        if startup_benefit * max_power > thermal.startup_cost
            # Beneficial to start up
            p_min_total = max(p_min_total, thermal.min_stable_power)
            thermal.is_on = true
            thermal.startup_time = 0.0
        else
            # Keep unit off
            p_optimal = 0.0
            p_min_total = 0.0
            p_max_total = 0.0
        end
    else
        # Unit is on, check if it should shut down
        shutdown_benefit = total_incremental_cost - lambda
        if shutdown_benefit * current_power > thermal.shutdown_cost
            # Beneficial to shut down
            p_optimal = 0.0
            thermal.is_on = false
        else
            # Keep unit on with minimum stable power
            p_min_total = max(p_min_total, thermal.min_stable_power)
        end
    end
    
    # Project onto feasible region
    p_final = max(p_min_total, min(p_max_total, p_optimal))
    
    # Update voltage angle based on power dispatch
    # Simplified relationship: δ = δ₀ + K*(P - P₀)
    # where K is the sensitivity coefficient
    
    # Voltage angle sensitivity (simplified)
    angle_sensitivity = 0.001  # radians per MW (typical value)
    power_change = p_final - current_power
    
    # Consider system impedance and network effects
    if length(neighbors) > 0
        # Network effect: angle depends on power flow to neighbors
        neighbor_avg = mean(neighbors)
        network_effect = (p_final - neighbor_avg) * angle_sensitivity * 0.5
    else
        network_effect = 0.0
    end
    
    # Updated voltage angle
    new_angle = voltage_angle + power_change * angle_sensitivity + network_effect
    
    # Angle limits (typical power system limits)
    angle_limit = π/6  # 30 degrees
    new_angle = max(-angle_limit, min(angle_limit, new_angle))
    
    # Update generator state
    thermal.active_power = p_final
    
    # Return optimal power and angle
    return (power = p_final, angle = new_angle)
end

"""
Dual variable update for thermal generator in APP-ADMM
"""
function update_thermal_duals!(thermal::ExtendedThermalGenerator, 
                              power_mismatch::Float64,
                              rho::Float64, 
                              lambda::Vector{Float64}, 
                              t::Int)
    # Standard ADMM dual update
    lambda[t] += rho * power_mismatch
    
    # Adaptive penalty parameter adjustment
    if abs(power_mismatch) > 0.1
        # Large mismatch - increase penalty
        rho *= 1.1
    elseif abs(power_mismatch) < 0.01
        # Small mismatch - decrease penalty
        rho *= 0.95
    end
    
    # Bounds on penalty parameter
    rho = max(0.1, min(1000.0, rho))
    
    # Store updated values
    thermal.ext["lambda"] = lambda[t]
    thermal.ext["rho"] = rho
    
    return lambda, rho
end

"""
Consensus step for thermal generator in APP-ADMM
"""
function thermal_consensus_step!(thermal::ExtendedThermalGenerator,
                                neighbor_powers::Vector{Float64},
                                rho::Float64,
                                alpha::Float64 = 1.0)
    # Accelerated consensus update (APP-ADMM)
    current_power = thermal.active_power
    
    # Compute consensus power
    if length(neighbor_powers) > 0
        neighbor_avg = mean(neighbor_powers)
        
        # Weighted average based on generator capacity
        weight = thermal.rating / (thermal.rating + 100.0)  # Normalize by 100 MW
        consensus_power = alpha * neighbor_avg + (1 - alpha) * current_power
        
        # Apply constraints
        min_power = get_active_power_limits(thermal).min
        max_power = get_active_power_limits(thermal).max
        
        if thermal.is_on
            min_power = max(min_power, thermal.min_stable_power)
        else
            min_power = 0.0
            max_power = 0.0
        end
        
        consensus_power = max(min_power, min(max_power, consensus_power))
    else
        consensus_power = current_power
    end
    
    return consensus_power
end

"""
Calculate marginal cost for thermal generator
Uses piecewise linear approximation of heat rate curve
"""
function calculate_marginal_cost(thermal::ExtendedThermalGenerator, power::Float64)
    # Get heat rate at current power level
    heat_rate = evaluate_heat_rate(thermal, power)
    
    # Fuel cost ($/MMBtu) * Heat rate (MMBtu/MWh) = $/MWh
    fuel_cost_per_mwh = thermal.fuel_cost * heat_rate
    
    # Variable O&M cost ($/MWh)
    vom_cost = get(thermal.ext, "variable_om_cost", 5.0)  # Default 5 $/MWh
    
    # Marginal cost = fuel cost + variable O&M
    marginal_cost = fuel_cost_per_mwh + vom_cost
    
    # Add penalty for operating near limits (helps with numerical stability)
    min_power = get_active_power_limits(thermal).min
    max_power = get_active_power_limits(thermal).max
    
    if power > 0.95 * max_power
        # High penalty near maximum power
        penalty = 1000.0 * (power - 0.95 * max_power) / (0.05 * max_power)
        marginal_cost += penalty
    elseif power < 1.05 * min_power && power > min_power
        # Penalty near minimum power (avoid shutdown)
        penalty = 500.0 * (1.05 * min_power - power) / (0.05 * min_power)
        marginal_cost += penalty
    end
    
    return marginal_cost
end

"""
Evaluate heat rate curve for thermal generator
Typically a quadratic function: HR(P) = a + b*P + c*P²
"""
function evaluate_heat_rate(thermal::ExtendedThermalGenerator, power::Float64)
    # Get heat rate curve coefficients
    # Format: [a, b, c] for quadratic HR(P) = a + b*P + c*P²
    heat_rate_coeffs = get(thermal.ext, "heat_rate_coeffs", [9.5, 0.0, 0.0001])
    
    if length(heat_rate_coeffs) >= 3
        # Quadratic heat rate curve
        a, b, c = heat_rate_coeffs[1], heat_rate_coeffs[2], heat_rate_coeffs[3]
        heat_rate = a + b * power + c * power^2
    elseif length(heat_rate_coeffs) == 2
        # Linear heat rate curve
        a, b = heat_rate_coeffs[1], heat_rate_coeffs[2]
        heat_rate = a + b * power
    else
        # Constant heat rate
        heat_rate = heat_rate_coeffs[1]
    end
    
    # Typical heat rate bounds for thermal units (MMBtu/MWh)
    heat_rate = max(7.0, min(15.0, heat_rate))
    
    return heat_rate
end

"""
Calculate temperature derating factor for thermal generator
Account for reduced capacity at high ambient temperatures
"""
function calculate_temperature_derating(thermal::ExtendedThermalGenerator, temperature::Float64)
    # Reference temperature (°C) - typically 15°C for ISO conditions
    reference_temp = get(thermal.ext, "reference_temperature", 15.0)
    
    # Temperature derating coefficient (%/°C) - typically 0.5-1.0% per °C
    temp_coeff = get(thermal.ext, "temperature_coefficient", 0.007)
    
    # Calculate derating factor
    temp_difference = temperature - reference_temp
    derating_factor = 1.0 - temp_coeff * temp_difference
    
    # Bound the derating factor between 0.7 and 1.05
    derating_factor = max(0.7, min(1.05, derating_factor))
    
    return derating_factor
end

"""
Calculate emissions cost for thermal generator
Includes CO2, NOx, and SO2 emissions
"""
function calculate_emissions_cost(thermal::ExtendedThermalGenerator, power::Float64)
    # Get emissions rates (tons/MWh) and costs ($/ton)
    co2_rate = get(thermal.ext, "co2_emission_rate", 0.85)      # tons CO2/MWh
    nox_rate = get(thermal.ext, "nox_emission_rate", 0.002)     # tons NOx/MWh  
    so2_rate = get(thermal.ext, "so2_emission_rate", 0.005)     # tons SO2/MWh
    
    co2_cost = get(thermal.ext, "co2_cost", 25.0)              # $/ton CO2
    nox_cost = get(thermal.ext, "nox_cost", 5000.0)            # $/ton NOx
    so2_cost = get(thermal.ext, "so2_cost", 1000.0)            # $/ton SO2
    
    # Total emissions cost ($/MWh)
    emissions_cost = co2_rate * co2_cost + nox_rate * nox_cost + so2_rate * so2_cost
    
    return emissions_cost
end

"""
Get active power limits for thermal generator
"""
function get_active_power_limits(thermal::ExtendedThermalGenerator)
    # Return named tuple with min and max power limits
    return (min = thermal.active_power_limits.min, max = thermal.active_power_limits.max)
end