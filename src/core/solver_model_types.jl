"""
parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaInner positive # APP tuning parameter for across the dispatch intervals
  gamma positive # APP tuning parameter for across the dispatch intervals
  lambda_1 (dim); lambda_2 (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  gammaSC positive # APP tuning parameter
  lambda_1SC (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  ones (dim) # Vector of all ones and zeroes
  RgMax positive; RgMin negative # Generator maximum ramp up and ramp down limits
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNu; PgNuInner # Previous iterates of the corresponding decision variable values
  PgNextNu (dim) nonnegative
  B (dim)# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  D (dim)# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC (dim) # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  PgPrev nonnegative # Generator's output in the previous interval
end

variables
  Pg # Generator real power output
  PgNext (dim) # Generator's belief about its output in the next interval
  Thetag # Generator bus angle for base case
end
Optimization problem for a typical thermal generator with quadratic cost curve
minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaInner/2)*(square(Pg-PgNuInner))+(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(sum(Pg*B)+(PgNext)'*D)+sum(Pg*lambda_1)+(lambda_2)'*PgNext+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= PgNext-Pg*ones <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""
abstract type AbstractModel end
abstract type IntervalType end
abstract type PowerFlowConstraint end
abstract type GenIntervals <: IntervalType end
abstract type LineIntervals <: IntervalType end
abstract type LoadIntervals <: IntervalType end
@kwdef mutable struct GenFirstBaseInterval <: GenIntervals
    lambda_1::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D::Array{Float64} # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    cont_count::Int64 #Number of contingency scenarios
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_1_sc::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev::Float64 # Generator's output in the previous interval
end

function GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho,
                              beta, beta_inner, gamma, gamma_sc,lambda_1_sc, 
                              Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, 
                              Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu,Pg_prev)
    GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end

#=function GenFirstBaseInterval(; lambda_1 = Float64[], 
                              lambda_2 = Float64[], 
                              B = Float64[], 
                              D = Float64[], 
                              BSC = Float64[], 
                              cont_count::Int64 = 0, 
                              rho::Float64 = 1.0, 
                              beta::Float64 = 1.0, 
                              beta_inner::Float64 = 1.0, 
                              gamma::Float64 = 1.0, 
                              gamma_sc::Float64 = 1.0, 
                              lambda_1_sc::Array{Float64} = zeros(Float64, length(lambda_1)),
                              Pg_N_init::Float64 = 0.0, 
                              Pg_N_avg::Float64 = 0.0, 
                              thetag_N_avg::Float64 = 0.0, 
                              ug_N::Float64 = 0.0, 
                              vg_N::Float64 = 0.0, 
                              Vg_N_avg::Float64 = 0.0, 
                              Pg_nu::Float64 = 0.0, 
                              Pg_nu_inner::Float64 = 0.0, 
                              Pg_next_nu::Array{Float64} = zeros(Float64, length(lambda_1)),
                              Pg_prev::Float64 = 0.0)
    GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end

function GenFirstBaseInterval_kwarg_constructor(; kwargs...)
    GenFirstBaseInterval(; kwargs...)
end

function GenFirstBaseInterval(lambda_1::Array{Float64}, lambda_2::Array{Float64}, B::Array{Float64}, D::Array{Float64}, BSC::Array{Float64}, cont_count::Int64, rho::Float64 = 1.0, beta::Float64 = 1.0, beta_inner::Float64 = 1.0, gamma::Float64 = 1.0, gamma_sc::Float64 = 1.0, lambda_1_sc::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_N_init::Float64 = 0.0, Pg_N_avg::Float64 = 0.0, thetag_N_avg::Float64 = 0.0, ug_N::Float64 = 0.0, vg_N::Float64 = 0.0, Vg_N_avg::Float64 = 0.0, Pg_nu::Float64 = 0.0, Pg_nu_inner::Float64 = 0.0, Pg_next_nu::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_prev::Float64 = 0.0)
    GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end=#

function GenFirstBaseInterval(::Nothing)
    GenFirstBaseInterval(; lambda_1 = Float64[], 
                         lambda_2 = Float64[], 
                         B = Float64[], 
                         D = Float64[], 
                         BSC = Float64[], 
                         cont_count = 0, 
                         rho = 1.0, 
                         beta = 1.0, 
                         beta_inner = 1.0, 
                         gamma = 1.0, 
                         gamma_sc = 1.0, 
                         lambda_1_sc = Float64[], 
                         Pg_N_init = 0.0, 
                         Pg_N_avg = 0.0, 
                         thetag_N_avg = 0.0, 
                         ug_N = 0.0, 
                         vg_N = 0.0, 
                         Vg_N_avg = 0.0, 
                         Pg_nu = 0.0, 
                         Pg_nu_inner = 0.0, 
                         Pg_next_nu = Float64[], 
                         Pg_prev = 0.0)
end

# Regularization term functions for different GenIntervals types

"""
    regularization_term(interval::GenFirstBaseInterval, Pg, PgNext, Thetag)

