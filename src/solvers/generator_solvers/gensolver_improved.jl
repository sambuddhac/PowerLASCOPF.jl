"""
Generator Solver for PowerLASCOPF
Implements the first base interval generator optimization subproblem
"""

# Fix the typo and missing type
@kwdef mutable struct GenSolver{T<:Union{ExtendedThermalGenerationCost,
                                        ExtendedRenewableGenerationCost,  # Fixed typo
                                        ExtendedHydroGenerationCost,
                                        ExtendedStorageGenerationCost},   # Fixed name
                               U<:GenIntervals} <: AbstractModel
    interval_type::U
    cost_curve::T
    model::Union{JuMP.Model, Nothing} = nothing
end

# Constructors
GenSolver(interval_type, cost_curve) = GenSolver(; interval_type, cost_curve)
function GenSolver(::Nothing)
    GenSolver(interval_type=GenFirstBaseInterval(nothing), 
              cost_curve=ExtendedThermalGenerationCost(nothing))
end

"""
Add decision variables to the generator solver model
"""
function add_decision_variables!(solver::GenSolver, model::JuMP.Model)
    @variables model begin
        0 <= Pg        # Generator real power output
        0 <= PgNext    # Generator's belief about its output in the next interval
        thetag         # Generator bus angle for base case
    end
    return model
end

"""
Add constraints to the generator solver model
"""
function add_constraints!(solver::GenSolver, model::JuMP.Model, params::Dict)
    # Extract parameters
    PgMax = params["PgMax"]
    PgMin = params["PgMin"] 
    RgMax = params["RgMax"]
    RgMin = params["RgMin"]
    Pg_prev = params["Pg_prev"]
    
    @constraints model begin
        # Power limits
        Pg <= PgMax
        Pg >= PgMin
        PgNext <= PgMax
        PgNext >= PgMin
        
        # Ramping constraints
        PgNext - Pg <= RgMax
        PgNext - Pg >= RgMin
        Pg - Pg_prev <= RgMax
        Pg - Pg_prev >= RgMin
    end
    return model
end

"""
Set the objective function for the generator solver
"""
function set_objective!(solver::GenSolver, model::JuMP.Model, params::Dict)
    # Extract cost parameters
    c0 = get_fixed(solver.cost_curve)
    c1 = get_variable(solver.cost_curve)
    c2 = get_variable(solver.cost_curve)  # Assuming quadratic coefficient
    
    # Extract regularization term parameters
    reg_term = get_regularization(solver.cost_curve)
    if isa(reg_term, GenFirstBaseInterval)
        beta = reg_term.beta
        beta_inner = reg_term.beta_inner
        gamma = reg_term.gamma
        gamma_sc = reg_term.gamma_sc
        rho = reg_term.rho
        
        # Previous iteration values
        Pg_nu = reg_term.Pg_nu
        Pg_nu_inner = reg_term.Pg_nu_inner
        Pg_next_nu = reg_term.Pg_next_nu
        
        # Lagrange multipliers
        lambda_1 = reg_term.lambda_1
        lambda_2 = reg_term.lambda_2
        lambda_1_sc = reg_term.lambda_1_sc
        
        # Disagreement terms
        B = reg_term.B
        D = reg_term.D
        BSC = reg_term.BSC
        cont_count = reg_term.cont_count
        
        # Network variables
        Pg_N_init = reg_term.Pg_N_init
        Pg_N_avg = reg_term.Pg_N_avg
        thetag_N_avg = reg_term.thetag_N_avg
        ug_N = reg_term.ug_N
        vg_N = reg_term.vg_N
        Vg_N_avg = reg_term.Vg_N_avg
        
        @objective(model, Min, 
            # Generation cost
            c2 * (Pg^2) + c1 * Pg + c0 +
            
            # APP regularization terms
            (beta/2) * ((Pg - Pg_nu)^2 + (PgNext - sum(Pg_next_nu))^2) +
            (beta_inner/2) * (Pg - Pg_nu_inner)^2 +
            
            # Security constraint regularization
            gamma_sc * sum(Pg * BSC[i] for i in 1:cont_count) +
            sum(Pg * lambda_1_sc[i] for i in 1:cont_count) +
            
            # Interval coupling terms
            gamma * (Pg * sum(B) + PgNext * sum(D)) +
            sum(lambda_1 .* Pg) + sum(lambda_2 .* PgNext) +
            
            # ADMM penalty terms
            (rho/2) * ((Pg - Pg_N_init + Pg_N_avg + ug_N)^2 + 
                      (thetag - Vg_N_avg - thetag_N_avg + vg_N)^2)
        )
    else
        # Simple regularization case
        @objective(model, Min, c2 * (Pg^2) + c1 * Pg + c0)
    end
    
    return model
end

"""
Solve the generator optimization subproblem
"""
function solve_generator!(solver::GenSolver, params::Dict; 
                         optimizer=nothing, time_limit=300)
    
    # Create or get the model
    if solver.model === nothing
        solver.model = JuMP.Model()
    end
    model = solver.model
    
    # Set optimizer if provided
    if optimizer !== nothing
        set_optimizer(model, optimizer)
    end
    
    # Set time limit
    set_time_limit_sec(model, time_limit)
    
    # Build the model
    add_decision_variables!(solver, model)
    add_constraints!(solver, model, params)
    set_objective!(solver, model, params)
    
    # Solve
    start_time = time()
    optimize!(model)
    solve_time = time() - start_time
    
    # Check solution status
    status = termination_status(model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            error("Generator solver: Infeasible problem")
        elseif status == MOI.TIME_LIMIT
            @warn "Generator solver: Time limit reached"
        elseif status == MOI.INFEASIBLE_OR_UNBOUNDED
            error("Generator solver: Infeasible or unbounded")
        else
            @warn "Generator solver: Non-optimal status: $status"
        end
    end
    
    # Extract results
    results = Dict(
        "Pg" => value(model[:Pg]),
        "PgNext" => value(model[:PgNext]),
        "thetag" => value(model[:thetag]),
        "objective_value" => objective_value(model),
        "solve_time" => solve_time,
        "termination_status" => status,
        "primal_status" => primal_status(model),
        "dual_status" => dual_status(model)
    )
    
    return results
end

"""
Update regularization parameters for the next iteration
"""
function update_regularization!(solver::GenSolver, new_values::Dict)
    reg_term = get_regularization(solver.cost_curve)
    if isa(reg_term, GenFirstBaseInterval)
        # Update previous iteration values
        if haskey(new_values, "Pg_nu")
            reg_term.Pg_nu = new_values["Pg_nu"]
        end
        if haskey(new_values, "Pg_nu_inner")
            reg_term.Pg_nu_inner = new_values["Pg_nu_inner"]
        end
        if haskey(new_values, "Pg_next_nu")
            reg_term.Pg_next_nu = new_values["Pg_next_nu"]
        end
        # Add other updates as needed
    end
end