#=
    #gelsolverFirstDZ() for first interval OPF solver for generator with dummy zero interval
    #This is the first interval Generator Optimization Model for the base case when there is a dummy zero interval preceding it 
=#

function gensolverFirstDZ(
    PgNextNu::Array, #nonnegative power in the next interval in the previous iteration
    A::Float64, # Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    B::Array,# Disagreement between the generator output values for the previous interval by the present and the previous interval, at the previous iteration
    D::Array,# Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    lambda_1::Array, lambda_2::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_3::Float64, lambda_4::Float64, # APP Lagrange Multiplier corresponding to the complementary slackness
    lambda_1SC::Array; # APP Lagrange Multiplier corresponding to the complementary slackness
    dim=200, #Number of contingency scenarios
    rho = 1,  #positive # ADMM tuning parameter
    beta = 1, #positive # APP tuning parameter for across the dispatch intervals
    betaInner = 1, #positive # APP tuning parameter for across the dispatch intervals
    gamma = 1, #positive # APP tuning parameter for across the dispatch intervals
    gammaSC = 1, #positive # APP tuning parameter
    ones = [1 for i in 1:dim], # Vector of all ones and zeroes
    RgMax = 100, RgMin = -100, #positve; negative # Generator maximum ramp up and ramp down limits
    PgMax = 100, PgMin = 0, #positive;nonnegative # Generator Limits
    c2 = 1, c1 = 1, c0 = 1, #All nonnegative # Generator cost coefficients, quadratic, liear and constant terms respectively
    Pg_N_init = 0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg = 0, # Net average power from last iteration for base case and contingencies
    Thetag_N_avg = 0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N = 0, # Dual variable for net power balance for base case and contingencies
    vg_N = 0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg = 0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu = 0, PgNuInner = 0, # Previous iterates of the corresponding decision variable values 
    PgPrevNu = 0, # Generator's output in the previous interval in previous iteration
    solChoice=1, #Choice of the solver
    )
    start_t = now()

   @variables model begin
        0 <= Pg # Generator real power output
        0 <= PgNext[1:dim] # Generator's belief about its output in the next interval
        PgPrev # Generator's output in the previous interval
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

    @NLobjective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((PgPrev-PgPrevNu)^2+(Pg-PgNu)^2+sum((PgNext[i]-PgNextNu[i])^2 for i in 1:dim))+(betaInner/2)*((Pg-PgNuInner)^2)
    +(gammaSC)*(sum(Pg*BSC[i] for i in 1:dim))+sum(Pg*lambda_1SC[i] for i in 1:dim)+(gamma)*(PgPrev*A+sum(Pg*B[i] for i in 1:dim)
    +sum(PgNext[i]*D[i] for i in 1:dim))+sum(Pg*lambda_1[i] for i in 1:dim)+sum(lambda_2[i]*PgNext[i] for i in 1:dim)-lambda_3*PgPrev-lambda_4*Pg
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
        "Generator_Next_MW_Belief" => JuMP.value(PgNext),
        "Generator_Prev_MW_Belief" => JuMP.value(PgPrev),
        "Generator_Self_voltAngle_Belief" => JuMP.value(Thetag),
        "Generator_Optimal_Cost" => JuMP.objective_value(model),
    )

    return results
end
