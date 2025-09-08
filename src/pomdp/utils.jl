using PowerSystems
using LinearAlgebra

"""
Utility functions for PowerLASCOPF POMDP integration
"""

"""
Solve power flow for given system state
"""
function solve_power_flow(pomdp::PowerLASCOPFPOMDP, line_status::Vector{Bool}, 
                         load_demands::Vector{Float64}, gen_setpoints::Vector{Float64})
    
    n_nodes = length(pomdp.nodes)
    n_gens = length(pomdp.generators)
    
    # Simplified DC power flow
    # Build admittance matrix considering line status
    Y = build_admittance_matrix(pomdp, line_status)
    
    # Power injections
    P_inj = zeros(n_nodes)
    
    # Add generation
    for (i, gen) in enumerate(pomdp.generators)
        node_idx = gen.nodeConng.node_id
        if i <= length(gen_setpoints)
            P_inj[node_idx] += gen_setpoints[i]
        end
    end
    
    # Subtract loads
    for (i, load) in enumerate(pomdp.loads)
        node_idx = PSY.get_number(PSY.get_bus(load))
        if i <= length(load_demands)
            P_inj[node_idx] -= load_demands[i]
        end
    end
    
    # Solve for angles (reference bus at node 1)
    Y_reduced = Y[2:end, 2:end]
    P_reduced = P_inj[2:end]
    
    if det(Y_reduced) != 0
        theta_reduced = Y_reduced \ P_reduced
        theta = vcat([0.0], theta_reduced)
    else
        theta = zeros(n_nodes)
    end
    
    # Assume flat voltage profile
    voltages = ones(n_nodes)
    
    return gen_setpoints, voltages, theta
end

"""
Build admittance matrix considering line outages
"""
function build_admittance_matrix(pomdp::PowerLASCOPFPOMDP, line_status::Vector{Bool})
    n_nodes = length(pomdp.nodes)
    Y = zeros(n_nodes, n_nodes)
    
    for (i, line) in enumerate(pomdp.transmission_lines)
        if i <= length(line_status) && line_status[i]
            # Line is operational
            from_idx = line.conn_nodet1_ptr.node_id
            to_idx = line.conn_nodet2_ptr.node_id
            
            # Get line reactance
            if isa(line.transl_type, PSY.Line)
                x = PSY.get_x(line.transl_type)
            elseif isa(line.transl_type, PSY.HVDCLine)
                x = 0.01  # Simplified for HVDC
            else
                x = 0.01  # Default
            end
            
            # Add to admittance matrix
            y = 1.0 / x
            Y[from_idx, from_idx] += y
            Y[to_idx, to_idx] += y
            Y[from_idx, to_idx] -= y
            Y[to_idx, from_idx] -= y
        end
    end
    
    return Y
end

"""
Calculate line flows from node angles
"""
function calculate_line_flows(pomdp::PowerLASCOPFPOMDP, state::PowerSystemState)
    flows = Float64[]
    
    for (i, line) in enumerate(pomdp.transmission_lines)
        if i <= length(state.line_status) && state.line_status[i]
            from_idx = line.conn_nodet1_ptr.node_id
            to_idx = line.conn_nodet2_ptr.node_id
            
            if from_idx <= length(state.node_angles) && to_idx <= length(state.node_angles)
                theta_diff = state.node_angles[from_idx] - state.node_angles[to_idx]
                
                # Get line reactance
                if isa(line.transl_type, PSY.Line)
                    x = PSY.get_x(line.transl_type)
                else
                    x = 0.01
                end
                
                flow = theta_diff / x
                push!(flows, flow)
            else
                push!(flows, 0.0)
            end
        else
            push!(flows, 0.0)
        end
    end
    
    return flows
end

