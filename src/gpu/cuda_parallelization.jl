using CUDA
using CUDA.CUSPARSE
using CUDA.CUBLAS
using LinearAlgebra
using SparseArrays

"""
GPU-accelerated PowerLASCOPF solver framework
"""

# GPU memory management for PowerLASCOPF data structures
struct GPUPowerSystemData
    # Generator data (batched)
    n_generators::Int
    generator_cost_coeffs::CuArray{Float32, 2}  # [c2, c1, c0] × n_generators
    generator_limits::CuArray{Float32, 2}       # [Pmin, Pmax] × n_generators
    ramp_limits::CuArray{Float32, 2}            # [up, down] × n_generators
    
    # Transmission line data
    n_lines::Int
    line_admittances::CuArray{Float32, 1}       # 1/reactance for each line
    line_limits::CuArray{Float32, 1}            # thermal limits
    line_from_buses::CuArray{Int32, 1}          # from bus indices
    line_to_buses::CuArray{Int32, 1}            # to bus indices
    
    # Load data
    n_loads::Int
    load_demands::CuArray{Float32, 1}
    load_buses::CuArray{Int32, 1}
    
    # Network topology (sparse on GPU)
    admittance_matrix::CuSparseMatrixCSR{Float32}
    incidence_matrix::CuSparseMatrixCSR{Float32}
    
    # ADMM/APP parameters (broadcasted to all threads)
    rho::Float32
    beta::Float32
    gamma::Float32
    
    function GPUPowerSystemData(generators, lines, loads, nodes)
        # Convert PowerLASCOPF data to GPU arrays
        n_gens = length(generators)
        n_lines = length(lines)
        n_loads = length(loads)
        
        # Extract generator cost coefficients
        cost_coeffs = zeros(Float32, 3, n_gens)
        gen_limits = zeros(Float32, 2, n_gens)
        ramp_lims = zeros(Float32, 2, n_gens)
        
        for (i, gen) in enumerate(generators)
            # Extract cost function coefficients
            if hasfield(typeof(gen.cost_function), :variable_cost)
                cost_coeffs[1, i] = extract_c2(gen.cost_function)  # quadratic
                cost_coeffs[2, i] = extract_c1(gen.cost_function)  # linear
                cost_coeffs[3, i] = extract_c0(gen.cost_function)  # constant
            end
            
            # Extract power limits
            limits = PSY.get_active_power_limits(gen.generator)
            gen_limits[1, i] = limits.min
            gen_limits[2, i] = limits.max
            
            # Extract ramp limits
            ramp = PSY.get_ramp_limits(gen.generator)
            if !isnothing(ramp)
                ramp_lims[1, i] = ramp.up
                ramp_lims[2, i] = ramp.down
            else
                ramp_lims[1, i] = gen_limits[2, i]  # No ramp limit
                ramp_lims[2, i] = gen_limits[2, i]
            end
        end
        
        # Build admittance matrix on GPU
        Y_cpu = build_admittance_matrix_cpu(lines, nodes)
        Y_gpu = CuSparseMatrixCSR(sparse(Y_cpu))
        
        # Build incidence matrix
        A_cpu = build_incidence_matrix_cpu(lines, nodes)
        A_gpu = CuSparseMatrixCSR(sparse(A_cpu))
        
        new(n_gens, CuArray(cost_coeffs), CuArray(gen_limits), CuArray(ramp_lims),
            n_lines, CuArray(extract_line_data(lines)...),
            n_loads, CuArray(extract_load_data(loads)...),
            Y_gpu, A_gpu, 1.0f0, 1.0f0, 1.0f0)
    end
end

