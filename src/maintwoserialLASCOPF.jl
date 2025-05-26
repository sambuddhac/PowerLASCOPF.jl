struct SuperNetwork 
    net_id::Int
    solver_choice::Int
    set_rho_tuning::Int
    last::Int
    next_choice::Int
    dummy_interval_choice::Int
    cont_solver_accuracy::Int
    future_net_vector::Vector{SuperNetwork}
end

function run_simulation_lascopf()
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***\n")
    
    futureNetVector = Vector{SuperNetwork}()
    
    supernet = SuperNetwork(netID, solverChoice, setRhoTuning, 0, 0, dummyIntervalChoice, contSolverAccuracy, [])
    push!(futureNetVector, supernet)
    
    supernet1 = SuperNetwork(netID, solverChoice, setRhoTuning, 0, 1, dummyIntervalChoice, contSolverAccuracy, [])
    push!(futureNetVector, supernet1)
    
function generate_supernetwork(numberOfCont::Int, RNDIntervals::Int, RSDIntervals::Int, futureNetVector::Vector{SuperNetwork}, netID::Int, solverChoice::Int, setRhoTuning::Int, dummyIntervalChoice::Int, contSolverAccuracy::Int, nextChoice::Int)

    	for i in 0:numberOfCont
		for j in 1:RNDIntervals
	    		lineOutaged = 0 # the serial number of transmission line outaged in any scenario: default value is zero
	    		if i > 0 # for the post-contingency scenarios
				lineOutaged = futureNetVector[1].indexOfLineOut(i) # gets the serial number of transmission line outaged in this scenario 
	    		end
	    		supernet = superNetwork(netID, solverChoice, setRhoTuning, i, j, 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals) # create the network instances for the future next-to-upcoming-dispatch intervals for pos-contingency cases
	    		push!(futureNetVector, supernet) # push to the vector of future network instances
		end
		for j in 0:RSDIntervals
	    		lineOutaged = 0 # the serial number of transmission line outaged in any scenario: default value is zero
	    		if i > 0 # for the post-contingency scenarios
				lineOutaged = futureNetVector[1].indexOfLineOut(i) # gets the serial number of transmission line outaged in this scenario 
	    		end
	    		if j == RSDIntervals # set the flag to 1 to indicate the last interval
				last = 1 # set the flag to 1 to indicate the last interval
	    		end
	    		supernet = superNetwork(netID, solverChoice, setRhoTuning, i, (j + RNDIntervals), 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals) # create the network instances for the future next-to-upcoming-dispatch intervals for pos-contingency cases
	    		push!(futureNetVector, supernet) # push to the vector of future network instances
		end
    	end
