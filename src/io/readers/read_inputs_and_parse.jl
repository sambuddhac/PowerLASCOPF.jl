using CSV
using DataFrames
using JSON
using YAML
using Dates
using TimeSeries

# Include other input reader modules
include("read_csv_inputs.jl")
include("read_json_inputs.jl")
include("make_lanl_ansi_pm_compatible.jl")
include("make_nrel_sienna_compatible.jl")

"""
Helper function to find files with specific patterns (replaces Glob functionality)
"""
function find_files_with_pattern(directory::String, pattern::String)
    files = String[]
    if isdir(directory)
        for file in readdir(directory)
            if occursin(pattern, file)
                push!(files, joinpath(directory, file))
            end
        end
    end
    return files
end

"""
Helper function to find files with specific extension
"""
function find_files_with_extension(directory::String, extension::String)
    files = String[]
    if isdir(directory)
        for file in readdir(directory)
            if endswith(file, extension)
                push!(files, joinpath(directory, file))
            end
        end
    end
    return files
end

"""
Main function to read and parse input data from various formats
"""
function read_inputs_and_parse(data_path::AbstractString; format_type::Union{AbstractString, Nothing} = nothing, kwargs...)
    # Auto-detect format if not specified
    if format_type === nothing
        format_type = auto_detect_format(data_path)
    end
    
    println("Reading data from: $data_path")
    println("Detected format: $format_type")
    
    # Parse based on format type
    input_data = if format_type == "PowerLASCOPF"
        read_powerlascopf_format(data_path; kwargs...)
    elseif format_type == "PowerModels" || format_type == "MATPOWER"
        read_powermodels_format(data_path; kwargs...)
    elseif format_type == "NREL_Sienna"
        read_nrel_sienna_format(data_path; kwargs...)
    elseif format_type == "Egret"
        read_egret_format(data_path; kwargs...)
    elseif format_type == "CSV"
        read_csv_format(data_path; kwargs...)
    elseif format_type == "PSS/E"
        read_psse_format(data_path; kwargs...)
    else
        error("Unsupported format type: $format_type")
    end
    
    # Post-process and standardize for PowerLASCOPF
    processed_data = post_process_for_powerlascopf(input_data, format_type)
    
    return processed_data
end

"""
Auto-detect the input data format based on file structure and extensions
"""
function auto_detect_format(data_path::AbstractString)
    if isdir(data_path)
        files = readdir(data_path)
        
        # Check for PowerLASCOPF format indicators
        if any(f -> endswith(f, "LASCOPF_settings.yml"), files)
            return "PowerLASCOPF"
        end
        
        # Check for CSV format
        if any(f -> endswith(f, ".csv"), files)
            return "CSV"
        end
        
        # Check for JSON format (could be Sienna or Egret)
        json_files = filter(f -> endswith(f, ".json"), files)
        if !isempty(json_files)
            # Try to determine if it's Sienna or Egret by examining content
            sample_json = joinpath(data_path, json_files[1])
            try
                data = JSON.parsefile(sample_json)
                if haskey(data, "elements")
                    return "Egret"
                elseif haskey(data, "components") || haskey(data, "system_data")
                    return "NREL_Sienna"
                else
                    return "JSON"
                end
            catch
                return "JSON"
            end
        end
        
        # Check for MATPOWER files
        if any(f -> endswith(f, ".m"), files)
            return "MATPOWER"
        end
        
        # Check for PSS/E files
        if any(f -> endswith(f, ".RAW") || endswith(f, ".raw"), files)
            return "PSS/E"
        end
        
        return "Unknown"
    else
        # Single file
        if endswith(data_path, ".m")
            return "MATPOWER"
        elseif endswith(data_path, ".json")
            return "JSON"
        elseif endswith(data_path, ".csv")
            return "CSV"
        elseif endswith(data_path, ".RAW") || endswith(data_path, ".raw")
            return "PSS/E"
        else
            return "Unknown"
        end
    end
end