"""
GPU kernel for parallel generator subproblem solving
"""
function generator_subproblem_kernel!(
    Pg_new::CuDeviceArray{Float32, 1},
    PgNext_new::CuDeviceArray{Float32, 2},
    theta_new::CuDeviceArray{Float32, 1},
    # Input data
    cost_coeffs::CuDeviceArray{Float32, 2},
    gen_limits::CuDeviceArray{Float32, 2},
    ramp_limits::CuDeviceArray{Float32, 2},
    # ADMM variables
    Pg_prev::CuDeviceArray{Float32, 1},
    PgNext_prev::CuDeviceArray{Float32, 2},
    theta_prev::CuDeviceArray{Float32, 1},
    # Dual variables
    lambda_p::CuDeviceArray{Float32, 1},
    lambda_theta::CuDeviceArray{Float32, 1},
    # APP parameters
    rho::Float32, beta::Float32, gamma::Float32,
    n_contingencies::Int32
)
    # Get thread index (one thread per generator)
    gen_idx = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    
    if gen_idx <= length(Pg_new)
        # Extract generator-specific data
        c2 = cost_coeffs[1, gen_idx]
        c1 = cost_coeffs[2, gen_idx]
        c0 = cost_coeffs[3, gen_idx]
        
        Pmin = gen_limits[1, gen_idx]
        Pmax = gen_limits[2, gen_idx]
        
        ramp_up = ramp_limits[1, gen_idx]
        ramp_down = ramp_limits[2, gen_idx]
        
        # Solve quadratic subproblem analytically
        # minimize: c2*Pg^2 + c1*Pg + (rho/2)*(Pg - target)^2 + other_terms
        
        # For base case power output
        target_p = Pg_prev[gen_idx] - lambda_p[gen_idx] / rho
        
        # Quadratic coefficient: c2 + rho/2
        a = c2 + rho * 0.5f0
        # Linear coefficient: c1 - rho*target_p
        b = c1 - rho * target_p
        
        # Analytical solution: Pg = -b/(2*a)
        Pg_unconstrained = -b / (2.0f0 * a)
        
        # Apply box constraints
        Pg_new[gen_idx] = max(Pmin, min(Pmax, Pg_unconstrained))
        
        # Update angle (simplified - would need more complex coupling)
        theta_target = theta_prev[gen_idx] - lambda_theta[gen_idx] / rho
        theta_new[gen_idx] = theta_target  # Simplified
        
        # Update next period power outputs for each contingency
        for cont in 1:n_contingencies
            PgNext_target = PgNext_prev[cont, gen_idx]
            
            # Apply ramp constraints
            ramp_up_limit = Pg_new[gen_idx] + ramp_up
            ramp_down_limit = Pg_new[gen_idx] - ramp_down
            
            PgNext_constrained = max(ramp_down_limit, min(ramp_up_limit, PgNext_target))
            PgNext_constrained = max(Pmin, min(Pmax, PgNext_constrained))
            
            PgNext_new[cont, gen_idx] = PgNext_constrained
        end
    end
    
    return nothing
end

"""
GPU kernel for parallel transmission line subproblems
"""
function line_subproblem_kernel!(
    Pt_new::CuDeviceArray{Float32, 2},  # [from_flow, to_flow] × n_lines
    # Input data
    line_admittances::CuDeviceArray{Float32, 1},
    line_limits::CuDeviceArray{Float32, 1},
    from_buses::CuDeviceArray{Int32, 1},
    to_buses::CuDeviceArray{Int32, 1},
    # Bus angles
    theta::CuDeviceArray{Float32, 1},
    # ADMM variables
    Pt_prev::CuDeviceArray{Float32, 2},
    # Dual variables
    lambda_flow::CuDeviceArray{Float32, 1},
    # Parameters
    rho::Float32
)
    line_idx = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    
    if line_idx <= length(line_admittances)
        from_bus = from_buses[line_idx]
        to_bus = to_buses[line_idx]
        
        # Calculate power flow from physics
        theta_diff = theta[from_bus] - theta[to_bus]
        susceptance = line_admittances[line_idx]
        
        # Physical power flow
        Pt_physics = susceptance * theta_diff
        
        # ADMM update with flow limits
        flow_limit = line_limits[line_idx]
        
        # Project onto feasible region [-limit, limit]
        Pt_constrained = max(-flow_limit, min(flow_limit, Pt_physics))
        
        Pt_new[1, line_idx] = Pt_constrained      # from end
        Pt_new[2, line_idx] = -Pt_constrained     # to end (conservation)
    end
    
    return nothing
end

