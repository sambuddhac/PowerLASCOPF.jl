using Gurobi ### ChatGPT 4.0 Generated code translation from C++ to Julia

mutable struct SuperNetwork
    # Define the fields of the SuperNetwork struct here
end

function main()
    netID::Int
    solverChoice::Int
    dummyIntervalChoice::Int
    RNDIntervals::Int
    RSDIntervals::Int
    nextChoice::Int
    contSolverAccuracy::Int
    setRhoTuning::Int
    last::Int = 0
    futureNetVector = Vector{SuperNetwork}()

    println("Enter the number of nodes to initialize the network. (Allowed choices are 2, 3, 5, 14, 30, 48, 57, 118, and 300 Bus IEEE Test Bus Systems as of now. So, please restrict yourself to one of these)")
    netID = parse(Int, readline())
    
    println("Enter the switch value to select between whether an extensive/exhaustive (and presumably more accurate) solver for contingency scenarios is desired, or just a simpler one is desired; 1 for former, 0 for latter")
    contSolverAccuracy = parse(Int, readline())
    
    println("Enter the choice of the solver for SCOPF of each dispatch interval, 1 for GUROBI-APMP(ADMM/PMP+APP), 2 for CVXGEN-APMP(ADMM/PMP+APP), 3 for GUROBI APP Coarse Grained, 4 for centralized GUROBI SCOPF")
    solverChoice = parse(Int, readline())
    
    println("Enter the choice pertaining to whether you want to consider the ramping constraint to the next interval, for the last interval: 0 for not considering and 1 for considering")
    nextChoice = parse(Int, readline())
    
    if solverChoice == 1 || solverChoice == 2
        println("Enter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant).")
        setRhoTuning = parse(Int, readline())
    else
        setRhoTuning = 0
    end
    
    println("Enter the choice pertaining to whether to include a dummy interval at the start or not (Inclusion of a dummy interval may speed up convergence and/or improve accuracy of solution). Enter 1 to include and 0 to not include")
    dummyIntervalChoice = parse(Int, readline())
    
    println("Enter the number of look-ahead dispatch intervals for restoring line flows to within normal long-term ratings.")
    RNDIntervals = parse(Int, readline())
    
    println("Enter the number of furthermore look-ahead dispatch intervals for making the system secure w.r.t. next set of contingencies.")
    RSDIntervals = parse(Int, readline())
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")
    
    environmentGUROBI = Gurobi.Env("GUROBILogFile.log")
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

println("Enter the choice pertaining to whether to include a dummy interval at the start or not (Inclusion of a dummy interval may speed up convergence and/or improve accuracy of solution). Enter 1 to include and 0 to not include")
dummyIntervalChoice = parse(Int, readline())  # Read and parse the input as an integer

println("Enter the number of look-ahead dispatch intervals for restoring line flows to within normal long-term ratings.")
RNDIntervals = parse(Int, readline())  # Read and parse the input as an integer

println("Enter the number of furthermore look-ahead dispatch intervals for making the system secure w.r.t. next set of contingencies.")
RSDIntervals = parse(Int, readline())  # Read and parse the input as an integer


# Create SuperNetwork instances (push! adds to the end of the vector)
futureNetVector = SuperNetwork[]  

# ... rest of the supernetwork initialization
# ... (Previous input handling code) ...

println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")

# Set up the Gurobi environment (if using JuMP with Gurobi)
# You'll need to install and load the Gurobi.jl package first
env = Gurobi.Env() # Create Gurobi environment

# Create initial SuperNetworks
supernet = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 0, 0, next_choice, dummy_interval_choice, cont_solver_accuracy, 0, RND_intervals, RSD_intervals)
number_of_cont = ret_cont_count(supernet)  # Assuming retContCount is defined in your SuperNetwork type
push!(future_net_vector, supernet)

supernet1 = SuperNetwork(net_id, solver_choice, set_rho_tuning, 0, 0, 1, 0, next_choice, dummy_interval_choice, cont_solver_accuracy, 0, RND_intervals, RSD_intervals)
push!(future_net_vector, supernet1)

spawn_networks!(future_net_vector, number_of_cont, RND_intervals, RSD_intervals, next_choice, dummy_interval_choice, cont_solver_accuracy)

