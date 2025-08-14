using CSV
using DataFrames
using JSON
using YAML
using Dates
using TimeSeries
using Glob

# Include other input reader modules
include("read_csv_inputs.jl")
include("read_json_inputs.jl")
include("make_lanl_ansi_pm_compatible.jl")
include("make_nrel_sienna_compatible.jl")

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

# Export all functions
export read_inputs_and_parse, auto_detect_format