"""
GPU kernel for parallel load subproblems (load shedding)
"""
function load_subproblem_kernel!(
    load_served::CuDeviceArray{Float32, 1},
    load_shed::CuDeviceArray{Float32, 1},
    # Input data
    load_demands::CuDeviceArray{Float32, 1},
    load_shed_cost::Float32,
    # ADMM variables
    load_prev::CuDeviceArray{Float32, 1},
    # Dual variables
    lambda_load::CuDeviceArray{Float32, 1},
    # Parameters
    rho::Float32
)
    load_idx = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    
    if load_idx <= length(load_demands)
        demand = load_demands[load_idx]
        
        # Target from ADMM
        target = load_prev[load_idx] - lambda_load[load_idx] / rho
        
        # Economic dispatch: serve load if cost-effective
        if load_shed_cost > rho  # High penalty for shedding
            load_served[load_idx] = min(demand, max(0.0f0, target))
        else
            load_served[load_idx] = max(0.0f0, min(demand, target))
        end
        
        load_shed[load_idx] = demand - load_served[load_idx]
    end
    
    return nothing
end

"""
GPU-accelerated consensus update using cuBLAS
"""
function consensus_update_gpu!(
    Pg_avg::CuArray{Float32, 1},
    theta_avg::CuArray{Float32, 1},
    # Generator outputs from all scenarios
    Pg_base::CuArray{Float32, 1},
    Pg_contingencies::CuArray{Float32, 2},  # n_contingencies × n_generators
    theta_base::CuArray{Float32, 1},
    theta_contingencies::CuArray{Float32, 2},
    # Network matrices
    incidence_matrix::CuSparseMatrixCSR{Float32}
)
    n_scenarios = size(Pg_contingencies, 1) + 1  # +1 for base case
    
    # Average across scenarios using cuBLAS
    CUBLAS.axpy!(length(Pg_base), 1.0f0, Pg_base, 1, Pg_avg, 1)
    
    for scenario in 1:size(Pg_contingencies, 1)
        scenario_data = @view Pg_contingencies[scenario, :]
        CUBLAS.axpy!(length(scenario_data), 1.0f0, scenario_data, 1, Pg_avg, 1)
    end
    
    # Normalize
    CUBLAS.scal!(length(Pg_avg), 1.0f0 / n_scenarios, Pg_avg, 1)
    
    # Similar for angles
    fill!(theta_avg, 0.0f0)
    CUBLAS.axpy!(length(theta_base), 1.0f0, theta_base, 1, theta_avg, 1)
    
    for scenario in 1:size(theta_contingencies, 1)
        scenario_data = @view theta_contingencies[scenario, :]
        CUBLAS.axpy!(length(scenario_data), 1.0f0, scenario_data, 1, theta_avg, 1)
    end
    
    CUBLAS.scal!(length(theta_avg), 1.0f0 / n_scenarios, theta_avg, 1)
end

