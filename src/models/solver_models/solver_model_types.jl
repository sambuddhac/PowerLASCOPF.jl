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
mutable struct GenLastBaseInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

mutable struct GenLastContInterval <: GenIntervals
    Pg::Float64 # Generator real power output
    PgNext::Float64 # Generator's belief about its output in the next interval
    thetag::Float64 # Generator bus angle for base case
end

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