Compute regularization term for GenFirstBaseInterval based on the optimization formulation:
(beta/2)*(square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaInner/2)*(square(Pg-PgNuInner))+
(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(sum(Pg*B)+(PgNext)'*D)+
sum(Pg*lambda_1)+(lambda_2)'*PgNext+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+
square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
"""
function regularization_term(interval::GenFirstBaseInterval, Pg, PgNext, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    for i in eachindex(PgNext)
        JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext[i] - interval.Pg_next_nu[i]), (PgNext[i] - interval.Pg_next_nu[i]))
    end
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))

    # APP consensus terms
    for i in eachindex(interval.BSC)
        JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC[i], Pg)
    end
    for i in eachindex(interval.lambda_1_sc)
        JuMP.add_to_expression!(reg_term, interval.lambda_1_sc[i], Pg)
    end
    for i in eachindex(interval.B)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.B[i], Pg)
    end
    for i in eachindex(interval.D)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.D[i], PgNext[i])
    end
    for i in eachindex(interval.lambda_1)
        JuMP.add_to_expression!(reg_term, interval.lambda_1[i], Pg)
    end
    for i in eachindex(interval.lambda_2)
        JuMP.add_to_expression!(reg_term, interval.lambda_2[i], PgNext[i])
    end
    
    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)
    
    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
    regularization_term(interval::GenFirstBaseInterval, Pg, PgNext, Thetag)

Compute regularization term for GenFirstBaseInterval based on the optimization formulation:
(beta/2)*(square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaInner/2)*(square(Pg-PgNuInner))+
(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(sum(Pg*B)+(PgNext)'*D)+
sum(Pg*lambda_1)+(lambda_2)'*PgNext+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+
square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
"""
function regularization_term(interval::GenFirstBaseInterval, Pg, PgNext, Thetag)
    reg_term = AffExpr(0.0)
    
    # APP regularization terms
    add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    for i in eachindex(PgNext)
        add_to_expression!(reg_term, interval.beta/2, (PgNext[i] - interval.Pg_next_nu[i]), (PgNext[i] - interval.Pg_next_nu[i]))
    end
    add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))
    
    # APP consensus terms
    for i in eachindex(interval.BSC)
        add_to_expression!(reg_term, interval.gamma_sc * interval.BSC[i], Pg)
    end
    for i in eachindex(interval.lambda_1_sc)
        add_to_expression!(reg_term, interval.lambda_1_sc[i], Pg)
    end
    for i in eachindex(interval.B)
        add_to_expression!(reg_term, interval.gamma * interval.B[i], Pg)
    end
    for i in eachindex(interval.D)
        add_to_expression!(reg_term, interval.gamma * interval.D[i], PgNext[i])
    end
    for i in eachindex(interval.lambda_1)
        add_to_expression!(reg_term, interval.lambda_1[i], Pg)
    end
    for i in eachindex(interval.lambda_2)
        add_to_expression!(reg_term, interval.lambda_2[i], PgNext[i])
    end
    
    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)
    
    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)
    
    return reg_term
end

"""
dimensions
  dim=190
end
parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaInner positive # APP tuning parameter for across the dispatch intervals
  gamma positive # APP tuning parameter for across the dispatch intervals
  lambda_1 (dim); lambda_2 (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  lambda_3; lambda_4 # APP Lagrange Multiplier corresponding to the complementary slackness
  gammaSC positive # APP tuning parameter
  lambda_1SC (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  ones (dim) # Vector of all ones and zeroes
  RgMax positive; RgMin negative # Generator maximum ramp up and ramp down limits
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNu; PgNuInner # Previous iterates of the corresponding decision variable values
  PgNextNu (dim) nonnegative
  PgPrevNu
  A # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  B (dim)# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  D (dim)# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC (dim) # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
end

variables
  Pg # Generator real power output
  PgNext (dim) # Generator's belief about its output in the next interval
  PgPrev # Generator's output in the previous interval
  Thetag # Generator bus angle for base case
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(PgPrev-PgPrevNu)+square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaInner/2)*(square(Pg-PgNuInner))+(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(PgPrev*A+sum(Pg*B)+(PgNext)'*D)+sum(Pg*lambda_1)+(lambda_2)'*PgNext-lambda_3*PgPrev-lambda_4*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= PgNext-Pg*ones <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""
@kwdef mutable struct GenFirstBaseIntervalDZ <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_1::Array{Float64}# APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness 
    lambda_3::Float64
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1_sc::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 # Generator's output in the previous interval
    A::Float64 # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    B::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D::Array{Float64} # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    cont_count::Int64 #Number of contingency scenarios
end

# Simplified constructor for GenFirstBaseIntervalDZ that provides compatibility with existing code
function GenFirstBaseIntervalDZ(lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, cont_count; 
                              rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg,
                              thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev_nu
                              )
    return GenFirstBaseIntervalDZ(rho=rho, beta=beta, beta_inner=beta_inner, gamma=gamma, gamma_sc=gamma_sc,
                                lambda_1=lambda_1, lambda_2=lambda_2, lambda_3=lambda_3, lambda_4=lambda_4,
                                B=B, D=D, A=A, BSC=BSC, cont_count=cont_count, lambda_1_sc=lambda_1_sc,
                                Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg, thetag_N_avg=thetag_N_avg,
                                ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg, Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner,
                                Pg_next_nu=Pg_next_nu, Pg_prev_nu=Pg_prev_nu)
end

# Alternative constructor for Nothing input
function GenFirstBaseIntervalDZ(::Nothing)
    GenFirstBaseIntervalDZ(;
    rho = 1.0, # ADMM tuning parameter
    beta = 1.0, # APP tuning parameter for across the dispatch intervals
    beta_inner = 1.0, # APP tuning parameter
    gamma = 1.0, # APP tuning parameter for across the dispatch intervals
    gamma_sc = 1.0, # APP tuning parameter
    lambda_1 = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_2 = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness 
    lambda_3 = 0.0,
    lambda_4 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1_sc = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
    thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
    vg_N = 0.0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_next_nu = Float64[], # Previous iterates of the corresponding decision variable values
    Pg_prev_nu = 0.0, # Generator's output in the previous interval
    A = 0.0, # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    B = Float64[], # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D = Float64[], # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    BSC = Float64[], # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    cont_count = 0 #Number of contingency scenarios
    )
end
"""
 lambda_1_sc
 Pg_next_nu
