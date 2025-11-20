using CSV
using DataFrames
using Glob

function read_csv_files(folder_path)
	csv_files = glob(joinpath(folder_path, "*.csv"))
	data_dict = Dict{String, DataFrame}()

	for file in csv_files
		file_name = split(file, "/")[end]
		data = CSV.read(file, DataFrame)
		data_dict[file_name] = data
	end

	return data_dict
end

# Usage
#=
folder_path = "example_cases/IEEE_Test_Cases/IEEE_300_Bus/"
data_dict = read_csv_files(folder_path)

# Accessing the data
file_name = "Gen300.csv"
data = data_dict[file_name]
=#


#=
data_directory = "./1_three_zones";

# read in relevant CSV files

storage_df = CSV.read(joinpath(data_directory, "resources", "Storage.csv"), DataFrame) ;
thermal_df = CSV.read(joinpath(data_directory, "resources", "Thermal.csv"), DataFrame) ;
vre_df = CSV.read(joinpath(data_directory, "resources", "Vre.csv"), DataFrame) ;
capacity_df = CSV.read(joinpath(data_directory, "results", "capacity.csv"), DataFrame);
demand_df = CSV.read(joinpath(data_directory, "system", "Demand_data.csv"), DataFrame) ;
network_df = CSV.read(joinpath(data_directory, "system", "Network.csv"), DataFrame) ;
network_expansion_df = CSV.read(joinpath(data_directory, "results", "network_expansion.csv"), DataFrame) ;
fuels_df = CSV.read(joinpath(data_directory, "system", "Fuels_data.csv"), DataFrame) ;
gen_variability_df = CSV.read(joinpath(data_directory, "system", "Generators_variability.csv"), DataFrame) ;
mt_df = CSV.read(joinpath(data_directory, "MoverTypesMapping.csv"), DataFrame) ;
fm_df = CSV.read(joinpath(data_directory, "FuelMapping.csv"), DataFrame) ;
sm_df = CSV.read(joinpath(data_directory, "StorageMapping.csv"), DataFrame) ;
rm_df = CSV.read(joinpath(data_directory, "RenewableMapping.csv"), DataFrame) ;

# create 3 dictionaries, one for fuel types, one for mover types, one for storage types
mover_dict = Dict((row.Key) => row.Value for row in eachrow(mt_df)) ;
fuel_dict = Dict((row.Key) => row.Value for row in eachrow(fm_df)) ;
storage_dict = Dict((row.Key) => row.Value for row in eachrow(sm_df)) ;
renewable_dict = Dict((row.Key) => row.Value for row in eachrow(rm_df)) ;

#fuel costs:
column_names = names(fuels_df)
columns_to_read = column_names[2:end]
fuel_prices = Dict{String, Union{Float64, Missing}}()
for col in columns_to_read
    average = mean(fuels_df[2:end, Symbol(col)])  # Ignore the first row
    fuel_prices[String(col)] = average
end=#