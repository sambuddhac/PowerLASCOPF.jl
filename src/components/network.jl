using DataFrames
using CSV
using LinearAlgebra
using Statistics
using JSON3
using PowerSystems
using InfrastructureSystems
using Dates
using Printf
const PSY = PowerSystems
const IS = InfrastructureSystems

# Include component types
include("node.jl")
include("transmission_line.jl")
include("GeneralizedGenerator.jl")
include("../extensions/extended_system.jl")
include("../io/readers/read_csv_inputs.jl")
include("../io/readers/read_inputs_and_parse.jl")
include("../io/readers/make_lanl_ansi_pm_compatible.jl")
include("../io/readers/make_nrel_sienna_compatible.jl")
include("../io/readers/read_json_inputs.jl")

"""
Network structure for PowerLASCOPF optimization
Represents a complete power system network with generators, loads, transmission lines, and nodes
"""
@kwdef mutable struct Network
    # Core PowerLASCOPFSystem integration
    net_sys::Union{PowerLASCOPFSystem, Nothing} = nothing
    
    # Network identification
    network_id::Int = 0
    scenario_index::Int = 0
    post_cont_scenario::Int = 0
    pre_post_cont_scen::Bool = false
    
    # Component counts
    gen_number::Int = 0
    load_number::Int = 0
    transl_number::Int = 0
    device_term_count::Int = 0
    node_number::Int = 0
    
    # Algorithm parameters
    dummy_z::Int = 0
    accuracy::Int = 1
    rho::Float64 = 1.0
    interval_id::Int = 0
    last_flag::Int = 0
    contingency_count::Int = 0
    solver_choice::Int = 1  # 1=IPOPT, 2=Gurobi
    verbose::Bool = false
    
    # Outage tracking
    outaged_line::Vector{Int} = Int[]
    outaged_line_single::Int = 0
    base_outaged_line::Int = 0
    
    # ADMM/APP coordination variables
    p_self_belief::Vector{Float64} = Float64[]
    p_self_belief_inner::Vector{Float64} = Float64[]
    p_prev_belief::Vector{Float64} = Float64[]
    p_next_belief::Vector{Float64} = Float64[]
    
    # Node connectivity tracking
    conn_node_num_list::Vector{Int} = Int[]
    node_val_list::Vector{Int} = Int[]
    assigned_node_ser::Int = 0
    
    # Buffer arrays for different solvers
    p_self_buffer::Vector{Float64} = Float64[]
    p_prev_buffer::Vector{Float64} = Float64[]
    p_next_buffer::Vector{Float64} = Float64[]
    p_self_buffer_gurobi::Vector{Float64} = Float64[]
    p_next_buffer_gurobi::Vector{Float64} = Float64[]
    p_prev_buffer_gurobi::Vector{Float64} = Float64[]
    
    # Result strings and file paths
    matrix_result_string::String = ""
    dev_prod_string::String = ""
    iteration_result_string::String = ""
    lmp_result_string::String = ""
    objective_result_string::String = ""
    primal_result_string::String = ""
    dual_result_string::String = ""
    
    # Performance tracking
    gen_single_time_vec::Vector{Float64} = Float64[]
    gen_admm_max_time_vec::Vector{Float64} = Float64[]
    virtual_exec_time::Float64 = 0.0
    div_conv_mwpu::Float64 = 100.0  # MW per unit conversion
    
    # Component objects
    gen_object::Vector{GeneralizedGenerator} = GeneralizedGenerator[]
    load_object::Vector{Load} = Load[]  # Placeholder for Load type
    transl_object::Vector{transmissionLine} = transmissionLine[]
    node_object::Vector{Node} = Node[]
    
    # Data file paths and case information
    data_path::String = ""
    case_name::String = ""
    case_format::Symbol = :matpower  # :matpower, :psse, :ieee_cdf, :custom
end

"""
Initialize network variables and load system data
"""
function network_init_var(
    pre_post_scenario::Bool;
    net_sys::Union{PowerLASCOPFSystem, Nothing} = nothing,
    data_path::String = "",
    case_name::String = "",
    case_format::Symbol = :matpower
)
    network = Network(
	net_sys = net_sys,
        network_id = net_sys.network_id,
        rho = 1.0,
        scenario_index = net_sys.scenario_index,
        post_cont_scenario = net_sys.post_contingency_scenario,
        pre_post_cont_scen = pre_post_scenario,
        dummy_z = net_sys.dummy_zero_flag,
        accuracy = net_sys.accuracy,
        contingency_count = 0,
        interval_id = net_sys.interval_id,
        last_flag = net_sys.last_flag,
        solver_choice = net_sys.solver_choice,
        data_path = data_path,
        case_name = case_name,
        case_format = case_format
    )
    push!(network.outaged_line, net_sys.outaged_line)
    # Load network data
    set_network_variables!(network)
    
    return network
end

"""
Load network data from files based on case format and create PowerLASCOPFSystem
"""
function set_network_variables!(network::Network)
    println("Setting network variables for network ID: $(network.network_id) ...")

    # Check if PowerLASCOPFSystem already exists and is populated
    if network.net_sys !== nothing
        println("PowerLASCOPFSystem already exists, checking component population...")
        
        # Check if system is already fully populated
        is_populated = check_system_population(network.net_sys)
        
        if is_populated
            println("System is already fully populated, skipping data loading...")
            # Just update counts from existing system
            update_network_counts_from_system!(network)
            initialize_coordination_variables!(network)
            return
        else
            println("System is partially populated, will populate missing components...")
        end
    else
        println("Creating new PowerLASCOPFSystem...")
    
	# Create PowerLASCOPFSystem based on network size or case name
	if !isempty(network.case_name)
		# Use specific case file
		case_file = joinpath(network.data_path, network.case_name)
		network.net_sys = load_case_to_power_lascopf_system(case_file, network.case_format)
	else
		# Use standard IEEE cases
		network.net_sys = create_ieee_case_system(network.network_id, network.data_path)
	end
	
	if network.net_sys === nothing
		error("Failed to create PowerLASCOPFSystem")
	end	
    end

    # Populate missing components
    populate_missing_components!(network)
    
    # Initialize coordination variables
    initialize_coordination_variables!(network)
    
    println("Network setup complete: $(network.node_number) nodes, $(network.gen_number) generators, $(network.transl_number) lines")
end

"""
Check if PowerLASCOPFSystem is fully populated
"""
function check_system_population(sys::PowerLASCOPFSystem)::Bool
    has_nodes = !isempty(get_nodes(sys))
    has_generators = (get_extended_thermal_generator_count(sys) > 0 || 
                     get_extended_hydro_generator_count(sys) > 0 || 
                     get_extended_renewable_generator_count(sys) > 0)
    has_lines = get_transmission_line_count(sys) > 0
    has_loads = any(node -> node.conn_load_val != 0.0, get_nodes(sys))
    println("has_nodes: $has_nodes, has_generators: $has_generators, has_lines: $has_lines, has_loads: $has_loads")
    
    is_fully_populated = has_nodes && has_generators && has_lines
    
    if is_fully_populated
        println("  ✓ System has nodes: $(get_node_count(sys))")
        println("  ✓ System has generators: $(get_extended_thermal_generator_count(sys))")
        println("  ✓ System has transmission lines: $(get_transmission_line_count(sys))")
    else
        println("  Missing components:")
        !has_nodes && println("    ✗ No nodes found")
        !has_generators && println("    ✗ No generators found")
        !has_lines && println("    ✗ No transmission lines found")
    end
    
    return is_fully_populated
