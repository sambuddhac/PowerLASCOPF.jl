"""
ADMM/APP Solver for PowerLASCOPF

This module implements the Alternating Direction Method of Multipliers (ADMM)
with Analytical Prior Predictor (APP) for solving LASCOPF problems.
"""

using JuMP
using Ipopt
using LinearAlgebra
using Printf

"""
    LASCOPFSolver

Main solver struct for PowerLASCOPF optimization
"""
mutable struct LASCOPFSolver
    system_data::Dict
    parameters::Dict
    convergence_history::Vector{Dict}
    current_iteration::Int
    
    function LASCOPFSolver(system_data::Dict, parameters::Dict)
        solver = new()
        solver.system_data = system_data
        solver.parameters = parameters
        solver.convergence_history = Dict[]
        solver.current_iteration = 0
        return solver
    end
end

"""
    solve_lascopf!(solver::LASCOPFSolver)

Main LASCOPF solution function using ADMM/APP algorithm
"""
function solve_lascopf!(solver::LASCOPFSolver)
    println("Starting ADMM/APP algorithm...")
    
    start_time = time()
    max_iter = solver.parameters["max_iterations"]
    tolerance = solver.parameters["tolerance"]
    
    # Initialize ADMM variables
    initialize_admm_variables!(solver)
    
    # Main ADMM loop
    for iter in 1:max_iter
        solver.current_iteration = iter
        
        println("Iteration $iter:")
        
        # Step 1: Solve generator subproblems
        solve_generator_subproblems!(solver)
        
        # Step 2: Solve transmission line subproblems
        solve_transmission_subproblems!(solver)
        
        # Step 3: Update node variables (dual averaging)
        update_node_variables!(solver)
        
        # Step 4: Update dual variables
        update_dual_variables!(solver)
        
        # Step 5: Check convergence
        residuals = calculate_residuals(solver)
        push!(solver.convergence_history, residuals)
        
        println("  - Primal residual: $(round(residuals["primal_residual"], digits=6))")
        println("  - Dual residual: $(round(residuals["dual_residual"], digits=6))")
        
        if residuals["primal_residual"] < tolerance && residuals["dual_residual"] < tolerance
            println("✓ Converged in $iter iterations!")
            break
        end
        
        if iter == max_iter
            @warn "Maximum iterations reached without convergence"
        end
    end
    
    solve_time = time() - start_time
    
    # Compile results
    results = compile_results(solver, solve_time)
    
    return results
end

"""
    initialize_admm_variables!(solver::LASCOPFSolver)

Initialize all ADMM variables for generators, lines, and nodes
"""
function initialize_admm_variables!(solver::LASCOPFSolver)
    println("  Initializing ADMM variables...")
    
    # Initialize generator variables
    for gen in [solver.system_data["thermal_generators"];
                solver.system_data["renewable_generators"];
                solver.system_data["hydro_generators"];
                solver.system_data["storage_generators"]]
        set_gen_data!(gen)
    end
    
    # Initialize transmission line variables
    for line in solver.system_data["branches"]
        set_tran_data(line)
    end
    
    # Initialize node variables
    for node in solver.system_data["nodes"]
        # Node initialization is handled in constructor
    end
    
    println("  ✓ ADMM variables initialized")
end

"""
    solve_generator_subproblems!(solver::LASCOPFSolver)

Solve all generator optimization subproblems
"""
function solve_generator_subproblems!(solver::LASCOPFSolver)
    println("    Solving generator subproblems...")
    
    rho = solver.parameters["rho"]
    
    # Solve all generator technologies
    for gen in [solver.system_data["thermal_generators"];
                solver.system_data["renewable_generators"];
                solver.system_data["hydro_generators"];
                solver.system_data["storage_generators"]]
        solve_generator_subproblem!(gen, rho, solver.current_iteration)
    end
    
    println("    ✓ Generator subproblems solved")
end