"""
Read PowerLASCOPF native format data
"""
function read_powerlascopf_format(data_path::AbstractString; kwargs...)
    println("Reading PowerLASCOPF format from: $data_path")
    
    # Check for PowerLASCOPF case file
    case_files = find_files_with_extension(data_path, ".jl")
    case_file = nothing
    
    for file in case_files
        if occursin("data_", basename(file)) || occursin("case_", basename(file))
            case_file = file
            break
        end
    end
    
    if case_file === nothing
        error("No PowerLASCOPF case file found in $data_path")
    end
    
    # Include and execute the case file
    include(case_file)
    
    # Try to find the main system creation function
    system_data = if isdefined(Main, :create_5bus_powerlascopf_system)
        create_5bus_powerlascopf_system()
    elseif isdefined(Main, :create_powerlascopf_system)
        create_powerlascopf_system()
    else
        error("No PowerLASCOPF system creation function found")
    end
    
    return system_data
end

"""
Read PowerModels/MATPOWER format and convert to PowerLASCOPF
"""
function read_powermodels_format(data_path::AbstractString; kwargs...)
    println("Reading PowerModels/MATPOWER format")
    
    if isdir(data_path)
        # Look for .m files
        m_files = find_files_with_extension(data_path, ".m")
        if isempty(m_files)
            error("No MATPOWER files found in $data_path")
        end
        data_file = m_files[1]
    else
        data_file = data_path
    end
    
    # Use PowerModels to parse
    try
        using PowerModels
        pm_data = PowerModels.parse_file(data_file)
        return convert_powermodels_to_powerlascopf(pm_data)
    catch e
        error("Failed to parse PowerModels file: $e")
    end
end

"""
Read NREL Sienna format and convert to PowerLASCOPF
"""
function read_nrel_sienna_format(data_path::AbstractString; kwargs...)
    println("Reading NREL Sienna format")
    
    try
        # Look for system serialization files
        json_files = find_files_with_extension(data_path, ".json")
        if isempty(json_files)
            error("No JSON files found in $data_path")
        end
        
        system_file = json_files[1]
        psy_system = PSY.System(system_file)
        
        return convert_psy_to_powerlascopf(psy_system)
    catch e
        error("Failed to parse Sienna system: $e")
    end
end

"""
Read CSV format and convert to PowerLASCOPF
"""
function read_csv_format(data_path::AbstractString; kwargs...)
    println("Reading CSV format")
    
    csv_files = find_files_with_extension(data_path, ".csv")
    if isempty(csv_files)
        error("No CSV files found in $data_path")
    end
    
    # Read standard CSV files
    data = Dict()
    for file in csv_files
        filename = basename(file)
        if occursin("bus", filename) || occursin("node", filename)
            data["buses"] = CSV.read(file, DataFrame)
        elseif occursin("branch", filename) || occursin("line", filename)
            data["branches"] = CSV.read(file, DataFrame)
        elseif occursin("gen", filename) || occursin("generator", filename)
            data["generators"] = CSV.read(file, DataFrame)
        elseif occursin("load", filename)
            data["loads"] = CSV.read(file, DataFrame)
        end
    end
    
    return convert_csv_to_powerlascopf(data)
end

