# Extended System for PowerLASCOPF.jl
# This module extends PowerSystems.System to support custom PowerLASCOPF types

# Import our custom types
include("../core/types.jl")
include("../components/node.jl")
include("../components/transmission_line.jl")
include("../components/load.jl")
include("../components/ExtendedThermalGenerator.jl")
include("../components/ExtendedRenewableGenerator.jl")
include("../components/ExtendedHydroGenerator.jl")
include("../components/ExtendedStorageGenerator.jl")

# Define our extended system structure

@kwdef mutable struct PowerLASCOPFSystem
    # Core PSY.System
    psy_system::PSY.System
    
    # PowerLASCOPF specific extensions
    nodes::Vector{Node} = Node[]
    transmission_lines::Vector{transmissionLine} = transmissionLine[]
    extended_thermal_generators::Vector{ExtendedThermalGenerator} = ExtendedThermalGenerator[]
    extended_hydro_generators::Vector{ExtendedHydroGenerator} = ExtendedHydroGenerator[]
    extended_renewable_generators::Vector{ExtendedRenewableGenerator} = ExtendedRenewableGenerator[]
    extended_storage_generators::Vector{ExtendedStorageGenerator} = ExtendedStorageGenerator[]
    extended_loads::Vector{Load} = Load[]
    
    # Network properties
    network_id::Int = 0
    scenario_index::Int = 0
    post_contingency_scenario::Int = 0
    contingency_count::Int = 0
    interval_id::Int = 0
    last_flag::Bool = false
    outaged_line::Int = 0
    
    # Solver properties
    solver_choice::Int = 1
    rho_tuning::Float64 = 1.0
    accuracy::Int = 1
    dummy_zero_flag::Int = 0
    
    # APP algorithm properties
    rnd_intervals::Int = 6
    rsd_intervals::Int = 6
    
    # Time series properties
    time_series_resolution::Dates.Period = Dates.Hour(1)
    forecast_horizon::Int = 24
end

# Simplified constructor - let @kwdef handle the defaults
function PowerLASCOPFSystem(psy_system::PSY.System; kwargs...)
    return PowerLASCOPFSystem(; psy_system=psy_system, kwargs...)
end

# ===== EXTEND PSY.SYSTEM INTERFACE =====

# Forward core PSY.System methods to our extended system
PSY.get_name(sys::PowerLASCOPFSystem) = PSY.get_name(sys.psy_system)
PSY.get_base_power(sys::PowerLASCOPFSystem) = PSY.get_base_power(sys.psy_system)
PSY.get_frequency(sys::PowerLASCOPFSystem) = PSY.get_frequency(sys.psy_system)
PSY.get_units_base(sys::PowerLASCOPFSystem) = PSY.get_units_base(sys.psy_system)
PSY.set_name!(sys::PowerLASCOPFSystem, name::String) = PSY.set_name!(sys.psy_system, name)

# Component access methods
PSY.get_components(::Type{T}, sys::PowerLASCOPFSystem) where {T} = PSY.get_components(T, sys.psy_system)
PSY.get_component(::Type{T}, sys::PowerLASCOPFSystem, name::String) where {T} = PSY.get_component(T, sys.psy_system, name)

# Time series methods - Use actual PowerSystems methods
PSY.get_forecast_horizon(sys::PowerLASCOPFSystem) = sys.forecast_horizon

# Forward time series methods to the underlying PSY system
PSY.get_time_series_keys(sys::PowerLASCOPFSystem, component) = PSY.get_time_series_keys(component)
PSY.get_time_series(sys::PowerLASCOPFSystem, component, name) = PSY.get_time_series(component, name)
PSY.add_time_series!(sys::PowerLASCOPFSystem, component, ts) = PSY.add_time_series!(sys.psy_system, component, ts)

# Our custom time series methods
function get_time_series_resolution(sys::PowerLASCOPFSystem)
    return sys.time_series_resolution
end

function set_time_series_resolution!(sys::PowerLASCOPFSystem, resolution::Dates.Period)
    sys.time_series_resolution = resolution
    return sys
end

function get_forecast_horizon_hours(sys::PowerLASCOPFSystem)
    return sys.forecast_horizon
end

function set_forecast_horizon!(sys::PowerLASCOPFSystem, horizon::Int)
    sys.forecast_horizon = horizon
    return sys
end
# ===== POWERLASCOPF SPECIFIC METHODS =====