"""

"""
    regularization_term(interval::GenFirstBaseIntervalDZ, Pg, PgNext, PgPrev, Thetag)

Compute regularization term for GenFirstBaseIntervalDZ with dummy zero interval
"""
function regularization_term(interval::GenFirstBaseIntervalDZ, Pg, PgNext, PgPrev, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    for i in eachindex(PgNext)
        JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext[i] - interval.Pg_next_nu[i]), (PgNext[i] - interval.Pg_next_nu[i]))
    end
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))
    
    # APP consensus terms
    for i in eachindex(interval.BSC)
        JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC[i], Pg)
    end
    for i in eachindex(interval.lambda_1_sc)
        JuMP.add_to_expression!(reg_term, interval.lambda_1_sc[i], Pg)
    end
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    for i in eachindex(interval.B)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.B[i], Pg)
    end
    for i in eachindex(interval.D)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.D[i], PgNext[i])
    end
    for i in eachindex(interval.lambda_1)
        JuMP.add_to_expression!(reg_term, interval.lambda_1[i], Pg)
    end
    for i in eachindex(interval.lambda_2)
        JuMP.add_to_expression!(reg_term, interval.lambda_2[i], PgNext[i])
    end
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)

    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)
    
    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
dimensions
  dim=200
end

parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaSC positive # APP tuning parameter
  gamma positive # APP tuning parameter for across the dispatch intervals
  gammaSC positive # APP tuning parameter
  lambda_1 (dim); lambda_2 (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  lambda_2SC # APP Lagrange Multiplier corresponding to the complementary slackness
  ones (dim) # Vector of all ones and zeroes
  RgMax positive; RgMin negative # Generator maximum ramp up and ramp down limits
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNu; PgAPPSC # Previous iterates of the corresponding decision variable values
  PgNextNu (dim) nonnegative
  B (dim)# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  D (dim)# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  PgPrev nonnegative # Generator's output in the previous interval
end

variables
  Pg # Generator real power output
  PgNext (dim) # Generator's belief about its output in the next interval
  Thetag # Generator bus angle for base case and contingencies
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaSC/2)*(square(Pg-PgAPPSC))+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(gamma)*(sum(Pg*B)+(PgNext)'*D)+sum(Pg*lambda_1)+(lambda_2)'*PgNext+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= PgNext-Pg*ones <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
​
"""
@kwdef mutable struct GenFirstContInterval <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_1_sc::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1::Array{Float64}
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    B::Array{Float64} # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev::Float64 # Generator's output in the previous interval
end

# Simplified constructor for GenFirstContInterval that provides compatibility with existing code
function GenFirstContInterval(lambda_1, lambda_2, B, D, BSC,
                              Pg_N_init, Pg_N_avg, thetag_N_avg, 
                              ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, 
                              Pg_next_nu, Pg_prev, rho, beta, beta_inner, 
                              gamma, gamma_sc, lambda_1_sc)
    return GenFirstContInterval(rho=rho, beta=beta, beta_inner=beta_inner, gamma=gamma, gamma_sc=gamma_sc,
                              lambda_1_sc=lambda_1_sc, lambda_1=lambda_1, lambda_2=lambda_2, B=B, D=D, 
                              BSC=BSC, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg, thetag_N_avg=thetag_N_avg,
                              ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg, Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner,
                              Pg_next_nu=Pg_next_nu, Pg_prev=Pg_prev)
