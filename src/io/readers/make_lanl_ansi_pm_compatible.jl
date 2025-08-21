function translate_keywords(dictionary::Dict{String, Any})
	translation_dict = Dict(
		"keyword1" => "lanl_keyword1",
		"keyword2" => "lanl_keyword2",
		"keyword3" => "lanl_keyword3"
		# Add more translations as needed
	)
	
	translated_dict = Dict()
	for (key, value) in dictionary
		if haskey(translation_dict, key)
			translated_key = translation_dict[key]
			translated_dict[translated_key] = value
		else
			translated_dict[key] = value
		end
	end
	
	return translated_dict
end