# Node management
function add_node!(sys::PowerLASCOPFSystem, node::Node)
    # Add the underlying PSY.Bus to the PSY.System
    if !PSY.has_component(PSY.Bus, sys.psy_system, PSY.get_name(node.node_type))
        PSY.add_component!(sys.psy_system, node.node_type)
    end
    
    # Add to our extended system
    push!(sys.nodes, node)
    return nothing
end

function get_nodes(sys::PowerLASCOPFSystem)
    return sys.nodes
end

function get_node(sys::PowerLASCOPFSystem, node_id::Int)
    for node in sys.nodes
        if get_node_id(node) == node_id
            return node
        end
    end
    return nothing
end

function get_node_count(sys::PowerLASCOPFSystem)
    return length(sys.nodes)
end

# Transmission line management
function add_transmission_line!(sys::PowerLASCOPFSystem, line::transmissionLine)
    # Add the underlying PSY.ACBranch to the PSY.System
    if !PSY.has_component(typeof(line.transl_type), sys.psy_system, PSY.get_name(line.transl_type))
        PSY.add_component!(sys.psy_system, line.transl_type)
    end
    
    # Add to our extended system
    push!(sys.transmission_lines, line)
    return nothing
end

function get_transmission_lines(sys::PowerLASCOPFSystem)
    return sys.transmission_lines
end

function get_transmission_line(sys::PowerLASCOPFSystem, line_id::Int)
    for line in sys.transmission_lines
        if get_transl_id(line) == line_id
            return line
        end
    end
    return nothing
end

function get_transmission_line_count(sys::PowerLASCOPFSystem)
    return length(sys.transmission_lines)
end

# Extended thermal generator management
function add_extended_thermal_generator!(sys::PowerLASCOPFSystem, gen::ExtendedThermalGenerator)
    # Add the underlying PSY.ThermalGen to the PSY.System
    if !PSY.has_component(typeof(gen.generator), sys.psy_system, PSY.get_name(gen.generator))
        PSY.add_component!(sys.psy_system, gen.generator)
    end
    
    # Add to our extended system
    push!(sys.extended_thermal_generators, gen)
    return nothing
end

function get_extended_thermal_generators(sys::PowerLASCOPFSystem)
    return sys.extended_thermal_generators
end

function get_extended_thermal_generator(sys::PowerLASCOPFSystem, gen_id::Int)
    for gen in sys.extended_thermal_generators
        if get_gen_id(gen) == gen_id
            return gen
        end
    end
    return nothing
end

function get_extended_thermal_generator_count(sys::PowerLASCOPFSystem)
    return length(sys.extended_thermal_generators)
end

# Extended renewable generator management
function add_extended_renewable_generator!(sys::PowerLASCOPFSystem, gen::ExtendedRenewableGenerator)
    # Add the underlying PSY.RenewableGen to the PSY.System
    if !PSY.has_component(typeof(gen.generator), sys.psy_system, PSY.get_name(gen.generator))
        PSY.add_component!(sys.psy_system, gen.generator)
    end
    
    # Add to our extended system
    push!(sys.extended_renewable_generators, gen)
    return nothing
end

function get_extended_renewable_generators(sys::PowerLASCOPFSystem)
    return sys.extended_renewable_generators
end

function get_extended_renewable_generator(sys::PowerLASCOPFSystem, gen_id::Int)
    for gen in sys.extended_renewable_generators
        if get_gen_id(gen) == gen_id
            return gen
        end
    end
    return nothing
end

function get_extended_renewable_generator_count(sys::PowerLASCOPFSystem)
    return length(sys.extended_renewable_generators)
end

# Extended hydro generator management
function add_extended_hydro_generator!(sys::PowerLASCOPFSystem, gen::ExtendedHydroGenerator)
    # Add the underlying PSY.HydroGen to the PSY.System
    if !PSY.has_component(typeof(gen.generator), sys.psy_system, PSY.get_name(gen.generator))
        PSY.add_component!(sys.psy_system, gen.generator)
    end
    
    # Add to our extended system
    push!(sys.extended_hydro_generators, gen)
    return nothing
end

function get_extended_hydro_generators(sys::PowerLASCOPFSystem)
    return sys.extended_hydro_generators
end

function get_extended_hydro_generator(sys::PowerLASCOPFSystem, gen_id::Int)
    for gen in sys.extended_hydro_generators
        if get_gen_id(gen) == gen_id
            return gen
        end
    end
    return nothing
end

function get_extended_hydro_generator_count(sys::PowerLASCOPFSystem)
    return length(sys.extended_hydro_generators)