end

"""
Check which components are missing and need to be populated
"""
function check_missing_components(sys::PowerLASCOPFSystem)
    missing = Dict{Symbol, Bool}()
    
    missing[:nodes] = isempty(get_nodes(sys))
    missing[:thermal_generators] = get_extended_thermal_generator_count(sys) == 0
    missing[:hydro_generators] = get_extended_hydro_generator_count(sys) == 0
    missing[:renewable_generators] = get_extended_renewable_generator_count(sys) == 0
    missing[:storage_units] = get_extended_storage_unit_count(sys) == 0
    missing[:transmission_lines] = get_transmission_line_count(sys) == 0
    missing[:loads] = all(node -> node.conn_load_val == 0.0, get_nodes(sys))
    
    return missing
end

"""
Populate only the missing components in the network
"""
function populate_missing_components!(network::Network)
    missing = check_missing_components(network.net_sys)
    
    # Update network counts first
    update_network_counts_from_system!(network)
    
    # Populate nodes if missing
    if missing[:nodes]
        println("  Creating nodes from system...")
        create_nodes_from_system!(network)
    else
        println("  ✓ Nodes already exist ($(network.node_number))")
        # Just populate the network.node_object vector from existing nodes
        sync_nodes_from_system!(network)
    end
    
    # Load transmission line data if missing
    if missing[:transmission_lines]
        println("  Loading transmission data...")
        load_transmission_data!(network)
        create_transmission_lines_from_system!(network)
    else
        println("  ✓ Transmission lines already exist ($(network.transl_number))")
        sync_transmission_lines_from_system!(network)
    end
    
    # Load generator data if missing
    if missing[:thermal_generators] && missing[:hydro_generators] && 
       missing[:renewable_generators] && missing[:storage_units]
        println("  Loading generator data from system...")
        load_generator_data_from_system!(network)
    else
        println("  ✓ Generators already exist ($(network.gen_number))")
        sync_generators_from_system!(network)
    end
    
    # Load demand data if missing
    if missing[:loads]
        println("  Loading demand data from system...")
        load_demand_data_from_system!(network)
    else
        println("  ✓ Loads already exist ($(network.load_number))")
        sync_loads_from_system!(network)
    end
end
"""
Update network component counts from existing PowerLASCOPFSystem
"""
function update_network_counts_from_system!(network::Network)
    network.node_number = get_node_count(network.net_sys)
    network.gen_number = (get_extended_thermal_generator_count(network.net_sys) + 
                         get_extended_hydro_generator_count(network.net_sys) + 
                         get_extended_renewable_generator_count(network.net_sys) + 
                         get_extended_storage_unit_count(network.net_sys))
    network.transl_number = get_transmission_line_count(network.net_sys)
    
    # Count loads
    network.load_number = 0
    for node in get_nodes(network.net_sys)
        if node.conn_load_val != 0.0
            network.load_number += 1
        end
    end
end

"""
Sync nodes from PowerLASCOPFSystem to network.node_object (when nodes already exist)
"""
function sync_nodes_from_system!(network::Network)
    if isempty(network.node_object)
        nodes = get_nodes(network.net_sys)
        for node in nodes
            push!(network.node_object, node)
        end
    end
end

"""
Sync transmission lines from PowerLASCOPFSystem to network.transl_object
"""
function sync_transmission_lines_from_system!(network::Network)
    if isempty(network.transl_object)
        create_transmission_lines_from_system!(network)
    end
end

"""
Sync generators from PowerLASCOPFSystem to network.gen_object
"""
function sync_generators_from_system!(network::Network)
    if isempty(network.gen_object)
        load_generator_data_from_system!(network)
    end
end

"""
Sync loads from PowerLASCOPFSystem to network.load_object
"""
function sync_loads_from_system!(network::Network)
    if isempty(network.load_object)
        load_demand_data_from_system!(network)
    end
end

"""
Alternative: Create network from pre-populated PowerLASCOPFSystem
"""
function network_init_var_from_populated_system(
    net_sys::PowerLASCOPFSystem,
    pre_post_scenario::Bool;
    data_path::String = "",
    case_name::String = ""
)
    # Create network with existing system
    network = Network(
        net_sys = net_sys,
        network_id = net_sys.network_id,
        rho = 1.0,
        scenario_index = net_sys.scenario_index,
        post_cont_scenario = net_sys.post_contingency_scenario,
        pre_post_cont_scen = pre_post_scenario,
        dummy_z = net_sys.dummy_zero_flag,
        accuracy = net_sys.accuracy,
        contingency_count = 0,
        interval_id = net_sys.interval_id,
        last_flag = net_sys.last_flag,
        solver_choice = net_sys.solver_choice,
        data_path = data_path,
        case_name = case_name,
        case_format = :custom  # Since system is pre-populated
    )
    
    push!(network.outaged_line, net_sys.outaged_line)
    
    # Check if system is populated and sync components
    if check_system_population(net_sys)
        println("Using pre-populated PowerLASCOPFSystem...")
        update_network_counts_from_system!(network)
        sync_nodes_from_system!(network)
        sync_transmission_lines_from_system!(network)
        sync_generators_from_system!(network)
        sync_loads_from_system!(network)
        initialize_coordination_variables!(network)
    else
        # System is not fully populated, need to load data
        println("System not fully populated, loading missing components...")
        set_network_variables!(network)
    end
    
    return network
end

"""
Create PowerLASCOPFSystem for standard IEEE cases
"""
function create_ieee_case_system(network_id::Int, data_path::String)
    # Create base PowerSystems.System first
    base_power = 100.0
    psy_system = PSY.System(base_power)
    
    # Create PowerLASCOPFSystem
    power_lascopf_sys = PowerLASCOPFSystem(psy_system = psy_system)
    
    # Load IEEE case data based on network_id
    if network_id in [14, 30, 57, 118, 300]
        load_ieee_case_data!(power_lascopf_sys, network_id, data_path)
    else
        error("Unsupported IEEE case size: $network_id")
    end
    
    return power_lascopf_sys
end

"""
Load IEEE case data into PowerLASCOPFSystem
"""
function load_ieee_case_data!(sys::PowerLASCOPFSystem, network_id::Int, data_path::String)
    base_path = isempty(data_path) ? "data" : data_path
    
    # Determine data files
    gen_file = joinpath(base_path, "Gen$(network_id).csv")
    tran_file = joinpath(base_path, "Tran$(network_id).csv") 
    load_file = joinpath(base_path, "Load$(network_id).csv")
    
    # Load data using case readers
    if all(isfile.([gen_file, tran_file, load_file]))
        load_csv_case_data!(sys, gen_file, tran_file, load_file)
    else
        # Try to load from standard PowerSystems test cases
        load_standard_test_case!(sys, network_id)
    end
end

"""
Load case data from custom case file
"""
function load_case_to_power_lascopf_system(case_file::String, case_format::Symbol)
    try
        if case_format == :matpower
            return load_matpower_case_to_power_lascopf(case_file)
        elseif case_format == :psse
            return load_psse_case_to_power_lascopf(case_file)
        elseif case_format == :ieee_cdf
            return load_ieee_cdf_case_to_power_lascopf(case_file)
        else
            error("Unsupported case format: $case_format")
        end
    catch e
        @warn "Failed to load case file $case_file: $e"
        return nothing
    end
