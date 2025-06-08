abstract type AbstractModel end
abstract type IntervalType end
abstract type GenIntervals <: IntervalType end
abstract type LineIntervals <: IntervalType end
abstract type LoadIntervals <: IntervalType end

@kwdef mutable struct ExtendedRenewableGenerationCost{T<:GenIntervals}<:AbstractModel 
    renewable_cost_core::RenewableGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

@kwdef mutable struct ExtendedHydroGenerationCost{T<:GenIntervals}<:AbstractModel 
    hydro_cost_core::HydroGenerationCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

@kwdef mutable struct ExtendedStorageGenerationCost{T<:GenIntervals}<:AbstractModel 
    storage_cost_core::StorageCost # Coefficient of the quadratic term
    regularization_term::T # Regularization Term
end

"""
    @kwdef mutable struct ExtendedGeneratorCost{T<:GenIntervals}<:AbstractModel
        generator_cost_core::GeneratorCost # Coefficient of the quadratic term
        regularization_term::T # Regularization Term
    end

    This is the struct for implementing extended generator cost model with additional regularization term. This is needed for solving (N-1-1)
    contingency cases in the extended generator cost model.
        - generator_cost_core::GeneratorCost # Coefficient of the quadratic term
        - regularization_term::T # Regularization Term
    dimensions
  dim=200
end
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

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(Pg-PgNu)+sum(square(PgNext-PgNextNu)))+(betaInner/2)*(square(Pg-PgNuInner))+(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(sum(Pg*B)+(PgNext)'*D)+sum(Pg*lambda_1)+(lambda_2)'*PgNext+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= PgNext-Pg*ones <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""

mutable struct GenFirstBaseInterval <: GenIntervals
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

function GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho = 1.0,
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

function GenFirstBaseInterval(; lambda_1 = Float64[], 
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
                              lambda_1_sc::Array{Float64} = Float64[], 
                              Pg_N_init::Float64 = 0.0, 
                              Pg_N_avg::Float64 = 0.0, 
                              thetag_N_avg::Float64 = 0.0, 
                              ug_N::Float64 = 0.0, 
                              vg_N::Float64 = 0.0, 
                              Vg_N_avg::Float64 = 0.0, 
                              Pg_nu::Float64 = 0.0, 
                              Pg_nu_inner::Float64 = 0.0, 
                              Pg_next_nu::Array{Float64} = Float64[], 
                              Pg_prev::Float64 = 0.0)
    GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end

function GenFirstBaseInterval_kwarg_constructor(; kwargs...)
    GenFirstBaseInterval(; kwargs...)
end

function GenFirstBaseInterval(lambda_1::Array{Float64}, lambda_2::Array{Float64}, B::Array{Float64}, D::Array{Float64}, BSC::Array{Float64}, cont_count::Int64, rho::Float64 = 1.0, beta::Float64 = 1.0, beta_inner::Float64 = 1.0, gamma::Float64 = 1.0, gamma_sc::Float64 = 1.0, lambda_1_sc::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_N_init::Float64 = 0.0, Pg_N_avg::Float64 = 0.0, thetag_N_avg::Float64 = 0.0, ug_N::Float64 = 0.0, vg_N::Float64 = 0.0, Vg_N_avg::Float64 = 0.0, Pg_nu::Float64 = 0.0, Pg_nu_inner::Float64 = 0.0, Pg_next_nu::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_prev::Float64 = 0.0)
    GenFirstBaseInterval(lambda_1, lambda_2, B, D, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end

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
mutable struct GenFirstBaseIntervalDZ <: GenIntervals
    rho::Float64 = 1 # ADMM tuning parameter
    beta::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 = 1 # APP tuning parameter
    gamma::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 = 1 # APP tuning parameter
    lambda_1::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness 
    lambda_3::Float64
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1_sc::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init::Float64 = 0 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 = 0 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 = 0 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 = 0 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 = 0 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 = 0 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} = 0 # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 = 0 # Generator's output in the previous interval
    A::Float64 # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    B::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D::Array{Float64} # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    cont_count::Int64 #Number of contingency scenarios
end

function GenFirstBaseIntervalDZ(lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, cont_count, rho = 1.0,
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
                              Pg_prev_nu::Float64 = 0.0)
    GenFirstBaseIntervalDZ(lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev_nu)
end

function GenFirstBaseIntervalDZ(; lambda_1 = Float64[], 
                              lambda_2 = Float64[], 
                              lambda_3::Float64 = 0.0, 
                              lambda_4::Float64 = 0.0, 
                              B = Float64[], 
                              D = Float64[], 
                              A::Float64 = 0.0, 
                              BSC = Float64[], 
                              cont_count::Int64 = 0, 
                              rho::Float64 = 1.0, 
                              beta::Float64 = 1.0, 
                              beta_inner::Float64 = 1.0, 
                              gamma::Float64 = 1.0, 
                              gamma_sc::Float64 = 1.0, 
                              lambda_1_sc::Array{Float64} = Float64[], 
                              Pg_N_init::Float64 = 0.0, 
                              Pg_N_avg::Float64 = 0.0, 
                              thetag_N_avg::Float64 = 0.0, 
                              ug_N::Float64 = 0.0, 
                              vg_N::Float64 = 0.0, 
                              Vg_N_avg::Float64 = 0.0, 
                              Pg_nu::Float64 = 0.0, 
                              Pg_nu_inner::Float64 = 0.0, 
                              Pg_next_nu::Array{Float64} = Float64[], 
                              Pg_prev_nu::Float64 = 0.0)
    GenFirstBaseIntervalDZ(lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, cont_count, rho, beta, beta_inner, gamma, gamma_sc, lambda_1_sc, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev_nu)
end
function GenFirstBaseIntervalDZ_kwarg_constructor(; kwargs...)
    GenFirstBaseIntervalDZ(; kwargs...)
end

function GenFirstBaseIntervalDZ(::Nothing)
    GenFirstBaseIntervalDZ(; lambda_1 = Float64[], 
                         lambda_2 = Float64[], 
                         lambda_3 = 0.0, 
                         lambda_4 = 0.0, 
                         B = Float64[], 
                         D = Float64[], 
                         A = 0.0, 
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
                         Pg_prev_nu = 0.0)
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
mutable struct GenFirstContInterval <: GenIntervals
    rho::Float64 = 1 # ADMM tuning parameter
    beta::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 = 1 # APP tuning parameter
    gamma::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 = 1 # APP tuning parameter
    lambda_1_sc::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1::Array{Float64}
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    B::Array{Float64}# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array{Float64}# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    BSC::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init::Float64 = 0 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 = 0 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 = 0 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 = 0 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 = 0 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 = 0 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev::Float64 = 0 # Generator's output in the previous interval
end

function GenFirstContInterval(lambda_1, lambda_2, B, D, BSC, Pg_N_init = 0.0, Pg_N_avg = 0.0, thetag_N_avg = 0.0, ug_N = 0.0, vg_N = 0.0, Vg_N_avg = 0.0, Pg_nu = 0.0, Pg_nu_inner = 0.0, Pg_next_nu::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_prev::Float64 = 0.0; rho = 1.0, beta::Float64 = 1.0, beta_inner::Float64 = 1.0, gamma::Float64 = 1.0, gamma_sc::Float64 = 1.0)
    GenFirstContInterval(rho, beta, beta_inner, gamma, gamma_sc, lambda_1, lambda_2, B, D, BSC, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end
function GenFirstContInterval(; lambda_1 = Float64[], 
                              lambda_2 = Float64[], 
                              B = Float64[], 
                              D = Float64[], 
                              BSC::Float64 = 0.0, 
                              Pg_N_init::Float64 = 0.0, 
                              Pg_N_avg::Float64 = 0.0, 
                              thetag_N_avg::Float64 = 0.0, 
                              ug_N::Float64 = 0.0, 
                              vg_N::Float64 = 0.0, 
                              Vg_N_avg::Float64 = 0.0, 
                              Pg_nu::Float64 = 0.0, 
                              Pg_nu_inner::Float64 = 0.0, 
                              Pg_next_nu::Array{Float64} = Float64[], 
                              Pg_prev::Float64 = 0.0,
                              rho::Float64 = 1.0, 
                              beta::Float64 = 1.0, 
                              beta_inner::Float64 = 1.0, 
                              gamma::Float64 = 1.0, 
                              gamma_sc::Float64 = 1.0)
    GenFirstContInterval(rho, beta, beta_inner, gamma, gamma_sc, lambda_1, lambda_2, B, D, BSC, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev)
end
function GenFirstContInterval_kwarg_constructor(; kwargs...)
    GenFirstContInterval(; kwargs...)
end

function GenFirstContInterval(::Nothing)
    GenFirstContInterval(; lambda_1 = Float64[], 
                         lambda_2 = Float64[], 
                         B = Float64[], 
                         D = Float64[], 
                         BSC = 0.0, 
                         Pg_N_init = 0.0, 
                         Pg_N_avg = 0.0, 
                         thetag_N_avg = 0.0, 
                         ug_N = 0.0, 
                         vg_N = 0.0, 
                         Vg_N_avg = 0.0, 
                         Pg_nu = 0.0, 
                         Pg_nu_inner = 0.0, 
                         Pg_next_nu = Float64[], 
                         Pg_prev = 0.0,
                         rho = 1.0, 
                         beta = 1.0, 
                         beta_inner = 1.0, 
                         gamma = 1.0, 
                         gamma_sc = 1.0)
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
mutable struct GenFirstContIntervalDZ <: GenIntervals
    rho::Float64 = 1 # ADMM tuning parameter
    beta::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 = 1 # APP tuning parameter
    gamma::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 = 1 # APP tuning parameter
    lambda_1_sc::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1::Array{Float64}
    lambda_2::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_3::Float64
    lambda_4::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness
    B::Array{Float64}# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array{Float64}# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    A::Float64 # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    BSC::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    Pg_N_init::Float64 = 0 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 = 0 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 = 0 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 = 0 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 = 0 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 = 0 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    Pg_nu::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_nu_inner::Float64 = 0 # Previous iterates of the corresponding decision variable values
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    Pg_prev_nu::Float64 = 0 # Generator's output in the previous interval
end

function GenFirstContIntervalDZ(lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, Pg_N_init = 0.0, Pg_N_avg = 0.0, thetag_N_avg = 0.0, ug_N = 0.0, vg_N = 0.0, Vg_N_avg = 0.0, Pg_nu = 0.0, Pg_nu_inner = 0.0, Pg_next_nu::Array{Float64} = zeros(Float64, length(lambda_1)), Pg_prev_nu::Float64 = 0.0; rho = 1.0, beta::Float64 = 1.0, beta_inner::Float64 = 1.0, gamma::Float64 = 1.0, gamma_sc::Float64 = 1.0)
    GenFirstContIntervalDZ(rho, beta, beta_inner, gamma, gamma_sc, lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev_nu)
end
function GenFirstContIntervalDZ(; lambda_1 = Float64[], 
                              lambda_2 = Float64[], 
                              lambda_3::Float64 = 0.0, 
                              lambda_4::Float64 = 0.0, 
                              B = Float64[], 
                              D = Float64[], 
                              A::Float64 = 0.0, 
                              BSC::Float64 = 0.0, 
                              Pg_N_init::Float64 = 0.0, 
                              Pg_N_avg::Float64 = 0.0, 
                              thetag_N_avg::Float64 = 0.0, 
                              ug_N::Float64 = 0.0, 
                              vg_N::Float64 = 0.0, 
                              Vg_N_avg::Float64 = 0.0, 
                              Pg_nu::Float64 = 0.0, 
                              Pg_nu_inner::Float64 = 0.0, 
                              Pg_next_nu::Array{Float64} = Float64[], 
                              Pg_prev_nu::Float64 = 0.0,
                              rho::Float64 = 1.0, 
                              beta::Float64 = 1.0, 
                              beta_inner::Float64 = 1.0, 
                              gamma::Float64 = 1.0, 
                              gamma_sc::Float64 = 1.0)
    GenFirstContIntervalDZ(rho, beta, beta_inner, gamma, gamma_sc, lambda_1, lambda_2, lambda_3, lambda_4, B, D, A, BSC, Pg_N_init, Pg_N_avg, thetag_N_avg, ug_N, vg_N, Vg_N_avg, Pg_nu, Pg_nu_inner, Pg_next_nu, Pg_prev_nu)
end
function GenFirstContIntervalDZ(; kwargs...)
    GenFirstContIntervalDZ(; kwargs...)
end

function GenFirstContIntervalDZ(::Nothing)
    GenFirstContIntervalDZ(; lambda_1 = Float64[], 
                         lambda_2 = Float64[], 
                         lambda_3 = 0.0, 
                         lambda_4 = 0.0, 
                         B = Float64[], 
                         D = Float64[], 
                         A = 0.0, 
                         BSC = 0.0, 
                         Pg_N_init = 0.0, 
                         Pg_N_avg = 0.0, 
                         thetag_N_avg = 0.0, 
                         ug_N = 0.0, 
                         vg_N = 0.0, 
                         Vg_N_avg = 0.0, 
                         Pg_nu = 0.0, 
                         Pg_nu_inner = 0.0, 
                         Pg_next_nu = Float64[], 
                         Pg_prev_nu = 0.0,
                         rho = 1.0, 
                         beta = 1.0, 
                         beta_inner = 1.0, 
                         gamma = 1.0, 
                         gamma_sc = 1.0)
end

"""
dimensions
  dim=500
