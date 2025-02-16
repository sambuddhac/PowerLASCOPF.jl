@kwdef mutable struct GenSolver{T<:Union{ThermalGen,RenewableGen,HydroGen}, U<:GenIntervals}<:AbstractModel
    generator_type::T # Generator type
    interval_type::U # Interval type
    lambda_1::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    lambda_2::Float64 # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B::Float64 # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    D::Float64 # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    cont_count::Int64 #Number of contingency scenarios
    rho::Float64 = 1 # ADMM tuning parameter
    beta::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    beta_inner::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    gamma::Float64 = 1 # APP tuning parameter for across the dispatch intervals
    gamma_sc::Float64 = 1 # APP tuning parameter
    lambda_1_sc::Array{Float64} # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init::Float64 = 0 # Generator injection from last iteration for base case and contingencies
    Pg_N_avg::Float64 = 0 # Net average power from last iteration for base case and contingencies
    thetag_N_avg::Float64 = 0 # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N::Float64 = 0 # Dual variable for net power balance for base case and contingencies
    vg_N::Float64 = 0 #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg::Float64 = 0 # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu::Float64 = 0 # Previous iterates of the corresponding decision variable values
    PgNuInner::Float64 = 0 # Previous iterates of the corresponding decision variable values
    PgNextNu::Float64 = 0 # Previous iterates of the corresponding decision variable values
    PgPrev::Float64 = 0 # Generator's output in the previous interval
    BSC::Array{Float64} # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
end

    
    
    function GenSolver(
    lambda_1, lambda_2, # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    D;  # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    cont_count=1,  #Number of contingency scenarios
    rho=1, # ADMM tuning parameter
    beta=1, # APP tuning parameter for across the dispatch intervals
    beta_inner=1, # APP tuning parameter for across the dispatch intervals
    gamma=1, # APP tuning parameter for across the dispatch intervals
    gammaSC=1, # APP tuning parameter
    lambda_1SC::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    Pg_N_init=0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg=0, # Net average power from last iteration for base case and contingencies
    thetag_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N=0, # Dual variable for net power balance for base case and contingencies
    vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu=0, PgNuInner=0, PgNextNu=0, # Previous iterates of the corresponding decision variable values
    PgPrev=0, # Generator's output in the previous interval
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    )
    start_t = now()
    end

    function gensolver_decision_variable()

        @variables model begin
            0 <= Pg # Generator real power output
            0 <= PgNext # Generator's belief about its output in the next interval
            thetag # Generator bus angle for base case
        end
    end

    function gensolver_constraints()
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
    end

    function gensolver_objective()
        @objective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((Pg-PgNu)^2+(PgNext-PgNextNu)^2)+(beta_inner/2)*((Pg-PgNuInner)^2)
        +(gammaSC)*(sum(Pg*BSC[i] for i in 1:cont_count))+sum(Pg*lambda_1SC[i] for i in 1:cont_count)+(gamma)*(Pg*B+PgNext*D)+lambda_1*Pg
        +lambda_2*PgNext+(rho/2)*((Pg-Pg_N_init+Pg_N_avg+ug_N)^2+(thetag-Vg_N_avg-thetag_N_avg+vg_N)^2))
    end

    function gelsolver_solve()
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




