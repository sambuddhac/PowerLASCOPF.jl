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

function linesolver_base(
    lambda_txr::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    ecoeff::Array, #Line temperature evolution coefficients
    Pg_next_nu::Array, # Previous iterates of the corresponding decision variable values
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    E_temp_coeff::Array;
    alpha_factor=0.05, #Fraction of line MW flow, which is the Ohmic loss
    beta_factor=0.02, ##Dummy Value
    beta=0.5, # APP tuning parameter for across the dispatch intervals ##Dummy Value
    gamma=0.25, # APP tuning parameter for across the dispatch intervals ##Dummy Value
    Pt_max=100000, # Line flow MW Limits
    temp_init=340, #Initial line temperature in Kelvin
    temp_amb=300, #Ambient temperature in Kelvin
    max_temp=473, #Maximum allowed line temerature in Kelvin
    RND_int=6, #Number of intervals for restoration to nominal/normal flows
    cont_count=1, #Number of contingency scenarios
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
    One = repeat([1], cont_count, (RND_int-1))

    @variables model begin
        0 <= Pt # Transmission Line real power flow
        0 <= Pt_next[1:cont_count, 1:(RND_int-1)] # Transmission Line's belief about its flow in the next interval
    end

    @constraints model begin
        Pt_next .<= One * Pt_max
        Pt_next .>= One * -Pt_max
        for cont_ind in 1:cont_count 
            for omega in 1:RND_int
                ecoeff[omega]*temp_init+(1-ecoeff[omega])*temp_amb+(alpha_factor/beta_factor)*(sum((E_temp_coeff[cont_ind, omega]*(Pt_next[cont_ind, j])^2) for j in 1:(RND_int-omega))) <= max_temp
            end
        end
    end

    @NLobjective(model, Min, (beta/2)*(sum(sum((Pt_next[i, j]-Pt_next_nu[i, j])^2 for i in 1:cont_count) for j in 1:(RND_int-1)))
    +(gamma)*(sum(sum(Pt_next[i, j]*BSC[i, j] for i in 1:cont_count) for j in 1:(RND_int-1)))+sum(sum(Pt_next[i, j]*lambda_txr[i, j] for i in 1:cont_count) for j in 1:(RND_int-1)))

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
        "Line_Self_Flow_Belief" => JuMP.value(Pt),
        "Line_Next_Flow_Belief" => JuMP.value(Pt_next),
        "Line_Optimal_Objective" => JuMP.objective_value(model),
    )

    return results
end