"""
    solve_generator_subproblem!(gen::GeneralizedGenerator, rho::Float64, iteration::Int)

Solve individual generator optimization subproblem
"""
function solve_generator_subproblem!(gen::GeneralizedGenerator, rho::Float64, iteration::Int)
    # Get node information
    node = gen.conn_nodeg_ptr
    
    # Get average values from node
    P_avg = p_avg_message(node)
    theta_avg = theta_avg_message(node)
    v_avg = v_avg_message(node)
    u = u_message!(node)
    
    # Prepare APP parameters - simplified for demonstration
    outerAPPIt = iteration
    APPItCount = 10
    gsRho = rho
    Pgenavg = P_avg !== nothing ? P_avg : 0.0
    Powerprice = u !== nothing ? u : 0.0
    Angpriceavg = v_avg !== nothing ? v_avg : 0.0
    Angavg = theta_avg !== nothing ? theta_avg : 0.0
    Angprice = 0.0
    P_gen_prevAPP = gen.P_gen_prev
    PgenAPP = gen.Pg
    PgenAPPInner = gen.Pg
    P_gen_nextAPP = [gen.P_gen_next]
    
    # External APP parameters (simplified)
    AAPPExternal = 0.0
    BAPPExternal = zeros(2)
    DAPPExternal = zeros(2)
    LambAPP1External = zeros(2)
    LambAPP2External = zeros(2)
    LambAPP3External = 0.0
    LambAPP4External = 0.0
    BAPP = zeros(2)
    LambAPP1 = zeros(2)
    
    # Call generator power angle message (this handles the optimization)
    gpower_angle_message!(
        gen, outerAPPIt, APPItCount, gsRho, Pgenavg, Powerprice,
        Angpriceavg, Angavg, Angprice, P_gen_prevAPP, PgenAPP,
        PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal,
        DAPPExternal, LambAPP1External, LambAPP2External,
        LambAPP3External, LambAPP4External, BAPP, LambAPP1
    )
end

"""
    solve_thermal_generator_subproblem!(gen::GeneralizedGenerator; optimizer_factory, solve_options, time_horizon, include_unit_commitment)

Overload of `solve_thermal_generator_subproblem!` for `GeneralizedGenerator` in the APP
distributed context. Unpacks `gen.gen_solver` and `gen.generator` and routes through the
`(GenSolver, PSY.StaticInjection)` dispatch overload defined in ExtendedThermalGenerator.jl,
which calls `build_and_solve_gensolver_for_gen!` in gensolver_first_base.jl.
"""
function solve_thermal_generator_subproblem!(gen::GeneralizedGenerator;
                                             optimizer_factory=nothing,
                                             solve_options=Dict(),
                                             time_horizon=24,
                                             include_unit_commitment=false)
    return solve_thermal_generator_subproblem!(gen.gen_solver, gen.generator;
                                               optimizer_factory=optimizer_factory,
                                               solve_options=solve_options,
                                               time_horizon=time_horizon,
                                               include_unit_commitment=include_unit_commitment)
end

"""
    solve_renewable_generator_subproblem!(gen::GeneralizedGenerator; ...)

Overload of `solve_renewable_generator_subproblem!` for `GeneralizedGenerator`. Routes
through the `(GenSolver, PSY.RenewableGen)` dispatch overload in ExtendedRenewableGenerator.jl.
"""
function solve_renewable_generator_subproblem!(gen::GeneralizedGenerator;
                                               optimizer_factory=nothing,
                                               solve_options=Dict(),
                                               time_horizon=24,
                                               include_unit_commitment=false)
    return solve_renewable_generator_subproblem!(gen.gen_solver, gen.generator;
                                                 optimizer_factory=optimizer_factory,
                                                 solve_options=solve_options,
                                                 time_horizon=time_horizon,
                                                 include_unit_commitment=include_unit_commitment)
end

