function read_component(component_dict::Dict, input_filename::AbstractString)
	component_dict = JSON.parse(open(input_filename))
	return component_dict
end

function read_generator(component_dict::Dict, )
	read_component()
end

function read_transmission_line(component_dict::Dict, )
	read_component()
end

function read_load_demand(component_dict::Dict, )
	read_component()
end