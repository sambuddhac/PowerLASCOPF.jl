using Distributed

mutable struct LASCOPFSys

// ...existing code...


function init_cluster_workers!()
    if nworkers() > 0
        return
    end
    if haskey(ENV, "SLURM_NTASKS")
        # one Julia process per Slurm task; set --ntasks-per-node to sockets
        addprocs(parse(Int, ENV["SLURM_NTASKS"]) - 1)
    end
end

function run_sim_lascopf_temp(settings::Dict, inputPath::AbstractString)
    init_cluster_workers!()
    # delegate to new maintained path:
    return run_simulation_lascopf()  # from maintwoserialLASCOPF.jl
end
// ...existing code...
	
@kwdef mutable struct SuperNetwork
	net_id::Int
	solver_choice::Int
	set_rho_tuning::Int
	last::Int = 0
	RND_intervals::Int
    	RSD_intervals::Int
	next_choice::Int
	dummy_interval_choice::Int
	cont_solver_accuracy::Int
	future_net_vector::Vector{SuperNetwork}# Define the fields of the SuperNetwork struct here
end

function add_nodes()
	println("Enter the number of nodes to initialize the network. (Allowed choices are 2, 3, 5, 14, 30, 48, 57, 118, and 300 Bus IEEE Test Bus Systems as of now. So, please restrict yourself to one of these)")
	netID = parse(Int, readline())
end

function set_solver_accuracy()
	println("Enter the switch value to select between whether an extensive/exhaustive (and presumably more accurate) solver for contingency scenarios is desired, or just a simpler one is desired; 1 for former, 0 for latter")
	contSolverAccuracy = parse(Int, readline())
end

function set_solver_choice()
	println("Enter the choice of the solver for SCOPF of each dispatch interval, 1 for GUROBI-APMP(ADMM/PMP+APP), 2 for CVXGEN-APMP(ADMM/PMP+APP), 3 for GUROBI APP Coarse Grained, 4 for centralized GUROBI SCOPF")
	solverChoice = parse(Int, readline())
end

function set_ramping_choice()
	println("Enter the choice pertaining to whether you want to consider the ramping constraint to the next interval, for the last interval: 0 for not considering and 1 for considering")
	nextChoice = parse(Int, readline())
end

function set_rho_tuning(set_solver_choice::Int)
	# Conditional rho tuning (same logic as C++, but simpler syntax)
	setRhoTuning = 0
	if (solver_choice == 1) || (solver_choice == 2)
		println("Enter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant).")
		setRhoTuning = parse(Int, readline())
	else
		setRhoTuning = 0  # Dummy value when not using ADMM-PMP
	end
end

function set_rnd_intervals()
	println("Enter the number of look-ahead dispatch intervals for restoring line flows to within normal long-term ratings.")
	RND_intervals = parse(Int, readline())
end

function set_rsd_intervals()
	println("Enter the number of furthermore look-ahead dispatch intervals for making the system secure w.r.t. next set of contingencies.")
	RSD_intervals = parse(Int, readline())
end

function set_contingency_choice()
	println("Enter the choice pertaining to whether to include a dummy interval at the start or not (Inclusion of a dummy interval may speed up convergence and/or improve accuracy of solution). Enter 1 to include and 0 to not include")
	dummy_interval_choice = parse(Int, readline())
end

function run_simulation_lascopf(system::LASCOPFSys)
	run_simulation_lascopf(system.net_id, system.solver_choice, system.set_rho_tuning, system.last, system.RND_intervals, system.RSD_intervals, system.next_choice, system.dummy_interval_choice, system.cont_solver_accuracy)
end

function run_simulation_lascopf(node_num::Int, set_rho_tuning::Int, last::Int, RND_intervals::Int, RSD_intervals::Int; kwarg...)
	run_simulation_lascopf(system.net_id, system.solver_choice, system.set_rho_tuning, system.last, system.RND_intervals, system.RSD_intervals, system.next_choice, system.dummy_interval_choice, system.cont_solver_accuracy)
end