end

# Alternative constructor for Nothing input
function GenFirstContInterval(::Nothing)
    GenFirstContInterval(;
    rho = 1.0, # ADMM tuning parameter
    beta = 1.0, # APP tuning parameter for across the dispatch intervals
    beta_inner = 1.0, # APP tuning parameter
    gamma = 1.0, # APP tuning parameter for across the dispatch intervals
    gamma_sc = 1.0, # APP tuning parameter
    lambda_1_sc = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1 = Float64[],
    lambda_2 = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness
    B = Float64[], # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D = Float64[], # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC = 0.0, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
    thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
    vg_N = 0.0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_next_nu = Float64[], # Previous iterates of the corresponding decision variable values
    Pg_prev = 0.0 # Generator's output in the previous interval
    )
end

"""
    regularization_term(interval::GenFirstContInterval, Pg, PgNext, Thetag)

Compute regularization term for GenFirstContInterval
"""
function regularization_term(interval::GenFirstContInterval, Pg, PgNext, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    for i in eachindex(PgNext)
        JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext[i] - interval.Pg_next_nu[i]), (PgNext[i] - interval.Pg_next_nu[i]))
    end
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))
    
    # APP consensus terms
    JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC, Pg)
    JuMP.add_to_expression!(reg_term, -interval.lambda_1_sc, Pg)
    for i in eachindex(interval.B)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.B[i], Pg)
    end
    for i in eachindex(interval.D)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.D[i], PgNext[i])
    end
    for i in eachindex(interval.lambda_1)
        JuMP.add_to_expression!(reg_term, interval.lambda_1[i], Pg)
    end
    for i in eachindex(interval.lambda_2)
        JuMP.add_to_expression!(reg_term, interval.lambda_2[i], PgNext[i])
    end
    
    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)
    
    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end
"""
dimensions
  dim=190
end

parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaSC positive # APP tuning parameter
  gamma positive # APP tuning parameter for across the dispatch intervals
  gammaSC positive # APP tuning parameter
  lambda_1 (dim); lambda_2 (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
  lambda_3; lambda_4 # APP Lagrange Multiplier corresponding to the complementary slackness
  lambda_2SC # APP Lagrange Multiplier corresponding to the complementary slackness
  ones (dim) # Vector of all ones and zeroes
  RgMax positive; RgMin negative # Generator maximum ramp up and ramp down limits
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNu; PgAPPSC # Previous iterates of the corresponding decision variable values
  PgNextNu (dim) nonnegative
  PgPrevNu
  A # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  B (dim)# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  D (dim)# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
end

variables
  Pg # Generator real power output
  PgNext (dim) # Generator's belief about its output in the next interval
  PgPrev # Generator's output in the previous interval
  Thetag # Generator bus angle for base case and contingencies
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(PgPrev-PgPrevNu)+square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaSC/2)*(square(Pg-PgAPPSC))+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(gamma)*(PgPrev*A+sum(Pg*B)+(PgNext)'*D)+sum(Pg*lambda_1)+(lambda_2)'*PgNext-lambda_3*PgPrev-lambda_4*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= PgNext-Pg*ones <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""
##This is currently just a placeholder; Need to modify
@kwdef mutable struct GenFirstContIntervalDZ <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_1_sc::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1::Array{Float64}
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    B::Array{Float64} # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev::Float64 # Generator's output in the previous interval
end

# Simplified constructor for GenFirstContInterval that provides compatibility with existing code
function GenFirstContIntervalDZ(lambda_1, lambda_2, B, D, BSC,
                              Pg_N_init, Pg_N_avg, thetag_N_avg, 
                              ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, 
                              Pg_next_nu, Pg_prev, rho, beta, beta_inner, 
                              gamma, gamma_sc, lambda_1_sc)
    return GenFirstContIntervalDZ(rho=rho, beta=beta, beta_inner=beta_inner, gamma=gamma, gamma_sc=gamma_sc,
                              lambda_1_sc=lambda_1_sc, lambda_1=lambda_1, lambda_2=lambda_2, B=B, D=D, 
                              BSC=BSC, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg, thetag_N_avg=thetag_N_avg,
                              ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg, Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner,
                              Pg_next_nu=Pg_next_nu, Pg_prev=Pg_prev)
end

# Alternative constructor for Nothing input
function GenFirstContIntervalDZ(::Nothing)
    GenFirstContIntervalDZ(;
    rho = 1.0, # ADMM tuning parameter
    beta = 1.0, # APP tuning parameter for across the dispatch intervals
    beta_inner = 1.0, # APP tuning parameter
    gamma = 1.0, # APP tuning parameter for across the dispatch intervals
    gamma_sc = 1.0, # APP tuning parameter
    lambda_1_sc = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1 = Float64[],
    lambda_2 = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness
    B = Float64[], # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D = Float64[], # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC = 0.0, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
    thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
    vg_N = 0.0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
    Pg_next_nu = Float64[], # Previous iterates of the corresponding decision variable values
    Pg_prev = 0.0 # Generator's output in the previous interval
    )
end

"""
    regularization_term(interval::GenFirstContIntervalDZ, Pg, PgNext, PgPrev, Thetag)

