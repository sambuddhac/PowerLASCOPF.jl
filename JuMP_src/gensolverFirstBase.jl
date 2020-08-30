#=
    #gelsolverFirstBase() for Dummy zero interval OPF solver for generator

    #Author: Sambuddha Chakrabarti
    #This is the dummy zero Generator Optimization Model for the base case
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

function gensolverFirstBase(
    lambda_1, lambda_2, # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    D;  # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    ContCount=1,  #Number of contingency scenarios
    rho=1, # ADMM tuning parameter
    beta=1, # APP tuning parameter for across the dispatch intervals
    betaInner=1, # APP tuning parameter for across the dispatch intervals
    gamma=1, # APP tuning parameter for across the dispatch intervals
    gammaSC=1, # APP tuning parameter
    lambda_1SC::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    RgMax=100, RgMin=-100, # Generator maximum ramp up and ramp down limits
    PgMax=100, PgMin=0, # Generator Limits
    c2=1, c1=1, c0=1, # Generator cost coefficients, quadratic, liear and constant terms respectively
    Pg_N_init=0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg=0, # Net average power from last iteration for base case and contingencies
    Thetag_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N=0, # Dual variable for net power balance for base case and contingencies
    vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu=0, PgNuInner=0, PgNextNu=0, # Previous iterates of the corresponding decision variable values
    PgPrev=0, # Generator's output in the previous interval
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    solChoice=1, #Choice of the solver
    )
    start_t = now()
    if solChoice == 1
        model = Model(with_optimizer(Gurobi.Optimizer, OUTPUTLOG=OUTPUTLOG, MAXTIME=-MAXTIME))
    elseif solChoice == 2
        model = Model(with_optimizer(GLPK.Optimizer, OUTPUTLOG=OUTPUTLOG, MAXTIME=-MAXTIME))
    elseif solChoice == 3
        model = Model(with_optimizer(MathOptInterfaceMosek.Optimizer, OUTPUTLOG=OUTPUTLOG, MAXTIME=-MAXTIME))
    elseif solChoice == 4
        model = Model(with_optimizer(Cbc.Optimizer, OUTPUTLOG=OUTPUTLOG, MAXTIME=-MAXTIME))
    elseif solChoice == 5
        model = Model(with_optimizer(Ipopt.Optimizer, OUTPUTLOG=OUTPUTLOG, MAXTIME=-MAXTIME))
    else
        error("Invalid Solver Choice:", solChoice)
    end

    @variables model begin
        0 <= Pg # Generator real power output
        0 <= PgNext # Generator's belief about its output in the next interval
        Thetag # Generator bus angle for base case
    end

    @constraints model begin
        Pg <= PgMax
        Pg >= PgMin
        PgNext <= PgMax
        PgNext >= PgMin
        PgNext-Pg <= RgMax
        PgNext-Pg >= RgMin
        Pg-PgPrev <= RgMax
        Pg-PgPrev >= RgMin
    end

    @NLobjective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((Pg-PgNu)^2+(PgNext-PgNextNu)^2)+(betaInner/2)*((Pg-PgNuInner)^2)
    +(gammaSC)*(sum(Pg*BSC[i] for i in 1:ContCount))+sum(Pg*lambda_1SC[i] for i in 1:ContCount)+(gamma)*(Pg*B+PgNext*D)+lambda_1*Pg
    +lambda_2*PgNext+(rho/2)*((Pg-Pg_N_init+Pg_N_avg+ug_N)^2+(Thetag-Vg_N_avg-Thetag_N_avg+vg_N)^2))

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

    results = Dict(
        "expected_profit" => expected_profit,
        "VaR" => VaR,
        "CVaR" => JuMP.value(CVaR),
        "energy_sell" => energy_sell,
        "energy_buy" => energy_buy,
	    "z_sell" => z_sell, #SamChakra
	    "z_buy" => z_buy, #SamChakra
        "price_sell" =>  convert(Array{Float64,1}, non_zero_energy_offers),
        "price_buy" =>  convert(Array{Float64,1}, non_zero_energy_bids),
        "mean_mkt_prices" => mean_mkt_prices,
        "time_ms" => elapsed.value,
        "eta_stor_in" => eta_stor_in,
        "eta_stor_out" => eta_stor_out,
    )

    return results
end