# Main loop to create SuperNetworks for contingencies and intervals
function spawn_networks!(future_net_vector::Vector{SuperNetwork}, number_of_cont::Int64, RND_intervals::Int64, RSD_intervals::Int64, next_choice::Bool, dummy_interval_choice::Bool, cont_solver_accuracy::Bool)
    	last = 0  # Flag to indicate the last interval
	for i in 0:number_of_cont
    		for j in 1:(RND_intervals - 1)
        		line_outaged = if i > 0
            			future_net_vector[1].index_of_line_out(i)  # Assuming indexOfLineOut is defined
        		else
            			0
        		end
		end
        	supernet = SuperNetwork(netID, solverChoice, setRhoTuning, i, j, 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)
        	push!(futureNetVector, supernet)
    	end

    	for j in 0:RSDIntervals
        	lineOutaged = if i > 0
            			futureNetVector[1].indexOfLineOut(i) 
        		else
            			0
        		end
        
        	# Update last flag
        	last = (j == RSDIntervals) ? 1 : 0 # Ternary operator for conditional assignment
        
        	supernet = SuperNetwork(netID, solverChoice, setRhoTuning, i, (j + RNDIntervals), 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)
        	push!(futureNetVector, supernet)
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

# Calculate dimensions for Lagrange multipliers and consensus arrays
consLagDim = if dummyIntervalChoice == 1
    2 * ((numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1) * numberOfGenerators
else
    2 * ((numberOfCont + 1) * (RNDIntervals + RSDIntervals)) * numberOfGenerators
end
consLineLagDim = (RNDIntervals - 1) * numberOfLines * (numberOfCont + 1)

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

	numberOfGenerators = futureNetVector[0].getGenNumber() #get the number of generators in the system
	numberOfLines = futureNetVector[0].getTransNumber() #get the number of remaining transmission lines in the system
	iterCountAPP = 1 #Iteration counter for APP coarse grain decomposition algorithm
	alphaAPP = 100.0 #APP Parameter/Path-length
	#Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	if dummyIntervalChoice==1:
		consLagDim = 2*((numberOfCont+1)*(RNDIntervals+RSDIntervals)+1)*numberOfGenerators #Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	else:
		consLagDim = 2*((numberOfCont+1)*(RNDIntervals+RSDIntervals))*numberOfGenerators #Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	#Dimension of the vectors of APP Lagrange Multipliers and Line Flow consensus for (RND-1) intervals for temperature limiting	
	consLineLagDim = (RNDIntervals-1)*numberOfLines*(numberOfCont+1) #Dimension of the vectors of APP Lagrange Multipliers and remaining transmission lines in the system-flow Consensus
	lambdaAPP = np.zeros(consLagDim, float) #Array of APP Lagrange Multipliers for achieving consensus among the values of power generated, as guessed by different intervals
	powDiff = np.zeros(consLagDim, float) #Array of lack of consensus between generation values, as guessed by different intervals
	lambdaAPPLine = np.zeros(consLineLagDim, float) #Array of APP Lagrange Multipliers for achieving consensus among the values of line flows, as guessed by different intervals
	powDiffLine = np.zeros(consLineLagDim, float) #Array of lack of consensus between line flows, as guessed by different intervals
	if dummyIntervalChoice==1:
		supernetNum=(numberOfCont+1)*(RNDIntervals+RSDIntervals)+2 #Number of supernetworks considered for computation (whether dummy interval is included or not)
		supernetNumNext=(numberOfCont+1)*(RNDIntervals+RSDIntervals+1)+1 #Number of future supernetworks about which generation belief are held by the existing supernetworks
	else:
		supernetNum=(numberOfCont+1)*(RNDIntervals+RSDIntervals)+1 #Number of supernetworks considered for computation (whether dummy interval is included or not)
		supernetNumNext=(numberOfCont+1)*(RNDIntervals+RSDIntervals+1) #Number of future supernetworks about which generation belief are held by the existing supernetworks
	supernetLineNumNext=(numberOfCont+1)*numberOfLines*(RNDIntervals-1) #Number of future supernetworks about which line flow beliefs are held by the existing supernetworks
	powerSelfGen = np.zeros(supernetNum*numberOfGenerators, float) #what I think about myself
	powerNextBel = np.zeros(supernetNumNext*numberOfGenerators, float) #what I think about next door fellow
	powerPrevBel = np.zeros(supernetNum*numberOfGenerators, float) #what I think about previous door fellow
	powerNextFlowBel = np.zeros(supernetLineNumNext, float) #what I think about flows for next door fellow
	powerSelfFlowBel = np.zeros(supernetLineNumNext, float) #what I think about flows for myself (only look-ahead intervals 1 to (RNDIntervals-1))

	#Initializing the self belief, next belief, and previous beliefs about MW generated by a warm start with the respective generation values of last realized dispatch
	for i in range(supernetNum):
		for j in range(numberOfGenerators):
			powerSelfGen[i*numberOfGenerators+j] = (futureNetVector[0]).getPowPrev(j) #Use 0.0 if warm start is not desired
			if i==0:
				powerPrevBel[i*numberOfGenerators+j] = (futureNetVector[0]).getPowPrev(j) #Actual value of previous interval dispatch for the first interval
			else:
				powerPrevBel[i*numberOfGenerators+j] = (futureNetVector[0]).getPowPrev(j) #Use 0.0 if warm start is not desired
	for i in range(supernetNumNext):
		for j in range(numberOfGenerators):
			powerNextBel[i*numberOfGenerators+j] = (futureNetVector[0]).getPowPrev(j) #Use 0.0 if warm start is not desired
	for i in range(numberOfCont+1):
		for k in range(RNDIntervals-1):
			for j in range(numberOfLines):
				powerNextFlowBel[i*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = 0.0 #Difficult to warm start so just assume 0
				powerSelfFlowBel[i*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = 0.0 #Difficult to warm start so just assume 0
	finTol = 1000.0 #Initial Guess of the Final tolerance of the APP iteration/Stopping criterion
	finTolDelayed = 1000.0 #Initial Guess of the Final tolerance delayed of the APP iteration/Stopping criterion
	matrixResultAPPOut = dict() #create a new dictionary to output the results
		
	matrixResultAPPOut[0] = {'Initial Value of the Tolerance to kick-start the APP outer iterations':finTol}
	log.info("\n*** APMP ALGORITHM BASED LASCOPF FOR POST CONTINGENCY RESTORATION CONTROLLING LINE TEMPERATURE SIMULATION (SERIAL IMPLEMENTATION) SUPERNETWORK LAYER BEGINS ***\n")
	log.info("\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")

#*********************************************AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************//
	largestSuperNetTimeVec = [] # vector largest value of the computational time in a particular outer APP iteration for any supernetwork
	singleSuperNetTimeVec = [] #vector of the computational times in a particular outer APP iteration for all supernetworks
	actualSuperNetTime = 0 #Initialize the supernetwork computational time
	profiler.start() #begin keeping track of the time
	while finTol >= 0.005: #Check the termination criterion of the APP iterations #APP Coarse grain iterations start
	#for iterCountAPP in range(101):
		singleSuperNetTimeVec = [] #clear for upcoming iteration
		if dummyIntervalChoice == 1: #Outermost APP layer with a dummy zero interval at the beginning
			for netSimCount in range((numberOfCont+1)*(RNDIntervals+RSDIntervals)+2):
				if netSimCount == 0:
					log.info("\nStart of {} -th Outermost APP iteration for dummy zero dispatch interval".format(iterCountAPP))
				elif netSimCount == 1:
					log.info("\nStart of {} -th Outermost APP iteration for {} -th dispatch interval".format(iterCountAPP, netSimCount))
				else:
					log.info("\nStart of {} -th Outermost APP iteration for second dispatch interval for {} -th post-contingency scenario".format(iterCountAPP, netSimCount-2))
				futureNetVector[netSimCount].runSimulation(iterCountAPP, lambdaAPP, powDiff, powerSelfGen, powerNextBel, powerPrevBel, lambdaAPPLine, powDiffLine, powerSelfFlowBel, powerNextFlowBel)#, environmentGUROBI) #start simulation
				singleSuperNetTime = futureNetVector[netSimCount].getvirtualNetExecTime() #get the computational time for each supernetwork under the assumption of nested and complete parallelism of each generator optimization, within each coarse grain optimization in the supernetworks
				actualSuperNetTime += singleSuperNetTime #Actual time
				singleSuperNetTimeVec.append(singleSuperNetTime) #Vector of all independent supernet solve times
			largestSuperNetTime = max(singleSuperNetTimeVec) #get the laziest solve-time for this iteration
			largestSuperNetTimeVec.append(largestSuperNetTime) #vector of all te laziest supernet calculations over all iterations
			#Calculate the power generation opinions and disagreements between the different dispatch interval coarse grains
			for i in range((numberOfCont+1)*(RNDIntervals+RSDIntervals)+2):
				if i==0:
					for j in range(numberOfGenerators):
						powDiff[2*i*numberOfGenerators+j] = futureNetVector[i].getPowSelf(j) - futureNetVector[i+1].getPowPrev(j) #what I think about myself Vs. what next door fellow thinks about me
						powerSelfGen[i*numberOfGenerators+j] = futureNetVector[i].getPowSelf(j) #what I think about myself
						powerNextBel[i*numberOfGenerators+j] = futureNetVector[i].getPowNext(0,i,j) #what I think about next door fellow
						powerPrevBel[i*numberOfGenerators+j] = futureNetVector[i].getPowPrev(j) #what I think about previous interval
						powDiff[(2*i+1)*numberOfGenerators+j] = futureNetVector[i].getPowNext(0,i,j) - futureNetVector[i+1].getPowSelf(j) #what I think about next door fellow Vs. what next door fellow thinks about himself
				else:
					for j in range(numberOfGenerators):
						powerSelfGen[i*numberOfGenerators+j] = futureNetVector[i].getPowSelf(j) #what I think about myself
						if i == 1:
							for continCounter in range(numberOfCont+1):
								powerNextBel[(i+continCounter)*numberOfGenerators+j] = futureNetVector[i].getPowNext(continCounter, i, j) #what I think about next door fellow
								powDiff[2*(i+continCounter)*numberOfGenerators+j] = futureNetVector[i].getPowSelf(j) - futureNetVector[i+continCounter+1].getPowPrev(j) #what I think about myself Vs. what next door fellow thinks about me
								powDiff[(2*(i+continCounter)+1)*numberOfGenerators+j] = futureNetVector[i].getPowNext(continCounter, i, j) - futureNetVector[i+continCounter+1].getPowSelf(j) #what I think about next door fellow Vs. what next door fellow thinks about himself
						else:
							powerNextBel[(i+numberOfCont)*numberOfGenerators+j]= futureNetVector[i].getPowNext(0, i, j) #what I think about next door fellow
							for continCounter in range(numberOfCont+1): #Inefficient: Better, should run only for the particular value of continCounter for the particular i
								if i != (continCounter+1)*(RNDIntervals+RSDIntervals)+1: # Make sure the last supernetworks for any post-cont scenario are left out
									powDiff[2*(i+numberOfCont)*numberOfGenerators+j] = futureNetVector[i].getPowSelf(j) - futureNetVector[i+1].getPowPrev(j) #what I think about myself Vs. what next door fellow thinks about me
									powDiff[(2*(i+numberOfCont)+1)*numberOfGenerators+j] = futureNetVector[i].getPowNext(0, i, j) - futureNetVector[i+1].getPowSelf(j) #what I think about next door fellow Vs. what next door fellow thinks about himself
						powerPrevBel[i*numberOfGenerators+j] = futureNetVector[i].getPowPrev(j) #what I think about previous interval
					for j in range(numberOfLines):
						if i == 1:
							for continCounter in range(numberOfCont+1):
								for k in range(RNDIntervals-1):
									powerNextFlowBel[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i].getPowFlowNext(continCounter, i, k, j) #what I think about next door fellow
									powDiffLine[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i].getPowFlowNext(continCounter, i, k, j) - futureNetVector[2+continCounter*(RNDIntervals+RSDIntervals)+k].getPowFlowSelf(j)
						else:
							for continCounter in range(numberOfCont+1):
								for k in range(RNDIntervals-1):
									if i == 2+continCounter*(RNDIntervals+RSDIntervals)+k:u
										powerSelfFlowBel[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i].getPowFlowSelf(j)
			#Tuning the alphaAPP
			if ( iterCountAPP > 5 ) and ( iterCountAPP <= 10 ):
				alphaAPP = 75.0
			elif ( iterCountAPP > 10 ) and ( iterCountAPP <= 15 ):
				alphaAPP = 50.0
			elif ( iterCountAPP > 15 ) and ( iterCountAPP <= 20 ):
				alphaAPP = 25.0
			elif iterCountAPP > 20:
				alphaAPP = 10.0
			#Update power disagreement Lagrange Multipliers
			for i in range(consLagDim):
				lambdaAPP[i] += alphaAPP * (powDiff[i])
			for i in range(consLineLagDim):
				lambdaAPPLine[i] += alphaAPP * (powDiffLine[i])
			#iterCountAPP += 1 #increment the APP iteration counter
			tolAPP = 0.0
			tolAPPDelayed = 0.0 #APP tolerance, excluding the first (dummy) interval
			for i in range(consLagDim):
				tolAPP += powDiff[i] ** 2
				if i >= 2*numberOfGenerators:
					tolAPPDelayed += powDiff[i] ** 2
				matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+i+1] = {'Lack of consensus among power in {}-th interval'.format(i):powDiff[i]}
			for i in range(consLineLagDim):
				tolAPP += powDiffLine[i] ** 2
				tolAPPDelayed += powDiffLine[i] ** 2
				matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+i+1] = {'Lack of consensus among line-flows in {}-th interval'.format(i):powDiffLine[i]}
			finTol = math.sqrt(tolAPP)
			finTolDelayed = math.sqrt(tolAPPDelayed)
			matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+consLagDim+1] = {'APP Iteration Count':iterCountAPP,
																				'APP Tolerance':finTol,
																				'Delayed APP Tolerance':finTolDelayed}
			iterCountAPP += 1
			log.info("\nFinal Value of Outer APP Tolerance {} And Final Value of Outer APP Delayed Tolerance {}".format(finTol, finTolDelayed))
			finTol = finTolDelayed #Assign finTolDelayed to finTol in order for checking on the condition at the end of the loop
		else: #Outermost APP layer without a dummy zero interval at the beginning
			for netSimCount in range((numberOfCont+1)*(RNDIntervals+RSDIntervals)+1):
				if netSimCount == 0:
					log.info("\nStart of {} -th Outermost APP iteration for {} -th dispatch interval".format(iterCountAPP, netSimCount+1))
				else:
					log.info("\nStart of {} -th Outermost APP iteration for second dispatch interval for {} -th post-contingency scenario".format(iterCountAPP, netSimCount-1))
				futureNetVector[netSimCount+1].runSimulation(iterCountAPP, lambdaAPP, powDiff, powerSelfGen, powerNextBel, powerPrevBel, lambdaAPPLine, powDiffLine, powerSelfFlowBel, powerNextFlowBel)#, environmentGUROBI) #start simulation
				singleSuperNetTime = futureNetVector[netSimCount+1].getvirtualNetExecTime() #get the computational time for each supernetwork under the assumption of nested and complete parallelism of each generator optimization, within each coarse grain optimization in the supernetworks
				actualSuperNetTime += singleSuperNetTime #Actual time
				singleSuperNetTimeVec.append(singleSuperNetTime) #Vector of all independent supernet solve times
			largestSuperNetTime = max(singleSuperNetTimeVec) #get the laziest solve-time for this iteration
			largestSuperNetTimeVec.append(largestSuperNetTime) #vector of all te laziest supernet calculations over all iterations
			#Calculate the power generation opinions and disagreements between the different dispatch interval coarse grains
			for i in range((numberOfCont+1)*(RNDIntervals+RSDIntervals)+1):
				if i==0:
					for j in range(numberOfGenerators):
						powerSelfGen[i*numberOfGenerators+j] = futureNetVector[i+1].getPowSelf(j) #what I think about myself
						for continCounter in range(numberOfCont+1):
							powerNextBel[(i+continCounter)*numberOfGenerators+j] = futureNetVector[i+1].getPowNext(continCounter, (i+1), j) #what I think about next door fellow
							powDiff[2*(i+continCounter)*numberOfGenerators+j] = futureNetVector[i+1].getPowSelf(j) - futureNetVector[i+continCounter+2].getPowPrev(j) # what I think about myself Vs. what next door fellow thinks about me
							powDiff[(2*(i+continCounter)+1)*numberOfGenerators+j] = futureNetVector[i+1].getPowNext(continCounter, (i+1), j) - futureNetVector[i+continCounter+2].getPowSelf(j) #what I think about next door fellow Vs. what next door fellow thinks about himself
						powerPrevBel[i*numberOfGenerators+j] = futureNetVector[i+1].getPowPrev(j) #what I think about previous interval
				else:
					for j in range(numberOfGenerators):
						powerSelfGen[i*numberOfGenerators+j] = futureNetVector[i+1].getPowSelf(j) #what I think about myself
						powerNextBel[(i+numberOfCont)*numberOfGenerators+j] = futureNetVector[i+1].getPowNext(0, (i+1), j) #what I think about next door fellow
						powerPrevBel[i*numberOfGenerators+j] = futureNetVector[i+1].getPowPrev(j) #what I think about previous interval
						for continCounter in range(numberOfCont+1): #Inefficient: Better, should run only for the particular value of continCounter for the particular i
							if i != (continCounter+1)*(RNDIntervals+RSDIntervals): #Make sure the last supernetworks for any post-cont scenario are left out
								powDiff[2*(i+numberOfCont)*numberOfGenerators+j] = futureNetVector[i+1].getPowSelf(j) - futureNetVector[i+2].getPowPrev(j) #what I think about myself Vs. what next door fellow thinks about me
								powDiff[(2*(i+numberOfCont)+1)*numberOfGenerators+j] = futureNetVector[i+1].getPowNext(0, (i+1), j) - futureNetVector[i+2].getPowSelf(j) #what I think about next door fellow Vs. what next door fellow thinks about himself
				for j in range(numberOfLines):
					if i == 0:
						for continCounter in range(numberOfCont+1):
							for k in range(RNDIntervals - 1):
								powerNextFlowBel[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i+1].getPowFlowNext(continCounter, (i+1), k, j) #what I think about next door fellow
								powDiffLine[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i+1].getPowFlowNext(continCounter, (i+1), k, j) - futureNetVector[2+continCounter*(RNDIntervals+RSDIntervals)+k].getPowFlowSelf(j)
					else:
						for continCounter in range(numberOfCont+1):
							for k in range(RNDIntervals - 1):
								if i==1+continCounter*(RNDIntervals+RSDIntervals)+k:
									powerSelfFlowBel[continCounter*(RNDIntervals-1)*numberOfLines+k*numberOfLines+j] = futureNetVector[i+1].getPowFlowSelf(j)
			#Tuning the alphaAPP
			if ( iterCountAPP > 5 ) and ( iterCountAPP <= 10 ):
				alphaAPP = 75.0
			if ( iterCountAPP > 10 ) and ( iterCountAPP <= 15 ):
				alphaAPP = 50.0
			if ( iterCountAPP > 15 ) and ( iterCountAPP <= 20 ):
				alphaAPP = 25.0
			if iterCountAPP > 20:
				alphaAPP = 10.0
			#Update power disagreement Lagrange Multipliers
			for i in range(consLagDim):
				lambdaAPP[i] += alphaAPP * (powDiff[i])
			for i in range(consLineLagDim):
				lambdaAPPLine[i] += alphaAPP * (powDiffLine[i])
			#iterCountAPP += 1 #increment the APP iteration counter
			tolAPP = 0.0
			for i in range(consLagDim):
				tolAPP += powDiff[i] ** 2
				matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+i+1] = {'Lack of consensus among power in {}-th interval'.format(i):powDiff[i]}
			for i in range(consLineLagDim):
				tolAPP += powDiffLine[i] ** 2
				matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+i+1] = {'Lack of consensus among line-flows in {}-th interval'.format(i):powDiffLine[i]}
			finTol = math.sqrt(tolAPP)
			matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+consLagDim+1] = {'APP Iteration Count':iterCountAPP-1,
																				'APP Tolerance':finTol}
			iterCountAPP += 1
			log.info("\nFinal Value of Outer APP Tolerance {}".format(finTol)) #Check the termination criterion of the APP iterations