end

"""
Load transmission line data and count contingencies
"""
function load_transmission_data!(network::Network)
    lines = get_transmission_lines(network.net_sys)
    network.transl_number = length(lines)
    
    # Count contingency scenarios (lines marked for contingency analysis)
    network.contingency_count = 0
    for line in lines
        # Check if line is marked for contingency (could be in time series or extension data)
        if haskey(IS.get_ext(line.transl_type), "contingency_marked") && 
           IS.get_ext(line.transl_type)["contingency_marked"] == 1
            network.contingency_count += 1
        end
    end
    
    # Store outaged lines for contingency analysis
    if network.pre_post_cont_scen == false
        for (idx, line) in enumerate(lines)
            if haskey(IS.get_ext(line.transl_type), "contingency_marked") && 
               IS.get_ext(line.transl_type)["contingency_marked"] == 1
                push!(network.outaged_line, idx)
            end
        end
    end
end

"""
Create node objects from PowerLASCOPFSystem
"""
function create_nodes_from_system!(network::Network)
    nodes = get_nodes(network.net_sys)
    empty!(network.node_object)
    
    for node in nodes
        push!(network.node_object, node)
    end
    
    network.node_number = length(network.node_object)
end

"""
Create transmission line objects from PowerLASCOPFSystem
"""
function create_transmission_lines_from_system!(network::Network)
    lines = get_transmission_lines(network.net_sys)
    empty!(network.transl_object)
    
    # Filter out outaged lines
    for (idx, line) in enumerate(lines)
        # Skip outaged lines
        if (network.outaged_line_single == idx) || (network.base_outaged_line == idx)
            continue
        end
        
        push!(network.transl_object, line)
    end
    
    network.transl_number = length(network.transl_object)
end

"""
Load generator data from PowerLASCOPFSystem and create GeneralizedGenerator objects
"""
function load_generator_data_from_system!(network::Network)
    # Get all types of generators from the system
    thermal_gens = get_extended_thermal_generators(network.net_sys)
    hydro_gens = get_extended_hydro_generators(network.net_sys)
    renewable_gens = get_extended_renewable_generators(network.net_sys)
    storage_units = get_extended_storage_units(network.net_sys)
    
    empty!(network.gen_object)
    
    # Convert ExtendedThermalGenerators to GeneralizedGenerators
    for thermal_gen in thermal_gens
        gen_gen = convert_to_generalized_generator(thermal_gen, network)
        push!(network.gen_object, gen_gen)
    end
    
    # Convert ExtendedHydroGenerators to GeneralizedGenerators
    for hydro_gen in hydro_gens
        gen_gen = convert_to_generalized_generator(hydro_gen, network)
        push!(network.gen_object, gen_gen)
    end
    
    # Convert ExtendedRenewableGenerators to GeneralizedGenerators
    for renewable_gen in renewable_gens
        gen_gen = convert_to_generalized_generator(renewable_gen, network)
        push!(network.gen_object, gen_gen)
    end
    
    # Convert ExtendedStorageGenerators to GeneralizedGenerators
    for storage_unit in storage_units
        gen_gen = convert_to_generalized_generator(storage_unit, network)
        push!(network.gen_object, gen_gen)
    end
    
    network.gen_number = length(network.gen_object)
end

"""
Convert different generator types to GeneralizedGenerator
"""
function convert_to_generalized_generator(extended_gen::T, network::Network) where T
    if T <: ExtendedThermalGenerator
        # Convert thermal generator
        cost_function = extended_gen.thermal_cost_function
        generator = extended_gen.generator
        connected_node = extended_gen.conn_nodeg_ptr
        
    elseif T <: ExtendedHydroGenerator
        # Convert hydro generator
        cost_function = extended_gen.hydro_cost_function
        generator = extended_gen.generator
        connected_node = extended_gen.conn_nodeg_ptr
        
    elseif T <: ExtendedRenewableGenerator
        # Convert renewable generator
        cost_function = extended_gen.renewable_cost_function
        generator = extended_gen.generator
        connected_node = extended_gen.conn_nodeg_ptr
        
    elseif T <: ExtendedStorageGenerator
        # Convert storage generator
        cost_function = extended_gen.storage_cost_function
        generator = extended_gen.generator
        connected_node = extended_gen.conn_nodeg_ptr
        
    else
        error("Unsupported generator type: $T")
    end
    
    # Create GeneralizedGenerator with appropriate interval type
    interval_type = GenFirstBaseInterval()  # Default interval type
    
    gen_gen = GeneralizedGenerator(
        generator,
        interval_type,
        extended_gen.gen_id,
        network.interval_id,
        network.last_flag == 1,
        network.contingency_count,
        network.post_cont_scenario,
        network.pre_post_cont_scen,
        network.dummy_z,
        network.accuracy,
        connected_node,
        network.contingency_count,
        network.gen_number
    )
    
    return gen_gen
end

"""
Load demand data from PowerLASCOPFSystem
"""
function load_demand_data_from_system!(network::Network)
    nodes = get_nodes(network.net_sys)
    network.load_number = 0
    empty!(network.load_object)
    
    for node in nodes
        if node.conn_load_val != 0.0
            network.load_number += 1
            # Load object creation would go here when Load type is implemented
        end
    end
end

"""
Initialize ADMM/APP coordination variables
"""
function initialize_coordination_variables!(network::Network)
    # Calculate device terminal count
    network.device_term_count = if (network.pre_post_cont_scen == false) && (network.post_cont_scenario == 0)
        network.gen_number + network.load_number + 2 * network.transl_number
    elseif (network.pre_post_cont_scen == false) && (network.post_cont_scenario != 0)
        network.gen_number + network.load_number + 2 * (network.transl_number - 1)
    elseif (network.pre_post_cont_scen != false) && (network.post_cont_scenario == 0)
        network.gen_number + network.load_number + 2 * (network.transl_number - 1)
    else
        network.gen_number + network.load_number + 2 * (network.transl_number - 2)
    end
    
    # Initialize belief vectors
    resize!(network.p_self_belief, network.gen_number)
    resize!(network.p_self_belief_inner, network.gen_number)
    resize!(network.p_prev_belief, network.gen_number)
    resize!(network.p_next_belief, network.gen_number)
    
    # Initialize buffer arrays
    resize!(network.p_self_buffer, network.gen_number)
    resize!(network.p_prev_buffer, network.gen_number)
    resize!(network.p_next_buffer, network.gen_number)
    resize!(network.p_self_buffer_gurobi, network.gen_number)
    resize!(network.p_next_buffer_gurobi, network.gen_number)
    resize!(network.p_prev_buffer_gurobi, network.gen_number)
    
    # Initialize generation beliefs
    if network.interval_id == 0
        for i in 1:network.gen_number
            network.p_self_belief_inner[i] = 0.0
            network.p_self_belief[i] = 0.0
            network.p_prev_belief[i] = network.gen_object[i].P_gen_prev
            network.p_next_belief[i] = 0.0
        end
    else
        fill!(network.p_self_belief_inner, 0.0)
        fill!(network.p_self_belief, 0.0)
        fill!(network.p_prev_belief, 0.0)
        fill!(network.p_next_belief, 0.0)
    end