"""
Calculate generation cost for current dispatch
"""
function calculate_generation_cost(pomdp::PowerLASCOPFPOMDP, setpoints::Vector{Float64})
    total_cost = 0.0
    
    for (i, gen) in enumerate(pomdp.generators)
        if i <= length(setpoints)
            # Extract cost function from generator
            if hasfield(typeof(gen.cost_function), :variable_cost)
                if isa(gen.cost_function.variable_cost, Number)
                    total_cost += gen.cost_function.variable_cost * setpoints[i]
                elseif isa(gen.cost_function.variable_cost, PSY.VariableCost)
                    # Handle PSY VariableCost
                    cost_data = PSY.get_cost(gen.cost_function.variable_cost)
                    if isa(cost_data, Vector)
                        # Piecewise linear cost
                        total_cost += evaluate_pwl_cost(cost_data, setpoints[i])
                    else
                        # Constant cost
                        total_cost += cost_data * setpoints[i]
                    end
                end
            end
        end
    end
    
    return total_cost
end

"""
Evaluate piecewise linear cost function
"""
function evaluate_pwl_cost(cost_points::Vector, power::Float64)
    if length(cost_points) < 2
        return 0.0
    end
    
    # Assume cost_points are (power, cost) tuples
    for i in 1:(length(cost_points)-1)
        p1, c1 = cost_points[i]
        p2, c2 = cost_points[i+1]
        
        if p1 <= power <= p2
            # Linear interpolation
            slope = (c2 - c1) / (p2 - p1)
            return c1 + slope * (power - p1)
        end
    end
    
    # Extrapolate if outside range
    if power < cost_points[1][1]
        return cost_points[1][2]
    else
        return cost_points[end][2]
    end
end

"""
Calculate line flow constraint violations
"""
function calculate_flow_violations(pomdp::PowerLASCOPFPOMDP, state::PowerSystemState)
    flows = calculate_line_flows(pomdp, state)
    violations = 0.0
    
    for (i, line) in enumerate(pomdp.transmission_lines)
        if i <= length(flows) && i <= length(state.line_status) && state.line_status[i]
            capacity = get_line_capacity(line)
            flow_magnitude = abs(flows[i])
            
            if flow_magnitude > capacity
                violations += (flow_magnitude - capacity)^2
            end
        end
    end
    
    return violations
end

"""
Get line capacity from PowerSystems line object
"""
function get_line_capacity(line::transmissionLine)
    if isa(line.transl_type, PSY.Line)
        return PSY.get_rating(line.transl_type)
    elseif isa(line.transl_type, PSY.HVDCLine)
        # For HVDC, use active power limits
        limits = PSY.get_active_power_limits_from(line.transl_type)
        return limits.max
    else
        return 1.0  # Default capacity
    end
end

"""
Update parameter beliefs based on new observations
"""
function update_parameter_beliefs(current_beliefs::Dict{String, Distribution}, 
                                load_observations::Vector{Float64},
                                renewable_observations::Vector{Float64})
    
    new_beliefs = copy(current_beliefs)
    
    # Update load forecast error distribution
    if haskey(current_beliefs, "load_forecast_error")
        # Simple Bayesian update (simplified)
        current_dist = current_beliefs["load_forecast_error"]
        # In practice, this would be more sophisticated
        new_beliefs["load_forecast_error"] = Normal(mean(current_dist), std(current_dist) * 0.99)
    end
    
    # Update renewable forecast error distribution
    if haskey(current_beliefs, "renewable_forecast_error")
        current_dist = current_beliefs["renewable_forecast_error"]
        new_beliefs["renewable_forecast_error"] = Normal(mean(current_dist), std(current_dist) * 0.99)
    end
    
    return new_beliefs
end

"""
Create POMDP from existing PowerLASCOPF system data
"""
function create_pomdp_from_system_data(system_data::Dict)
    return PowerLASCOPFPOMDP(
        system_data["nodes"],
        system_data["branches"],
        vcat(system_data["thermal_generators"], 
             system_data["renewable_generators"],
             system_data["hydro_generators"]),
        system_data["loads"]
    )
end