"""
Convert PowerSystems System to PowerLASCOPF format
"""
function convert_psy_to_powerlascopf(psy_system::PSY.System)
    # Extract buses and create nodes
    buses = PSY.get_components(PSY.Bus, psy_system)
    nodes = [create_powerlascopf_node(bus, i) for (i, bus) in enumerate(buses)]
    
    # Extract branches and create transmission lines
    lines = PSY.get_components(PSY.Line, psy_system)
    branches = [create_powerlascopf_transmission_line(line, i, nodes) for (i, line) in enumerate(lines)]
    
    # Extract generators
    thermal_gens = [create_powerlascopf_generator(gen, i, nodes) 
                   for (i, gen) in enumerate(PSY.get_components(PSY.ThermalGen, psy_system))]
    
    renewable_gens = [create_powerlascopf_generator(gen, i, nodes) 
                     for (i, gen) in enumerate(PSY.get_components(PSY.RenewableGen, psy_system))]
    
    hydro_gens = [create_powerlascopf_generator(gen, i, nodes) 
                 for (i, gen) in enumerate(PSY.get_components(PSY.HydroGen, psy_system))]
    
    # Extract loads (keep as PSY loads for now)
    loads = collect(PSY.get_components(PSY.ElectricLoad, psy_system))
    
    # Create system data
    return Dict(
        "name" => PSY.get_name(psy_system),
        "nodes" => nodes,
        "branches" => branches,
        "thermal_generators" => thermal_gens,
        "renewable_generators" => renewable_gens,
        "hydro_generators" => hydro_gens,
        "storage_generators" => GeneralizedGenerator[],
        "loads" => loads,
        "base_power" => PSY.get_base_power(psy_system),
        "time_horizon" => collect(DateTime(2024,1,1):Hour(1):DateTime(2024,1,1,23)),
        "scenarios" => Dict[]
    )
end

"""
Create PowerLASCOPF Node from PSY Bus
"""
function create_powerlascopf_node(bus::PSY.Bus, id::Int)
    return Node{PSY.Bus}(
        bus_data = bus,
        node_id = id,
        conn_gen_var = 0,
        num_gens = 0,
        P_net = 0.0,
        theta_node = PSY.get_angle(bus),
        v_node = PSY.get_magnitude(bus),
        P_net_prev = 0.0,
        u = 0.0,
        theta_avg = PSY.get_angle(bus),
        v_avg = PSY.get_magnitude(bus),
        P_dev_init = 0.0,
        theta_dev_init = 0.0
    )
end

"""
Create PowerLASCOPF transmission line from PSY Line
"""
function create_powerlascopf_transmission_line(line::PSY.Line, id::Int, nodes::Vector{Node{PSY.Bus}})
    from_bus_name = PSY.get_name(PSY.get_from(PSY.get_arc(line)))
    to_bus_name = PSY.get_name(PSY.get_to(PSY.get_arc(line)))
    
    from_node_idx = findfirst(n -> PSY.get_name(n.bus_data) == from_bus_name, nodes)
    to_node_idx = findfirst(n -> PSY.get_name(n.bus_data) == to_bus_name, nodes)
    
    if from_node_idx === nothing || to_node_idx === nothing
        error("Could not find nodes for line $(PSY.get_name(line))")
    end
    
    # Create LineSolverBase
    solver_base = LineSolverBase(
        lambda_txr = [0.0],
        interval_type = MockLineInterval(),
        E_coeff = [1.0],
        Pt_next_nu = [0.0],
        BSC = [0.0],
        E_temp_coeff = reshape([0.1], 1, 1),
        RND_int = 1,
        cont_count = 1
    )
    
    return transmissionLine{PSY.Line}(
        transl_type = line,
        solver_line_base = solver_base,
        transl_id = id,
        conn_nodet1_ptr = nodes[from_node_idx],
        conn_nodet2_ptr = nodes[to_node_idx],
        cont_scen_tracker = 0.0,
        thetat1 = 0.0,
        thetat2 = 0.0,
        pt1 = 0.0,
        pt2 = 0.0,
        v1 = 0.0,
        v2 = 0.0
    )
end

