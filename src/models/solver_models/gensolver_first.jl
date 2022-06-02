#=
    #gelsolverFirst() for first interval OPF solver for generator without dummy zero interval

    #Author: Sambuddha Chakrabarti
    #This is the first interval Generator Optimization Model for the base case when there isn't a dummy zero interval preceding it
=#

import Pkg
Pkg.add("Gurobi")
Pkg.add("GLPK")
Pkg.add("MathOptInterfaceMosek")
Pkg.add("MathOptInterface")
Pkg.add("Cbc")
Pkg.add("Ipopt")
using JuMP
using Gurobi
using GLPK
using MathOptInterfaceMosek
using Cbc
using Ipopt
using MathOptInterface

function gensolverFirst(
    dim=200
    rho, # ADMM tuning parameter
    beta, # APP tuning parameter for across the dispatch intervals
    betaInner, # APP tuning parameter for across the dispatch intervals
    gamma, # APP tuning parameter for across the dispatch intervals
    lambda_1::Array, lambda_2::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    gammaSC, # APP tuning parameter
    lambda_1SC::Array; # APP Lagrange Multiplier corresponding to the complementary slackness
    ones = [1 for i in 1:dim], # Vector of all ones and zeroes
    RgMax, RgMin, # Generator maximum ramp up and ramp down limits
    PgMax, PgMin, # Generator Limits
    c2, c1, c0, # Generator cost coefficients, quadratic, liear and constant terms respectively
    Pg_N_init, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg, # Net average power from last iteration for base case and contingencies
    Thetag_N_avg, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N, # Dual variable for net power balance for base case and contingencies
    vg_N, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu, PgNuInner, # Previous iterates of the corresponding decision variable values
    PgNextNu::Array;
    B::Array; # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array; # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    BSC::Array; # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    PgPrev, # Generator's output in the previous interval
    )
    start_t = now()
    if solChoice == 1
        model = Model(with_optimizer(Gurobi.Optimizer))
    elseif solChoice == 2
        model = Model(with_optimizer(GLPK.Optimizer))
    elseif solChoice == 3
        model = Model(with_optimizer(MathOptInterfaceMosek.Optimizer))
    elseif solChoice == 4
        model = Model(with_optimizer(Cbc.Optimizer))
    elseif solChoice == 5
        model = Model(with_optimizer(Ipopt.Optimizer))
    else
        error("Invalid Solver Choice:", solChoice)
    end

    @variables model begin
        0 <= Pg # Generator real power output
        0 <= PgNext[1:dim] # Generator's belief about its output in the next interval
        Thetag # Generator bus angle for base case
    end 

    @constraints model begin
        Pg <= PgMax
        Pg >= PgMin
        PgNext-Pg*ones .<= RgMax
        PgNext-Pg*ones .>= RgMin
        Pg-PgPrev <= RgMax
        Pg-PgPrev >= RgMin
    end

    @NLobjective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((Pg-PgNu)^2+sum((PgNext[i]-PgNextNu[i])^2 for i in 1:dim))+(betaInner/2)*((Pg-PgNuInner)^2)
    +(gammaSC)*(sum(Pg*BSC[i] for i in 1:dim))+sum(Pg*lambda_1SC[i] for i in 1:dim)+(gamma)*(PgPrev*A+sum(Pg*B[i] for i in 1:dim)
    +sum(PgNext[i]*D[i] for i in 1:dim))+sum(Pg*lambda_1[i] for i in 1:dim)+sum(lambda_2[i]*PgNext[i] for i in 1:dim)
    +(rho/2)*((Pg-Pg_N_init+Pg_N_avg+ug_N)^2+(Thetag-Vg_N_avg-Thetag_N_avg+vg_N)^2))

    optimize!(model)
    elapsed = now() - start_t

    tstatus = termination_status(model)
    if tstatus != MathOptInterface.OPTIMAL
        if tstatus == MathOptInterface.INFEASIBLE
            error("Infeasible")
        elseif tstatus == MathOptInterface.TIME_LIMIT
            error("Timed-Out")
        elseif tstatus == MathOptInterface.INFEASIBLE_OR_UNBOUNDED
            error("Infeasible or Unbounded")
        else
            error("Status:", tstatus)
        end
    end

    results = Dict()

    return results
end