#***************************************END OF AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************//

	stop_s = profiler.get_interval()  #end
	log.info("\n*** LASCOPF FOR POST-CONTINGENCY RESTORATION CONTROLLING LINE TEMPERATURE SIMULATION SUPERNETWORK LAYER ENDS ***\n")
	log.info("\nExecution Outermost layer time (s): {:..2f} ".format(stop_s))
	log.info("\nVirtual Outermost layer Execution time (s): {:..2f} ".format(stop_s  - actualSuperNetTime + sum(largestSuperNetTimeVec)))
	matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+1] = {'Virtual Outermost layer Execution time (s)':stop_s - actualSuperNetTime + sum(largestSuperNetTimeVec),
						  									 'Execution Outermost layer time (s)': stop_s}
	#delete environmentGUROBI #Free the memory of the GUROBI environment object

	if solverChoice==1:
		outputAPPFileName = "ADMM_PMP_GUROBI"
	elif solverChoice==2:
		outputAPPFileName = "ADMM_PMP_CVXGEN"
	elif solverChoice==3:
		outputAPPFileName = "APP_Quasi_Decent_GUROBI"
	elif solverChoice==4:
		outputAPPFileName = "APP_GUROBI_Centralized_SCOPF"
	with open(os.path.join('results', '_{}_resultOuterAPP-SCOPF'.format(outputAPPFileName) + '.json'), 'w') as f:
                json.dump(matrixResultAPPOut, f, indent=4)	

end
print("\nThis is the simulation program for running LASCOPF problem for (N-1-1) post-contingency restoration in multiple dispatch intervals with explicit control of line-temperature rise in Python+Julia/JuMP\n")
end #end the module
