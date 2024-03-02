#=
    #GensolverSecondBase() for second interval base-case OPF solver for generator
    #This is the second (and subsequent) interval Generator Optimization Model for the base case
=#

function gensolverSecondBase(
    PgNext::Float64, # Generator's belief about its output in the next interval, which is taken as the last iterate value of the present interval belief  
    A::Float64, # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    B::Float64, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    lambda_3, lambda_4, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1SC::Array; # APP Lagrange Multiplier corresponding to the complementary slackness
    dim=200,  #Number of contingency scenarios
    rho=1, # ADMM tuning parameter
    beta=1, # APP tuning parameter for across the dispatch intervals
    betaInner=1, # APP tuning parameter for across the dispatch intervals
    gamma=1, # APP tuning parameter for across the dispatch intervals
    gammaSC=1, # APP tuning parameter
    RgMax=100, RgMin=-100, # Generator maximum ramp up and ramp down limits
    PgMax=100, PgMin=0, # Generator Limits
    c2=1, c1=1, c0=1, # Generator cost coefficients, quadratic, liear and constant terms respectively
    Pg_N_init=0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg=0, # Net average power from last iteration for base case and contingencies
    Thetag_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N=0, # Dual variable for net power balance for base case and contingencies
    vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu=0, PgNuInner=0, # Previous iterates of the corresponding decision variable values
    PgPrevNu=0, # Generator's output in the previous interval in previous iteration
    solChoice=1, #Choice of the solver
    )
    start_t = now()

    @variables model begin
        Pg # Generator real power output
        PgPrev # Generator's belief about its output in the previous interval
        Thetag # Generator bus angle for base case
    end

    @constraints model begin
        PgMin <= Pg <= PgMax
        RgMin <= selectZero*(PgNext-Pg) <= RgMax
        RgMin <= Pg-PgPrev <= RgMax
    end

    @NLobjective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((PgPrev-PgPrevNu)^2+(Pg-PgNu)^2)+(betaInner/2)*((Pg-PgNuInner)^2)
    +(gammaSC)*(sum(Pg*BSC[i] for i in 1:dim))+sum(Pg*lambda_1SC[i] for i in 1:dim)+(gamma)*(PgPrev*A+Pg*B)-lambda_3*PgPrev-lambda_4*Pg
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

    results = Dict(
        "Generator_Self_MW_Belief" => JuMP.value(Pg),
        "Generator_Prev_MW_Belief" => JuMP.value(PgPrev),
        "Generator_Self_voltAngle_Belief" => JuMP.value(Thetag),
        "Generator_Optimal_Cost" => JuMP.objective_value(model),
    )

    return results

end
