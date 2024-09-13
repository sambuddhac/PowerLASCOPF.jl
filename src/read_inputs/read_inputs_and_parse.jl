function read_inputs_and_parse(filename::AbstractString, PSModel_type::AbstractString; kwargs...)
	input_data_dict = Dict{Any, Any}()
	if PSModel_type == "PowerLASCOPF"

	elseif PSModel_type == "PowerModels"

	elseif PSModel_type == "NREL_Sienna"

	elseif PSModel_type == "Egret"

	else

	end

	return input_data_dict
end