Compute regularization term for GenFirstContIntervalDZ
"""

function regularization_term(interval::GenFirstContIntervalDZ, Pg, PgNext, PgPrev, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    for i in eachindex(PgNext)
        JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext[i] - interval.Pg_next_nu[i]), (PgNext[i] - interval.Pg_next_nu[i]))
    end
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))
    
    # APP consensus terms
    JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC, Pg)
    JuMP.add_to_expression!(reg_term, -interval.lambda_1_sc, Pg)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.B, Pg)
    for i in eachindex(interval.D)
        JuMP.add_to_expression!(reg_term, interval.gamma * interval.D[i], PgNext[i])
    end
    for i in eachindex(interval.lambda_1)
        JuMP.add_to_expression!(reg_term, interval.lambda_1[i], Pg)
    end
    for i in eachindex(interval.lambda_2)
        JuMP.add_to_expression!(reg_term, interval.lambda_2[i], PgNext[i])
    end
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)
    
    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)
    
    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
Generator Last Base Interval for final dispatch interval in base case scenarios
"""
@kwdef mutable struct GenLastBaseInterval <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_3::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1_sc::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals
    A::Float64 # Disagreement between the generator output values for the previous interval
    B::Float64 # Cumulative disagreement between the generator output values
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 # Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next::Float64 # Generator's belief about its output in the next interval
    select_zero::Int # Selection parameter to include or not include the last interval for PgNext constraint
end

# Simplified constructor for GenLastBaseInterval that provides compatibility with existing code
function GenLastBaseInterval(lambda_3, lambda_4, lambda_1_sc, BSC, A, B,
                           Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg,
                           Pg_nu, Pg_nu_inner, Pg_prev_nu, Pg_next, select_zero;
                           rho, beta, beta_inner, gamma, gamma_sc)
    return GenLastBaseInterval(rho=rho, beta=beta, beta_inner=beta_inner, gamma=gamma, gamma_sc=gamma_sc,
                             lambda_3=lambda_3, lambda_4=lambda_4, lambda_1_sc=lambda_1_sc, BSC=BSC,
                             A=A, B=B, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg, thetag_N_avg=thetag_N_avg,
                             ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg, Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner,
                             Pg_prev_nu=Pg_prev_nu, Pg_next=Pg_next, select_zero=select_zero)
end

# Alternative constructor for Nothing input
function GenLastBaseInterval(::Nothing)
    GenLastBaseInterval(;
        rho = 1.0, # ADMM tuning parameter
        beta = 1.0, # APP tuning parameter for across the dispatch intervals
        beta_inner = 1.0, # APP tuning parameter
        gamma = 1.0, # APP tuning parameter for across the dispatch intervals
        gamma_sc = 1.0, # APP tuning parameter
        lambda_3 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_4 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_1_sc = Float64[], # APP Lagrange Multiplier corresponding to the complementary slackness
        BSC = Float64[], # Cumulative disagreement between the generator output values for the previous and next intervals
        A = 0.0, # Disagreement between the generator output values for the previous interval
        B = 0.0, # Cumulative disagreement between the generator output values
        Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
        Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
        thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
        ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
        vg_N = 0.0, # Dual variable for net angle balance for base case and contingencies
        Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration
        Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_prev_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_next = 0.0, # Generator's belief about its output in the next interval
        select_zero = 0 # Selection parameter to include or not include the last interval for PgNext constraint
    )
end


"""
    regularization_term(interval::GenLastBaseInterval, Pg, PgPrev, Thetag)

Compute regularization term for GenLastBaseInterval
"""
function regularization_term(interval::GenLastBaseInterval, Pg, PgPrev, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))

    # APP consensus terms
    for i in eachindex(interval.BSC)
        JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC[i], Pg)
    end
    for i in eachindex(interval.lambda_1_sc)
        JuMP.add_to_expression!(reg_term, interval.lambda_1_sc[i], Pg)
    end
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.B, Pg)
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)

    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)

    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
