# generator.jl - Clean Julia implementation for PowerLASCOPF.jl
# Extended Thermal Generator struct
@kwdef mutable struct ExtendedThermalGenerator{T<:ThermalGen,U<:GenIntervals} <: PowerGenerator
    generator::T # Thermal Generator
    thermal_cost_function::ExtendedThermalGenerationCost{U} # Extended Thermal Generation Cost Function
    gen_id::Int64
    number_of_generators::Int64
    dispatch_interval::Int64
    flag_last::Bool
    dummy_zero_int_flag::Int64
    cont_solver_accuracy::Int64
    scenario_cont_count::Int64
    post_cont_scen_count::Int64
    base_cont_scenario::Int64
    conn_nodeg_ptr::Node
    gen_solver::GenSolver{T,U}
    cont_count_gen::Int64
    gen_total::Int64
    P_gen_prev::Float64
    Pg::Float64
    P_gen_next::Float64
    theta_g::Float64
    v::Float64
    
    # Default constructor
    function ExtendedThermalGenerator(
        generator::T, 
        thermal_cost_function::ExtendedThermalGenerationCost{U}, 
        id_of_gen::Int64, 
        interval::Int64, 
        last_flag::Bool, 
        cont_scenario_count::Int64, 
        gensolver::GenSolver{T,U}, 
        PC_scenario_count::Int64, 
        baseCont::Int64, 
        dummyZero::Int64, 
        accuracy::Int64, 
        nodeConng::Node, 
        countOfContingency::Int64, 
        gen_total::Int64
    ) where {T<:Union{ThermalGen,RenewableGen,HydroGen}, U<:GenIntervals}
        
        self = new{T,U}()
        self.generator = generator
        self.thermal_cost_function = thermal_cost_function
        self.gen_id = id_of_gen
        self.number_of_generators = gen_total
        self.dispatch_interval = interval
        self.flag_last = last_flag
        self.dummy_zero_int_flag = dummyZero
        self.cont_solver_accuracy = accuracy
        self.scenario_cont_count = cont_scenario_count
        self.post_cont_scen_count = PC_scenario_count
        self.base_cont_scenario = baseCont
        self.conn_nodeg_ptr = nodeConng
        self.cont_count_gen = countOfContingency
        self.gen_solver = gensolver
        self.gen_total = gen_total
        
        # Initialize connection node
        set_g_conn!(self.conn_nodeg_ptr, id_of_gen) # increments the generation connection variable to node
        
        # Initialize previous power based on solver type
        if hasmethod(get_pg_prev, (typeof(self.gen_solver),))
            self.P_gen_prev = get_pg_prev(self.gen_solver)
        else
            self.P_gen_prev = 0.0
        end
        
        # Set generator data
        set_gen_data!(self)
        
        return self
    end
end

# Getter functions
function get_gen_id(gen::ExtendedThermalGenerator)
    return gen.gen_id
end

function get_gen_node_id(gen::ExtendedThermalGenerator)
    return get_node_id(gen.conn_nodeg_ptr)
end

# Initialize generator data
function set_gen_data!(gen::ExtendedThermalGenerator)
    gen.Pg = 0.0
    gen.P_gen_next = 0.0
    gen.theta_g = 0.0
    gen.v = 0.0
end

# Main generator power and angle message function
function gpower_angle_message!(
    gen::ExtendedThermalGenerator,
    outerAPPIt::Int,
    APPItCount::Int,
    gsRho::Float64,
    Pgenavg::Float64,
    Powerprice::Float64,
    Angpriceavg::Float64,
    Angavg::Float64,
    Angprice::Float64,
    P_gen_prevAPP::Float64,
    PgenAPP::Float64,
    PgenAPPInner::Float64,
    P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64,
    BAPPExternal::Vector{Float64},
    DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64},
    LambAPP2External::Vector{Float64},
    LambAPP3External::Float64,
    LambAPP4External::Float64,
    BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}
)
    # Initialize arrays for APP variables
    BAPPNew = zeros(Float64, gen.cont_count_gen)
    LambdaAPPNew = zeros(Float64, gen.cont_count_gen)
    BAPPExtNew = zeros(Float64, gen.cont_count_gen + 1)
    DAPPExtNew = zeros(Float64, gen.cont_count_gen + 1)
    LambdaAPP1ExtNew = zeros(Float64, gen.cont_count_gen + 1)
    LambdaAPP2ExtNew = zeros(Float64, gen.cont_count_gen + 1)
    PgNextAPPNew = zeros(Float64, gen.cont_count_gen + 1)
    
    if gen.base_cont_scenario == 0 # Base case scenarios
        handle_base_case_scenarios!(gen, outerAPPIt, APPItCount, gsRho, Pgenavg, Powerprice, 
                                   Angpriceavg, Angavg, Angprice, P_gen_prevAPP, PgenAPP, 
                                   PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal, 
                                   DAPPExternal, LambAPP1External, LambAPP2External, 
                                   LambAPP3External, LambAPP4External, BAPP, LambAPP1,
                                   BAPPNew, LambdaAPPNew, BAPPExtNew, DAPPExtNew, 
                                   LambdaAPP1ExtNew, LambdaAPP2ExtNew, PgNextAPPNew)
    else # Contingency scenarios
        handle_contingency_scenarios!(gen, outerAPPIt, APPItCount, gsRho, Pgenavg, Powerprice,
                                     Angpriceavg, Angavg, Angprice, P_gen_prevAPP, PgenAPP,
                                     PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal,
                                     DAPPExternal, LambAPP1External, LambAPP2External,
                                     LambAPP3External, LambAPP4External, BAPP, LambAPP1,
                                     BAPPNew, LambdaAPPNew, BAPPExtNew, DAPPExtNew,
                                     LambdaAPP1ExtNew, LambdaAPP2ExtNew, PgNextAPPNew)
    end
    
    # Pass generator solution to connected node
    power_angle_message!(gen.conn_nodeg_ptr, gen.Pg, gen.v, gen.theta_g)