"""
Create PowerLASCOPF GeneralizedGenerator from PSY Generator
"""
function create_powerlascopf_generator(gen::PSY.Generator, id::Int, nodes::Vector{Node{PSY.Bus}})
    # Find corresponding node
    bus_name = PSY.get_name(PSY.get_bus(gen))
    node_idx = findfirst(n -> PSY.get_name(n.bus_data) == bus_name, nodes)
    
    if node_idx === nothing
        error("Could not find node for generator $(PSY.get_name(gen))")
    end
    
    # Create appropriate cost function based on generator type
    cost_function = if isa(gen, PSY.ThermalGen)
        ExtendedThermalGenerationCost{StandardGenIntervals}(
            variable_cost = PSY.get_variable(PSY.get_operation_cost(gen)),
            fixed_cost = PSY.get_fixed(PSY.get_operation_cost(gen)),
            startup_cost = PSY.get_start_up(PSY.get_operation_cost(gen)),
            shutdown_cost = PSY.get_shut_down(PSY.get_operation_cost(gen)),
            base_power = PSY.get_base_power(gen)
        )
    elseif isa(gen, PSY.RenewableGen)
        ExtendedRenewableGenerationCost{StandardGenIntervals}(
            variable_cost = PSY.get_variable(PSY.get_operation_cost(gen)),
            curtailment_cost = PSY.get_fixed(PSY.get_operation_cost(gen)),
            base_power = PSY.get_base_power(gen)
        )
    elseif isa(gen, PSY.HydroGen)
        ExtendedHydroGenerationCost{StandardGenIntervals}(
            variable_cost = isa(PSY.get_operation_cost(gen), PSY.TwoPartCost) ? 
                           PSY.get_variable(PSY.get_operation_cost(gen)) : 0.0,
            fixed_cost = isa(PSY.get_operation_cost(gen), PSY.TwoPartCost) ? 
                        PSY.get_fixed(PSY.get_operation_cost(gen)) : 0.0,
            storage_cost = 0.0,
            spillage_cost = 10.0,
            base_power = PSY.get_base_power(gen)
        )
    else
        error("Unsupported generator type: $(typeof(gen))")
    end
    
    # Create solver
    gen_solver = GenSolver{typeof(gen), StandardGenIntervals}()
    
    return GeneralizedGenerator{typeof(gen), StandardGenIntervals}(
        generator = gen,
        cost_function = cost_function,
        id_of_gen = id,
        interval = 1,
        last_flag = false,
        cont_scenario_count = 1,
        gensolver = gen_solver,
        PC_scenario_count = 1,
        baseCont = 0,
        dummyZero = 0,
        accuracy = 1,
        nodeConng = nodes[node_idx],
        countOfContingency = 1,
        gen_total = 1
    )
end

"""
Post-process data for PowerLASCOPF compatibility
"""
function post_process_for_powerlascopf(input_data, format_type::String)
    println("Post-processing data for PowerLASCOPF compatibility...")
    
    # Validate data structure
    validate_powerlascopf_data(input_data)
    
    # Add LASCOPF-specific parameters
    enhance_for_lascopf!(input_data)
    
    return input_data
end

"""
Validate PowerLASCOPF data structure
"""
function validate_powerlascopf_data(data)
    required_fields = ["nodes", "branches", "thermal_generators", "loads"]
    
    for field in required_fields
        if !hasfield(typeof(data), Symbol(field))
            @warn "Missing required field: $field"
        end
    end
    
    # Validate node connectivity
    for branch in data.branches
        if branch.from_node > length(data.nodes) || branch.to_node > length(data.nodes)
            error("Branch references invalid node")
        end
    end
    
    return true
end

"""
Enhance data with LASCOPF-specific parameters
"""
function enhance_for_lascopf!(data)
    # Add default ADMM/APP parameters
    for gen in [data.thermal_generators; data.renewable_generators; data.hydro_generators]
        if !hasfield(typeof(gen), :rho_parameter)
            gen.rho_parameter = 1.0
        end
        if !hasfield(typeof(gen), :app_iterations)
            gen.app_iterations = 100
        end
    end
    
    # Add contingency scenarios if not present
    if isempty(data.scenarios)
        base_scenario = LASCOPFScenario(
            scenario_id = 1,
            name = "Base Case",
            probability = 1.0,
            contingencies = Contingency[],
            renewable_forecasts = Dict{String, Vector{Float64}}(),
            load_forecasts = Dict{String, Vector{Float64}}(),
            hydro_inflows = Float64[]
        )
        push!(data.scenarios, base_scenario)
    end
    
    return data
end

# Export all functions
export read_inputs_and_parse, auto_detect_format