Generator Last Contingency Interval for final dispatch interval in contingency scenarios
"""
@kwdef mutable struct GenLastContInterval <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 # APP tuning parameter
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 # APP tuning parameter
    lambda_3::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1_sc::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    BSC::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals
    A::Float64 # Disagreement between the generator output values for the previous interval
    B::Float64 # Cumulative disagreement between the generator output values
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 # Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next::Float64 # Generator's belief about its output in the next interval
    select_zero::Int # Selection parameter to include or not include the last interval for PgNext constraint
end

# Simplified constructor for GenLastContInterval that provides compatibility with existing code
function GenLastContInterval(lambda_3, lambda_4, lambda_1_sc, BSC, A, B,
                           Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg,
                           Pg_nu, Pg_nu_inner, Pg_prev_nu, Pg_next, select_zero;
                           rho, beta, beta_inner, gamma, gamma_sc)
    return GenLastContInterval(rho=rho, beta=beta, beta_inner=beta_inner, gamma=gamma, gamma_sc=gamma_sc,
                             lambda_3=lambda_3, lambda_4=lambda_4, lambda_1_sc=lambda_1_sc, BSC=BSC,
                             A=A, B=B, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg, thetag_N_avg=thetag_N_avg,
                             ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg, Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner,
                             Pg_prev_nu=Pg_prev_nu, Pg_next=Pg_next, select_zero=select_zero)
end

# Alternative constructor for Nothing input
function GenLastContInterval(::Nothing)
    GenLastContInterval(;
        rho = 1.0, # ADMM tuning parameter
        beta = 1.0, # APP tuning parameter for across the dispatch intervals
        beta_inner = 1.0, # APP tuning parameter
        gamma = 1.0, # APP tuning parameter for across the dispatch intervals
        gamma_sc = 1.0, # APP tuning parameter
        lambda_3 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_4 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_1_sc = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        BSC = 0.0, # Cumulative disagreement between the generator output values for the previous and next intervals
        A = 0.0, # Disagreement between the generator output values for the previous interval
        B = 0.0, # Cumulative disagreement between the generator output values
        Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
        Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
        thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
        ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
        vg_N = 0.0, # Dual variable for net angle balance for base case and contingencies
        Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration
        Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_prev_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_next = 0.0, # Generator's belief about its output in the next interval
        select_zero = 0 # Selection parameter to include or not include the last interval for PgNext constraint
    )
end

"""
    regularization_term(interval::GenLastContInterval, Pg, PgPrev, Thetag)

Compute regularization term for GenLastContInterval
"""
function regularization_term(interval::GenLastContInterval, Pg, PgPrev, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    JuMP.add_to_expression!(reg_term, interval.beta_inner/2, (Pg - interval.Pg_nu_inner), (Pg - interval.Pg_nu_inner))

    # APP consensus terms
    JuMP.add_to_expression!(reg_term, interval.gamma_sc * interval.BSC, Pg)
    JuMP.add_to_expression!(reg_term, -interval.lambda_1_sc, Pg)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.B, Pg)
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)

    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)

    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
mutable struct GenInterRNDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end


Generator Intermediate RND Interval for ED
"""
@kwdef mutable struct GenInterRNDInterval <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    lambda_3::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    A::Float64 # Disagreement between the generator output values for the previous interval
    B::Float64 # Cumulative disagreement between the generator output values
    D::Float64 # Cumulative disagreement between the generator output values for the next interval
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 # Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next::Float64 # Generator's belief about its output in the next interval
    select_zero::Int # Selection parameter to include or not include the last interval for PgNext constraint
end

# Simplified constructor for GenInterRNDInterval that provides compatibility with existing code
function GenInterRNDInterval(lambda_3, lambda_4, A, B, D, Pg_N_init, Pg_N_avg,
                           thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner,
                           Pg_prev_nu, Pg_next, select_zero;
                           rho, beta, gamma)
    return GenInterRNDInterval(rho=rho, beta=beta, gamma=gamma, lambda_3=lambda_3, lambda_4=lambda_4,
                             A=A, B=B, D=D, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg,
                             thetag_N_avg=thetag_N_avg, ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg,
                             Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner, Pg_prev_nu=Pg_prev_nu,
                             Pg_next=Pg_next, select_zero=select_zero)
end

# Alternative constructor for Nothing input
function GenInterRNDInterval(::Nothing)
    GenInterRNDInterval(;
        rho = 1.0, # ADMM tuning parameter
        beta = 1.0, # APP tuning parameter for across the dispatch intervals
        gamma = 1.0, # APP tuning parameter for across the dispatch intervals
        lambda_3 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_4 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        A = 0.0, # Disagreement between the generator output values for the previous interval
        B = 0.0, # Cumulative disagreement between the generator output values
        D = 0.0, # Cumulative disagreement between the generator output values for the next interval
        Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
        Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
        thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
        ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
        vg_N = 0.0, # Dual variable for net angle balance for base case and contingencies
        Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration
        Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_prev_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_next = 0.0, # Generator's belief about its output in the next interval
        select_zero = 0 # Selection parameter to include or not include the last interval for PgNext constraint
    )
end

"""
    regularization_term(interval::GenLastBaseInterval, Pg, PgPrev, Thetag)

Compute regularization term for GenLastBaseInterval
"""
function regularization_term(interval::GenInterRNDInterval, Pg, PgPrev, PgNext, Thetag)
    reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext - interval.Pg_next_nu), (PgNext - interval.Pg_next_nu))

    # APP consensus terms
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.B, Pg)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.D, PgNext)
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)

    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)

    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