end

# Extended storage generator management
function add_extended_storage_generator!(sys::PowerLASCOPFSystem, gen::ExtendedStorageGenerator)
    # Add the underlying PSY.Storage to the PSY.System
    if !PSY.has_component(typeof(gen.storage_device), sys.psy_system, PSY.get_name(gen.storage_device))
        PSY.add_component!(sys.psy_system, gen.storage_device)
    end
    
    # Add to our extended system
    push!(sys.extended_storage_generators, gen)
    return nothing
end

function get_extended_storage_generators(sys::PowerLASCOPFSystem)
    return sys.extended_storage_generators
end

function get_extended_storage_generator(sys::PowerLASCOPFSystem, gen_id::Int)
    for gen in sys.extended_storage_generators
        if get_storage_id(gen) == gen_id
            return gen
        end
    end
    return nothing
end

function get_extended_storage_generator_count(sys::PowerLASCOPFSystem)
    return length(sys.extended_storage_generators)
end

# Extended load management
function add_extended_load!(sys::PowerLASCOPFSystem, load::Load)
    # Add the underlying PSY.Load to the PSY.System
    if !PSY.has_component(typeof(load.load_type), sys.psy_system, PSY.get_name(load.load_type))
        PSY.add_component!(sys.psy_system, load.load_type)
    end
    
    # Add to our extended system
    push!(sys.extended_loads, load)
    return nothing
end

function get_extended_loads(sys::PowerLASCOPFSystem)
    return sys.extended_loads
end

function get_extended_load(sys::PowerLASCOPFSystem, load_id::Int)
    for load in sys.extended_loads
        if get_load_id(load) == load_id
            return load
        end
    end
    return nothing
end

function get_extended_load_count(sys::PowerLASCOPFSystem)
    return length(sys.extended_loads)
end

# ===== SYSTEM BUILDING UTILITIES =====

function create_node_from_bus!(sys::PowerLASCOPFSystem, bus::PSY.Bus, number_of_scenarios::Int = 1)
    """Create a PowerLASCOPF Node from a PSY.Bus and add it to the system"""
    node_id = PSY.get_number(bus)
    node = Node(bus, node_id, number_of_scenarios)
    add_node!(sys, node)
    return node
end

function create_transmission_line_from_branch!(
    sys::PowerLASCOPFSystem, 
    branch::PSY.ACBranch,
    from_node::Node,
    to_node::Node,
    solver_line_base::LineSolverBase
)
    """Create a PowerLASCOPF transmissionLine from a PSY.ACBranch and add it to the system"""
    line = transmissionLine(
        transl_type = branch,
        solver_line_base = solver_line_base,
        conn_nodet1_ptr = from_node,
        conn_nodet2_ptr = to_node,
        transl_id = length(sys.transmission_lines) + 1
    )
    add_transmission_line!(sys, line)
    return line
end

function create_extended_thermal_generator_from_generator!(
    sys::PowerLASCOPFSystem,
    generator::PSY.ThermalGen,
    thermal_cost_function::ExtendedThermalGenerationCost,
    connected_node::Node,
    gen_solver::GenSolver;
    interval::Int = 0,
    last_flag::Bool = false,
    cont_scenario_count::Int = 1,
    pc_scenario_count::Int = 0,
    base_cont::Int = 0,
    dummy_zero::Int = 0,
    accuracy::Int = 1,
    count_of_contingency::Int = 1
)
    """Create a PowerLASCOPF ExtendedThermalGenerator from a PSY.ThermalGen and add it to the system"""
    gen_id = length(sys.extended_thermal_generators) + 1
    gen_total = PSY.get_components_by_type(PSY.ThermalGen, sys.psy_system) |> length
    
    extended_gen = ExtendedThermalGenerator(
        generator,
        thermal_cost_function,
        gen_id,
        interval,
        last_flag,
        cont_scenario_count,
        gen_solver,
        pc_scenario_count,
        base_cont,
        dummy_zero,
        accuracy,
        connected_node,
        count_of_contingency,
        gen_total
    )
    
    add_extended_thermal_generator!(sys, extended_gen)
    return extended_gen
end

# ===== SYSTEM CONVERSION AND VALIDATION =====

