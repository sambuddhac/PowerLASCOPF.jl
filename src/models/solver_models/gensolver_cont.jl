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
  rho positive # ADMM tuning parameter
  betaSC positive # APP tuning parameter
  gammaSC positive # APP tuning parameter
  lambda_2SC # APP Lagrange Multiplier corresponding to the complementary slackness
  PgMax positive; PgMin nonnegative # Generator Limits
  c2 nonnegative; c1 nonnegative; c0 nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
  Pg_N_init # Generator injection from last iteration for base case and contingencies
  Pg_N_avg # Net average power from last iteration for base case and contingencies
  Thetag_N_avg # Net average bus voltage angle from last iteration for base case and contingencies
  ug_N # Dual variable for net power balance for base case and contingencies
  vg_N #  Dual variable for net angle balance for base case and contingencies
  Vg_N_avg # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
  PgAPPSC # Previous iterates of the corresponding decision variable values
  BSC # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
end

variables
  Pg # Generator real power output
  Thetag # Generator bus angle for base case and contingencies
end

minimize
  c2*square(Pg)+c1*Pg+c0+(betaSC/2)*(square(Pg-PgAPPSC))+(gammaSC)*(Pg*BSC)-lambda_2SC*Pg+(rho/2)*(square(Pg-Pg_N_init+Pg_N_avg+ug_N)+square(Thetag-Vg_N_avg-Thetag_N_avg+vg_N))
subject to
  PgMin <= Pg <= PgMax
end