mutable struct GenInterRSDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

Generator Intermediate RSD Interval for OPF
"""
@kwdef mutable struct GenInterRSDInterval <: GenIntervals
    rho::Float64 # ADMM tuning parameter
    beta::Float64 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 # APP tuning parameter for across the dispatch intervals
    lambda_3::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    A::Float64 # Disagreement between the generator output values for the previous interval
    B::Float64 # Cumulative disagreement between the generator output values
    D::Float64 # Cumulative disagreement between the generator output values for the next interval
    Pg_N_init::Float64 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 # Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 # Average of dual variable for net angle balance from last to last iteration
    Pg_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 # Previous iterates of the corresponding decision variable values
    Pg_next::Float64 # Generator's belief about its output in the next interval
    select_zero::Int # Selection parameter to include or not include the last interval for PgNext constraint
end

# Simplified constructor for GenInterRSDInterval that provides compatibility with existing code
function GenInterRSDInterval(lambda_3, lambda_4, A, B, D, Pg_N_init, Pg_N_avg,
                           thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner,
                           Pg_prev_nu, Pg_next, select_zero;
                           rho, beta, gamma)
    return GenInterRSDInterval(rho=rho, beta=beta, gamma=gamma, lambda_3=lambda_3, lambda_4=lambda_4,
                             A=A, B=B, D=D, Pg_N_init=Pg_N_init, Pg_N_avg=Pg_N_avg,
                             thetag_N_avg=thetag_N_avg, ug_N=ug_N, vg_N=vg_N, Vg_N_avg=Vg_N_avg,
                             Pg_nu=Pg_nu, Pg_nu_inner=Pg_nu_inner, Pg_prev_nu=Pg_prev_nu,
                             Pg_next=Pg_next, select_zero=select_zero)
end

# Alternative constructor for Nothing input
function GenInterRSDInterval(::Nothing)
    GenInterRSDInterval(;
        rho = 1.0, # ADMM tuning parameter
        beta = 1.0, # APP tuning parameter for across the dispatch intervals
        gamma = 1.0, # APP tuning parameter for across the dispatch intervals
        lambda_3 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        lambda_4 = 0.0, # APP Lagrange Multiplier corresponding to the complementary slackness
        A = 0.0, # Disagreement between the generator output values for the previous interval
        B = 0.0, # Cumulative disagreement between the generator output values
        D = 0.0, # Cumulative disagreement between the generator output values for the next interval
        Pg_N_init = 0.0, # Generator injection from last iteration for base case and contingencies
        Pg_N_avg = 0.0, # Net average power from last iteration for base case and contingencies
        thetag_N_avg = 0.0, # Net average bus voltage angle from last iteration for base case and contingencies
        ug_N = 0.0, # Dual variable for net power balance for base case and contingencies
        vg_N = 0.0, # Dual variable for net angle balance for base case and contingencies
        Vg_N_avg = 0.0, # Average of dual variable for net angle balance from last to last iteration
        Pg_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_nu_inner = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_prev_nu = 0.0, # Previous iterates of the corresponding decision variable values
        Pg_next = 0.0, # Generator's belief about its output in the next interval
        select_zero = 0 # Selection parameter to include or not include the last interval for PgNext constraint
    )
end

"""
    regularization_term(interval::GenLastBaseInterval, Pg, PgPrev, Thetag)