function convert_psy_system_to_power_lascopf!(sys::PowerLASCOPFSystem; number_of_scenarios::Int = 1)
    """Convert all components in the PSY.System to PowerLASCOPF equivalents"""
    
    println("🔄 Converting PSY.System to PowerLASCOPF System...")
    
    # Convert all buses to nodes
    buses = PSY.get_components(PSY.Bus, sys.psy_system)
    node_map = Dict{Int, Node}()
    
    for bus in buses
        node = create_node_from_bus!(sys, bus, number_of_scenarios)
        node_map[PSY.get_number(bus)] = node
        println("  ✅ Created Node $(get_node_id(node)) from Bus $(PSY.get_name(bus))")
    end
    
    # Convert branches to transmission lines
    branches = PSY.get_components(PSY.ACBranch, sys.psy_system)
    for branch in branches
        from_bus_num = PSY.get_number(PSY.get_from(PSY.get_arc(branch)))
        to_bus_num = PSY.get_number(PSY.get_to(PSY.get_arc(branch)))
        
        from_node = node_map[from_bus_num]
        to_node = node_map[to_bus_num]
        
        # Create a default LineSolverBase for this line
        line_solver_base = LineSolverBase(
            lambda_txr = zeros(number_of_scenarios),
            interval_type = MockLineInterval(),
            E_coeff = [0.9^i for i in 1:sys.rnd_intervals],
            Pt_next_nu = zeros(number_of_scenarios),
            BSC = zeros(number_of_scenarios),
            E_temp_coeff = 0.01 * abs.(randn(sys.rnd_intervals, sys.rnd_intervals)),
            RND_int = sys.rnd_intervals,
            cont_count = number_of_scenarios
        )
        
        line = create_transmission_line_from_branch!(sys, branch, from_node, to_node, line_solver_base)
        println("  ✅ Created TransmissionLine $(get_transl_id(line)) from Branch $(PSY.get_name(branch))")
    end
    
    println("🎉 System conversion complete!")
    return sys
end

function validate_power_lascopf_system(sys::PowerLASCOPFSystem)
    """Validate that the PowerLASCOPF system is properly constructed"""
    println("🔍 Validating PowerLASCOPF System...")
    
    issues = String[]
    
    # Check that we have components
    if isempty(sys.nodes)
        push!(issues, "No nodes found in system")
    end
    
    if isempty(sys.transmission_lines)
        push!(issues, "No transmission lines found in system")
    end
    
    # Check node connections
    for node in sys.nodes
        total_connections = get_total_connections(node)
        if total_connections == 0
            push!(issues, "Node $(get_node_id(node)) has no connections")
        end
    end
    
    # Check transmission line connectivity
    for line in sys.transmission_lines
        from_node_id = get_transl_node_id1(line)
        to_node_id = get_transl_node_id2(line)
        
        from_node = get_node(sys, from_node_id)
        to_node = get_node(sys, to_node_id)
        
        if from_node === nothing
            push!(issues, "TransmissionLine $(get_transl_id(line)) references non-existent from_node $from_node_id")
        end
        
        if to_node === nothing
            push!(issues, "TransmissionLine $(get_transl_id(line)) references non-existent to_node $to_node_id")
        end
    end
    
    # Report validation results
    if isempty(issues)
        println("  ✅ System validation passed!")
        println("  📊 System summary:")
        println("     - Nodes: $(length(sys.nodes))")
        println("     - Transmission Lines: $(length(sys.transmission_lines))")
        println("     - Extended Thermal Generators: $(length(sys.extended_thermal_generators))")
        return true
    else
        println("  ❌ System validation failed:")
        for issue in issues
            println("     - $issue")
        end
        return false
    end
end

# ===== NETWORK INTEGRATION =====