"""
Main GPU-accelerated ADMM iteration
"""
function gpu_admm_iteration!(
    gpu_data::GPUPowerSystemData,
    # Decision variables (all on GPU)
    Pg_base::CuArray{Float32, 1},
    Pg_contingencies::CuArray{Float32, 2},
    PgNext_base::CuArray{Float32, 2},
    PgNext_contingencies::CuArray{Float32, 3},
    theta_base::CuArray{Float32, 1},
    theta_contingencies::CuArray{Float32, 2},
    Pt_base::CuArray{Float32, 2},
    Pt_contingencies::CuArray{Float32, 3},
    load_served::CuArray{Float32, 1},
    # Dual variables
    lambda_p::CuArray{Float32, 1},
    lambda_theta::CuArray{Float32, 1},
    lambda_flow::CuArray{Float32, 1},
    lambda_load::CuArray{Float32, 1},
    # Consensus variables
    Pg_avg::CuArray{Float32, 1},
    theta_avg::CuArray{Float32, 1}
)
    
    # Calculate optimal block sizes
    n_threads_per_block = 256
    n_gen_blocks = cld(gpu_data.n_generators, n_threads_per_block)
    n_line_blocks = cld(gpu_data.n_lines, n_threads_per_block)
    n_load_blocks = cld(gpu_data.n_loads, n_threads_per_block)
    
    # Solve generator subproblems in parallel
    @cuda threads=n_threads_per_block blocks=n_gen_blocks generator_subproblem_kernel!(
        Pg_base, PgNext_base, theta_base,
        gpu_data.generator_cost_coeffs, gpu_data.generator_limits, gpu_data.ramp_limits,
        Pg_avg, PgNext_base, theta_avg,  # Previous iteration
        lambda_p, lambda_theta,
        gpu_data.rho, gpu_data.beta, gpu_data.gamma,
        Int32(size(Pg_contingencies, 1))
    )
    
    # Solve contingency scenarios
    for cont in 1:size(Pg_contingencies, 1)
        Pg_cont = @view Pg_contingencies[cont, :]
        PgNext_cont = @view PgNext_contingencies[cont, :, :]
        theta_cont = @view theta_contingencies[cont, :]
        
        @cuda threads=n_threads_per_block blocks=n_gen_blocks generator_subproblem_kernel!(
            Pg_cont, PgNext_cont, theta_cont,
            gpu_data.generator_cost_coeffs, gpu_data.generator_limits, gpu_data.ramp_limits,
            Pg_avg, PgNext_cont, theta_avg,
            lambda_p, lambda_theta,
            gpu_data.rho, gpu_data.beta, gpu_data.gamma,
            Int32(size(PgNext_cont, 1))
        )
    end
    
    # Solve transmission line subproblems
    @cuda threads=n_threads_per_block blocks=n_line_blocks line_subproblem_kernel!(
        Pt_base,
        gpu_data.line_admittances, gpu_data.line_limits,
        gpu_data.line_from_buses, gpu_data.line_to_buses,
        theta_base, Pt_base, lambda_flow, gpu_data.rho
    )
    
    # Solve load subproblems
    @cuda threads=n_threads_per_block blocks=n_load_blocks load_subproblem_kernel!(
        load_served, CuArray(zeros(Float32, gpu_data.n_loads)),
        gpu_data.load_demands, 1000.0f0,  # High load shedding cost
        load_served, lambda_load, gpu_data.rho
    )
    
    # Update consensus variables
    consensus_update_gpu!(
        Pg_avg, theta_avg,
        Pg_base, Pg_contingencies,
        theta_base, theta_contingencies,
        gpu_data.incidence_matrix
    )
    
    # Update dual variables (element-wise operations)
    CUBLAS.axpy!(length(lambda_p), gpu_data.rho, Pg_base .- Pg_avg, 1, lambda_p, 1)
    CUBLAS.axpy!(length(lambda_theta), gpu_data.rho, theta_base .- theta_avg, 1, lambda_theta, 1)
    
    # Synchronize GPU
    CUDA.synchronize()
end

