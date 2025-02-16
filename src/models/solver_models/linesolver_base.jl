@kwdef mutable struct LineSolverBase <: AbstractModel
    lambda_txr::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    E_coeff::Array{Float64} #Line temperature evolution coefficients
    Pg_next_nu::Array{Float64} # Previous iterates of the corresponding decision variable values
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    E_temp_coeff::Array{Float64}
    alpha_factor::Float64 = 0.05 #Fraction of line MW flow, which is the Ohmic loss
    beta_factor::Float64 = 0.1
    beta::Float64 = 0.1 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 = 0.2 # APP tuning parameter for across the dispatch intervals
    Pt_max::Float64 = 100000 # Line flow MW Limits
    temp_init::Float64 = 340 #Initial line temperature in Kelvin
    temp_amb::Float64 = 300 #Ambient temperature in Kelvin
    max_temp::Float64 = 473 #Maximum allowed line temerature in Kelvin
    RND_int::Int64 = 6 #Number of intervals for restoration to nominal/normal flows
    cont_count::Int64 = 1 #Number of contingency scenarios
end

function linesolver_base(m::LineSolverBase)
    One = repeat([1], m.cont_count, (m.RND_int-1))

    @variables model begin
        0 <= Pt # Generator real power output
        0 <= PtNext[1:m.cont_count, 1:(m.RND_int-1)] # Generator's belief about its output in the next interval
    end

    @constraints model begin
        PtNext .<= One * m.Pt_max
        PtNext .>= One * -m.Pt_max
        for contInd in 1:m.cont_count 
            for omega in 1:m.RND_int
                m.E_coeff[omega]*m.temp_init+(1-m.E_coeff[omega])*m.temp_amb
                +(m.alpha_factor/m.beta_factor)*(sum((m.E_temp_coeff[i, omega]
                *(PtNext[contInd, j])^2) for j in 1:(m.RND_int-omega))) <= m.max_temp
            end
        end
    end

    @NLobjective(model, Min, (beta/2)*(sum(sum((PtNext[i, j]-PtNextNu[i, j])^2 for i in 1:cont_count) for j in 1:(RND_int-1)))
    +(gamma)*(sum(sum(PtNext[i, j]*BSC[i, j] for i in 1:cont_count) for j in 1:(RND_int-1)))+sum(sum(PtNext[i, j]*lambda_txr[i, j] for i in 1:cont_count) for j in 1:(RND_int-1)))

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