function create_network_from_system(sys::PowerLASCOPFSystem)
    """Create a Network instance from a PowerLASCOPFSystem"""
    
    # Create the underlying PSY.System
    net_sys = sys.psy_system
    
    # Initialize network variables
    network = Network(
        net_sys = net_sys,
        networkID = sys.network_id,
        scenarioIndex = sys.scenario_index,
        postContScenario = sys.post_contingency_scenario,
        prePostContScen = 0,
        genNumber = length(sys.extended_thermal_generators),
        genFields = 0,
        loadNumber = 0,  # TODO: Add load support
        loadFields = 0,
        translNumber = length(sys.transmission_lines),
        translFields = 0,
        deviceTermCount = 0,
        dummyZ = sys.dummy_zero_flag,
        Accuracy = sys.accuracy,
        nodeNumber = length(sys.nodes),
        Rho = sys.rho_tuning,
        intervalID = sys.interval_id,
        lastFlag = sys.last_flag ? 1 : 0,
        outagedLine = [sys.outaged_line],
        OutagedLine = sys.outaged_line,
        baseOutagedLine = sys.outaged_line,
        contingencyCount = sys.contingency_count,
        solverChoice = sys.solver_choice,
        Verbose = true,
        pSelfBeleif = zeros(Float64, length(sys.extended_thermal_generators)),
        pSelfBeleifInner = zeros(Float64, length(sys.extended_thermal_generators)),
        pPrevBeleif = zeros(Float64, length(sys.extended_thermal_generators)),
        pNextBeleif = zeros(Float64, length(sys.extended_thermal_generators)),
        connNodeNumList = Int[],
        nodeValList = Int[],
        assignedNodeSer = 0,
        pSelfBuffer = zeros(Float64, length(sys.extended_thermal_generators)),
        pPrevBuffer = zeros(Float64, length(sys.extended_thermal_generators)),
        pNextBuffer = zeros(Float64, length(sys.extended_thermal_generators)),
        pSelfBufferGUROBI = zeros(Float64, length(sys.extended_thermal_generators)),
        pNextBufferGUROBI = zeros(Float64, length(sys.extended_thermal_generators)),
        pPrevBufferGUROBI = zeros(Float64, length(sys.extended_thermal_generators)),
        matrixResultString = "",
        devProdString = "",
        iterationResultString = "",
        lmpResultString = "",
        objectiveResultString = "",
        primalResultString = "",
        dualResultString = "",
        genSingleTimeVec = Float64[],
        genADMMMaxTimeVec = Float64[],
        virtualExecTime = 0.0,
        divConvMWPU = 100.0,
        genObject = [], # TODO: Convert to proper Generator objects
        loadObject = [], # TODO: Add load objects
        translObject = [], # TODO: Convert to proper TransmissionLine objects
        nodeObject = sys.nodes
    )
    
    return network
end

# ===== UTILITY FUNCTIONS =====

function system_summary(sys::PowerLASCOPFSystem)
    """Print a comprehensive summary of the PowerLASCOPF system"""
    println("📋 PowerLASCOPF System Summary")
    println("=" ^ 50)
    println("🏢 System Name: $(PSY.get_name(sys))")
    println("⚡ Base Power: $(PSY.get_base_power(sys)) MVA")
    println("🔧 Network ID: $(sys.network_id)")
    println("📊 Scenario Index: $(sys.scenario_index)")
    println("🚨 Post-Contingency Scenario: $(sys.post_contingency_scenario)")
    println("🔄 Contingency Count: $(sys.contingency_count)")
    println("⏱️  Interval ID: $(sys.interval_id)")
    println("🔚 Last Flag: $(sys.last_flag)")
    println("❌ Outaged Line: $(sys.outaged_line)")
    println("🎛️  Solver Choice: $(sys.solver_choice)")
    println("🎚️  Rho Tuning: $(sys.rho_tuning)")
    println("🔧 Accuracy: $(sys.accuracy)")
    println("🏗️  RND Intervals: $(sys.rnd_intervals)")
    println("🏗️  RSD Intervals: $(sys.rsd_intervals)")
    println()
    println("📈 Component Counts:")
    println("   🔌 Nodes: $(length(sys.nodes))")
    println("   ⚡ Transmission Lines: $(length(sys.transmission_lines))")
    println("   🏭 Extended Thermal Generators: $(length(sys.extended_thermal_generators))")
    println("   🏢 PSY Buses: $(length(PSY.get_components(PSY.Bus, sys.psy_system)))")
    println("   🔗 PSY Branches: $(length(PSY.get_components(PSY.ACBranch, sys.psy_system)))")
    println("   ⚙️  PSY Generators: $(length(PSY.get_components(PSY.Generator, sys.psy_system)))")
    println("=" ^ 50)
end

# ===== EXPORTS =====

export PowerLASCOPFSystem
export add_node!, get_nodes, get_node, get_node_count
export add_transmission_line!, get_transmission_lines, get_transmission_line, get_transmission_line_count
export add_extended_thermal_generator!, get_extended_thermal_generators, get_extended_thermal_generator, get_extended_thermal_generator_count
export create_node_from_bus!, create_transmission_line_from_branch!, create_extended_thermal_generator_from_generator!
export convert_psy_system_to_power_lascopf!, validate_power_lascopf_system
export create_network_from_system, system_summary
export get_time_series_resolution, set_time_series_resolution!  # Add these
export get_forecast_horizon_hours, set_forecast_horizon!        # Add these