function run_simulation_lascopf(node_num::Int, solver_choice::Int, set_rho_tuning::Int, last::Int, RND_intervals::Int, RSD_intervals::Int, next_choice::Int, dummy_interval_choice::Int, cont_solver_accuracy::Int)
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")
    
    supernet = SuperNetwork(netID, solverChoice, setRhoTuning, 0, 0, 0, 0, nextChoice, dummyIntervalChoice, contSolverAccuracy, 0, RNDIntervals, RSDIntervals)
    numberOfCont = supernet.retContCount()
    push!(futureNetVector, supernet)
    
    supernet1 = SuperNetwork(netID, solverChoice, setRhoTuning, 0, 0, 1, 0, nextChoice, dummyIntervalChoice, contSolverAccuracy, 0, RNDIntervals, RSDIntervals)
    push!(futureNetVector, supernet1)
    
    for i in 0:numberOfCont
        for j in 1:RNDIntervals-1
            lineOutaged = 0
            if i > 0
                lineOutaged = futureNetVector[1].indexOfLineOut(i)
            end
            supernet = SuperNetwork(netID, solverChoice, setRhoTuning, i, j, 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)
            push!(futureNetVector, supernet)
        end
        
        for j in 0:RSDIntervals
            lineOutaged = 0
            if i > 0
                lineOutaged = futureNetVector[1].indexOfLineOut(i)
            end
            
            if j == RSDIntervals
                last = 1
            end
            
            supernet = SuperNetwork(netID, solverChoice, setRhoTuning, i, j + RNDIntervals, 2,

### ChatGPT 4.0 Generated code translation from C++ to Julia


### Gemini generated code translation
# ... (Your SuperNetwork type/struct definition would go here)

# Input and Initialization
println("Enter the number of nodes to initialize the network. (Allowed choices are 2, 3, 5, 14, 30, 48, 57, 118, and 300 Bus IEEE Test Bus Systems as of now. So, please restrict yourself to one of these)")
netID = parse(Int, readline())  # Read and parse the input as an integer

println("Enter the switch value to select between whether an extensive/exhaustive (and presumably more accurate) solver for contingency scenarios is desired, or just a simpler one is desired; 1 for former, 0 for latter")
contSolverAccuracy = parse(Int, readline())  # Read and parse the input as an integer

println("Enter the choice of the solver for SCOPF of each dispatch interval, 1 for GUROBI-APMP(ADMM/PMP+APP), 2 for CVXGEN-APMP(ADMM/PMP+APP), 3 for GUROBI APP Coarse Grained, 4 for centralized GUROBI SCOPF")
solverChoice = parse(Int, readline())  # Read and parse the input as an integer

println("Enter the choice pertaining to whether you want to consider the ramping constraint to the next interval, for the last interval: 0 for not considering and 1 for considering")
nextChoice = parse(Int, readline())  # Read and parse the input as an integer

# Conditional rho tuning (same logic as C++, but simpler syntax)
setRhoTuning = if (solverChoice == 1) || (solverChoice == 2)
    println("Enter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant).")
    parse(Int, readline())
else
    0  # Dummy value when not using ADMM-PMP
end

function read_settings(case_path::String)
	settings = Dict{String, Any}()
	settings_path = joinpath(case_path, "LASCOPF_settings.yml")
	println("Configuring Settings")
    
	settings = YAML.load(open(settings_path))
    
	return settings
end
    
    println("Enter the number of nodes to initialize the network. (Allowed choices are 2, 3, 5, 14, 30, 48, 57, 118, and 300 Bus IEEE Test Bus Systems as of now. So, please restrict yourself to one of these)")
    settings["netID"] = parse(Int, readline())

# Create SuperNetwork instances (push! adds to the end of the vector)
futureNetVector = SuperNetwork[]  

# ... rest of the supernetwork initialization
# ... (Previous input handling code) ...

println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")

# Create initial SuperNetworks
supernet = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 0, 0, next_choice, dummy_interval_choice, cont_solver_accuracy, 0, RND_intervals, RSD_intervals)
number_of_cont = ret_cont_count(supernet)  # Assuming retContCount is defined in your SuperNetwork type
push!(future_net_vector, supernet)

supernet1 = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 1, 0, next_choice, dummy_interval_choice, cont_solver_accuracy, 0, RND_intervals, RSD_intervals)
push!(future_net_vector, supernet1)

spawn_networks!(future_net_vector, number_of_cont, settings)

# Main loop to create SuperNetworks for contingencies and intervals
function spawn_networks!(future_net_vector::Vector{SuperNetwork}, number_of_cont::Int64, settings::Dict)
    	last = 0  # Flag to indicate the last interval
	for i in 0:number_of_cont
    		for j in 1:(RND_intervals - 1)
        		line_outaged = if i > 0
            			index_of_line_out(future_net_vector[1],i)  # Assuming indexOfLineOut is defined
        		else
            			0
        		end
		end
        	supernet = SuperNetwork(netID, i, j, 2, last, lineOutaged, settings)
        	push!(futureNetVector, supernet)
		for j in 0:RSDIntervals
			lineOutaged = if i > 0
				index_of_line_out(futureNetVector[1],i) 
			else
				0
			end
		
		# Update last flag
			last = (j == RSDIntervals) ? 1 : 0 # Ternary operator for conditional assignment
		
			supernet = SuperNetwork(netID, i, (j + RNDIntervals), 2, last, lineOutaged, settings)
			push!(futureNetVector, supernet)
		end
    	end
end

println("\n*** SUPERNETWORK INITIALIZATION STAGE ENDS ***\n")
# ... (Previous SuperNetwork initialization code) ...

# Retrieve data from the SuperNetwork
numberOfGenerators = futureNetVector[1].getGenNumber()
numberOfLines = futureNetVector[1].getTransNumber()

# APP algorithm parameters and counters
iterCountAPP = 1
alphaAPP = 100.0

function calculate_dimensions_lagrange_multipliers( and consensus arrays)
	cons_lag_dim = if dummy_interval_choice == 1
		2 * ((number_of_cont + 1) * (RND_intervals + RSD_intervals) + 1) * number_of_generators
	else
		2 * ((number_of_cont + 1) * (RND_intervals + RSD_intervals)) * number_of_generators
	end
	cons_line_lag_dim = (RND_intervals - 1) * number_of_lines * (number_of_cont + 1)
	return cons_lag_dim, cons_line_lag_dim
