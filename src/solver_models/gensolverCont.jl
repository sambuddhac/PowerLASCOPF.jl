#=
    #gelsolverFirst() for first interval OPF solver for generator with dummy sero interval

    #Author: Sambuddha Chakrabarti
    #This is the general Generator Optimization Model for the contingency case: Use it for dummy zero interval contingency case as well
=#

import Pkg
Pkg.add("Gurobi")
Pkg.add("GLPK")
Pkg.add("MathOptInterfaceMosek")
Pkg.add("MathOptInterface")
Pkg.add("Cbc")
Pkg.add("Cbc")
using JuMP
using Gurobi
using GLPK
using MathOptInterfaceMosek
using Cbc
using Ipopt
using MathOptInterface

function gensolverCont(
  BSC::Float64, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
  lambda_2SC::Float64; # APP Lagrange Multiplier corresponding to the complementary slackness
  rho=1, # ADMM tuning parameter
  betaInner=1,# APP tuning parameter
  gammaSC=1, # APP tuning parameter
  PgMax=100, PgMin=0, # Generator Limits
  c2=1, c1=1, c0=1, # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init=0, # Generator injection from last iteration for base case and contingencies
  Pg_N_avg=0, # Net average power from last iteration for base case and contingencies
  Thetag_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N=0, # Dual variable for net power balance for base case and contingencies
  vg_N=0, #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgNuInner=0, # Previous iterates of the corresponding decision variable values
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
  Thetag # Generator bus angle for base case and contingencies
end

@constraints model begin
  Pg <= PgMax
  Pg >= PgMin
end

@NLobjective(model, Min, c2*(Pg^2)+c1*Pg+c0+(betaInner/2)*((Pg-PgNuInner)^2)+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(rho/2)*((Pg-Pg_N_init+Pg_N_avg+ug_N)^2+(Thetag-Vg_N_avg-Thetag_N_avg+vg_N)^2))


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
    "Generator_Self_MW_Belief" => JuMP.value(Pg),
    "Generator_Self_voltAngle_Belief" => JuMP.value(Thetag),
    "Generator_Optimal_Cost" => JuMP.objective_value(model),
)

return results
end