end
    
    println("\n*** SUPERNETWORK INITIALIZATION STAGE ENDS ***\n")

    numberOfGenerators = futureNetVector[1].getGenNumber()  # get the number of generators in the system
    numberOfLines = futureNetVector[1].getTransNumber()  # get the number of remaining transmission lines in the system
    iterCountAPP = 1  # Iteration counter for APP coarse grain decomposition algorithm
    alphaAPP = 100.0  # APP Parameter/Path-length
    consLagDim::Int  # Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
    consLineLagDim::Int  # Dimension of the vectors of APP Lagrange Multipliers and Line Flow consensus for (RND-1) intervals for temperature limiting

    if dummyIntervalChoice == 1
       consLagDim = 2 * ((numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1) * numberOfGenerators
    else
       consLagDim = 2 * ((numberOfCont + 1) * (RNDIntervals + RSDIntervals)) * numberOfGenerators
    end
    consLineLagDim = (RNDIntervals - 1) * numberOfLines * (numberOfCont + 1)

    lambdaAPP = fill(0.0, consLagDim)  # Array of APP Lagrange Multipliers for achieving consensus among the values of power generated, as guessed by different intervals
    powDiff = fill(0.0, consLagDim)  # Array of lack of consensus between generation values, as guessed by different intervals
    lambdaAPPLine = fill(0.0, consLineLagDim)  # Array of APP Lagrange Multipliers for achieving consensus among the values of line flows, as guessed by different intervals
    powDiffLine = fill(0.0, consLineLagDim)  # Array of lack of consensus between line flows, as guessed by different intervals

    supernetNum::Int
    supernetNumNext::Int
    supernetLineNumNext::Int

    if dummyIntervalChoice == 1
       supernetNum = (numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 2
       supernetNumNext = (numberOfCont + 1) * (RNDIntervals + RSDIntervals + 1) + 1
    else
       supernetNum = (numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1
       supernetNumNext = (numberOfCont + 1) * (RNDIntervals + RSDIntervals + 1)
    end
    supernetLineNumNext = (numberOfCont + 1) * numberOfLines * (RNDIntervals - 1)

    powerSelfGen = fill(0.0, supernetNum * numberOfGenerators)  # what I think about myself
    powerNextBel = fill(0.0, supernetNumNext * numberOfGenerators)  # what I think about next door fellow
    powerPrevBel = fill(0.0, supernetNum * numberOfGenerators)  # what I think about previous door fellow
    powerNextFlowBel = fill(0.0, supernetLineNumNext)  # what I think about flows for next door fellow
    powerSelfFlowBel = fill(0.0, supernetLineNumNext)  # what I think about flows for myself (only look-ahead intervals 1 to (RNDIntervals-1))

    for i in 1:consLagDim
       lambdaAPP[i] = 0.0  # Initialize lambdaAPP for the first iteration of APP and ADMM-PMP
       powDiff[i] = 0.0  # Initialize powDiff for the first iteration of APP and ADMM-PMP
    end

    for i in 1:consLineLagDim
       lambdaAPPLine[i] = 0.0  # Initialize lambdaAPPLine for the first iteration of APP and ADMM-PMP
       powDiffLine[i] = 0.0  # Initialize powDiffLine for the first iteration of APP and ADMM-PMP
    end

    # Initializing the self belief, next belief, and previous beliefs about MW generated by a warm start with the respective generation values of last realized dispatch
    for i in 1:supernetNum
       for j in 1:numberOfGenerators
        powerSelfGen[(i-1)*numberOfGenerators+j] = futureNetVector[1].getPowPrev()[j]  # Use 0.0 if warm start is not desired
        if i == 1
            powerPrevBel[(i-1)*numberOfGenerators+j] = futureNetVector[1].getPowPrev()[j]  # Actual value of previous interval dispatch for the first interval
        else
            power
	end
    end

    # Initialize variables
powerSelfGen = zeros(supernetNum * numberOfGenerators)
powerPrevBel = zeros(supernetNum * numberOfGenerators)
powerNextBel = zeros(supernetNumNext * numberOfGenerators)
powerNextFlowBel = zeros((numberOfCont + 1) * (RNDIntervals - 1) * numberOfLines)
powerSelfFlowBel = zeros((numberOfCont + 1) * (RNDIntervals - 1) * numberOfLines)
finTol = 1000.0
finTolDelayed = 1000.0

outputAPPFileName = ""
if solverChoice == 1
    outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration_Temperature/output/ADMM_PMP_GUROBI/resultOuterAPP-SCOPF.txt"
elseif solverChoice == 2
    outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration_Temperature/output/ADMM_PMP_CVXGEN/resultOuterAPP-SCOPF.txt"
elseif solverChoice == 3
    outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration_Temperature/output/APP_Quasi_Decent_GUROBI/resultOuterAPP-SCOPF.txt"
elseif solverChoice == 4
    outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration_Temperature/output/APP_GUROBI_Centralized_SCOPF/resultOuterAPP-SCOPF.txt"
end

open(outputAPPFileName, "w") do matrixResultAPPOut
    # exit program if unable to create file
    if !isopen(matrixResultAPPOut)
        println("File could not be opened")
        exit(1)
    end
end

using Statistics

largestSuperNetTimeVec = Float64[]
singleSuperNetTimeVec = Float64[]

actualSuperNetTime = 0
start_s = time()

while true
    singleSuperNetTimeVec = Float64[]

    if dummyIntervalChoice == 1
        for netSimCount in 0:(numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1
            if netSimCount == 0
                println("\nStart of $iterCountAPP -th Outermost APP iteration for dummy zero dispatch interval")
            elseif netSimCount == 1
                println("\nStart of $iterCountAPP -th Outermost APP iteration for $netSimCount -th dispatch interval")
            else
                println("\nStart of $iterCountAPP -th Outermost APP iteration for second dispatch interval for $(netSimCount - 2) -th post-contingency scenario")
            end

            futureNetVector[netSimCount].runSimulation(iterCountAPP, lambdaAPP, powDiff, powerSelfGen, powerNextBel, powerPrevBel, lambdaAPPLine, powDiffLine, powerSelfFlowBel, powerNextFlowBel, environmentGUROBI)

            singleSuperNetTime = futureNetVector[netSimCount].getvirtualNetExecTime()
            actualSuperNetTime += singleSuperNetTime
            push!(singleSuperNetTimeVec, singleSuperNetTime)
        end

        largestSuperNetTime = maximum(singleSuperNetTimeVec)
        push!(largestSuperNetTimeVec, largestSuperNetTime)

        # Calculate power generation opinions and disagreements between different dispatch interval coarse grains
        for i in 0:((numberOfCont + 1) * (RNDIntervals + RSDIntervals) + 1)
            if i == 0
                for j in 0:numberOfGenerators-1
                    powDiff[2*i*numberOfGenerators+j] = futureNetVector[i].getPowSelf()[j] - futureNetVector[i+1].getPowPrev()[j]
                    powerSelfGen[i*numberOfGenerators+j] = futureNetVector[i].getPowSelf()[j]
                    powerNextBel[i*numberOfGenerators+j] = futureNetVector[i].getPowNext(0, i)[j]
                    powerPrevBel[i*numberOfGenerators+j] = futureNetVector[i].getPowPrev()[j]
                    powDiff[(2*i+1)*numberOfGenerators+j] = futureNetVector[i].getPowNext(0, i)[j] - futureNetVector[i+1].getPowSelf()[j]
                end
            else
                # Continue the translation for this section
                # You can continue the translation in a similar manner for the remaining C++ code
            end
        end

        # Tuning the alphaAPP
        if iterCountAPP > 5 && iterCountAPP <= 10
            alphaAPP = 75.0
        elseif iterCountAPP > 10 && iterCountAPP <= 15
            alphaAPP = 50.0
        elseif iterCountAPP > 15 && iterCountAPP <= 20
            alphaAPP = 25.0
        elseif iterCountAPP > 20
            alphaAPP = 10.0
        end

        # Update power disagreement Lagrange Multipliers
        for i in 1:consLagDim
            lambdaAPP[i] += alphaAPP * powDiff[i]
        end

        for i in 1:consLineLagDim
            lambdaAPPLine[i] += alphaAPP * powDiffLine[i]
        end

        tolAPP = 0.0
        tolAPPDelayed = 0.0
        # Continue the translation for this section
    else
        # Continue the translation for this section
    end
end

end
### ChatGPT 4.0 Generated code translation from C++ to Julia















function runSimLASCOPFTemp() #function runSimLASCOPFTemp begins program execution
	last = 0 #flag to indicate the last interval; last = 0, for dispatch interval that is not the last one; last = 1, for the last interval
	futureNetVector = [] #Vector of future look-ahead dispatch interval supernetwork objects
	netID = int(input("\nEnter the number of nodes to initialize the network. (Allowed choices are 2, 3, 5, 14, 30, 48, 57, 118, and 300 Bus IEEE Test Bus Systems as of now. So, please restrict yourself to one of these)"))
	contSolverAccuracy = int(input("\nEnter the switch value to select between whether an extensive/exhaustive (and presumably more accurate) solver for contingency scenarios is desired, or just a simpler one is desired; 1 for former, 0 for latter"))
	solverChoice =  int(input("\nEnter the choice of the solver for SCOPF of each dispatch interval, 1 for GUROBI-APMP(ADMM/PMP+APP), 2 for CVXGEN-APMP(ADMM/PMP+APP), 3 for GUROBI APP Coarse Grained, 4 for centralized GUROBI SCOPF"))
	nextChoice = int(input("\nEnter the choice pertaining to whether you want to consider the ramping constraint to the next interval, for the last interval: 0 for not considering and 1 for considering"))
	if (solverChoice==1) || (solverChoice==2) #APMP Fully distributed, Bi-layer (N-1) SCOPF Simulation 
		setRhoTuning = int(input("\nEnter the tuning mode; Enter 1 for maintaining Rho * primTol = dualTol; 2 for primTol = dualTol; anything else for Adaptive Rho (with mode-1 being implemented for the first 3000 iterations and then Rho is held constant)."))
	else
		setRhoTuning = 0 #Otherwise, if we aren't using ADMM-PMP, Rho tuning is unnecessary, 0 is a dummy value
	end
	dummyIntervalChoice =  int(input("Enter the choice pertaining to whether to include a dummy interval at the start or not (Inclusion of a dummy interval may speed up convergence and/or improve accuracy of solution). Enter 1 to include and 0 to not include"))

	RNDIntervals = int(input("\nEnter the number of look-ahead dispatch intervals for restoring line flows to within normal long-term ratings.\n"))
	RSDIntervals = int(input("\nEnter the number of furthermore look-ahead dispatch intervals for making the system secure w.r.t. next set of contingencies.\n"))

	log.info("\n*** SUPERNETWORK INITIALIZATION STAGE BEGINS ***")
	#GRBEnv* environmentGUROBI = new GRBEnv("GUROBILogFile.log"); // GUROBI Environment object for storing the different optimization models
	supernet = superNetwork(netID, solverChoice, setRhoTuning, 0, 0, 0, 0, nextChoice, dummyIntervalChoice, contSolverAccuracy, 0, RNDIntervals, RSDIntervals) #create the network instances for the future dummy zero dispatch intervals
	numberOfCont = supernet.retContCount() #gets the number of contingency scenarios in the variable numberOfCont
	futureNetVector.append(supernet) #push to the vector of future network instances 
	supernet1 = superNetwork(netID, solverChoice, setRhoTuning, 0, 0, 1, 0, nextChoice, dummyIntervalChoice, contSolverAccuracy, 0, RNDIntervals, RSDIntervals) #create the network instances for the future upcoming dispatch intervals
	futureNetVector.append(supernet1) #push to the vector of future network instances 
	for i in 1:numberOfCont
		for j in 1:(RNDIntervals - 2)
			lineOutaged = 0 #the serial number of transmission line outaged in any scenario: default value is zero
			if i > 0 #for the post-contingency scenarios
				lineOutaged = futureNetVector[0].indexOfLineOut(i) #gets the serial number of transmission line outaged in this scenario 
			#create the network instances for the future next-to-upcoming-dispatch intervals for pos-contingency cases
			futureNetVector.append(superNetwork(netID, solverChoice, setRhoTuning, i, j+1, 2, last, nextChoice, dummyIntervalChoice, contSolverAccuracy, lineOutaged, RNDIntervals, RSDIntervals)) #push to the vector of future network instances
			end
		end
		for j in 1:RSDIntervals
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

	numberOfGenerators = futureNetVector[0].getGenNumber() #get the number of generators in the system
	numberOfLines = futureNetVector[0].getTransNumber() #get the number of remaining transmission lines in the system
	iterCountAPP = 1 #Iteration counter for APP coarse grain decomposition algorithm
	alphaAPP = 100.0 #APP Parameter/Path-length
	#Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	if dummyIntervalChoice==1
		consLagDim = 2*((numberOfCont+1)*(RNDIntervals+RSDIntervals)+1)*numberOfGenerators #Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	else
		consLagDim = 2*((numberOfCont+1)*(RNDIntervals+RSDIntervals))*numberOfGenerators #Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus
	end
	#Dimension of the vectors of APP Lagrange Multipliers and Line Flow consensus for (RND-1) intervals for temperature limiting	
	consLineLagDim = (RNDIntervals-1)*numberOfLines*(numberOfCont+1) #Dimension of the vectors of APP Lagrange Multipliers and remaining transmission lines in the system-flow Consensus
	lambdaAPP = np.zeros(consLagDim, float) #Array of APP Lagrange Multipliers for achieving consensus among the values of power generated, as guessed by different intervals
	powDiff = np.zeros(consLagDim, float) #Array of lack of consensus between generation values, as guessed by different intervals
	lambdaAPPLine = np.zeros(consLineLagDim, float) #Array of APP Lagrange Multipliers for achieving consensus among the values of line flows, as guessed by different intervals
	powDiffLine = np.zeros(consLineLagDim, float) #Array of lack of consensus between line flows, as guessed by different intervals
	if dummyIntervalChoice==1
		supernetNum=(numberOfCont+1)*(RNDIntervals+RSDIntervals)+2 #Number of supernetworks considered for computation (whether dummy interval is included or not)
		supernetNumNext=(numberOfCont+1)*(RNDIntervals+RSDIntervals+1)+1 #Number of future supernetworks about which generation belief are held by the existing supernetworks
	else
		supernetNum=(numberOfCont+1)*(RNDIntervals+RSDIntervals)+1 #Number of supernetworks considered for computation (whether dummy interval is included or not)
		supernetNumNext=(numberOfCont+1)*(RNDIntervals+RSDIntervals+1) #Number of future supernetworks about which generation belief are held by the existing supernetworks
	end
	supernetLineNumNext=(numberOfCont+1)*numberOfLines*(RNDIntervals-1) #Number of future supernetworks about which line flow beliefs are held by the existing supernetworks
	powerSelfGen = np.zeros(supernetNum*numberOfGenerators, float) #what I think about myself
	powerNextBel = np.zeros(supernetNumNext*numberOfGenerators, float) #what I think about next door fellow
	powerPrevBel = np.zeros(supernetNum*numberOfGenerators, float) #what I think about previous door fellow
	powerNextFlowBel = np.zeros(supernetLineNumNext, float) #what I think about flows for next door fellow
	powerSelfFlowBel = np.zeros(supernetLineNumNext, float) #what I think about flows for myself (only look-ahead intervals 1 to (RNDIntervals-1))

	#Initializing the self belief, next belief, and previous beliefs about MW generated by a warm start with the respective generation values of last realized dispatch
	for i in 1:supernetNum-1
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
									if i == 2+continCounter*(RNDIntervals+RSDIntervals)+k:
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
end
print("\nThis is the simulation program for running LASCOPF problem for (N-1-1) post-contingency restoration in multiple dispatch intervals with explicit control of line-temperature rise in Python+Julia/JuMP\n")

try:
    if __name__ == '__main__': runSimLASCOPFTemp()
except:
    log.warning("Simulation FAILED !!!!")