end

"""
Run ADMM simulation for the network
"""
function run_simulation!(
    network::Network,
    outer_iter::Int,
    lambda_outer::Vector{Float64},
    power_diff_outer::Vector{Float64},
    set_rho_tuning::Int,
    count_of_app_iter::Int,
    app_lambda::Vector{Float64},
    diff_of_power::Vector{Float64},
    power_self_belief::Vector{Float64},
    power_next_belief::Vector{Float64},
    power_prev_belief::Vector{Float64},
    lambda_line::Vector{Float64},
    power_diff_line::Vector{Float64},
    power_self_flow_belief::Vector{Float64},
    power_next_flow_belief::Vector{Float64}
)
    max_iter = 80002
    iteration_count = 1
    dual_tol = 1.0
    primal_tol = 0.0
    
    # Initialize tracking vectors
    iteration_graph = Int[]
    prim_tol_graph = Float64[]
    dual_tol_graph = Float64[]
    objective_value = Float64[]
    
    # Initialize node variables
    v_avg = zeros(Float64, network.node_number)
    lmp = zeros(Float64, network.node_number)
    
    # Initialize ADMM parameters
    rho_1 = 1.0
    w = 0.0
    w_prev = 0.0
    lambda_adap = 0.0001
    mu_adap = 0.0005
    xi_adap = 0.0000
    controller_sum = 0.0
    
    start_time = time()
    
    println("Starting ADMM iterations for Network $(network.network_id)...")
    
    # Main ADMM loop
    while (primal_tol >= 0.06 || dual_tol >= 0.6) && iteration_count < max_iter
        if network.verbose
            println("Starting iteration $iteration_count")
        end
        
        # Store iteration data
        push!(iteration_graph, iteration_count)
        push!(prim_tol_graph, primal_tol)
        push!(dual_tol_graph, dual_tol)
        
        # Initialize average variables
        fill!(v_avg, 0.0)
        
        # Generator optimization problems
        calc_objective = 0.0
        
        for (gen_idx, gen) in enumerate(network.gen_object)
            # Solve generator subproblem
            solve_generator_subproblem!(gen, network, iteration_count, outer_iter, 
                                      count_of_app_iter, app_lambda, diff_of_power,
                                      lambda_outer, power_diff_outer)
            
            calc_objective += get_generator_objective(gen)
        end
        
        # Load optimization problems (placeholder)
        for load in network.load_object
            solve_load_subproblem!(load, network, iteration_count)
        end
        
        # Transmission line optimization problems
        for line in network.transl_object
            solve_transmission_line_subproblem!(line, network, iteration_count)
        end
        
        # Update Rho using adaptive control
        if set_rho_tuning == 1
            w = rho_1 * (primal_tol / dual_tol) - 1
        elseif set_rho_tuning == 2
            w = (primal_tol / dual_tol) - 1
        else
            if iteration_count <= 3000
                w = rho_1 * (primal_tol / dual_tol) - 1
            else
                w = 0.0
            end
        end
        
        controller_sum += w
        rho_1 = network.rho
        network.rho = rho_1 * exp(lambda_adap * w + mu_adap * (w - w_prev) + xi_adap * controller_sum)
        w_prev = w
        
        # Gather operation - collect node information
        for (node_idx, node) in enumerate(network.node_object)
            gather_node_information!(node, v_avg, node_idx)
        end
        
        # Broadcast operation - update generator/load/line information
        for gen in network.gen_object
            broadcast_generator_information!(gen, network)
        end
        
        for load in network.load_object
            broadcast_load_information!(load, network)
        end
        
        for line in network.transl_object
            broadcast_transmission_line_information!(line, network)
        end
        
        # Calculate LMPs
        for (i, node) in enumerate(network.node_object)
            lmp[i] = (network.rho / 100) * get_node_lmp(node)
        end
        
        # Reset nodes for next iteration
        for node in network.node_object
            reset_node!(node)
        end
        
        # Calculate tolerances
        primal_tol = calculate_primal_tolerance(network)
        dual_tol = calculate_dual_tolerance(network, iteration_count, rho_1)
        
        push!(objective_value, calc_objective)
        iteration_count += 1
        
        if network.verbose && (iteration_count % 100 == 0)
            println("Iteration $iteration_count: Primal tol = $primal_tol, Dual tol = $dual_tol")
        end
    end
    
    network.virtual_exec_time = time() - start_time
    
    println("ADMM converged in $(iteration_count-1) iterations")
    println("Final objective: $(objective_value[end])")
    println("Execution time: $(network.virtual_exec_time) seconds")
    
    # Store results
    store_network_results!(network, iteration_graph, prim_tol_graph, dual_tol_graph, 
                          objective_value, lmp)
    
    return calc_objective
end

# Placeholder functions for subproblem solving (to be implemented)
function solve_generator_subproblem!(gen::GeneralizedGenerator, network::Network, 
                                   iteration::Int, outer_iter::Int, count_app_iter::Int,
                                   app_lambda::Vector{Float64}, diff_power::Vector{Float64},
                                   lambda_outer::Vector{Float64}, power_diff_outer::Vector{Float64})
    # Implement generator optimization subproblem
    # This would call the appropriate solver based on network.solver_choice
end

function solve_load_subproblem!(load, network::Network, iteration::Int)
    # Implement load optimization subproblem
end

function solve_transmission_line_subproblem!(line::transmissionLine, network::Network, iteration::Int)
    # Implement transmission line optimization subproblem
end

function gather_node_information!(node::Node, v_avg::Vector{Float64}, node_idx::Int)
    # Gather node information for ADMM coordination
end

function broadcast_generator_information!(gen::GeneralizedGenerator, network::Network)
    # Broadcast updated generator information
end

function broadcast_load_information!(load, network::Network)
    # Broadcast updated load information
end

function broadcast_transmission_line_information!(line::transmissionLine, network::Network)
    # Broadcast updated transmission line information
end

function calculate_primal_tolerance(network::Network)::Float64
    # Calculate primal tolerance for ADMM convergence
    return 0.1  # Placeholder
end

function calculate_dual_tolerance(network::Network, iteration::Int, rho_1::Float64)::Float64
    # Calculate dual tolerance for ADMM convergence
    return 0.1  # Placeholder
end

function get_generator_objective(gen::GeneralizedGenerator)::Float64
    # Get generator objective value
    return 100.0  # Placeholder
end

function get_node_lmp(node::Node)::Float64
    # Get node LMP value
    return 50.0  # Placeholder
end

function reset_node!(node::Node)
    # Reset node variables for next iteration
end

function store_network_results!(network::Network, iteration_graph::Vector{Int},
                               prim_tol_graph::Vector{Float64}, dual_tol_graph::Vector{Float64},
                               objective_value::Vector{Float64}, lmp::Vector{Float64})
    # Store simulation results to files
    println("Storing results for Network $(network.network_id)")
end

# Getter functions
get_gen_number(network::Network) = network.gen_number
get_contingency_count(network::Network) = network.contingency_count
get_outaged_line_index(network::Network, cont_scen::Int) = network.outaged_line[cont_scen]

"""
Get power generation beliefs for coordination
"""
function get_power_self(network::Network)
    for (i, gen) in enumerate(network.gen_object)
        network.p_self_buffer[i] = gen.Pg
    end
    return network.p_self_buffer