"""
    solve_hydro_generator_subproblem!(gen::GeneralizedGenerator; ...)

Overload of `solve_hydro_generator_subproblem!` for `GeneralizedGenerator`. Routes
through the `(GenSolver, PSY.HydroGen)` dispatch overload in ExtendedHydroGenerator.jl.
"""
function solve_hydro_generator_subproblem!(gen::GeneralizedGenerator;
                                           optimizer_factory=nothing,
                                           solve_options=Dict(),
                                           time_horizon=24,
                                           include_unit_commitment=false)
    return solve_hydro_generator_subproblem!(gen.gen_solver, gen.generator;
                                             optimizer_factory=optimizer_factory,
                                             solve_options=solve_options,
                                             time_horizon=time_horizon,
                                             include_unit_commitment=include_unit_commitment)
end

"""
    solve_storage_generator_subproblem!(gen::GeneralizedGenerator; ...)

Overload of `solve_storage_generator_subproblem!` for `GeneralizedGenerator`. Routes
through the `(GenSolver, PSY.Storage)` dispatch overload in ExtendedStorageGenerator.jl.
"""
function solve_storage_generator_subproblem!(gen::GeneralizedGenerator;
                                              optimizer_factory=nothing,
                                              solve_options=Dict(),
                                              time_horizon=24,
                                              include_unit_commitment=false)
    return solve_storage_generator_subproblem!(gen.gen_solver, gen.generator;
                                               optimizer_factory=optimizer_factory,
                                               solve_options=solve_options,
                                               time_horizon=time_horizon,
                                               include_unit_commitment=include_unit_commitment)
end

"""
Technology dispatch for APP generator subproblem. Selects the correct
`solve_*_generator_subproblem!` based on the PSY type wrapped by `GeneralizedGenerator`.
"""
_dispatch_gen_subproblem!(gen::GeneralizedGenerator{<:PSY.ThermalGen})  = solve_thermal_generator_subproblem!(gen)
_dispatch_gen_subproblem!(gen::GeneralizedGenerator{<:PSY.RenewableGen}) = solve_renewable_generator_subproblem!(gen)
_dispatch_gen_subproblem!(gen::GeneralizedGenerator{<:PSY.HydroGen})    = solve_hydro_generator_subproblem!(gen)
_dispatch_gen_subproblem!(gen::GeneralizedGenerator{<:PSY.Storage})     = solve_storage_generator_subproblem!(gen)

"""
    gpower_angle_message!(gen::GeneralizedGenerator, outerAPPIt, APPItCount, gsRho, ...)

APP message-passing subproblem for `GeneralizedGenerator`. Maps the full APP consensus
parameter set onto the `GenFirstBaseInterval` ADMM state via `update_admm_parameters!`,
then delegates to `solve_thermal_generator_subproblem!` to run the JuMP optimization.

Parameter mapping to `GenFirstBaseInterval` fields:
- gsRho          → rho
- Pgenavg        → Pg_N_avg
- Powerprice     → ug_N      (net power balance dual)
- Angpriceavg    → Vg_N_avg  (average angle dual)
- Angavg         → thetag_N_avg
- Angprice       → vg_N      (angle balance dual)
- P_gen_prevAPP  → Pg_prev
- PgenAPP        → Pg_N_init, Pg_nu   (outer-iterate reference)
- PgenAPPInner   → Pg_nu_inner
- P_gen_nextAPP  → Pg_next_nu
- BAPP           → B         (base-case cumulative disagreement)
- BAPPExternal   → BSC       (contingency cumulative disagreement)
- DAPPExternal   → D         (next-interval disagreement)
- LambAPP1       → lambda_1  (base-case Lagrange multiplier)
- LambAPP1External → lambda_1_sc (contingency Lagrange multiplier)
- LambAPP2External → lambda_2   (next-interval Lagrange multiplier)
- AAPPExternal, LambAPP3External, LambAPP4External: contingency coupling terms
  not yet mapped to GenFirstBaseInterval fields (reserved for future extension)
"""
function gpower_angle_message!(
    gen::GeneralizedGenerator,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    Pgenavg::Float64,
    Powerprice::Float64,
    Angpriceavg::Float64,
    Angavg::Float64,
    Angprice::Float64,
    P_gen_prevAPP::Float64,
    PgenAPP::Float64,
    PgenAPPInner::Float64,
    P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64,
    BAPPExternal::Vector{Float64},
    DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64},
    LambAPP2External::Vector{Float64},
    LambAPP3External::Float64,
    LambAPP4External::Float64,
    BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}
)
    # Map APP consensus parameters onto GenFirstBaseInterval ADMM state
    update_admm_parameters!(gen.gen_solver, Dict(
        "rho"          => gsRho,
        "Pg_N_avg"     => Pgenavg,
        "ug_N"         => Powerprice,
        "Vg_N_avg"     => Angpriceavg,
        "thetag_N_avg" => Angavg,
        "vg_N"         => Angprice,
        "Pg_prev"      => P_gen_prevAPP,
        "Pg_N_init"    => PgenAPP,
        "Pg_nu"        => PgenAPP,
        "Pg_nu_inner"  => PgenAPPInner,
        "Pg_next_nu"   => P_gen_nextAPP,
        "B"            => BAPP,
        "BSC"          => BAPPExternal,
        "D"            => DAPPExternal,
        "lambda_1"     => LambAPP1,
        "lambda_1_sc"  => LambAPP1External,
        "lambda_2"     => LambAPP2External
    ))

    # Invoke the technology-appropriate generator subproblem with the updated APP state
    return _dispatch_gen_subproblem!(gen)
