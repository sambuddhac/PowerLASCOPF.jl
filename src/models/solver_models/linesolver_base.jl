#=
    #gelsolverFirstBase() for Dummy zero interval OPF solver for generator

    #Author: Sambuddha Chakrabarti
    #This is the first interval Transmission line Optimization Model for the base case
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

function linesolverBase(
    lambda_TXR::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    ECoeff::Array, #Line temperature evolution coefficients
    PgNextNu::Array, # Previous iterates of the corresponding decision variable values
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    ETempCoeff::Array;
    alphaFactor=0.05, #Fraction of line MW flow, which is the Ohmic loss
    betaFactor=,
    beta=, # APP tuning parameter for across the dispatch intervals
    gamma=, # APP tuning parameter for across the dispatch intervals
    PtMax=100000, # Line flow MW Limits
    tempInit=340, #Initial line temperature in Kelvin
    tempAmb=300, #Ambient temperature in Kelvin
    maxTemp=473, #Maximum allowed line temerature in Kelvin
    RNDInt=6, #Number of intervals for restoration to nominal/normal flows
    ContCount=1, #Number of contingency scenarios
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
    One = repeat([1], ContCount, (RNDInt-1))

    @variables model begin
        0 <= Pt # Generator real power output
        0 <= PtNext[1:ContCount, 1:(RNDInt-1)] # Generator's belief about its output in the next interval
    end

    @constraints model begin
        PtNext .<= One * PtMax
        PtNext .>= One * -PtMax
        for contInd in 1:ContCount 
            for omega in 1:RNDInt
                ECoeff[omega]*tempInit+(1-ECoeff[omega])*tempAmb+(alphaFactor/betaFactor)*(sum((ETempCoeff[i, omega]*(PtNext[contInd, j])^2) for j in 1:(RNDInt-omega))) <= maxTemp
            end
        end
    end

    @NLobjective(model, Min, (beta/2)*(sum(sum((PtNext[i, j]-PtNextNu[i, j])^2 for i in 1:ContCount) for j in 1:(RNDInt-1)))
    +(gamma)*(sum(sum(PtNext[i, j]*BSC[i, j] for i in 1:ContCount) for j in 1:(RNDInt-1)))+sum(sum(PtNext[i, j]*lambda_TXR[i, j] for i in 1:ContCount) for j in 1:(RNDInt-1)))

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
        
    )

    return results
end