end
parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaInner positive # APP tuning parameter for across the dispatch intervals
  gamma positive # APP tuning parameter for across the dispatch intervals
  lambda_3; lambda_4 # APP Lagrange Multiplier corresponding to the complementary slackness
  gammaSC positive # APP tuning parameter
  lambda_1SC (dim) # APP Lagrange Multiplier corresponding to the complementary slackness
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
  PgPrevNu # Previous iterates of the corresponding decision variable values
  A # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  B # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC (dim) # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  PgNext nonnegative # Generator's belief about its output in the next interval, which is taken as the last iterate value of the present interval belief  
  selectZero # Selection parameter to include or not include the last interval for PgNext constraint on ramping select 0 to not include the constraint, and 1 otherwise
end

variables
  Pg # Generator real power output
  PgPrev # Generator's belief about its output in the previous interval
  Thetag # Generator bus angle for base case
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(PgPrev-PgPrevNu)+square(Pg-PgNu))+(betaInner/2)*(square(Pg-PgNuInner))+(gammaSC)*(sum(Pg*BSC))+sum(Pg*lambda_1SC)+(gamma)*(PgPrev*A+Pg*B)-lambda_3*PgPrev-lambda_4*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= selectZero*(PgNext-Pg) <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""
mutable struct GenLastBaseInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