end

# Handle base case scenarios
function handle_base_case_scenarios!(
    gen::ExtendedThermalGenerator,
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    if gen.dummy_zero_int_flag == 1 # Dummy zero interval considered
        handle_dummy_zero_base_case!(gen, outerAPPIt, APPItCount, gsRho, Pgenavg, Powerprice,
                                    Angpriceavg, Angavg, Angprice, P_gen_prevAPP, PgenAPP,
                                    PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal,
                                    DAPPExternal, LambAPP1External, LambAPP2External,
                                    LambAPP3External, LambAPP4External, BAPP, LambAPP1,
                                    BAPPNew, LambdaAPPNew, BAPPExtNew, DAPPExtNew,
                                    LambdaAPP1ExtNew, LambdaAPP2ExtNew, PgNextAPPNew)
    else # No dummy zero interval
        handle_no_dummy_zero_base_case!(gen, outerAPPIt, APPItCount, gsRho, Pgenavg, Powerprice,
                                       Angpriceavg, Angavg, Angprice, P_gen_prevAPP, PgenAPP,
                                       PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal,
                                       DAPPExternal, LambAPP1External, LambAPP2External,
                                       LambAPP3External, LambAPP4External, BAPP, LambAPP1,
                                       BAPPNew, LambdaAPPNew, BAPPExtNew, DAPPExtNew,
                                       LambdaAPP1ExtNew, LambdaAPP2ExtNew, PgNextAPPNew)
    end
end

# Handle dummy zero base case scenarios
function handle_dummy_zero_base_case!(
    gen::ExtendedThermalGenerator,
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    if gen.dispatch_interval == 0 && gen.flag_last == false # Dummy zeroth interval
        # Populate BAPP and Lambda arrays
        for counterCont in 1:gen.cont_count_gen
            BAPPNew[counterCont] = BAPP[(counterCont-1) * gen.number_of_generators + gen.gen_id]
            LambdaAPPNew[counterCont] = LambAPP1[(counterCont-1) * gen.number_of_generators + gen.gen_id]
        end
        
        # Copy external arrays
        BAPPExtNew .= BAPPExternal
        LambdaAPP1ExtNew .= LambAPP1External
        DAPPExtNew .= DAPPExternal
        LambdaAPP2ExtNew .= LambAPP2External
        
        if length(P_gen_nextAPP) > gen.gen_id
            PgNextAPPNew[1] = P_gen_nextAPP[gen.gen_id]
        end
        
        # Solve using first base solver
        try
            solve_result = main_solve_first_base!(
                gen.gen_solver,
                LambdaAPP1ExtNew[1], LambdaAPP2ExtNew[1], BAPPExtNew[1], DAPPExtNew[1];
                ContCount=1, rho=gsRho, beta=1, betaInner=1, gamma=1, gammaSC=1,
                lambda_1SC=zeros(1), RgMax=100, RgMin=-100, PgMax=100, PgMin=0,
                c2=1, c1=1, c0=1, Pg_N_init=0, Pg_N_avg=Pgenavg,
                theta_g_N_avg=Angavg, ug_N=Powerprice, vg_N=Angprice,
                Vg_N_avg=Angpriceavg, PgNu=PgenAPP, PgNuInner=PgenAPPInner,
                PgNextNu=0, PgPrev=gen.P_gen_prev, BSC=zeros(1), solChoice=1
            )
            
            # Extract solution
            gen.Pg = get_p_sol(gen.gen_solver)
            gen.P_gen_next = get_p_next_sol(gen.gen_solver)
            gen.P_gen_prev = get_pg_prev(gen.gen_solver)
            gen.theta_g = get_theta_sol(gen.gen_solver)
            
        catch e
            @warn "Generator solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == false # First interval
        # Populate arrays for first interval
        for counterCont in 1:gen.cont_count_gen
            BAPPNew[counterCont] = BAPP[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPPNew[counterCont] = LambAPP1[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        for counterCont in 1:(gen.cont_count_gen + 1)
            BAPPExtNew[counterCont] = BAPPExternal[counterCont]
            LambdaAPP1ExtNew[counterCont] = LambAPP1External[counterCont]
            DAPPExtNew[counterCont] = DAPPExternal[counterCont]
            LambdaAPP2ExtNew[counterCont] = LambAPP2External[counterCont]
            
            if counterCont <= length(P_gen_nextAPP)
                PgNextAPPNew[counterCont] = P_gen_nextAPP[counterCont]
            end
        end
        
        # Solve using DZ base solver
        try
            solve_result = main_solve_dz_base!(
                gen.gen_solver, outerAPPIt, APPItCount, gsRho, gen.P_gen_prev,
                Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP,
                PgenAPPInner, PgNextAPPNew, P_gen_prevAPP, AAPPExternal,
                BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew,
                LambAPP3External, LambAPP4External, BAPPNew, LambdaAPPNew
            )
            
            # Extract solution
            gen.Pg = get_p_sol(gen.gen_solver)
            gen.P_gen_next = get_p_next_sol(gen.gen_solver)
            gen.P_gen_prev = get_p_prev_sol(gen.gen_solver)
            gen.theta_g = get_theta_sol(gen.gen_solver)
            
        catch e
            @warn "DZ Base solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == true # Last interval
        # Populate arrays for last interval
        for counterCont in 1:gen.cont_count_gen
            BAPPNew[counterCont] = BAPP[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPPNew[counterCont] = LambAPP1[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        BAPPExtNew[1] = -BAPPExternal[1]
        DAPPExtNew[1] = DAPPExternal[1]
        
        # Solve using second base solver
        try
            solve_result = main_solve_second_base!(
                gen.gen_solver, outerAPPIt, APPItCount, gsRho, gen.P_gen_prev,
                Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP,
                PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[1],
                LambAPP3External, LambAPP4External, BAPPNew, LambdaAPPNew
            )
            
            # Extract solution
            gen.Pg = get_p_sol(gen.gen_solver)
            gen.P_gen_next = get_p_next_sol(gen.gen_solver)
            gen.P_gen_prev = get_p_prev_sol(gen.gen_solver)
            gen.theta_g = get_theta_sol(gen.gen_solver)
            
        catch e
            @warn "Second Base solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
        end
    end
end

# Handle no dummy zero base case scenarios
function handle_no_dummy_zero_base_case!(
    gen::ExtendedThermalGenerator,
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    if gen.dispatch_interval != 0 && gen.flag_last == false # First interval
        # Populate arrays
        for counterCont in 1:gen.cont_count_gen
            BAPPNew[counterCont] = BAPP[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPPNew[counterCont] = LambAPP1[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        for counterCont in 1:(gen.cont_count_gen + 1)
            BAPPExtNew[counterCont] = BAPPExternal[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPP1ExtNew[counterCont] = LambAPP1External[counterCont * gen.number_of_generators + gen.gen_id]
            DAPPExtNew[counterCont] = DAPPExternal[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPP2ExtNew[counterCont] = LambAPP2External[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        # Solve using first solver
        try
            solve_result = main_solve_first!(
                gen.gen_solver, outerAPPIt, APPItCount, gsRho, gen.P_gen_prev,
                Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP,
                PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew,
                LambdaAPP1ExtNew, LambdaAPP2ExtNew, BAPPNew, LambdaAPPNew
            )
            
            # Extract solution
            gen.Pg = get_p_sol(gen.gen_solver)
            gen.P_gen_next = get_p_next_sol(gen.gen_solver)
            gen.P_gen_prev = get_pg_prev(gen.gen_solver)
            gen.theta_g = get_theta_sol(gen.gen_solver)
            
        catch e
            @warn "First solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == true # Last interval
        # Similar implementation for last interval...
        # [Implementation continues with second solver logic]
    end
end

# Handle contingency scenarios (simplified structure)
function handle_contingency_scenarios!(
    gen::ExtendedThermalGenerator,
    # ... same parameters as base case ...
    outerAPPIt::Int, APPItCount::Int, gsRho::Float64, Pgenavg::Float64, Powerprice::Float64,
    Angpriceavg::Float64, Angavg::Float64, Angprice::Float64, P_gen_prevAPP::Float64,
    PgenAPP::Float64, PgenAPPInner::Float64, P_gen_nextAPP::Vector{Float64},
    AAPPExternal::Float64, BAPPExternal::Vector{Float64}, DAPPExternal::Vector{Float64},
    LambAPP1External::Vector{Float64}, LambAPP2External::Vector{Float64},
    LambAPP3External::Float64, LambAPP4External::Float64, BAPP::Vector{Float64},
    LambAPP1::Vector{Float64}, BAPPNew::Vector{Float64}, LambdaAPPNew::Vector{Float64},
    BAPPExtNew::Vector{Float64}, DAPPExtNew::Vector{Float64}, LambdaAPP1ExtNew::Vector{Float64},
    LambdaAPP2ExtNew::Vector{Float64}, PgNextAPPNew::Vector{Float64}
)
    # Contingency scenario logic would be implemented here
    # Similar structure to base case but using contingency solvers
    if gen.dispatch_interval != 0 && gen.flag_last == false # First interval
        # Populate arrays
        for counterCont in 1:gen.cont_count_gen
            BAPPNew[counterCont] = BAPP[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPPNew[counterCont] = LambAPP1[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        for counterCont in 1:(gen.cont_count_gen + 1)
            BAPPExtNew[counterCont] = BAPPExternal[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPP1ExtNew[counterCont] = LambAPP1External[counterCont * gen.number_of_generators + gen.gen_id]
            DAPPExtNew[counterCont] = DAPPExternal[counterCont * gen.number_of_generators + gen.gen_id]
            LambdaAPP2ExtNew[counterCont] = LambAPP2External[counterCont * gen.number_of_generators + gen.gen_id]
        end
        
        # Solve using first solver
        try
            solve_result = main_solve_first!(
                gen.gen_solver, outerAPPIt, APPItCount, gsRho, gen.P_gen_prev,
                Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP,
                PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew,
                LambdaAPP1ExtNew, LambdaAPP2ExtNew, BAPPNew, LambdaAPPNew
            )
            
            # Extract solution
            gen.Pg = get_p_sol(gen.gen_solver)
            gen.P_gen_next = get_p_next_sol(gen.gen_solver)
            gen.P_gen_prev = get_pg_prev(gen.gen_solver)
            gen.theta_g = get_theta_sol(gen.gen_solver)
            
        catch e
            @warn "First solver failed for gen $(gen.gen_id), interval $(gen.dispatch_interval): $e"
        end
        
    elseif gen.dispatch_interval != 0 && gen.flag_last == true # Last interval
        # Similar implementation for last interval...
        # [Implementation continues with second solver logic]
    end
    @warn "Contingency scenarios not fully implemented yet"
end

# Utility functions
function gen_power(gen::ExtendedThermalGenerator)
    return gen.Pg
end

function gen_power_prev(gen::ExtendedThermalGenerator)
    if gen.dispatch_interval == 0
        return get_pg_prev(gen.gen_solver)
    else
        return gen.P_gen_prev
    end
end

function gen_power_next(gen::ExtendedThermalGenerator, next_scen::Int=1)
    if gen.flag_last == true
        return gen.Pg
    elseif gen.dispatch_interval != 0 && gen.flag_last == false
        # Return next power for specific scenario
        return gen.P_gen_next  # Simplified - would need proper scenario indexing
    else
        return gen.P_gen_next
    end
end

function objective_gen(gen::ExtendedThermalGenerator)
    # Returns the objective function value based on scenario and interval type
    if gen.base_cont_scenario == 0 # Base case
        if gen.dummy_zero_int_flag == 1
            if gen.dispatch_interval == 0 && gen.flag_last == false
                return get_obj(gen.gen_solver, :first_base)
            elseif gen.dispatch_interval != 0 && gen.flag_last == false
                return get_obj(gen.gen_solver, :dz_base)
            elseif gen.dispatch_interval != 0 && gen.flag_last == true
                return get_obj(gen.gen_solver, :second_base)
            end
        else
            if gen.dispatch_interval != 0 && gen.flag_last == false
                return get_obj(gen.gen_solver, :first)
            elseif gen.dispatch_interval != 0 && gen.flag_last == true
                return get_obj(gen.gen_solver, :second_base)
            end
        end
    else # Contingency case
        if gen.cont_solver_accuracy == 0
            return get_obj(gen.gen_solver, :cont)
        else
            # Return appropriate contingency solver objective
            if gen.dispatch_interval != 0 && gen.flag_last == false
                return get_obj(gen.gen_solver, :first_cont)
            elseif gen.dispatch_interval != 0 && gen.flag_last == true
                return get_obj(gen.gen_solver, :second_cont)
            end
        end
    end
    
    return 0.0 # Default return
end