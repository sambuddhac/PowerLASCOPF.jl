# current working directory
working_path = pwd()

# LASCOPF path
lascopf_path = pwd()

#Settings file path
settings_path = joinpath(pwd(), "LASCOPF_settings.yml")

# Load GenX modules
push!(LOAD_PATH, lascopf_path)
println(settings_path)
println("Loading packages")

using LASCOPFTemp
using YAML
using Dates
using DataFrames
using Gurobi
using CPLEX

println(now())

# Load inputs
push!(LOAD_PATH, working_path)

inpath="$working_path/data"
setup = YAML.load(open(settings_path))

inputs=Dict()

# KickStart the model
println("Loading inputs and starting the model")
inputs = runSimLASCOPFTemp(setup,inpath)