end

# Initialize Lagrange multipliers and consensus arrays
lambdaAPP = zeros(consLagDim)
powDiff = zeros(consLagDim)
lambdaAPPLine = zeros(consLineLagDim)
powDiffLine = zeros(consLineLagDim)

# Number of supernetworks based on dummy interval choice
supernetNum = if dummyIntervalChoice == 1
    (numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 2
else
    (numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1
end
supernetNumNext = (numberOfCont + 1) * (RNDIntervals + RSDIntervals + 1) + (dummyIntervalChoice == 1 ? 1 : 0) # Condition for dummyInterval
supernetLineNumNext = (numberOfCont + 1) * numberOfLines * (RNDIntervals - 1)

# Power generation and line flow beliefs
powerSelfGen = zeros(supernetNum * numberOfGenerators)  
powerNextBel = zeros(supernetNumNext * numberOfGenerators)
powerPrevBel = zeros(supernetNum * numberOfGenerators)
powerNextFlowBel = zeros(supernetLineNumNext)
powerSelfFlowBel = zeros(supernetLineNumNext)
# ... (Previous variable definitions) ...


# Initialize Lagrange multipliers and power differences 
lambdaAPP .= 0.0   # Broadcasted assignment to initialize all elements to 0.0
powDiff .= 0.0
lambdaAPPLine .= 0.0
powDiffLine .= 0.0

# Initializing self, next, and previous power beliefs (warm start)
for i in 1:supernetNum # In Julia, arrays start at index 1
    for j in 1:numberOfGenerators
        # Warm start using previous dispatch results (or 0.0)
        prev_power = futureNetVector[1].getPowPrev()[j]  # Assuming getPowPrev returns an array
        powerSelfGen[(i - 1) * numberOfGenerators + j] = prev_power  # Indexing adjustment
        
        # Special case for the first interval
        if i == 1
            powerPrevBel[(i - 1) * numberOfGenerators + j] = prev_power
        else
            # You might want to change this based on your warm-start strategy
            powerPrevBel[(i - 1) * numberOfGenerators + j] = 0.0  # Or another value
        end
    end
end

for i in 1:supernetNumNext
    for j in 1:numberOfGenerators
        # You might want to change this based on your warm-start strategy
        powerNextBel[(i - 1) * numberOfGenerators + j] = futureNetVector[1].getPowPrev()[j]  # Or another value
    end
end


# Initialize power flow beliefs (difficult to warm start, so set to 0.0)
for i in 1:(numberOfCont + 1)
    for k in 1:(RNDIntervals - 1)
        for j in 1:numberOfLines
            index_next_flow = (i - 1) * (RNDIntervals - 1) * numberOfLines + (k - 1) * numberOfLines + j
            index_self_flow = (i - 1) * (RNDIntervals - 1) * numberOfLines + (k - 1) * numberOfLines + j
            powerNextFlowBel[index_next_flow] = 0.0
            powerSelfFlowBel[index_self_flow] = 0.0 
        end
    end
end
# ... (Previous variable initialization code) ...

# Initialize tolerance variables
finTol = 1000.0
finTolDelayed = 1000.0

# Determine output file name based on solver choice
outputAPPFileName = "" # Initialize the string variable
if solverChoice == 1
    outputAPPFileName = "ADMM_PMP_GUROBI/resultOuterAPP-SCOPF.txt"  # Relative path for better portability
elseif solverChoice == 2
    outputAPPFileName = "ADMM_PMP_CVXGEN/resultOuterAPP-SCOPF.txt"
elseif solverChoice == 3
    outputAPPFileName = "APP_Quasi_Decent_GUROBI/resultOuterAPP-SCOPF.txt"
elseif solverChoice == 4
    outputAPPFileName = "APP_GUROBI_Centralized_SCOPF/resultOuterAPP-SCOPF.txt"
end

# Open the file for writing
try
    open(outputAPPFileName, "w") do matrixResultAPPOut
        # Write initial messages to the file
        println(matrixResultAPPOut, "\n*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) SUPERNETWORK LAYER BEGINS ***\n")
        println(matrixResultAPPOut, "\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")
        println(matrixResultAPPOut, "\nInitial Value of the Tolerance to kick-start the APP outer iterations= $finTol\n")
        println(matrixResultAPPOut, "APP Iteration Count\tAPP Tolerance")

        # --- (The rest of your APP algorithm will go here) ---
    end  # Close the file automatically when the block ends
catch e
    println(stderr, "File could not be opened: ", e) # Output the error to stderr
    exit(1) # Exit program with error
end

# Print messages to the console as well
println("\n*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) SUPERNETWORK LAYER BEGINS ***\n")
println("\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")
# ... (Your previous code)

# Vectors to store timing information
largestSuperNetTimeVec = Float64[]  # Vector to store the largest supernetwork time per iteration
singleSuperNetTimeVec = Float64[]  # Vector to store individual supernetwork times

# Clear vectors for the upcoming iteration
empty!(largestSuperNetTimeVec)
empty!(singleSuperNetTimeVec)

# Initialize actual supernetwork time
actualSuperNetTime = 0.0

# Start timing
start_time = time()  # Use Julia's `time()` function to get the current time in seconds
# ... (Previous code for initialization and variable definitions) ...


# APP Iteration Loop
while finTol >= 0.005  # Termination criterion
	empty!(singleSuperNetTimeVec)  # Clear the vector to store this iteration's times
    
	if dummyIntervalChoice == 1
	    netSimRange = 0:(numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1
	else
	    netSimRange = 0:(numberOfCont + 1) * (RNDIntervals + RSDIntervals)
	end
    
	for netSimCount in netSimRange
	    # Display iteration information
	    if netSimCount == 0
		println("\nStart of $iterCountAPP-th Outermost APP iteration for dummy zero dispatch interval")
	    elseif netSimCount == 1
		println("\nStart of $iterCountAPP-th Outermost APP iteration for $netSimCount-th dispatch interval")
	    else
		println("\nStart of $iterCountAPP-th Outermost APP iteration for second dispatch interval for $(netSimCount - 2)-th post-contingency scenario")
	    end
	    
	    # Run simulation for the current SuperNetwork
	    # Adjust the index if dummyIntervalChoice is 0
	    supernet_index = netSimCount + (dummyIntervalChoice == 0 ? 1 : 0)
	    futureNetVector[supernet_index].runSimulation(iterCountAPP, lambdaAPP, powDiff, powerSelfGen, powerNextBel, powerPrevBel, lambdaAPPLine, powDiffLine, powerSelfFlowBel, powerNextFlowBel, env) 
	    
	    # Store timing information
	    single_net_time = futureNetVector[supernet_index].getvirtualNetExecTime()
	    actualSuperNetTime += single_net_time
	    push!(singleSuperNetTimeVec, single_net_time)
	end
    
	# Find and store the largest supernetwork time from this iteration
	largestSuperNetTime = maximum(singleSuperNetTimeVec)
	push!(largestSuperNetTimeVec, largestSuperNetTime)
    
	# Update beliefs and disagreements (This is complex and depends on your SuperNetwork structure; you'll need to fill this in)
	# ... your code for updating powerSelfGen, powerNextBel, powerPrevBel, powDiff, powerNextFlowBel, powerSelfFlowBel, powDiffLine...
    
	# Tune alphaAPP (adaptive step size)
	if 5 < iterCountAPP <= 10
	    alphaAPP = 75.0
	elseif 10 < iterCountAPP <= 15
	    alphaAPP = 50.0
	elseif 15 < iterCountAPP <= 20
	    alphaAPP = 25.0
	elseif iterCountAPP > 20
	    alphaAPP = 10.0
	end
    
	# Update Lagrange multipliers
	lambdaAPP .+= alphaAPP .* powDiff  # Element-wise update
	lambdaAPPLine .+= alphaAPP .* powDiffLine
    
    
	# Calculate and Output tolerances (This requires output handling, not shown here)
	#... your code for calculating and outputting tolAPP, finTol, tolAPPDelayed, finTolDelayed
       
	iterCountAPP += 1
    end
 ### Gemini generated code translation   






# Main function for implementing APMP Algorithm for the LASCOPF for Post-Contingency Restoration Controlling Line Temperature case in serial mode
module LASCOPFTemp
export runSimLASCOPFTemp

using JuMP # used for mathematical programming
using DataFrames #This package allows put together data into a matrix
using Gurobi #Gurobi solver
using MathProgBase #for fix_integers
using CSV
using StatsBase
using LinearAlgebra
using JSON
using superNetwork
include("Julia_src/superNetwork.jl")

function run_sim_lascopf_temp(setting::Dict, inputPath::AbstractString) #function runSimLASCOPFTemp begins program execution
	last = 0 #flag to indicate the last interval; last = 0, for dispatch interval that is not the last one; last = 1, for the last interval
	futureNetVector = Dict() #Vector of future look-ahead dispatch interval supernetwork objects
	if (solverChoice==1) or (solverChoice==2) #APMP Fully distributed, Bi-layer (N-1) SCOPF Simulation
		println("Enter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant).") 
		setRhoTuning = parse(Int64, readline())
	else
		setRhoTuning = 0 #Otherwise, if we aren't using ADMM-PMP, Rho tuning is unnecessary, 0 is a dummy value
	end
	supernetwork_initialization()
end

function supernetwork_initialization()
	log.info("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***")
	#GRBEnv* environmentGUROBI = new GRBEnv("GUROBILogFile.log"); // GUROBI Environment object for storing the different optimization models
	supernet = superNetwork(netID, setting['solverChoice'], setting['setRhoTuning'], 0, 0, 0, 0, setting['nextChoice'], setting['dummyIntervalChoice'], setting['contSolverAccuracy'], 0, setting['RNDIntervals'], setting['RSDIntervals']) #create the network instances for the future dummy zero dispatch intervals
	numberOfCont = supernet.retContCount() #gets the number of contingency scenarios in the variable numberOfCont
	futureNetVector.append(supernet) #push to the vector of future network instances 
	supernet1 = superNetwork(netID, solverChoice, setRhoTuning, 0, 0, 1, 0, nextChoice, dummyIntervalChoice, contSolverAccuracy, 0, RNDIntervals, RSDIntervals) #create the network instances for the future upcoming dispatch intervals
	futureNetVector.append(supernet1) #push to the vector of future network instances 
	for i in range(numberOfCont+1)
		for j in range(RNDIntervals - 1)
			lineOutaged = 0 #the serial number of transmission line outaged in any scenario: default value is zero
			if i > 0 #for the post-contingency scenarios
				lineOutaged = futureNetVector[0].indexOfLineOut(i) #gets the serial number of transmission line outaged in this scenario 
			end
			#create the network instances for the future next-to-upcoming-dispatch intervals for pos-contingency cases
			futureNetVector.append(superNetwork(netID, solverChoice, setRhoTuning, i, j+1, 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)) #push to the vector of future network instances
		end
		for j in range(RSDIntervals+1)
			lineOutaged = 0 #the serial number of transmission line outaged in any scenario: default value is zero
			if i > 0 #for the post-contingency scenarios
				lineOutaged = futureNetVector[0].indexOfLineOut(i) #gets the serial number of transmission line outaged in this scenario 
			end
			if j == RSDIntervals #set the flag to 1 to indicate the last interval
				last = 1 #set the flag to 1 to indicate the last interval
			end
			#create the network instances for the future next-to-upcoming-dispatch intervals for pos-contingency cases
			futureNetVector.append(superNetwork(netID, solverChoice, setRhoTuning, i, (j+RNDIntervals), 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)) # push to the vector of future network instances
		end
	end
	log.info("\n*** SUPERNETWORK INITIALIZATION STAGE ENDS ***\n")
end

"""
    run_app_outer_loop!(future_net_vector, number_of_cont, rnd_intervals, rsd_intervals,
                        dummy_interval_choice, solver_choice; max_app_iterations, output_dir)

APP coarse-grained outer iteration loop for the LASCOPF post-contingency restoration problem.

Manages the Lagrange multiplier (λ) arrays and power/flow belief vectors across all
dispatch-interval × contingency-scenario SuperNetworks until the consensus disagreement
(`fin_tol`) drops below 0.005 or `max_app_iterations` is reached.

`future_net_vector` is the pre-built vector from `spawn_networks!`, with one entry per
(contingency scenario, dispatch interval) pair. The dummy zero-interval entry, when used,
is always at index 1.

Returns the result log as a `Dict{String, Any}`.
"""
function run_app_outer_loop!(
    future_net_vector::Vector{SuperNetwork},
    number_of_cont::Int,
    rnd_intervals::Int,
    rsd_intervals::Int,
    dummy_interval_choice::Bool,
    solver_choice::Int;
    max_app_iterations::Int = typemax(Int),
    output_dir::String = "results"
)::Dict{String, Any}

    # ------------------------------------------------------------------
    # Consensus array dimensions
    # ------------------------------------------------------------------
    n_gen   = get_gen_number(future_net_vector[1])
    n_lines = get_trans_number(future_net_vector[1])

    if dummy_interval_choice
        cons_lag_dim      = 2 * ((number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1) * n_gen
        supernet_num      = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1) + 1
    else
        cons_lag_dim      = 2 * (number_of_cont + 1) * (rnd_intervals + rsd_intervals) * n_gen
        supernet_num      = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
        supernet_num_next = (number_of_cont + 1) * (rnd_intervals + rsd_intervals + 1)
    end
    cons_line_lag_dim      = (rnd_intervals - 1) * n_lines * (number_of_cont + 1)
    supernet_line_num_next = (number_of_cont + 1) * n_lines * (rnd_intervals - 1)

    # ------------------------------------------------------------------
    # Lagrange multiplier and disagreement arrays
    # ------------------------------------------------------------------
    lambda_app      = zeros(cons_lag_dim)
    pow_diff        = zeros(cons_lag_dim)
    lambda_app_line = zeros(cons_line_lag_dim)
    pow_diff_line   = zeros(cons_line_lag_dim)

    # ------------------------------------------------------------------
    # Power and line-flow belief arrays
    # ------------------------------------------------------------------
    power_self_gen      = zeros(supernet_num * n_gen)
    power_next_bel      = zeros(supernet_num_next * n_gen)
    power_prev_bel      = zeros(supernet_num * n_gen)
    power_next_flow_bel = zeros(supernet_line_num_next)
    power_self_flow_bel = zeros(supernet_line_num_next)

    # Warm-start: seed all generation beliefs with the last realised dispatch.
    # The if/else in the original source is identical in both branches, so we
    # write it once. Flow beliefs have no reliable warm start and stay at zero.
    prev_powers = get_pow_prev(future_net_vector[1])
    for i in 0:(supernet_num - 1), j in 0:(n_gen - 1)
        power_self_gen[i * n_gen + j + 1] = prev_powers[j + 1]
        power_prev_bel[i * n_gen + j + 1] = prev_powers[j + 1]
    end
    for i in 0:(supernet_num_next - 1), j in 0:(n_gen - 1)
        power_next_bel[i * n_gen + j + 1] = prev_powers[j + 1]
    end

    # ------------------------------------------------------------------
    # APP iteration state
    # ------------------------------------------------------------------
    fin_tol        = 1000.0
    fin_tol_delayed = 1000.0
    iter_count_app  = 1

    result_log = Dict{String, Any}("initial_tolerance" => fin_tol)

    println("\n*** APMP LASCOPF SUPERNETWORK LAYER BEGINS ***")
    println("*** SIMULATION IN PROGRESS ***\n")

    largest_supernet_time_vec = Float64[]
    actual_supernet_time      = 0.0
    start_time                = time()

    # ==================================================================
    # Main APP outer iteration loop
    # ==================================================================
    while fin_tol >= 0.005 && iter_count_app <= max_app_iterations
        single_supernet_time_vec = Float64[]

        # ---- Phase 1: solve each SuperNetwork for the current λ ------
        if dummy_interval_choice
            n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2
            for nsc in 0:(n_nets - 1)
                _log_app_iteration(iter_count_app, nsc; dummy=true)
                sn = future_net_vector[nsc + 1]
                run_simulation!(sn, iter_count_app,
                                lambda_app, pow_diff,
                                power_self_gen, power_next_bel, power_prev_bel,
                                lambda_app_line, pow_diff_line,
                                power_self_flow_bel, power_next_flow_bel)
                t = get_virtual_net_exec_time(sn)
                actual_supernet_time += t
                push!(single_supernet_time_vec, t)
            end
        else
            n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1
            for nsc in 0:(n_nets - 1)
                _log_app_iteration(iter_count_app, nsc; dummy=false)
                # Python accessed futureNetVector[nsc+1] (0-based); +1 more for Julia 1-based
                sn = future_net_vector[nsc + 2]
                run_simulation!(sn, iter_count_app,
                                lambda_app, pow_diff,
                                power_self_gen, power_next_bel, power_prev_bel,
                                lambda_app_line, pow_diff_line,
                                power_self_flow_bel, power_next_flow_bel)
                t = get_virtual_net_exec_time(sn)
                actual_supernet_time += t
                push!(single_supernet_time_vec, t)
            end
        end

        push!(largest_supernet_time_vec, maximum(single_supernet_time_vec))

        # ---- Phase 2: update beliefs and disagreements ---------------
        if dummy_interval_choice
            _update_beliefs_with_dummy!(
                future_net_vector, pow_diff, pow_diff_line,
                power_self_gen, power_next_bel, power_prev_bel,
                power_next_flow_bel, power_self_flow_bel,
                number_of_cont, n_gen, n_lines, rnd_intervals, rsd_intervals)
        else
            _update_beliefs_without_dummy!(
                future_net_vector, pow_diff, pow_diff_line,
                power_self_gen, power_next_bel, power_prev_bel,
                power_next_flow_bel, power_self_flow_bel,
                number_of_cont, n_gen, n_lines, rnd_intervals, rsd_intervals)
        end

        # ---- Phase 3: update λ and check convergence -----------------
        alpha_app = tune_alpha_app(iter_count_app)
        lambda_app      .+= alpha_app .* pow_diff
        lambda_app_line .+= alpha_app .* pow_diff_line

        tol_app = sum(abs2, pow_diff) + sum(abs2, pow_diff_line)

        if dummy_interval_choice
            # Delayed tolerance excludes the dummy interval's 2*n_gen contributions
            # (Python: `if i >= 2*numberOfGenerators` skips the first block of powDiff)
            tol_app_delayed = sum(abs2, @view pow_diff[(2 * n_gen + 1):end]) +
                              sum(abs2, pow_diff_line)
            fin_tol         = sqrt(tol_app)
            fin_tol_delayed = sqrt(tol_app_delayed)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance"         => fin_tol,
                "Delayed_APP_Tolerance" => fin_tol_delayed,
                "alpha_app"             => alpha_app
            )
            @printf("APP iter %d: tol = %.6f, delayed = %.6f, α = %.1f\n",
                    iter_count_app, fin_tol, fin_tol_delayed, alpha_app)
            # Convergence is tested on the delayed tolerance (excludes dummy interval)
            fin_tol = fin_tol_delayed
        else
            fin_tol = sqrt(tol_app)
            result_log["iter_$(iter_count_app)"] = Dict{String, Any}(
                "APP_Tolerance" => fin_tol,
                "alpha_app"     => alpha_app
            )
            @printf("APP iter %d: tol = %.6f, α = %.1f\n", iter_count_app, fin_tol, alpha_app)
        end

        iter_count_app += 1
    end

    # ------------------------------------------------------------------
    # Wrap-up: timing and results
    # ------------------------------------------------------------------
    stop_s       = time() - start_time
    virtual_time = stop_s - actual_supernet_time + sum(largest_supernet_time_vec)

    println("\n*** LASCOPF SUPERNETWORK LAYER ENDS ***")
    @printf("Execution time:         %.2f s\n", stop_s)
    @printf("Virtual execution time: %.2f s\n", virtual_time)

    result_log["timing"] = Dict{String, Any}(
        "execution_s"         => stop_s,
        "virtual_execution_s" => virtual_time
    )

    _save_app_results(result_log, solver_choice; output_dir)
    return result_log
end

# ──────────────────────────────────────────────────────────────────────────────
# Private helpers
# ──────────────────────────────────────────────────────────────────────────────

# Loop variables throughout are kept 0-based (matching the Python index formulas);
# +1 is added only at Julia array-access and SuperNetwork-vector-access points.

"""
Belief and disagreement update for the WITH-dummy case.
"""
function _update_beliefs_with_dummy!(
    fv::Vector{SuperNetwork},
    pow_diff::Vector{Float64},         pow_diff_line::Vector{Float64},
    power_self_gen::Vector{Float64},   power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},   power_next_flow_bel::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    number_of_cont::Int, n_gen::Int, n_lines::Int,
    rnd_intervals::Int, rsd_intervals::Int
)
    n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 2

    for i in 0:(n_nets - 1)
        sn_i = fv[i + 1]

        if i == 0
            sn_ip1 = fv[2]
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                next_j = get_pow_next(sn_i, 1, 1, j + 1)
                pow_diff[j + 1]         = self_j - get_pow_prev(sn_ip1)[j + 1]
                power_self_gen[j + 1]   = self_j
                power_next_bel[j + 1]   = next_j
                power_prev_bel[j + 1]   = get_pow_prev(sn_i)[j + 1]
                pow_diff[n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
            end
        else
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                power_self_gen[i * n_gen + j + 1] = self_j

                if i == 1
                    for cc in 0:number_of_cont
                        sn_cc  = fv[i + cc + 2]
                        next_j = get_pow_next(sn_i, cc + 1, i + 1, j + 1)
                        power_next_bel[(i + cc) * n_gen + j + 1]       = next_j
                        pow_diff[2*(i+cc)*n_gen + j + 1]               = self_j - get_pow_prev(sn_cc)[j + 1]
                        pow_diff[(2*(i+cc)+1)*n_gen + j + 1]           = next_j - get_pow_self(sn_cc, j + 1)
                    end
                else
                    next_j = get_pow_next(sn_i, 1, i + 1, j + 1)
                    power_next_bel[(i + number_of_cont) * n_gen + j + 1] = next_j
                    for cc in 0:number_of_cont
                        # Skip the last interval of each post-contingency sequence
                        if i != (cc + 1) * (rnd_intervals + rsd_intervals) + 1
                            sn_ip1 = fv[i + 2]
                            pow_diff[2*(i+number_of_cont)*n_gen + j + 1]     = self_j - get_pow_prev(sn_ip1)[j + 1]
                            pow_diff[(2*(i+number_of_cont)+1)*n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
                        end
                    end
                end

                power_prev_bel[i * n_gen + j + 1] = get_pow_prev(sn_i)[j + 1]
            end

            for j in 0:(n_lines - 1)
                if i == 1
                    for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                        fidx     = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                        # Python: futureNetVector[2+cc*(RND+RSD)+k] → Julia: fv[3+cc*(rnd+rsd)+k]
                        sn_tgt   = fv[3 + cc * (rnd_intervals + rsd_intervals) + k]
                        flo_next = get_pow_flow_next(sn_i, cc + 1, i + 1, k + 1, j + 1)
                        power_next_flow_bel[fidx] = flo_next
                        pow_diff_line[fidx]        = flo_next - get_pow_flow_self(sn_tgt, j + 1)
                    end
                else
                    for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                        if i == 2 + cc * (rnd_intervals + rsd_intervals) + k
                            fidx = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                            power_self_flow_bel[fidx] = get_pow_flow_self(sn_i, j + 1)
                        end
                    end
                end
            end
        end
    end
end

"""
Belief and disagreement update for the WITHOUT-dummy case.
"""
function _update_beliefs_without_dummy!(
    fv::Vector{SuperNetwork},
    pow_diff::Vector{Float64},         pow_diff_line::Vector{Float64},
    power_self_gen::Vector{Float64},   power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},   power_next_flow_bel::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    number_of_cont::Int, n_gen::Int, n_lines::Int,
    rnd_intervals::Int, rsd_intervals::Int
)
    n_nets = (number_of_cont + 1) * (rnd_intervals + rsd_intervals) + 1

    for i in 0:(n_nets - 1)
        # Python: futureNetVector[i+1] (0-based i) → Julia: fv[i+2]
        sn_i = fv[i + 2]

        if i == 0
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                power_self_gen[j + 1] = self_j
                for cc in 0:number_of_cont
                    # Python: futureNetVector[i+cc+2] → Julia: fv[cc+3] (i=0)
                    sn_cc  = fv[cc + 3]
                    next_j = get_pow_next(sn_i, cc + 1, i + 2, j + 1)
                    power_next_bel[cc * n_gen + j + 1]       = next_j
                    pow_diff[2*cc*n_gen + j + 1]             = self_j - get_pow_prev(sn_cc)[j + 1]
                    pow_diff[(2*cc+1)*n_gen + j + 1]         = next_j - get_pow_self(sn_cc, j + 1)
                end
                power_prev_bel[j + 1] = get_pow_prev(sn_i)[j + 1]
            end
            for j in 0:(n_lines - 1)
                for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                    fidx     = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                    # Python: futureNetVector[2+cc*(RND+RSD)+k] → Julia: fv[3+cc*(rnd+rsd)+k]
                    sn_tgt   = fv[3 + cc * (rnd_intervals + rsd_intervals) + k]
                    flo_next = get_pow_flow_next(sn_i, cc + 1, i + 2, k + 1, j + 1)
                    power_next_flow_bel[fidx] = flo_next
                    pow_diff_line[fidx]        = flo_next - get_pow_flow_self(sn_tgt, j + 1)
                end
            end
        else
            for j in 0:(n_gen - 1)
                self_j = get_pow_self(sn_i, j + 1)
                next_j = get_pow_next(sn_i, 1, i + 2, j + 1)
                power_self_gen[i * n_gen + j + 1]                    = self_j
                power_next_bel[(i + number_of_cont) * n_gen + j + 1] = next_j
                power_prev_bel[i * n_gen + j + 1]                    = get_pow_prev(sn_i)[j + 1]
                for cc in 0:number_of_cont
                    # Skip the last interval of each post-contingency sequence
                    if i != (cc + 1) * (rnd_intervals + rsd_intervals)
                        # Python: futureNetVector[i+2] → Julia: fv[i+3]
                        sn_ip1 = fv[i + 3]
                        pow_diff[2*(i+number_of_cont)*n_gen + j + 1]     = self_j - get_pow_prev(sn_ip1)[j + 1]
                        pow_diff[(2*(i+number_of_cont)+1)*n_gen + j + 1] = next_j - get_pow_self(sn_ip1, j + 1)
                    end
                end
            end
            for j in 0:(n_lines - 1)
                for cc in 0:number_of_cont, k in 0:(rnd_intervals - 2)
                    if i == 1 + cc * (rnd_intervals + rsd_intervals) + k
                        fidx = cc * (rnd_intervals - 1) * n_lines + k * n_lines + j + 1
                        power_self_flow_bel[fidx] = get_pow_flow_self(sn_i, j + 1)
                    end
                end
            end
        end
    end
end

"""
Log the start of an APP network simulation in a consistent format.
"""
function _log_app_iteration(iter_count_app::Int, net_sim_count::Int; dummy::Bool)
    if dummy
        if net_sim_count == 0
            println("Start of $iter_count_app-th APP iteration for dummy zero dispatch interval")
        elseif net_sim_count == 1
            println("Start of $iter_count_app-th APP iteration for $(net_sim_count)-th dispatch interval")
        else
            println("Start of $iter_count_app-th APP iteration for second dispatch interval for $(net_sim_count - 2)-th post-contingency scenario")
        end
    else
        if net_sim_count == 0
            println("Start of $iter_count_app-th APP iteration for $(net_sim_count + 1)-th dispatch interval")
        else
            println("Start of $iter_count_app-th APP iteration for second dispatch interval for $(net_sim_count - 1)-th post-contingency scenario")
        end
    end
end

"""
    run_simulation!(sn, iter_count_app, lambda_app, pow_diff, ..., power_next_flow_bel)

Dispatch for running one per-interval SuperNetwork's inner optimization within the APP loop.
Receives all belief and λ arrays so the solver can read consensus targets and update the
network's internal power/angle variables (making them visible to `get_pow_self` etc.).

Needs a concrete implementation once the inner ADMM/APP solver is wired up to `SuperNetwork`.
"""
function run_simulation!(
    sn::SuperNetwork,
    iter_count_app::Int,
    lambda_app::Vector{Float64},
    pow_diff::Vector{Float64},
    power_self_gen::Vector{Float64},
    power_next_bel::Vector{Float64},
    power_prev_bel::Vector{Float64},
    lambda_app_line::Vector{Float64},
    pow_diff_line::Vector{Float64},
    power_self_flow_bel::Vector{Float64},
    power_next_flow_bel::Vector{Float64}
)
    for network in sn.networks
        run_simulation!(network, sn, iter_count_app, 1)
    end
end

function _save_app_results(result_log::Dict{String, Any}, solver_choice::Int;
                            output_dir::String = "results")
    solver_names = Dict(1 => "ADMM_PMP_GUROBI",
                        2 => "ADMM_PMP_CVXGEN",
                        3 => "APP_Quasi_Decent_GUROBI",
                        4 => "APP_GUROBI_Centralized_SCOPF")
    isdir(output_dir) || mkdir(output_dir)
    name     = get(solver_names, solver_choice, "Unknown_Solver")
    filename = joinpath(output_dir, "$(name)_resultOuterAPP-SCOPF.json")
    open(filename, "w") do f
        JSON3.pretty(f, result_log)
    end
    println("Results saved to $filename")
end