end

"""
    solve_transmission_subproblems!(solver::LASCOPFSolver)

Solve all transmission line optimization subproblems
"""
function solve_transmission_subproblems!(solver::LASCOPFSolver)
    println("    Solving transmission subproblems...")
    
    rho = solver.parameters["rho"]
    
    for line in solver.system_data["branches"]
        solve_transmission_subproblem!(line, rho)
    end
    
    println("    ✓ Transmission subproblems solved")
end

"""
    solve_transmission_subproblem!(line::transmissionLine, rho::Float64)

Solve individual transmission line optimization subproblem
"""
function solve_transmission_subproblem!(line::transmissionLine, rho::Float64)
    # Get node information
    node1 = line.conn_nodet1_ptr
    node2 = line.conn_nodet2_ptr
    
    # Get average values from nodes
    P_avg1 = p_avg_message(node1)
    P_avg2 = p_avg_message(node2)
    theta_avg1 = theta_avg_message(node1)
    theta_avg2 = theta_avg_message(node2)
    v_avg1 = v_avg_message(node1)
    v_avg2 = v_avg_message(node2)
    u1 = u_message!(node1)
    u2 = u_message!(node2)
    
    # Call transmission power angle message
    tpowerangle_message(
        line, rho,
        line.pt1, P_avg1 !== nothing ? P_avg1 : 0.0, u1 !== nothing ? u1 : 0.0,
        v_avg1 !== nothing ? v_avg1 : 0.0, theta_avg1 !== nothing ? theta_avg1 : 0.0, 0.0,
        line.pt2, P_avg2 !== nothing ? P_avg2 : 0.0, u2 !== nothing ? u2 : 0.0,
        v_avg2 !== nothing ? v_avg2 : 0.0, theta_avg2 !== nothing ? theta_avg2 : 0.0, 0.0
    )
end

"""
    update_node_variables!(solver::LASCOPFSolver)

Update node variables by averaging connected device variables
"""
function update_node_variables!(solver::LASCOPFSolver)
    println("    Updating node variables...")
    
    for node in solver.system_data["nodes"]
        update_node_averages!(node)
    end
    
    println("    ✓ Node variables updated")
end

"""
    update_dual_variables!(solver::LASCOPFSolver)

Update dual variables for ADMM algorithm
"""
function update_dual_variables!(solver::LASCOPFSolver)
    println("    Updating dual variables...")
    
    # Update generator dual variables
    for gen in [solver.system_data["thermal_generators"]; 
                solver.system_data["renewable_generators"]; 
                solver.system_data["hydro_generators"]]
        # Dual variable updates are handled within generator functions
    end
    
    # Update transmission line dual variables
    for line in solver.system_data["branches"]
        getv1(line)
        getv2(line)
    end
    
    println("    ✓ Dual variables updated")
