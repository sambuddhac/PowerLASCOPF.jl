
# check packages and install if needed
include(joinpath(dirname(@__FILE__), "julenv.jl")) #Run this line only for the first time; comment it out for all subsequent use
println("Activating the Julia virtual environment")