end

function get_power_prev(network::Network)
    for (i, gen) in enumerate(network.gen_object)
        network.p_prev_buffer[i] = gen.P_gen_prev
    end
    return network.p_prev_buffer
end

function get_power_next(network::Network)
    for (i, gen) in enumerate(network.gen_object)
        network.p_next_buffer[i] = gen.P_gen_next
    end
    return network.p_next_buffer
end

# GUROBI buffer accessors
get_power_self_gurobi(network::Network) = network.p_self_buffer_gurobi
get_power_next_gurobi(network::Network) = network.p_next_buffer_gurobi

function get_power_prev_gurobi(network::Network)
    if network.interval_id == 0
        for (i, gen) in enumerate(network.gen_object)
            network.p_prev_buffer_gurobi[i] = gen.P_gen_prev
        end
    end
    return network.p_prev_buffer_gurobi
end

"""
Reset network for next iteration
"""
function reset_network!(network::Network)
    for node in network.node_object
        reset_node!(node)
    end
    
    # Clear performance vectors
    empty!(network.gen_single_time_vec)
    # Note: don't clear gen_admm_max_time_vec as it tracks across iterations
end

"""
Get network summary information
"""
function get_network_summary(network::Network)
    return Dict(
        "network_id" => network.network_id,
        "nodes" => network.node_number,
        "generators" => network.gen_number,
        "transmission_lines" => network.transl_number,
        "loads" => network.load_number,
        "contingencies" => network.contingency_count,
        "interval" => network.interval_id,
        "scenario" => network.scenario_index,
        "case_name" => network.case_name,
        "case_format" => network.case_format
    )
end

"""
Display network information
"""
function Base.show(io::IO, network::Network)
    println(io, "PowerLASCOPF Network:")
    println(io, "  ID: $(network.network_id)")
    println(io, "  Case: $(network.case_name)")
    println(io, "  Format: $(network.case_format)")
    println(io, "  Nodes: $(network.node_number)")
    println(io, "  Generators: $(network.gen_number)")
    println(io, "  Transmission Lines: $(network.transl_number)")
    println(io, "  Loads: $(network.load_number)")
    println(io, "  Contingencies: $(network.contingency_count)")
    println(io, "  Interval: $(network.interval_id)")
    println(io, "  Scenario: $(network.scenario_index)")
end

"""
Access functions that get components from the shared PowerLASCOPFSystem
rather than from duplicated local storage.
"""

