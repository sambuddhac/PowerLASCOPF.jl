using CSV
using DataFrames
using Glob

function read_csv_files(folder_path)
	csv_files = glob("example_cases/IEEE_Test_Cases/*.csv")
	data_dict = Dict{String, DataFrame}()

	for file in csv_files
		file_name = split(file, "/")[end]
		data = CSV.read(file)
		data_dict[file_name] = data
	end

	return data_dict
end

# Usage
folder_path = "example_cases/IEEE_Test_Cases/"
data_dict = read_csv_files(folder_path)

# Accessing the data
file_name = "example.csv"
data = data_dict[file_name]