"""
High-level GPU-accelerated PowerLASCOPF solver
"""
function solve_powerlascopf_gpu(
    generators::Vector{GeneralizedGenerator},
    lines::Vector{transmissionLine},
    loads::Vector,
    nodes::Vector{Node};
    max_iterations::Int = 100,
    tolerance::Float64 = 1e-4
)
    
    # Initialize GPU data structures
    gpu_data = GPUPowerSystemData(generators, lines, loads, nodes)
    
    # Initialize decision variables on GPU
    Pg_base = CUDA.zeros(Float32, gpu_data.n_generators)
    Pg_contingencies = CUDA.zeros(Float32, 2, gpu_data.n_generators)  # 2 contingencies
    PgNext_base = CUDA.zeros(Float32, 2, gpu_data.n_generators)       # 2 future periods
    PgNext_contingencies = CUDA.zeros(Float32, 2, 2, gpu_data.n_generators)
    
    theta_base = CUDA.zeros(Float32, length(nodes))
    theta_contingencies = CUDA.zeros(Float32, 2, length(nodes))
    
    Pt_base = CUDA.zeros(Float32, 2, gpu_data.n_lines)
    Pt_contingencies = CUDA.zeros(Float32, 2, 2, gpu_data.n_lines)
    
    load_served = CuArray(gpu_data.load_demands)  # Initially serve all load
    
    # Initialize dual variables
    lambda_p = CUDA.zeros(Float32, gpu_data.n_generators)
    lambda_theta = CUDA.zeros(Float32, length(nodes))
    lambda_flow = CUDA.zeros(Float32, gpu_data.n_lines)
    lambda_load = CUDA.zeros(Float32, gpu_data.n_loads)
    
    # Initialize consensus variables
    Pg_avg = CUDA.zeros(Float32, gpu_data.n_generators)
    theta_avg = CUDA.zeros(Float32, length(nodes))
    
    # ADMM iterations
    for iteration in 1:max_iterations
        # Store previous iteration for convergence check
        Pg_prev = copy(Pg_avg)
        theta_prev = copy(theta_avg)
        
        # Perform GPU-accelerated ADMM iteration
        gpu_admm_iteration!(
            gpu_data,
            Pg_base, Pg_contingencies, PgNext_base, PgNext_contingencies,
            theta_base, theta_contingencies, Pt_base, Pt_contingencies,
            load_served, lambda_p, lambda_theta, lambda_flow, lambda_load,
            Pg_avg, theta_avg
        )
        
        # Check convergence
        p_residual = CUBLAS.nrm2(Pg_avg .- Pg_prev)
        theta_residual = CUBLAS.nrm2(theta_avg .- theta_prev)
        
        if p_residual < tolerance && theta_residual < tolerance
            println("GPU ADMM converged in $iteration iterations")
            break
        end
        
        if iteration % 10 == 0
            println("Iteration $iteration: P residual = $p_residual, θ residual = $theta_residual")
        end
    end
    
    # Transfer results back to CPU
    results = Dict(
        "Pg_base" => Array(Pg_base),
        "Pg_contingencies" => Array(Pg_contingencies),
        "theta_base" => Array(theta_base),
        "theta_contingencies" => Array(theta_contingencies),
        "Pt_base" => Array(Pt_base),
        "load_served" => Array(load_served)
    )
    
    return results
end

"""
Integration with existing PowerLASCOPF POMDP framework
"""
function solve_pomdp_action_gpu(
    pomdp::PowerLASCOPFPOMDP,
    belief::PowerSystemBelief
)
    # Extract most likely system state from belief
    state_estimate = extract_state_estimate(belief)
    
    # Solve using GPU-accelerated ADMM
    gpu_results = solve_powerlascopf_gpu(
        pomdp.generators,
        pomdp.transmission_lines,
        pomdp.loads,
        pomdp.nodes
    )
    
    # Convert GPU results to PowerSystemAction
    return PowerSystemAction(
        gpu_results["Pg_base"],           # generator setpoints
        state_estimate.line_status,       # line switching (from belief)
        zeros(length(pomdp.loads)),       # load shedding
        zeros(length(pomdp.generators))   # reserves
    )
end

# Pre-allocate GPU memory pools
struct GPUMemoryPool
    generator_workspace::CuArray{Float32, 2}
    line_workspace::CuArray{Float32, 2}
    consensus_workspace::CuArray{Float32, 1}
    temp_arrays::Vector{CuArray{Float32, 1}}
end

function allocate_gpu_memory_pool(n_generators, n_lines, n_nodes, n_contingencies)
    GPUMemoryPool(
        CUDA.zeros(Float32, n_generators, n_contingencies + 1),
        CUDA.zeros(Float32, n_lines, n_contingencies + 1),
        CUDA.zeros(Float32, n_nodes),
        [CUDA.zeros(Float32, max(n_generators, n_lines, n_nodes)) for _ in 1:4]
    )
end

# Leverage CUSPARSE for network operations
function gpu_power_flow_update!(
    theta::CuArray{Float32, 1},
    Pg::CuArray{Float32, 1},
    Pd::CuArray{Float32, 1},
    Y_gpu::CuSparseMatrixCSR{Float32},
    workspace::CuArray{Float32, 1}
)
    # P_net = Pg - Pd
    CUBLAS.copy!(length(Pg), Pg, 1, workspace, 1)
    CUBLAS.axpy!(length(Pd), -1.0f0, Pd, 1, workspace, 1)
    
    # Solve Y * theta = P_net (simplified)
    # In practice, would use iterative solver like CG
    CUSPARSE.mv!('N', 1.0f0, Y_gpu, workspace, 0.0f0, theta)
end