"""Get all thermal generators from the shared system"""
function get_thermal_generators(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.extended_thermal_generators
    end
    return ExtendedThermalGenerator[]
end

"""Get all hydro generators from the shared system"""
function get_hydro_generators(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.extended_hydro_generators
    end
    return ExtendedHydroGenerator[]
end

"""Get all renewable generators from the shared system"""
function get_renewable_generators(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.extended_renewable_generators
    end
    return ExtendedRenewableGenerator[]
end

"""Get all storage generators from the shared system"""
function get_storage_generators(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.extended_storage_generators
    end
    return ExtendedStorageGenerator[]
end

"""Get all generators (combined) from the shared system"""
function get_all_generators(network::Network)
    all_gens = PowerGenerator[]
    append!(all_gens, get_thermal_generators(network))
    append!(all_gens, get_hydro_generators(network))
    append!(all_gens, get_renewable_generators(network))
    append!(all_gens, get_storage_generators(network))
    return all_gens
end

"""Get all transmission lines from the shared system"""
function get_transmission_lines(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.transmission_lines
    end
    return transmissionLine[]
end

"""Get all nodes from the shared system"""
function get_nodes(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.nodes
    end
    return Node[]
end

"""Get all loads from the shared system"""
function get_loads(network::Network)
    if network.net_sys !== nothing
        return network.net_sys.extended_loads
    end
    return Load[]
end

"""
Get a specific generator by index.
This accounts for all generator types in order: thermal, hydro, renewable, storage.
"""
function get_generator_by_index(network::Network, idx::Int)
    all_gens = get_all_generators(network)
    if idx > 0 && idx <= length(all_gens)
        return all_gens[idx]
    end
    error("Generator index $idx out of bounds (1:$(length(all_gens)))")
end

"""
Check if a transmission line is outaged in this network scenario.
"""
function is_line_outaged(network::Network, line_id::Int)
    return (network.outaged_line_single == line_id) || 
           (network.base_outaged_line == line_id)
end

"""
Get the effective power capacity for a line, considering outages.
Returns 0 if the line is outaged in this scenario.
"""
function get_effective_line_capacity(network::Network, line::transmissionLine)
    if is_line_outaged(network, line.transl_id)
        return 0.0  # Line is outaged
    end
    return line.transl_rating  # Normal capacity
end

# Export functions
export Network, network_init_var, set_network_variables!
export get_gen_number, get_contingency_count, get_outaged_line_index
export get_thermal_generators, get_hydro_generators, get_renewable_generators
export get_storage_generators, get_all_generators, get_transmission_lines
export get_nodes, get_loads, get_generator_by_index
export get_effective_line_capacity, is_line_outaged
export get_power_self, get_power_prev, get_power_next
export get_power_self_gurobi, get_power_next_gurobi, get_power_prev_gurobi
export reset_network!, get_network_summary
export create_ieee_case_system, load_case_to_power_lascopf_system
export run_simulation!
		#=	uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( generatorIterator->getu() );
			angtildeBuffer[ bufferIndex ] = generatorIterator->calcThetatilde();
			//generatorIterator->calcvtilde();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( generatorIterator->getv() );
			if ( Verbose ) {
				matrixResultOut << "\nPower price after this iteration ($/MWh, LMP) is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << endl;
			}
		}

		// vector< Load >::const_iterator loadIterator;	// Broadcast to Loads
		for ( loadIterator = loadObject.begin(); loadIterator != loadObject.end(); loadIterator++ ) {
			bufferIndex = genNumber + ( loadIterator->getLoadID() - 1 );
			if ( Verbose ) {
				matrixResultOut << "\n***Load: " << loadIterator->getLoadID() << " results***\n" << endl;
			}
			powerBuffer[ bufferIndex ] = loadIterator->calcPtilde();
			uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( loadIterator->getu() );
			angtildeBuffer[ bufferIndex ] = loadIterator->calcThetatilde();
			//loadIterator->calcvtilde();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( loadIterator->getv() );
			if ( Verbose ) {
				matrixResultOut << "\nPower price after this iteration ($/MWh, LMP) is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << endl;
			}
		}

		int temptrans = 0; // temporary count of transmission lines to account for both the ends // Broadcast to Transmission Lines
		// vector< transmissionLine >::const_iterator translIterator;	
		for ( translIterator = translObject.begin(); translIterator != translObject.end(); translIterator++ ) {
			bufferIndex = genNumber + loadNumber + ( translIterator->getTranslID() - 1 ) + temptrans;
			if ( Verbose ) {
				matrixResultOut << "\n***Transmission Line: " << translIterator->getTranslID() << " results***\n" << endl;
			}
			powerBuffer[ bufferIndex ] = translIterator->calcPtilde1();
			uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( translIterator->getu1() );
			angtildeBuffer[ bufferIndex ] = translIterator->calcThetatilde1();
			//translIterator->calcvtilde1();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( translIterator->getv1() );
			powerBuffer[ ( bufferIndex + 1 ) ] = translIterator->calcPtilde2();
			uPrice[ ( bufferIndex + 1 ) ] = ( Rho1 / Rho ) * ( translIterator->getu2() );
			angtildeBuffer[ ( bufferIndex + 1 ) ] = translIterator->calcThetatilde2();
			//translIterator->calcvtilde2();
			vPrice[ ( bufferIndex + 1 ) ] = ( Rho1 / Rho ) * ( translIterator->getv2() );
			temptrans++;
			if ( Verbose ) {
				matrixResultOut << "\nPower price ($/MWh, LMP at end-1) after this iteration is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price (end-1) after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde (end-1) after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde (end-1) at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << "\nPower price ($/MWh, LMP at end-2) after this iteration is: " << ( Rho / 100 ) * uPrice[ ( bufferIndex + 1 ) ] << "\nAngle price (end-2) after this iteration is: " << ( Rho ) * vPrice[ ( bufferIndex + 1 ) ] << "\nPtilde (end-2) after this iteration is: " << powerBuffer[ ( bufferIndex + 1 ) ] << "\nThetatilde (end-2)  at the end of this iteration is: " << angtildeBuffer[ ( bufferIndex + 1 ) ] <<endl;
			}
		}

		//if ( ( iteration_count >= 100 ) && ( ( ( iteration_count % 100 ) == 0 ) || ( iteration_count == MAX_ITER - 1 ) ) ) {
			int i = 0;
			for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
				LMP[ i ] = ( Rho / 100 ) * nodeIterator->uMessage(); // record the LMP values; rescaled and converted to $/MWh
				//nodeIterator->reset(); // reset the node variables that need to start from zero in the next iteration
				++i;
			}
			//++first;
		//}
	
		for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
			nodeIterator->reset(); // reset the node variables that need to start from zero in the next iteration
		}

		// Calculation of Primal Tolerance, primalTol at the end of this particular iteration
		double primsum = 0.0;
		double Primsum = 0.0;
		for ( int i = 0; i < nodeNumber; i++ ) {
			primsum = primsum + pow( pavBuffer[ i ], 2.0 );
			Primsum = Primsum + pow( pavBuffer[ i ], 2.0 );
		}
		for ( int j = 0; j < deviceTermCount; j++ )
			primsum = primsum + pow( angtildeBuffer[ j ], 2.0 );
		primalTol = sqrt( primsum );
		PrimalTol = sqrt( Primsum );
		if ( Verbose ) {
			matrixResultOut << "\nPrimal Tolerance at the end of this iteration is: " << primalTol << endl;
		}
		// Calculation of Dual Tolerance, dualTol at the end of this particular iteration
		double sum = 0.0;
		if ( iteration_count > 1 ) {
			for ( int k = 0; k < deviceTermCount; k++ ) {
				sum = sum + pow( ( powerBuffer[ k ] - powerBuffer1[ k ] ), 2.0 ); 
				//matrixResultOut << "\npowerBuffer: " << powerBuffer[ k ] << "\npowerBuffer1: " << powerBuffer1[ k ] << endl;
			}
			for ( int i = 0; i < nodeNumber; i++ ) {
				sum = sum + pow( ( angleBuffer[ i ] - angleBuffer1[ i ] ), 2.0 );
				//matrixResultOut << "\nangleBuffer: " << angleBuffer[ i ] << "\nangleBuffer1: " << angleBuffer1[ i ] << endl;
			}
		}
		else {
			for ( int i = 0; i < nodeNumber; i++ )
				sum = sum + pow( ( angleBuffer[ i ] ), 2.0 ); 
			for ( int k = 0; k < deviceTermCount; k++ )
				sum = sum + pow( ( powerBuffer[ k ] - ptildeinitBuffer[ k ] ), 2.0 );
		}
		
		dualTol = ( Rho1 ) * sqrt( sum );
		//matrixResultOut << sqrt( sum ) << endl;
		if ( Verbose ) {
			matrixResultOut << "\nDual Tolerance at the end of this iteration is: " << dualTol << endl;
			matrixResultOut << "\nObjective value at the end of this iteration is ($): " << calcObjective << endl;
			matrixResultOut << "\n****************End of " << iteration_count << " -th iteration***********\n";
		}
		objectiveValue.push_back( calcObjective ); // record the objective values

		iteration_count++;
		//cout << iteration_count << endl;

	} // end of one iteration
	clock_t stop_s = clock();  // end
	matrixResultOut << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;
	matrixResultOut << "\nVirtual Execution Time (s): " << (static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC) - genActualTime + accumulate(genADMMMaxTimeVec.begin(), genADMMMaxTimeVec.end(), 0.0)<< endl;
	virtualExecTime=(static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC) - genActualTime + accumulate(genADMMMaxTimeVec.begin(), genADMMMaxTimeVec.end(), 0.0);
	matrixResultOut << "\nLast value of dual residual / Rho = " << dualTol / Rho1 << endl;
	matrixResultOut << "\nLast value of primal residual = " << primalTol << endl;
	matrixResultOut << "\nLast value of Rho = " << Rho1 << endl;
	matrixResultOut << "\nLast value of dual residual = " << dualTol << endl;
	matrixResultOut << "\nTotal Number of Iterations = " << iteration_count - 1 << endl;	
	//cout << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;

	/**PRINT MW**/
	ofstream devProdOut( devProdString, ios::out ); // create a new file powerResult.txt to output the results	
	// exit program if unable to create file
	if ( !devProdOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	devProdOut << "Gen#" << "\t" << "Conn." << "\t" << "MW" << endl;
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) {
		devProdOut << generatorIterator->getGenID() << "\t" << generatorIterator->getGenNodeID() << "\t" <<    generatorIterator->genPower() * 100 << endl;
	}
	devProdOut << "T.line#" << "\t" << "From" << "\t" << "To" << "\t" << "From MW" << "\t" << "To MW" << endl;
	for ( translIterator = translObject.begin(); translIterator != translObject.end(); translIterator++ ) {
		devProdOut << translIterator->getTranslID() << "\t" << translIterator->getTranslNodeID1() << "\t" << translIterator->getTranslNodeID2() << "\t" << translIterator->translPower1() * 100 << "\t" << translIterator->translPower2() * 100 << endl;
	}

	/**PRINT ITERATION COUNTS**/
	ofstream iterationResultOut( iterationResultString, ios::out ); // create a new file itresult.txt to output the results	
	// exit program if unable to create file
	if ( !iterationResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	iterationResultOut << "\nIteration Count: " << endl;
	vector< int >::iterator iterationCountIterator; 
	for ( iterationCountIterator = iterationGraph.begin(); iterationCountIterator != iterationGraph.end(); iterationCountIterator++ )  		{
		iterationResultOut << *iterationCountIterator << endl;
	}

	/**PRINT LMPs**/
	ofstream lmpResultOut( lmpResultString, ios::out ); // create a new file itresult.txt to output the results	
	// exit program if unable to create file
	if ( !lmpResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	lmpResultOut << "\nLocational Marginal Prices for Real Power at nodes ($/MWh): " << endl;
	
	//for ( int j = 0; j < firstIndex; ++j ) {
		//lmpResultOut << "After " << ( j + 1 ) * 100 << " iterations, LMPs are:" << endl;
		for ( int i = 0; i < nodeNumber; ++i ) {
			lmpResultOut << i + 1 << "\t" << LMP[ i ] << endl; // print the LMP values
		}
	//}
	
	/**PRINT OBJECTIVE VALUES**/
	ofstream objectiveResultOut( objectiveResultString, ios::out ); // create a new file objective.txt to output the results	
	// exit program if unable to create file
	if ( !objectiveResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	objectiveResultOut << "\nObjective value: " << endl;
	vector< double >::iterator objectiveIterator; 
	for ( objectiveIterator = objectiveValue.begin(); objectiveIterator != objectiveValue.end(); objectiveIterator++ )  {
		objectiveResultOut << *objectiveIterator << endl;
	}
	matrixResultOut << "\nLast value of Objective = " << *(objectiveIterator-1) << endl;

	/**PRINT PRIMAL RESIDUAL**/
	ofstream primalResultOut( primalResultString, ios::out ); // create a new file primresult.txt to output the results	
	// exit program if unable to create file
	if ( !primalResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	primalResultOut << "\nPrimal Residual: " << endl;
	vector< double >::iterator primalToleranceIterator;
	for ( primalToleranceIterator = primTolGraph.begin(); primalToleranceIterator != primTolGraph.end(); primalToleranceIterator++ )  		{
		primalResultOut << *primalToleranceIterator << endl;
	}
	
	/**PRINT DUAL RESIDUAL**/
	ofstream dualResultOut( dualResultString, ios::out ); // create a new file dualresult.txt to output the results	
	// exit program if unable to create file
	if ( !dualResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	dualResultOut << "\nDual Residual: " << endl;
	vector< double >::iterator dualToleranceIterator;
	for ( dualToleranceIterator = dualTolGraph.begin(); dualToleranceIterator != dualTolGraph.end(); dualToleranceIterator++ )  		
	{
		dualResultOut << *dualToleranceIterator << endl;
	}
} // end runSimulation

double Network::returnVirtualExecTime(){return virtualExecTime;}

void Network::runSimAPPGurobiBase(int outerIter, double LambdaOuter[], double powDiffOuter[], int countOfAPPIter, double appLambda[], double diffOfPow[], double powSelfBel[], double powNextBel[], double powPrevBel[], GRBEnv* environmentGUROBI) { // runs the APP coarse grain Gurobi OPF for base case
	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double betaSC =200.0;
	double gammaSC =100.0;
	double externalGamma =100.0;
	double PgAPPSC[genNumber];
	double PgAPPNext[genNumber];
	double PgAPPPrev[genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		PgAPPSC[(genIterator->getGenID()-1)]=-powSelfBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPNext[(genIterator->getGenID()-1)]=-powNextBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPPrev[(genIterator->getGenID()-1)]=-powPrevBel[intervalID*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/Summary_of_Result_Log_BaseCase" + to_string(scenarioIndex) + "_Scen"+to_string(intervalID)+"_Inter.txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (6 * genNumber + 2 * translNumber + nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, upper and lower ramping constraints, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
	int dimCol;
	if (intervalID == 0) {
        	dimCol = (2*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 0)) {
        	dimCol = (3*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 1)) {
        	dimCol = (2*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	GRBVar decvar[dimCol+1];
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	double BAPPNew[genNumber];
	double LambdaAPPNew[genNumber];
	for ( int i = 0; i < genNumber; ++i ) {
		BAPPNew[i]=0; 
		LambdaAPPNew[i]=0;
	}
	for ( int i = 0; i < genNumber; ++i ) {
		 for (int counterCont = 0; counterCont < contingencyCount; ++counterCont) {
			BAPPNew[i]+=diffOfPow[counterCont*genNumber+i]; 
			LambdaAPPNew[i]+=appLambda[counterCont*genNumber+i];
		}
	}
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)])+LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*(powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))+(LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*(-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))-(LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		obj += 0*(decvar[colCount]);	
		++colCount;
	}
	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/PgenFile_BaseCase" + to_string(scenarioIndex) + "_Scen"+to_string(intervalID)+"_Inter.txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		outPutFile << "\nGeneration\t" << rCount << "\n";
		int genListLength = (nodeIterator)->getGenLength(); // get the number
		lhs[rCount]=0;
		if (intervalID == 0){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[3*((nodeIterator)->getGenSer(cCount))-2]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
		if (intervalID == 0){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[2*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[3*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[2*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
		int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
		if (intervalID == 0){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		busCount.push_back(rCount);
		if (((nodeIterator)->getLoadVal())==0) {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
		}
		else {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
		}
		outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
		outPutFile << rCount << "\t";
		if (((nodeIterator)->getLoadVal())==0)
			outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		else
			outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next node object
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	int scaler;
	if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1)))
		scaler = 2;
	if ((intervalID != 0) && (lastFlag == 0))
		scaler = 3;
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}
	// Coefficients corresponding to lower ramp rate limits
	outPutFile << "\nCoefficients corresponding to lower ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper ramp rate limits
	outPutFile << "\nCoefficients corresponding to upper ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	//cout << "\nSimulation in Progress. Wait !!! ....." << endl;
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		//cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/AngleResult_BaseCase.txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/TranFlow_BaseCase.txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		//cout << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		if (intervalID == 0){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = genIterator->getPgenPrev(); // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = 0; // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			internalAngleOut << (nodeIterator)->getNodeID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
			++arrayInd;			
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "MW FLOW" << "\n";
		if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1)))
			scaler = 2;
		if ((intervalID != 0) && (lastFlag == 0))
			scaler = 3;
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler*genNumber +(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		//cout << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
}
void Network::runSimAPPGurobiCont(int outerIter, double LambdaOuter[], double powDiffOuter[], int countOfAPPIter, double appLambda[], double diffOfPow[], GRBEnv* environmentGUROBI) { // runs the APP coarse grain Gurobi OPF for contingency scenarios	
	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double betaSC =200.0;
	double gammaSC =-100.0;
	double PgAPPSC[genNumber];
	double lambdaNewAPP[contingencyCount*genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		if (countOfAPPIter==1)
			PgAPPSC[(genIterator->getGenID()-1)]=0;
		else
			PgAPPSC[(genIterator->getGenID()-1)] = -pSelfBufferGUROBI[(genIterator->getGenID()-1)];
		lambdaNewAPP[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)]=-appLambda[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/Summary_of_Result_Log" + to_string(scenarioIndex) + ".txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (2 * genNumber + 2 * translNumber + nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
        int dimCol = (genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
	//cout << "\nGurobi model created" << endl;
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	//cout << "\nGurobi model created and name set" << endl;
	GRBVar decvar[dimCol+1];
	//cout << "\nGurobi decision variables created" << endl;
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	//cout << "\nGurobi decision variables to be assigned" << endl;
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	//cout << "\nGurobi dummy decision variable created" << endl;
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*diffOfPow[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)])+appLambda[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
		++colCount;
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		obj += 0*(decvar[colCount]);	
		++colCount;
	}

	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/PgenFile" + to_string(scenarioIndex) + ".txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		outPutFile << "\nGeneration\t" << rCount << "\n";
		int genListLength = (nodeIterator)->getGenLength(); // get the number
		lhs[rCount]=0;
		for (int cCount = 1; cCount <= genListLength; ++cCount){
			lhs[rCount] += 1*(decvar[(nodeIterator)->getGenSer(cCount)]);
			outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
		}
		outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
		lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[genNumber+rCount]);
		outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
		int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
		for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
			if (((nodeIterator)->getConnReact(cCount))<=0)
				lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[genNumber+((nodeIterator)->getConnSer(cCount))]);
			else
				lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[genNumber+((nodeIterator)->getConnSer(cCount))]);
			outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

		}
		busCount.push_back(rCount);
		if (((nodeIterator)->getLoadVal())==0) {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
		}
		else {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
		}
		outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
		outPutFile << rCount << "\t";
		if (((nodeIterator)->getLoadVal())==0)
			outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		else
			outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next node object
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[rCount - nodeNumber];
		modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
		outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[rCount - (genNumber + nodeNumber)];
		modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
		outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}	
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	//cout << "\nSimulation in Progress. Wait !!! ....." << endl;
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		//cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/AngleResult" + to_string(scenarioIndex) + ".txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/TranFlow" + to_string(scenarioIndex) + ".txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		//cout << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
			powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
			++arrayInd;
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			internalAngleOut << (nodeIterator)->getNodeID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
			++arrayInd;			
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "MW FLOW" << "\n";
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << (1/((tranIterator)->getReactance()))*((decvar[genNumber +(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		//cout << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
}

void Network::runSimulationCentral(int outerIter, double LambdaOuter[], double powDiffOuter[], double powSelfBel[], double powNextBel[], double powPrevBel[], GRBEnv* environmentGUROBI)
{	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double externalGamma =5.0;
	double betaSC =10.0;
	double PgAPPSC[genNumber];
	double PgAPPNext[genNumber];
	double PgAPPPrev[genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		PgAPPSC[(genIterator->getGenID()-1)]=-powSelfBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPNext[(genIterator->getGenID()-1)]=-powNextBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPPrev[(genIterator->getGenID()-1)]=-powPrevBel[intervalID*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/Summary_of_Result_Log"+to_string(intervalID)+".txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (6 * genNumber + 2*translNumber + 2*contingencyCount*(translNumber-1) + (contingencyCount+1)*nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
	int dimCol;
	if (intervalID == 0) {
        	dimCol = (2*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 0)) {
        	dimCol = (3*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 1)) {
        	dimCol = (2*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	GRBVar decvar[dimCol+1];
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {	
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)])+LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*(powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))+(LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*(-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))-(LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {	
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			obj += 0*(decvar[colCount]);	
			++colCount;
		}
	}
	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/PgenFile"+to_string(intervalID)+".txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	//cout << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {
		cout << "\nScenario\t" << scenCount << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			//cout << "\nNode\t" << nodeIterator->getNodeID() << "\n";
			outPutFile << "\nGeneration\t" << rCount << "\n";
			int genListLength = (nodeIterator)->getGenLength(); // get the number
			lhs[rCount]=0;
			if (intervalID == 0){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[3*((nodeIterator)->getGenSer(cCount))-2]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
			//cout << "\nIntrazonal Node Angles\t" << rCount << "\n";
			if (intervalID == 0){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[2*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[3*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[2*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
			//cout << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
			int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
			if (intervalID == 0){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			//cout << "\nThe scenario compensated connected node " << genNumber+scenCount*nodeNumber+((nodeIterator)->getConnSerScen(scenCount)) << " and connected serial is " << ((nodeIterator)->getConnSerScen(scenCount)) << endl;
			lhs[rCount] += ((nodeIterator)->getConnReactCompensate(scenCount))*(decvar[genNumber+scenCount*nodeNumber+((nodeIterator)->getConnSerScen(scenCount))]);
			//busCount.push_back(rCount);
			if (((nodeIterator)->getLoadVal())==0) {
				modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
			}
			else {
				modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
			}
			outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
			//cout << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
			outPutFile << rCount << "\t";
			if (((nodeIterator)->getLoadVal())==0)
				outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
			else
				outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next node object
		}
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	//cout << "\nCoefficients corresponding to lower generation limits\n";
	int scaler1, scaler2;
	if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1))) {
		scaler1 = 2;
		scaler2=1;
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		scaler1 = 3;
		scaler2=2;
	}
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[scaler1*(genIterator->getGenID())-scaler2];
		modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
		outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[scaler1*(genIterator->getGenID())-scaler2];
		modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
		outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber +(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}	
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber +(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			if ((tranIterator)->getOutageScenario()!=scenCount) {
				lhs[rCount] = 0;
				lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
				lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
				modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
				outPutFile << rCount << "\t";
				outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
				++rCount; // Increment the row count to point to the next transmission line object
			}		
		}	
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			if ((tranIterator)->getOutageScenario()!=scenCount) {
				lhs[rCount] = 0;
				lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
				lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
				modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
				outPutFile << rCount << "\t";
				outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
				++rCount; // Increment the row count to point to the next transmission line object
			}
		}
	}	
	// Coefficients corresponding to lower ramp rate limits
	outPutFile << "\nCoefficients corresponding to lower ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper ramp rate limits
	outPutFile << "\nCoefficients corresponding to upper ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/AngleResult"+to_string(intervalID)+".txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/TranFlow"+to_string(intervalID)+".txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		if (intervalID == 0){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = genIterator->getPgenPrev(); // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = 0; // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "CONTINGENCY SCENARIO" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
			for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				internalAngleOut << (nodeIterator)->getNodeID() << "\t" << scenCount << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
				++arrayInd;			
			}
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "CONTINGENCY SCENARIO" << "\t" << "MW FLOW" << "\n";
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << "Base-Case" << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler1*genNumber + (tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler1*genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
			for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
				if ((tranIterator)->getOutageScenario()!=scenCount) {
					tranFlowOut << (tranIterator)->getTranslID() << "\t" << scenCount << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				}
			}
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
	// Close the different output files
	outPutFile.close();
	powerGenOut.close();
}

double *Network::getPowSelf()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pSelfBuffer[ bufferIndex ] = generatorIterator->genPower(); // Store the most recent generation MW belief in the array
	}
	return pSelfBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowPrev()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pPrevBuffer[ bufferIndex ] = generatorIterator->genPowerPrev(); // Store the most recent generation MW belief in the array
	}
	return pPrevBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowNext()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pNextBuffer[ bufferIndex ] = generatorIterator->genPowerNext(int nextScen); // Store the most recent generation MW belief in the array
	}
	return pNextBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

def getPowFlowNext(self, continCounter, supernetCount, rndInterCount, lineCount):

def getPowFlowSelf(self, lineCount):=#
"""
double *Network::getPowSelfGUROBI()
{
	return pSelfBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowNextGUROBI()
{
	return pNextBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its next generation values from the most recently finished APP iteration

double *Network::getPowPrevGUROBI()
{
	if (intervalID==0) {
		vector< Generator >::iterator generatorIterator; // Iterator for generators	
		for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
			int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
			pPrevBufferGUROBI[ bufferIndex ] = generatorIterator->genPowerPrev(); // Store the most recent generation MW belief in the array
		}
		return pPrevBufferGUROBI;
	}
	else
		return pPrevBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its previous generation values from the most recently finished APP iteration
"""
