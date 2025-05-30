@kwdef mutable struct GenSolver{T<:Union{ExtendedThermalGenerationCost,
    ExtendedRenewableGenarationCost,
    ExtendedHydroGenerationCost,
    ExtendedStorageCost}, U<:GenIntervals}<:AbstractModel
    interval_type::U # Interval type
    cost_curve::T
end

GenSolver(interval_type, cost_curve) = GenSolver(; interval_type, cost_curve)
function GenSolver()

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
            Pg-Pg_prev <= RgMax
            Pg-Pg_prev >= RgMin
        end
    end

    function gensolver_objective()
        @objective(model, Min, c2*(Pg^2)+c1*Pg+c0+(beta/2)*((Pg-Pg_nu)^2+(PgNext-Pg_next_nu)^2)+(beta_inner/2)*((Pg-Pg_nuInner)^2)
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