"""
parameters
  rho positive # ADMM tuning parameter
  beta positive # APP tuning parameter for across the dispatch intervals
  betaSC positive # APP tuning parameter
  gamma positive # APP tuning parameter for across the dispatch intervals
  lambda_3; lambda_4 # APP Lagrange Multiplier corresponding to the complementary slackness
  gammaSC positive # APP tuning parameter
  lambda_2SC # APP Lagrange Multiplier corresponding to the complementary slackness
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
  PgPrevNu # Previous iterates of the corresponding decision variable values
  A # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
  B # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  BSC # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  PgNext nonnegative # Generator's belief about its output in the next interval, which is taken as the last iterate value of the present interval belief  
  selectZero # Selection parameter to include or not include the last interval for PgNext constraint on ramping select 0 to not include the constraint, and 1 otherwise
end

variables
  Pg # Generator real power output
  PgPrev # Generator's belief about its output in the previous interval
  Thetag # Generator bus angle for base case and contingencies
end

minimize
  c2*square(Pg)+c1*Pg+c0+(beta/2)*(square(PgPrev-PgPrevNu)+square(Pg-PgNu))+(betaSC/2)*(square(Pg-PgAPPSC))+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(gamma)*(PgPrev*A+Pg*B)-lambda_3*PgPrev-lambda_4*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
  RgMin <= selectZero*(PgNext-Pg) <= RgMax
  RgMin <= Pg-PgPrev <= RgMax
end
"""

mutable struct GenLastContInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end
"""

"""
mutable struct GenInterRNDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

mutable struct GenInterRSDInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

mutable struct LineBaseInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

mutable struct LineRNDInterval <: LineIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end