Compute regularization term for GenLastBaseInterval
"""
function regularization_term(interval::GenInterRSDInterval, Pg, PgPrev, PgNext, Thetag)
   reg_term = JuMP.QuadExpr()
    
    # APP regularization terms
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgPrev - interval.Pg_prev_nu), (PgPrev - interval.Pg_prev_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (Pg - interval.Pg_nu), (Pg - interval.Pg_nu))
    JuMP.add_to_expression!(reg_term, interval.beta/2, (PgNext - interval.Pg_next_nu), (PgNext - interval.Pg_next_nu))

    # APP consensus terms
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.A, PgPrev)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.B, Pg)
    JuMP.add_to_expression!(reg_term, interval.gamma * interval.D, PgNext)
    JuMP.add_to_expression!(reg_term, -interval.lambda_3, PgPrev)
    JuMP.add_to_expression!(reg_term, -interval.lambda_4, Pg)

    # ADMM consensus terms
    power_consensus = Pg - interval.Pg_N_init + interval.Pg_N_avg + interval.ug_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, power_consensus, power_consensus)

    angle_consensus = Thetag - interval.Vg_N_avg - interval.thetag_N_avg + interval.vg_N
    JuMP.add_to_expression!(reg_term, interval.rho/2, angle_consensus, angle_consensus)

    return reg_term
end

"""
mutable struct LineBaseInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end
"""

@kwdef mutable struct LineBaseInterval <: LineIntervals
    rho::Float64 = 1.0 # ADMM tuning parameter
    beta::Float64 = 1.0 # APP tuning parameter for across the dispatch intervals
    lambda_flow::Float64 = 0.0 # APP Lagrange Multiplier corresponding to the power flow consensus
    lambda_angle::Float64 = 0.0 # APP Lagrange Multiplier corresponding to the angle difference consensus
    Pt_prev::Float64 = 0.0 # Power flow in the previous interval
    theta_diff_prev::Float64 = 0.0 # Voltage angle difference in the previous interval
    reactance::Float64 = 0.0 # Line reactance
    restoration_factor::Float64 = 1.0 # Restoration factor for power flow during restoration
    emergency_mode::Bool = false # Flag indicating if the line is in emergency mode
    thermal_limit_emergency::Float64 = 0.0 # Emergency thermal limit for the line
end

"""
mutable struct LineRNDInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end
"""
@kwdef mutable struct LineRNDInterval <: LineIntervals
    rho::Float64 = 1.0 # ADMM tuning parameter
    beta::Float64 = 1.0 # APP tuning parameter for across the dispatch intervals
    lambda_flow::Float64 = 0.0 # APP Lagrange Multiplier corresponding to the power flow consensus
    lambda_angle::Float64 = 0.0 # APP Lagrange Multiplier corresponding to the angle difference consensus
    Pt_prev::Float64 = 0.0 # Power flow in the previous interval
    theta_diff_prev::Float64 = 0.0 # Voltage angle difference in the previous interval
    reactance::Float64 = 0.0 # Line reactance
    restoration_factor::Float64 = 1.0 # Restoration factor for power flow during restoration
    emergency_mode::Bool = false # Flag indicating if the line is in emergency mode
    thermal_limit_emergency::Float64 = 0.0 # Emergency thermal limit for the line
end

"""
    regularization_term(interval::LineBaseInterval, Pt1, Pt2, theta1, theta2)

Compute regularization term for LineBaseInterval transmission line optimization
"""
#=
function regularization_term(interval::LineBaseInterval, Pt1, Pt2, theta1, theta2)
    reg_term = AffExpr(0.0)
    
    # APP regularization terms for power flows
    add_to_expression!(reg_term, interval.beta/2, (Pt1 - interval.Pt_prev), (Pt1 - interval.Pt_prev))
    add_to_expression!(reg_term, interval.beta/2, (Pt2 + interval.Pt_prev), (Pt2 + interval.Pt_prev))
    
    # APP regularization terms for voltage angles
    theta_diff = theta1 - theta2
    add_to_expression!(reg_term, interval.beta/2, (theta_diff - interval.theta_diff_prev), (theta_diff - interval.theta_diff_prev))
    
    # APP consensus terms
    add_to_expression!(reg_term, interval.lambda_flow, Pt1)
    add_to_expression!(reg_term, interval.lambda_angle, theta_diff)
    
    # ADMM consensus terms (power flow relationship)
    power_flow_violation = Pt1 - (theta_diff / interval.reactance)
    add_to_expression!(reg_term, interval.rho/2, power_flow_violation, power_flow_violation)
    
    return reg_term
end

"""
    regularization_term(interval::LineRNDInterval, Pt1, Pt2, theta1, theta2)

Compute regularization term for LineRNDInterval transmission line optimization during restoration
"""

function regularization_term(interval::LineRNDInterval, Pt1, Pt2, theta1, theta2)
    reg_term = AffExpr(0.0)
    
    # APP regularization terms for power flows (with restoration factor)
    restoration_prev = interval.restoration_factor * interval.Pt_prev
    add_to_expression!(reg_term, interval.beta/2, (Pt1 - restoration_prev), (Pt1 - restoration_prev))
    add_to_expression!(reg_term, interval.beta/2, (Pt2 + restoration_prev), (Pt2 + restoration_prev))
    
    # APP regularization terms for voltage angles
    theta_diff = theta1 - theta2
    add_to_expression!(reg_term, interval.beta/2, (theta_diff - interval.theta_diff_prev), (theta_diff - interval.theta_diff_prev))
    
    # APP consensus terms
    add_to_expression!(reg_term, interval.lambda_flow, Pt1)
    add_to_expression!(reg_term, interval.lambda_angle, theta_diff)
    
    # ADMM consensus terms (power flow relationship with restoration considerations)
    power_flow_violation = Pt1 - (theta_diff / interval.reactance)
    add_to_expression!(reg_term, interval.rho/2, power_flow_violation, power_flow_violation)
    
    # Emergency mode penalty (if needed as constraint, add separately)
    if interval.emergency_mode
        # This would typically be handled as a constraint rather than in the objective
        # But if needed as penalty:
        # emergency_violation = max(0, abs(Pt1) - interval.thermal_limit_emergency)
        # This requires special handling for non-smooth functions
    end
    
    return reg_term
end
=#