end

"""
    calculate_residuals(solver::LASCOPFSolver)

Calculate primal and dual residuals for convergence checking
"""
function calculate_residuals(solver::LASCOPFSolver)
    primal_residual = 0.0
    dual_residual = 0.0
    
    # Calculate primal residuals (power balance violations)
    for node in solver.system_data["nodes"]
        power_balance = get_power_balance(node)
        primal_residual += power_balance^2
    end
    primal_residual = sqrt(primal_residual)
    
    # Calculate dual residuals (consensus violations)
    for gen in [solver.system_data["thermal_generators"]; 
                solver.system_data["renewable_generators"]; 
                solver.system_data["hydro_generators"]]
        node = gen.conn_nodeg_ptr
        P_avg = p_avg_message(node)
        if P_avg !== nothing
            dual_residual += (gen.Pg - P_avg)^2
        end
    end
    dual_residual = sqrt(dual_residual)
    
    return Dict(
        "primal_residual" => primal_residual,
        "dual_residual" => dual_residual,
        "iteration" => solver.current_iteration
    )
end

"""
    compile_results(solver::LASCOPFSolver, solve_time::Float64)

Compile final optimization results
"""
function compile_results(solver::LASCOPFSolver, solve_time::Float64)
    # Calculate total objective value
    total_objective = 0.0
    
    for gen in [solver.system_data["thermal_generators"]; 
                solver.system_data["renewable_generators"]; 
                solver.system_data["hydro_generators"]]
        total_objective += objective_gen(gen)
    end
    
    # Extract solution
    generator_solutions = Dict()
    for (i, gen) in enumerate(solver.system_data["thermal_generators"])
        generator_solutions["thermal_$(i)"] = Dict(
            "name" => PSY.get_name(gen.generator),
            "power" => gen.Pg,
            "angle" => gen.theta_g,
            "node" => get_gen_node_id(gen)
        )
    end
    
    line_solutions = Dict()
    for (i, line) in enumerate(solver.system_data["branches"])
        line_solutions["line_$(i)"] = Dict(
            "name" => PSY.get_name(line.transl_type),
            "flow_1to2" => line.pt1,
            "flow_2to1" => line.pt2,
            "angle_1" => line.thetat1,
            "angle_2" => line.thetat2
        )
    end
    
    return Dict(
        "status" => "OPTIMAL",
        "iterations" => solver.current_iteration,
        "solve_time" => solve_time,
        "objective_value" => total_objective,
        "generator_solutions" => generator_solutions,
        "line_solutions" => line_solutions,
        "convergence_history" => solver.convergence_history
    )
end

"""
    display_results(results::Dict, system_data::Dict)

Display simulation results in a formatted way
"""
function display_results(results::Dict, system_data::Dict)
    println("\n📋 Generator Solutions:")
    for (key, gen_sol) in results["generator_solutions"]
        println("  $(gen_sol["name"]): $(round(gen_sol["power"], digits=3)) MW @ $(round(gen_sol["angle"], digits=4)) rad")
    end
    
    println("\n🔌 Line Flow Solutions:")
    for (key, line_sol) in results["line_solutions"]
        println("  $(line_sol["name"]): $(round(line_sol["flow_1to2"], digits=3)) MW")
    end
    
    println("\n📊 Convergence Summary:")
    println("  Final primal residual: $(round(results["convergence_history"][end]["primal_residual"], digits=6))")
    println("  Final dual residual: $(round(results["convergence_history"][end]["dual_residual"], digits=6))")
end

"""
    save_results(results::Dict, system_data::Dict, filename::String)

Save results to JSON file
"""
function save_results(results::Dict, system_data::Dict, filename::String)
    using JSON
    
    output_data = Dict(
        "system_name" => system_data["name"],
        "results" => results,
        "timestamp" => string(now())
    )
    
    open(filename, "w") do io
        JSON.print(io, output_data, 2)
    end
    
    println("✓ Results saved to $filename")
end
