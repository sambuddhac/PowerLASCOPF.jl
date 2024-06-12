module Network

#Member functions for class Network
using JSON
# include definitions for classes generator, load, transmission line, network and node
using Generator
using transmissionLine
using Load
using Node

mutable struct Network
	networkID::Int
	scenarioIndex::Int
	postContScenario::Int
	prePostContScen::Int
	genNumber::Int
	genFields::Int
	loadNumber::Int
	loadFields::Int
	translNumber::Int
	translFields::Int
	deviceTermCount::Int
	dummyZ::Int
	Accuracy::Int
	nodeNumber::Int
	Rho::Float64
	intervalID::Int
	lastFlag::Int
	outagedLine::Vector{Int}
	OutagedLine::Int
	baseOutagedLine::Int
	contingencyCount::Int
	solverChoice::Int
	Verbose::Bool
	pSelfBeleif::Vector{Float64}
	pSelfBeleifInner::Vector{Float64}
	pPrevBeleif::Vector{Float64}
	pNextBeleif::Vector{Float64}
	connNodeNumList::Vector{Int}
	nodeValList::Vector{Int}
	assignedNodeSer::Int
	pSelfBuffer::Vector{Float64}
	pPrevBuffer::Vector{Float64}
	pNextBuffer::Vector{Float64}
	pSelfBufferGUROBI::Vector{Float64}
	pNextBufferGUROBI::Vector{Float64}
	pPrevBufferGUROBI::Vector{Float64}
	matrixResultString::String
	devProdString::String
	iterationResultString::String
	lmpResultString::String
	objectiveResultString::String
	primalResultString::String
	dualResultString::String
	genSingleTimeVec::Vector{Float64}
	genADMMMaxTimeVec::Vector{Float64}
	virtualExecTime::Float64
	divConvMWPU::Float64
	genObject::Vector{Generator}
	loadObject::Vector{Load}
	translObject::Vector{TransmissionLine}
	nodeObject::Vector{Node}
    end
    

function network_init_var(val, postContScen, scenarioContingency, lineOutaged, prePostScenario, solverChoice, dummy, accuracy, intervalNum, lasIntFlag, nextChoice, outagedLine)
	networkVar = Dict()
	networkVar["MAX_ITER"] = 80002
	#networkVar["LINE_CAP"] = 100.00
	networkVar["networkID"] = val #constructor begins; initialize networkID  and Rho through constructor initializer list
	networkVar["Rho"] = 1.0
	networkVar["scenarioIndex"] = scenarioContingency #this is always zero for a base-case network instance, even if that corresponds to an outaged base case, or in other words, if postContScen is not zero
	networkVar["postContScenario"] = postContScen
	networkVar["prePostContScen"] = prePostScenario
	networkVar["dummyZ"] = dummy
	networkVar["Accuracy"] = accuracy
	networkVar["OutagedLine"] = lineOutaged
	networkVar["contingencyCount"] = 0
	networkVar["intervalID"] = intervalNum
	networkVar["lastFlag"] = lasIntFlag
	networkVar["baseOutagedLine"] = outagedLine
	networkVar["solverChoice"] = solverChoice
	#Initializes the number and fields of Transmission lines, Generators, Loads, Nodes, and Device Terminals.
	networkVar["translNumber"] = 0
	networkVar["translFields"] = 0
	networkVar["genNumber"] = 0
	networkVar["genFields"] = 0
	networkVar["loadNumber"] = 0
	networkVar["loadFields"] = 0
	networkVar["deviceTermCount"] = 0
	networkVar["nodeNumber"] = 0
	networkVar["assignedNodeSer"] = 0
	networkVar["divConvMWPU"] = 100.0 # Divisor, which is set to 100 for all other systems, except two bus system, for which it is set to 1
	networkVar["outagedLine"] = Int[]
	networkVar["connNodeNumList"] = []
	networkVar["nodeValList"] = []
	set_network_variables(networkVar, nextChoice) #sets the variables of the networkID
end # end constructor

function getGenNumber(networkVar::Dict)
	return networkVar["genNumber"] #returns the number of Generators in the network
end

function retContCount(networkVar::Dict)
	return networkVar["contingencyCount"] #returns the number of contingency scenarios
end

function indexOfLineOut(contScen::Int64)
	return outagedLine[contScen-1] #returns the serial number of the outaged line
end

function set_network_variables(netVar::Dict, nextChoice::Int64) #Function setNetworkVariables starts to initialize the parameters and variables
	Verbose = False #disable intermediate result display. If you want, make it "true"

	nodeNumber = netVar["networkID"] #set the number of nodes of the network

	if  nodeNumber == 14 # 14 Bus case	
		genFile = DataFrame(CSV.File(string(path,sep,"Gen14.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran14.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load14.csv"), header=true), copycols=true)
	elseif  nodeNumber == 30 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen30.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran30.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load30.csv"), header=true), copycols=true)
	elseif  nodeNumber == 57 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen57.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran57.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load57.csv"), header=true), copycols=true)
	elseif  nodeNumber == 118 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen118.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran118.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load118.csv"), header=true), copycols=true)
	elseif  nodeNumber == 300 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen300.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran300.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load300.csv"), header=true), copycols=true)
	elseif  nodeNumber == 3 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen3A.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran3A.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load3A.csv"), header=true), copycols=true)
	elseif  nodeNumber == 5 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen5.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran5.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load5.csv"), header=true), copycols=true)
	elseif  nodeNumber == 2 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen2.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran2.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load2.csv"), header=true), copycols=true)
	elseif  nodeNumber == 48 # 30 Bus case
		genFile = DataFrame(CSV.File(string(path,sep,"Gen48.csv"), header=true), copycols=true)
		tranFile = DataFrame(CSV.File(string(path,sep,"Tran48.csv"), header=true), copycols=true)
		loadFile = DataFrame(CSV.File(string(path,sep,"Load48.csv"), header=true), copycols=true)
			
	else # catch all other entries
		println("Sorry, invalid case. Can't do simulation at this moment.")
			
	end #exit switch
	if nodeNumber == 2
		netVar["divConvMWPU"] = 1.0
	end
	# Transmission lines
	matrixFirstFile = size(collect(skipmissing(tranFile[!,:Capacity])),1)
	netVar["transmission"] = tranFile
	#Count the total number of contingency scenarios
	for item in 1:matrixFirstFile
		netVar["contingencyCount"] += tranFile[!,:ContingencyMarked][item] #count the number of contingency scenarios
	end
	if netVar["prePostContScen"] == 0
		for index in 1:matrixFirstFile
			if netVar["transmission"][!,:ContingencyMarked][index] == 1
				push!(netVar["outagedLine"], index)
			end
		end
	end

	#print("\nThe total number of contingency scenarios considerred is : {}".format(contingencyCount))
	#self.contingencyCount = 0 #Uncomment this statement for purposes of Base-Case/OPF Simulation (Comment out for SCOPF Simulation)
	#Nodes
	for l in range(self.nodeNumber):
		#print("\nCreating the {} -th Node:\n".format(l+1))
		if self.postContScenario == 0: #for no outage case
			modifiedContCount = self.contingencyCount #modified contingency count, to account for the change in contingency scenarios in different post-cont scenarios
		else: #for the outaged cases
			modifiedContCount = self.contingencyCount - 1
		
		nodeInstance = Node(l + 1, modifiedContCount) #creates nodeInstance object with ID l + 1
		self.nodeObject.append(nodeInstance) #pushes the nodeInstance object into the vector
		#end initialization for Nodes

	contingencyTracker = 0 #contingency tracker for centralized GUROBI solver
	#Resume Creation of Transmission Lines
	for item in range(len(matrixTranList)):
		if self.nodeNumber == 300: #Since for IEEE 300 bus system, the nodes are not serialy numbered, but name-numbered instead, below is conversion code
			tNodeID1300 = matrixTranList[item]['fromNode'] #From end node identifier
			tNodeID2300 = matrixTranList[item]['toNode'] #To end node identifier
			if tNodeID1300 in self.connNodeNumList: #If node identifier value for this particular node is present in the list
				pos = self.connNodeNumList.index(tNodeID1300) # find the position of the node identifier in the chart of node identifiers
				tNodeID1 = self.nodeValList[pos] # Get the serial number of the node from the nodeValList
				#print("For line {} Identifier of the From Node: {} From Node assigned Serial: {} FRESH".format(index + 1 , tNodeID1300, tNodeID1))
			else:
				self.connNodeNumList.append(tNodeID1300) #For a new node identifier
				assignedNodeSer += 1
				self.nodeValList.append(assignedNodeSer) #Assign the node serial
				tNodeID1 = assignedNodeSer #Get the serial number of the node from the nodeValList
				#print("For line {} Identifier of the From Node: {} From Node assigned Serial: {} FRESH".format(index + 1 , tNodeID1300, tNodeID1))
			if tNodeID2300 in self.connNodeNumList: #If node identifier value for this particular node is present in the list
				pos = self.connNodeNumList.index(tNodeID2300) # find the position of the node identifier in the chart of node identifiers
				tNodeID2 = self.nodeValList[pos] # Get the serial number of the node from the nodeValList
				#print("For line {} Identifier of the From Node: {} From Node assigned Serial: {} FRESH".format(index + 1 , tNodeID2300, tNodeID2))
			else:
				self.connNodeNumList.append(tNodeID2300) #For a new node identifier
				assignedNodeSer += 1
				self.nodeValList.append(assignedNodeSer) #Assign the node serial
				tNodeID2 = assignedNodeSer #Get the serial number of the node from the nodeValList
				#print("For line {} Identifier of the From Node: {} From Node assigned Serial: {} FRESH".format(index + 1 , tNodeID2300, tNodeID2))
			#print("\nStuck while creating nodes of transmission line: {}".format(index + 1))
			#node IDs of the node objects to which this transmission line is connected.
		else:
			tNodeID1 = matrixTranList[item]['fromNode'] #From end
			tNodeID2 = matrixTranList[item]['toNode'] #To end
		if (self.OutagedLine != (item + 1)) and (self.baseOutagedLine != (item + 1)):
			#Parameters for Transmission Line
			#print("Stuck while creating transmission line: {}".format( index + 1 ))
			#Resistance:
			resT = matrixTranList[item]['Resistance']
			#Reactance:
			reacT = matrixTranList[item]['Reactance']
			#values of maximum allowable power flow on line in the forward and reverse direction:
			#Forward direction:
			ptMax = matrixTranList[item]['Capacity'] / self.divConvMWPU #LINE_CAP
			ptMin = -ptMax #Reverse direction
			if matrixTranList[item]['ContingencyMarked'] == 1:
				contingencyTracker += matrixTran[item]['ContingencyMarked'] #Get the serial number of the contingency scenario when this line is outaged, if it's marked for contingency analysis
			#creates transLineInstance object with ID item + 1
			if (matrixTranList[item]['ContingencyMarked'] == 1) and (self.prePostContScen == 0):
				tempTracker = contingencyTracker
			else:
				tempTracker = 0
			transLineInstance = transmissionLine(item + 1, nodeObject[tNodeID1 - 1], nodeObject[tNodeID2 - 1], ptMax, reacT, resT, tempTracker)
			self.translObject.append( transLineInstance ) #pushes the transLineInstance object into the vector
		else:
			if matrixTranList[index]['ContingencyMarked'] == 1:
				contingencyTracker += matrixTranList[index]['ContingencyMarked'] #Get the serial number of the contingency scenario when this line is outaged, if it's marked for contingency analysis
	#end initialization for Transmission Lines

		#Generators
		matrixSecondFile = json.load(genFile) #opens the file of Generators
		matrixGenList = []
		#Generator matrix
		for item in matrixSecondFile:
			matrixGen = {"connNode": None, "c2": None, "c1": None, "c0": None, "PgMax": None, "PgMin": None, "RgMax": None, "RgMin": None, "PgPrev": None}
			matrixGen['connNode'] = item['connNode']
			matrixGen['c2'] = item['c2']
			matrixGen['c1'] = item['c1']
			matrixGen['c0'] = item['c0']
			matrixGen['PgMax'] = item['PgMax']
			matrixGen['PgMin'] = item['PgMin']
			matrixGen['RgMax'] = item['RgMax']
			matrixGen['RgMin'] = item['RgMin']
			matrixGen['PgPrev'] = item['PgPrev']
			matrixGenList.append(matrixGen)
		
		#Create Generators
		for item in matrixGenList:
			if self.nodeNumber == 300:#Since for IEEE 300 bus system, the nodes are not serialy numbered, but name-numbered instead, below is conversion code
				gNodeID300 = matrixGenList[item]['connNode'] #Generator node identifier
				if gNodeID300 in self.connNodeNumList: #If node identifier value for this particular node is present in the list
					pos = self.connNodeNumList.index(gNodeID300) #find the position of the node identifier in the chart of node identifiers
					gNodeID = self.nodeValList[pos] #Get the serial number of the node from the nodeValList
					#print("For Generator {} Identifier of the Conn Node: {} Conn Node assigned Serial: {} REPEATED".format(index + 1, gNodeID300, gNodeID))
				else:
					self.connNodeNumList.append(gNodeID300) # For a new node identifier
					assignedNodeSer += 1
					self.nodeValList.append(assignedNodeSer) #Assign the node serial
					gNodeID = assignedNodeSer #Get the serial number of the node from the nodeValList
					#print("For Generator {} Identifier of the Conn Node: {} Conn Node assigned Serial: {} FRESH".format(index + 1, gNodeID300, gNodeID))
			else:
				gNodeID = matrixGenList[item]['connNode']
			#Parameters for Generator
			Beta = 200.0
			innerBeta = 200.0
			Gamma = 100.0
			externalGamma = 100.0
			#Quadratic Coefficient: 
			c2 = matrixGenList[item]['c2'] * (self.divConvMWPU ** 2)
			#Linear coefficient: 
			c1 = matrixGenList[item]['c1'] * self.divConvMWPU
			#Constant term: 
			c0 = matrixGenList[item]['c0']
			#Maximum Limit:
			PgMax = matrixGenList[item]['PgMax'] / self.divConvMWPU
			#Minimum Limit:
			PgMin = matrixGenList[item]['PgMin'] / self.divConvMWPU
			#Maximum Ramping Limit:
			RgMax = matrixGenList[item]['RgMax'] / self.divConvMWPU
			#Minimum Ramping Limit:
			RgMin = matrixGenList[item]['RgMin'] / self.divConvMWPU
			#Present Output
			PgPrevious = matrixGenList[item]['PgPrev'] / self.divConvMWPU

			generatorInstance = Generator(item + 1, c2, c1, c0, PgMax, PgMin, RgMax, RgMin, Beta, innerBeta, externalGamma, Gamma, PgPrevious, intervalID, lastFlag, scenarioIndex, postContScenario, prePostContScen, dummyZ, Accuracy, nodeObject[ gNodeID - 1 ], contingencyCount, genNumber ) #creates generatorInstance object with ID number index + 1
			
		#end initialization for Generators

		# Loads
		matrixThirdFile = json.load(loadFile) #opens the file of Generators
		matrixLoadList = []
		#Load matrix
		for item in matrixThirdFile:
			matrixLoad = {"ConnNode": None, "Interval-1_Load": None, "Interval-2_Load": None}
			matrixLoad['ConnNode'] = item['ConnNode']
			matrixLoad['Interval-1_Load'] = item['Interval-1_Load']
			matrixLoad['Interval-2_Load'] = item['Interval-2_Load']
			matrixLoadList.append(matrixLoad)

		#Create Loads
		for item in matrixLoadList:
			#print("\nEnter the parameters of the {} -th Load:\n".format(index + 1))
			if self.nodeNumber==300: #Since for IEEE 300 bus system, the nodes are not serialy numbered, but name-numbered instead, below is conversion code
				lNodeID300 = matrixLoadList[item]['ConnNode'] #Load node identifier
				if lNodeID300 in self.connNodeNumList: #If node identifier value for this particular node is present in the list
					pos = self.connNodeNumList.index(lNodeID300) #find the position of the node identifier in the chart of node identifiers
					lNodeID = nodeValList[pos] #Get the serial number of the node from the nodeValList
					#print("For Load {} Identifier of the Conn Node: {} Conn Node assigned Serial: {} REPEATED".format(index + 1, lNodeID300 , lNodeID))
				else:
					self.connNodeNumList.append(lNodeID300) #For a new node identifier
					assignedNodeSer += 1
					self.nodeValList.append(assignedNodeSer) #Assign the node serial
					lNodeID = assignedNodeSer #Get the serial number of the node from the nodeValList
					#print("For Load {} Identifier of the Conn Node: {} Conn Node assigned Serial: {} FRESH" .format(index + 1, lNodeID300, lNodeID))
			else:
				#node ID of the node object to which this load object is connected.
				lNodeID = matrixLoadList[item]['ConnNode']
			#value of allowable power consumption capability of load with a negative sign to indicate consumption:
			#Power Consumption:
			if (self.intervalID == 0) or (self.intervalID == 1):
				P_Load = matrixLoadList[item]['Interval-1_Load'] / self.divConvMWPU
			else:
				P_Load = matrixLoadList[item]['Interval-2_Load'] / self.divConvMWPU
			loadInstance = Load(item + 1, nodeObject[ lNodeID - 1 ], P_Load ) #creates loadInstance object object with ID number index + 1
			self.loadObject.append(loadInstance) #pushes the loadInstance object into the vector
		# end initialization for Loads
	
		if (self.prePostContScen == 0) and (self.postContScenario == 0):
			self.deviceTermCount = self.genNumber + self.loadNumber + 2 * self.translNumber #total number of device-terminals
		elif (self.prePostContScen == 0) and (self.postContScenario != 0):
			self.deviceTermCount = self.genNumber + self.loadNumber + 2 * (self.translNumber - 1) #total number of device-terminals
		elif (self.prePostContScen != 0) and (self.postContScenario == 0):
			self.deviceTermCount = self.genNumber + self.loadNumber + 2 * (self.translNumber - 1) #total number of device-terminals
		elif (self.prePostContScen != 0) and (self.postContScenario != 0):
			self.deviceTermCount = self.genNumber + self.loadNumber + 2 * (self.translNumber - 2) #total number of device-terminals
		#Initializing the Generation beleifs about previous interval, present interval, and next interval outputs
		if self.intervalID == 0:
			for i in range(genNumber):
				self.pSelfBeleifInner.append(0.0) #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
				self.pSelfBeleif.append(0.0) #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
				self.pPrevBeleif.append(genObject[i].genPowerPrev()) #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
				self.pNextBeleif.append(0.0) #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
		else:
			for i in range(genNumber):
				self.pSelfBeleifInner.append(0.0) #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
				self.pSelfBeleif.append(0.0) #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
				self.pPrevBeleif.append(0.0) #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
				self.pNextBeleif.append(0.0) #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
		return
	# end setNetworkVariables function

	#runSimulation function definition
	function run_simulation(network_instance::Network, outerIter, LambdaOuter, powDiffOuter, setRhoTuning, countOfAPPIter, appLambda, diffOfPow, powSelfBel, powNextBel, powPrevBel, lambdaLine, powerDiffLine, powSelfFlowBel, powNextFlowBel): #Function runSimulation begins
		#Declaration of intermerdiate variables and parameters for running the simulation
		iteration_count = 1 #iteration counter
		dualTol = 1.0 #initialize the dual tolerance
		ptolsq = 0.0 #initialize the primal tolerance square
		iterationGraph = [] #vector of iteration counts
		primTolGraph = [] #vector of primal tolerance
		PrimTolGraph = []
		dualTolGraph = [] #vector of dual tolerance
		objectiveValue = [] #vector of objective function values
		V_avg = np.zeros(self.nodeNumber, float) #array of average node angle imbalance price from last to last iterate
		vBuffer1 = np.zeros(self.nodeNumber, float) #intermediate buffer for average node angle price from last to last iterate
		vBuffer2 = np.zeros(self.nodeNumber, float) #intermediate buffer for average node angle price from last iterate
		angleBuffer = np.zeros(self.nodeNumber, float) #buffer for average node voltage angles from present iterate
		angleBuffer1 = np.zeros(self.nodeNumber, float) #buffer for average node voltage angles from last iterate
		angtildeBuffer = np.zeros(self.deviceTermCount, float) #Thetatilde from present iterate
		powerBuffer = np.zeros(self.deviceTermCount, float) #Ptilde from present iterate
		powerBuffer1 = np.zeros(self.deviceTermCount, float) #Ptilde from last iterate
		pavBuffer = np.zeros(self.nodeNumber, float) #Pav from present iterate
		ptildeinitBuffer = np.zeros(self.deviceTermCount, float) #Ptilde before iterations begin
		firstIndex = ( MAX_ITER / 100 ) + 1
		uPrice = np.zeros(self.deviceTermCount, float) #u parameter from previous iteration
		vPrice = np.zeros(self.deviceTermCount, float) #v parameter from previous iteration
		LMP = np.zeros(self.nodeNumber, float) #vector of LMPs
		Rho1 = 1.0 #Previous value of Rho from previous iteration
		double W, Wprev; #Present and previous values of W for the PID controller for modifying Rho
		lambdaAdap = 0.0001 #Parameter of the Proportional (P) controller for adjusting the ADMM tuning parameter
		muAdap = 0.0005 #Parameter of the Derivative (D) controller for adjusting the ADMM tuning parameter
		xiAdap = 0.0000 #Parameter of the Integral (I) controller for adjusting the ADMM tuning parameter
		controllerSum = 0.0 #Integral term of the PID controller

		#Set the type of tuning #parameter to select adaptive rho, fixed rho, and type of adaptive rho
		setTuning = setRhoTuning

		# Calculation of initial value of Primal Tolerance before the start of the iterations	
		for loadIterator in self.loadObject:
			ptolsq += ptolsq + loadIterator.pinitMessage() ** 2 #calls the node to divide by the number of devices connected
		primalTol = math.sqrt(ptolsq) #initial value of primal tolerance to kick-start the iterations
		PrimalTol = primalTol
		#Calculation of initial value of Ptilde before the iterations start
		for generatorIterator in self.genObject:
			bufferIndex = generatorIterator.getGenID() - 1
			ptildeinitBuffer[bufferIndex] = -(generatorIterator.calcPavInit())

		for loadIterator in self.loadObject:
			bufferIndex = self.genNumber + loadIterator.getLoadID() - 1
			ptildeinitBuffer[bufferIndex] = loadIterator.calcPavInit()

		temptrans1 = 0 #counter to make sure that two values of Ptilde are accounted for each line
		for translIterator in self.translObject.end():
			bufferIndex = self.genNumber + self.loadNumber + (translIterator.getTranslID() - 1) + temptrans1
			ptildeinitBuffer[bufferIndex] = -(translIterator.calcPavInit1()) #Ptilde corresponding to 'from' end
			ptildeinitBuffer[bufferIndex + 1] = -(translIterator.calcPavInit2()) #Ptilde corresponding to 'to' end
			temptrans1 += 1

		if countOfAPPIter != 1:
			for i in range(self.genNumber):
				pSelfBeleifInner[i] = *(getPowSelf()+i); // Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration powSelfBel[intervalID*genNumber+i]
		elif countOfAPPIter == 1: #If warm start for inner APP iterations is not desired, comment this if block
			for i in range(self.genNumber):
				pSelfBeleifInner[i] = powSelfBel[(intervalID+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration powSelfBel[intervalID*genNumber+i]
		
		if dummyZ == 1:
			if intervalID == 1:
				for i in range(self.genNumber):
					pSelfBeleif[i] = powSelfBel[intervalID*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
					pPrevBeleif[i] = powPrevBel[intervalID*genNumber+i] #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
					for pcTrack in range(contingencyCount+1):
						pNextBeleif[pcTrack*genNumber+i] = powNextBel[(intervalID+pcTrack)*genNumber+i] #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
			elif intervalID == 2:
				for i in range(self.genNumber):
					pSelfBeleif[i] = powSelfBel[(intervalID+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
					pPrevBeleif[i] = powPrevBel[(intervalID+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
					pNextBeleif[i] = powNextBel[(contingencyCount+2+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
			else:
				for i in range(self.genNumber):
					pSelfBeleif[i] = powSelfBel[intervalID*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
					pPrevBeleif[i] = powPrevBel[intervalID*genNumber+i] #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
					pNextBeleif[i] = powNextBel[intervalID*genNumber+i] #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
		elif dummyZ == 0:
			if intervalID == 1:
				for i in range(self.genNumber):
					pSelfBeleif[i] = powSelfBel[(intervalID-1)*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
					pPrevBeleif[i] = powPrevBel[(intervalID-1)*genNumber+i] #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
					for pcTrack in range(contingencyCount+1):
						pNextBeleif[pcTrack*genNumber+i] = powNextBel[((intervalID-1)+pcTrack)*genNumber+i] #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration
			elif intervalID == 2:
				for i in range(self.genNumber):
					pSelfBeleif[i] = powSelfBel[((intervalID-1)+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration
					pPrevBeleif[i] = powPrevBel[((intervalID-1)+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in previous dispatch interval from the previous APP iteration
					pNextBeleif[i] = powNextBel[(contingencyCount+1+postContScenario)*genNumber+i] #Belief about the generator MW output of the generators in next dispatch interval from the previous APP iteration

		if (solverChoice == 1) {
			matrixResultString = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/Summary_of_Result_Log" + to_string(scenarioIndex) + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			devProdString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/powerResult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			iterationResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/itresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt"; 
			lmpResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/LMPresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			objectiveResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/objective" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			primalResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/primresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			dualResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/dualresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
		else:
			matrixResultString = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/Summary_of_Result_Log" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			devProdString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/powerResult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt"+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			iterationResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/itresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt"; 
			lmpResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/LMPresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			objectiveResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/objective" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			primalResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/primresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
			dualResultString="/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/dualresult" + to_string(scenarioIndex)  + "_Scen"+to_string(intervalID)+"Inter_PCScen:"+to_string(postContScenario)+".txt";
	
		ofstream matrixResultOut( matrixResultString, ios::out ); // create a new file result.txt to output the results
	
		// exit program if unable to create file
		if ( !matrixResultOut ) {
			cerr << "File could not be opened" << endl;
			exit( 1 );
	
		if Verbose:
			matrixResultOut << "\nThe initial value of primal tolerance to kick-start iterations is: " << primalTol << "\nThe initial value of dual tolerance to kick-start iterations is: " << dualTol << endl;
	
	clock_t start_s = clock(); // begin keeping track of the time
	//int first = 0;
	double genActualTime = 0;
	genADMMMaxTimeVec.clear();
	// Starting of the ADMM Based Proximal Message Passing Algorithm Iterations
	//for ( iteration_count = 1; iteration_count < MAX_ITER; iteration_count++ ) {
	while( ( ( primalTol >= 0.06 ) || ( dualTol >= 0.6 ) ) && (iteration_count < MAX_ITER) ){ // ( iteration_count <= 122 )
	
		if ( Verbose ) {
			matrixResultOut << "\nThe value of primal tolerance before this iteration is: " << primalTol << "\nThe value of dual tolerance before this iteration is: " << dualTol << endl;
			matrixResultOut << "\n**********Start of " << iteration_count << " -th iteration***********\n";
		}		
		// Recording data for plotting graphs
		
		iterationGraph.push_back( iteration_count ); // stores the iteration count to be graphed
		primTolGraph.push_back( primalTol ); // stores the primal tolerance value to be graphed
		PrimTolGraph.push_back( PrimalTol ); 
		dualTolGraph.push_back( dualTol ); // stores the dual tolerance value to be graphed
		//Initialize the average node angle imbalance price (v) vector from last to last interation, V_avg
		//**if ( iteration_count <= 2 ) {
			for ( int i = 0; i < nodeNumber; i++ )
				V_avg[ i ] = 0.0; // initialize to zero for the first and second iterations if the initial values are zero
		//**}
		//**else {
			//**for ( int j = 0; j < nodeNumber; j++ )
				//**V_avg[ j ] = vBuffer1[ j ]; // initialize to the average node v from last to last iteration for 3rd iteration on
		
		//**}
		// Initialize average v, average theta, ptilde, average P before the start of a particular iteration
		if ( iteration_count >= 2 ) {
			angleBuffer1[ 0 ] = 0.0; // set the first node as the slack node, the average voltage angle is always zero
			for ( int i = 0; i < nodeNumber; i++ ) {
				//**vBuffer1[ i ] = vBuffer2[ i ]; // Save to vBuffer1, the average v from last iteration for use in next iteration
				angleBuffer1[ i ] = angleBuffer[ i ]; // Save to angleBuffer1, the average node voltage angle from last iteration
			}

			for ( int j = 0; j < deviceTermCount; j++ )
				powerBuffer1[ j ] = powerBuffer[ j ]; // Save to powerBuffer1, the Ptilde for each device term. from last itern

		}
		
		else {
			Wprev = 0.0; // for the first iteration
			for ( int i = 0; i < nodeNumber; i++ ) {
			
				angleBuffer1[ i ] = 0.0; // Set average node voltage angle to zero for 1st iteration
			}

			vector< Node >::iterator nodeIterator;
			for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
				bufferIndex = nodeIterator->getNodeID() - 1;
				pavBuffer[ bufferIndex ] = nodeIterator->devpinitMessage(); // Average node power injection before 1st iteration
			}
			for ( int j = 0; j < deviceTermCount; j++ )
				powerBuffer1[ j ] = ptildeinitBuffer[ j ]; // Save to powerBuffer1, the Ptilde before the 1st iteration
		}
		genSingleTimeVec.clear();
		//vector< Generator >::const_iterator generatorIterator; // Distributed Optimizations; Generators' Opt. Problems
		double calcObjective = 0.0;	// initialize the total generator cost for this iteration
		for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) {
			clock_t start_sgen = clock(); // begin keeping track of the time
			double Pgit, PowerPrice, APrice; // Generator Power, Power Price, & Angle Price iterates from last iterations
			bufferIndex = generatorIterator->getGenID() - 1;
			int gnid = generatorIterator->getGenNodeID() - 1; // gets the ID number of connection node
			if ( iteration_count > 1 ) { // If 2nd or higher iterations, initialize to previous iterate values
				Pgit = generatorIterator->genPower();
				PowerPrice = uPrice[ bufferIndex ];
				
				if ( gnid == 0 ) {
					APrice = 0.0; // Consider node-1 as the slack node, the angle price is zero always
				}

				else {
					APrice = vPrice[ bufferIndex ];
				}
			}
			else { // If 1st iteration, initialize to zero
				Pgit = 0.0;
				PowerPrice = 0.0;
				APrice = 0.0; 
			}
			if ( Verbose ) {
				matrixResultOut << "\nStarting of Generator Optimization Iterations for Generator " << bufferIndex + 1 << "\n";
				matrixResultOut << "Previous power iterate (MW/pu)\n" << Pgit << "\nPrevious average power (MW/pu) for this node\n" << pavBuffer[ gnid ] << "\nPrevious power price (scaled LMP)\n" << PowerPrice << "\nAngle price from last to last iterate (scaled)\n" << V_avg[ gnid ] << "\nAngle value from last iterate\n" << angleBuffer1[ gnid ] << "\nPrevious angle price (scaled)\n" << APrice << endl;
			}
			if (solverChoice == 1) {
				if (intervalID == 0) {	
					double AAPP = 0.0;
					double *BAPP;
					double *DAPP;
					BAPP = powDiffOuter+(bufferIndex);
					DAPP = powDiffOuter+(genNumber+bufferIndex);
					generatorIterator->gpowerangleMessageGUROBI( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], pNextBeleif, AAPP, BAPP, DAPP, (LambdaOuter+bufferIndex), (LambdaOuter+genNumber+bufferIndex), 0.0, 0.0, diffOfPow, appLambda, environmentGUROBI ); // Solve the Optimization Problem	
				}			
				if ((intervalID != 0) && (lastFlag == 0)) {
					double AAPP = 0.0;
					double BAPP[contingencyCount+1];
					double DAPP[contingencyCount+1];
					double LambOuterB[contingencyCount+1];
					double LambOuterD[contingencyCount+1];
					double PgNextbel[contingencyCount+1];
					for (int consensusCounter = 0; consensusCounter <= contingencyCount; ++consensusCounter) {
						if (consensusCounter==contingencyCount) {
							BAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex]-(dummyZ*powDiffOuter[genNumber+bufferIndex]);
							DAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							LambOuterB[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							LambOuterD[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							PgNextbel[consensusCounter] = pNextBeleif[(consensusCounter)*genNumber+bufferIndex];
						}
						else {
							BAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							DAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							LambOuterB[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							LambOuterD[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							PgNextbel[consensusCounter] = pNextBeleif[(consensusCounter)*genNumber+bufferIndex];
						}
					}
					AAPP = -dummyZ*(powDiffOuter[bufferIndex]);
					generatorIterator->gpowerangleMessageGUROBI( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], PgNextbel, AAPP, BAPP, DAPP, LambOuterB, LambOuterD, dummyZ*(LambdaOuter[bufferIndex]), dummyZ*(LambdaOuter[genNumber+bufferIndex]), diffOfPow, appLambda, environmentGUROBI ); // Solve the Optimization Problem
				}
				if ((intervalID != 0) && (lastFlag == 1)) {
					double *BAPP;
					double LambOuterB=0;
					double LambOuterD=0;
					double DAPP = 0.0;
					double AAPP = -powDiffOuter[2*dummyZ*genNumber+2*postContScenario*genNumber+bufferIndex];
					BAPP = -powDiffOuter+(2*dummyZ*genNumber+(2*postContScenario+1)*genNumber+bufferIndex);
					generatorIterator->gpowerangleMessageGUROBI( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], pNextBeleif, AAPP, BAPP, &DAPP, &LambOuterB, &LambOuterD, LambdaOuter[2*dummyZ*genNumber+2*postContScenario*genNumber+bufferIndex], LambdaOuter[2*dummyZ*genNumber+(2*postContScenario+1)*genNumber+bufferIndex], diffOfPow, appLambda, environmentGUROBI ); // Solve the Optimization Problem
				}
				calcObjective = calcObjective + generatorIterator->objectiveGenGUROBI(); // calculate the total objective after this iteration
			}
			else {
				if (intervalID == 0) {	
					double AAPP = 0.0;
					double *BAPP;
					double *DAPP;
					BAPP = powDiffOuter+(bufferIndex);
					DAPP = powDiffOuter+(genNumber+bufferIndex);
					generatorIterator->gpowerangleMessage( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], pNextBeleif, AAPP, BAPP, DAPP, (LambdaOuter+bufferIndex), (LambdaOuter+genNumber+bufferIndex), 0.0, 0.0, diffOfPow, appLambda ); // Solve the Optimization Problem
				}			
				if ((intervalID != 0) && (lastFlag == 0)) {
					double AAPP = 0.0;
					double BAPP[contingencyCount+1];
					double DAPP[contingencyCount+1];
					double LambOuterB[contingencyCount+1];
					double LambOuterD[contingencyCount+1];
					double PgNextbel[contingencyCount+1];
					for (int consensusCounter = 0; consensusCounter <= contingencyCount; ++consensusCounter) {
						if (consensusCounter==contingencyCount) {
							BAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex]-(dummyZ*powDiffOuter[genNumber+bufferIndex]);
							DAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							LambOuterB[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							LambOuterD[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							PgNextbel[consensusCounter] = pNextBeleif[(consensusCounter)*genNumber+bufferIndex];
						}
						else {
							BAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							DAPP[consensusCounter] = powDiffOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							LambOuterB[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+2*consensusCounter*genNumber+bufferIndex];
							LambOuterD[consensusCounter] = LambdaOuter[2*dummyZ*genNumber+(2*consensusCounter+1)*genNumber+bufferIndex];
							PgNextbel[consensusCounter] = pNextBeleif[(consensusCounter)*genNumber+bufferIndex];
						}
					}
					AAPP = -dummyZ*(powDiffOuter[bufferIndex]);
					generatorIterator->gpowerangleMessage( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], PgNextbel, AAPP, BAPP, DAPP, LambOuterB, LambOuterD, dummyZ*(LambdaOuter[bufferIndex]), dummyZ*(LambdaOuter[genNumber+bufferIndex]), diffOfPow, appLambda ); // Solve the Optimization Problem
				}
				if ((intervalID != 0) && (lastFlag == 1)) {
					double *BAPP;
					double LambOuterB=0;
					double LambOuterD=0;
					double DAPP = 0.0;
					double AAPP = -powDiffOuter[2*dummyZ*genNumber+2*postContScenario*genNumber+bufferIndex];
					BAPP = powDiffOuter+(2*dummyZ*genNumber+(2*postContScenario+1)*genNumber+bufferIndex);
					generatorIterator->gpowerangleMessage( outerIter, countOfAPPIter, Rho, Pgit, pavBuffer[ gnid ], PowerPrice, V_avg[ gnid ], angleBuffer1[ gnid ], APrice, pPrevBeleif[ bufferIndex ], pSelfBeleif[ bufferIndex ], pSelfBeleifInner[ bufferIndex ], pNextBeleif, AAPP, BAPP, &DAPP, &LambOuterB, &LambOuterD, LambdaOuter[2*dummyZ*genNumber+2*postContScenario*genNumber+bufferIndex], LambdaOuter[2*dummyZ*genNumber+(2*postContScenario+1)*genNumber+bufferIndex], diffOfPow, appLambda ); // Solve the Optimization Problem
				}
				calcObjective = calcObjective + generatorIterator->objectiveGen(); // calculate the total objective after this iteration
			}
			clock_t stop_sgen = clock(); // begin keeping track of the time
			double genSingleTime = static_cast<double>( stop_sgen - start_sgen ) / CLOCKS_PER_SEC;
			genSingleTimeVec.push_back(genSingleTime);
			genActualTime += genSingleTime;
		}
		double largestGenTime = *max_element(genSingleTimeVec.begin(), genSingleTimeVec.end());
		genADMMMaxTimeVec.push_back(largestGenTime);
		//vector< Load >::const_iterator loadIterator;	// Distributed Optimizations; Loads' Optimization Problems
		for ( loadIterator = loadObject.begin(); loadIterator != loadObject.end(); loadIterator++ ) {
			double APrice, PPrice; // Load Power Price and Angle Price from last iterations
			bufferIndex = genNumber + ( loadIterator->getLoadID() - 1 );
			int lnid = loadIterator->getLoadNodeID() - 1; // gets ID number of connection node
			if ( iteration_count > 1 ) { // If 2nd or higher iterations, initialize to previous iterate values
				
				if ( lnid == 0 ) {
					APrice = 0.0; // Consider node-1 as the slack node, the angle price is zero always
				}

				else {
					APrice = vPrice[ bufferIndex ];
				}
				PPrice = uPrice[ bufferIndex ];
			}
			else 
				APrice = 0.0; // If 1st iteration, initialize to zero
			if ( Verbose ) {
				matrixResultOut << "\nStarting of Load Optimization Iterations for Load " << loadIterator->getLoadNodeID() << "\n";
				matrixResultOut << "\nAngle price from last to last iterate (scaled)\n" << V_avg[ lnid ] << "\nAngle value from last iterate\n" << angleBuffer1[ lnid ] << "\nPrevious angle price (scaled)\n" << APrice << endl;
			}
			loadIterator->lpowerangleMessage( Rho, V_avg[ lnid ], angleBuffer1[ lnid ], APrice ); // Solve the Optimization Problem
		}
		//vector< transmissionLine >::const_iterator translIterator;// Distributed Optimizations; TLine' Optimization Problems
		int temptrans2 = 0;	
		for ( translIterator = translObject.begin(); translIterator != translObject.end(); translIterator++ ) {
			double Ptit1, Ptit2, PowerPrice1, PowerPrice2, APrice1, APrice2; // Tline Power, Power price, Angle price at both ends
			bufferIndex = genNumber + loadNumber + ( translIterator->getTranslID() - 1 ) + temptrans2;
			int tnid1 = translIterator->getTranslNodeID1() - 1; // gets ID number of first conection node
			int tnid2 = translIterator->getTranslNodeID2() - 1; // gets ID number of second connection node
			if (iteration_count > 1 ) { // If 2nd or higher iterations, initialize to previous iterate values
				Ptit1 = translIterator->translPower1();
				Ptit2 = translIterator->translPower2();
				PowerPrice1 = uPrice[ bufferIndex ];
				PowerPrice2 = uPrice[ ( bufferIndex + 1 ) ];
				
				if ( tnid1 == 0 ) {
					APrice1 = 0.0; // Consider node-1 as the slack node, the angle price is zero always
				}

				else {
					APrice1 = vPrice[ bufferIndex ];
				}
				
				if ( tnid2 == 0 ) {
					APrice2 = 0.0; // Consider node-1 as the slack node, the angle price is zero always
				}

				else {
					APrice2 = vPrice[ ( bufferIndex + 1 ) ];
				}
			}
			else { // If 1st iteration, initialize to zero
				Ptit1 = 0.0;
				Ptit2 = 0.0;
				PowerPrice1 = 0.0;
				PowerPrice2 = 0.0;
				APrice1 = 0.0;
				APrice2 = 0.0;
			}
			if ( Verbose ) {
				matrixResultOut << "\nStarting of Transmission Line Optimization Iterations for Transmission line " << translIterator->getTranslID() << "\n";
				matrixResultOut << "Previous power iterate (MW/pu) for end-1\n" << Ptit1 << "\nPrevious average power (MW/pu) for end-1\n" << pavBuffer[ tnid1 ] << "\nPrevious power price (scaled LMP) for end-1\n" << PowerPrice1 << "\nAngle price from last to last iterate for end-1 (scaled)\n" << V_avg[ tnid1 ] << "\nAngle value from last iterate for end-1\n" << angleBuffer1[ tnid1 ] << "\nPrevious angle price for end-1 (scaled)\n" << APrice1 << "\nPrevious power iterate (MW/pu) for end-2\n" << Ptit2 << "\nPrevious average power (MW/pu) for end-2\n" << pavBuffer[ tnid2 ] << "\nPrevious power price (scaled LMP) for end-2\n" << PowerPrice2 << "\nAngle price from last to last iterate for end-2 (scaled)\n" << V_avg[ tnid2 ] << "\nAngle value from last iterate for end-2\n" << angleBuffer1[ tnid2 ] << "\nPrevious angle price for end-2 (scaled)\n" << APrice2 << endl;	
			}			
			translIterator->tpowerangleMessage( Rho, Ptit1, pavBuffer[ tnid1 ], PowerPrice1, V_avg[ tnid1 ], angleBuffer1[ tnid1 ], APrice1, Ptit2, pavBuffer[ tnid2 ], PowerPrice2, V_avg[ tnid2 ], angleBuffer1[ tnid2 ], APrice2 ); // Solve the Opt. Problem
			temptrans2++; 
		}
		
		
		if ( setTuning == 1 ) {
			W = ( Rho1 ) * ( primalTol / dualTol ) - 1; // Definition of W for adaptive Rho with Rho1 * primalTol = dualTol
		}
		else {
			if ( setTuning == 2 ) {
				W = ( primalTol / dualTol ) - 1; // Definition of W for adaptive Rho with primalTol = dualTol
			}
			else {
	 			//W = 0.0; // Definition of W for fixed Rho
				if ( iteration_count <= 3000 ) {
					W = ( Rho1 ) * ( primalTol / dualTol ) - 1; // Definition of W for adaptive Rho with Rho1 * primalTol = dualTol
				}
				else {
					W = 0.0; // Definition of W for fixed Rho
				}
			}
		}
		// Calculation of Adaptive Rho
		controllerSum = controllerSum + W;
		Rho1 = Rho; // Store previous Rho
		Rho = ( Rho1 ) * ( exp( ( lambdaAdap * W ) + ( muAdap * ( W - Wprev ) ) + ( xiAdap * controllerSum  ) ) ); // Next iterate value of Rho
		Wprev = W; // Buffering
		
		if ( Verbose ) {
			matrixResultOut << "\n*********Starting of Gather Operation************\n";
		}
		vector< Node >::iterator nodeIterator; // Distributed Optimizations; Nodes' Optimization Problem; Gather Operation
		for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
			bufferIndex = nodeIterator->getNodeID() - 1;
			//**vBuffer2[ bufferIndex ] = ( Rho1 / Rho ) * ( nodeIterator->vavMessage() ); // Gather & Calculate average v after present iteration/node
			if ( bufferIndex == 0 ) {
				angleBuffer [ bufferIndex ] = 0.0; // consider node 1 as slack node; average voltage angle always zero
			}
			else {
				angleBuffer[ bufferIndex ] = nodeIterator->ThetaavMessage(); // Calculate average angle after present iteration/node
			}
			pavBuffer[ bufferIndex ] = nodeIterator->PavMessage(); // Calculate average power after present iteration/node
			if ( Verbose ) {
				matrixResultOut << "\nNode Number: " << bufferIndex + 1 /*<< "\nV_avg = " << vBuffer2[ bufferIndex ] */<< "\nTheta_avg = " << angleBuffer[ bufferIndex ] << "\nP_avg = " << pavBuffer[ bufferIndex ] << endl;
			}
		}

		if ( Verbose ) {
			matrixResultOut << "\n*******Starting of Broadcast Operation*******\n";
		}
		// vector< Generator >::const_iterator generatorIterator;	// Broadcast to Generators
		for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) {
			bufferIndex = generatorIterator->getGenID() - 1;
			if ( Verbose ) {
				matrixResultOut << "\n***Generator: " << bufferIndex + 1 << " results***\n" << endl;
			}
			powerBuffer[ bufferIndex ] = generatorIterator->calcPtilde();
			uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( generatorIterator->getu() );
			angtildeBuffer[ bufferIndex ] = generatorIterator->calcThetatilde();
			//generatorIterator->calcvtilde();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( generatorIterator->getv() );
			if ( Verbose ) {
				matrixResultOut << "\nPower price after this iteration ($/MWh, LMP) is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << endl;
			}
		}

		// vector< Load >::const_iterator loadIterator;	// Broadcast to Loads
		for ( loadIterator = loadObject.begin(); loadIterator != loadObject.end(); loadIterator++ ) {
			bufferIndex = genNumber + ( loadIterator->getLoadID() - 1 );
			if ( Verbose ) {
				matrixResultOut << "\n***Load: " << loadIterator->getLoadID() << " results***\n" << endl;
			}
			powerBuffer[ bufferIndex ] = loadIterator->calcPtilde();
			uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( loadIterator->getu() );
			angtildeBuffer[ bufferIndex ] = loadIterator->calcThetatilde();
			//loadIterator->calcvtilde();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( loadIterator->getv() );
			if ( Verbose ) {
				matrixResultOut << "\nPower price after this iteration ($/MWh, LMP) is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << endl;
			}
		}

		int temptrans = 0; // temporary count of transmission lines to account for both the ends // Broadcast to Transmission Lines
		// vector< transmissionLine >::const_iterator translIterator;	
		for ( translIterator = translObject.begin(); translIterator != translObject.end(); translIterator++ ) {
			bufferIndex = genNumber + loadNumber + ( translIterator->getTranslID() - 1 ) + temptrans;
			if ( Verbose ) {
				matrixResultOut << "\n***Transmission Line: " << translIterator->getTranslID() << " results***\n" << endl;
			}
			powerBuffer[ bufferIndex ] = translIterator->calcPtilde1();
			uPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( translIterator->getu1() );
			angtildeBuffer[ bufferIndex ] = translIterator->calcThetatilde1();
			//translIterator->calcvtilde1();
			vPrice[ bufferIndex ] = ( Rho1 / Rho ) * ( translIterator->getv1() );
			powerBuffer[ ( bufferIndex + 1 ) ] = translIterator->calcPtilde2();
			uPrice[ ( bufferIndex + 1 ) ] = ( Rho1 / Rho ) * ( translIterator->getu2() );
			angtildeBuffer[ ( bufferIndex + 1 ) ] = translIterator->calcThetatilde2();
			//translIterator->calcvtilde2();
			vPrice[ ( bufferIndex + 1 ) ] = ( Rho1 / Rho ) * ( translIterator->getv2() );
			temptrans++;
			if ( Verbose ) {
				matrixResultOut << "\nPower price ($/MWh, LMP at end-1) after this iteration is: " << ( Rho / 100 ) * uPrice[ bufferIndex ] << "\nAngle price (end-1) after this iteration is: " << ( Rho ) * vPrice[ bufferIndex ] << "\nPtilde (end-1) after this iteration is: " << powerBuffer[ bufferIndex ] << "\nThetatilde (end-1) at the end of this iteration is: " << angtildeBuffer[ bufferIndex ] << "\nPower price ($/MWh, LMP at end-2) after this iteration is: " << ( Rho / 100 ) * uPrice[ ( bufferIndex + 1 ) ] << "\nAngle price (end-2) after this iteration is: " << ( Rho ) * vPrice[ ( bufferIndex + 1 ) ] << "\nPtilde (end-2) after this iteration is: " << powerBuffer[ ( bufferIndex + 1 ) ] << "\nThetatilde (end-2)  at the end of this iteration is: " << angtildeBuffer[ ( bufferIndex + 1 ) ] <<endl;
			}
		}

		//if ( ( iteration_count >= 100 ) && ( ( ( iteration_count % 100 ) == 0 ) || ( iteration_count == MAX_ITER - 1 ) ) ) {
			int i = 0;
			for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
				LMP[ i ] = ( Rho / 100 ) * nodeIterator->uMessage(); // record the LMP values; rescaled and converted to $/MWh
				//nodeIterator->reset(); // reset the node variables that need to start from zero in the next iteration
				++i;
			}
			//++first;
		//}
	
		for ( nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); nodeIterator++ ) {
			nodeIterator->reset(); // reset the node variables that need to start from zero in the next iteration
		}

		// Calculation of Primal Tolerance, primalTol at the end of this particular iteration
		double primsum = 0.0;
		double Primsum = 0.0;
		for ( int i = 0; i < nodeNumber; i++ ) {
			primsum = primsum + pow( pavBuffer[ i ], 2.0 );
			Primsum = Primsum + pow( pavBuffer[ i ], 2.0 );
		}
		for ( int j = 0; j < deviceTermCount; j++ )
			primsum = primsum + pow( angtildeBuffer[ j ], 2.0 );
		primalTol = sqrt( primsum );
		PrimalTol = sqrt( Primsum );
		if ( Verbose ) {
			matrixResultOut << "\nPrimal Tolerance at the end of this iteration is: " << primalTol << endl;
		}
		// Calculation of Dual Tolerance, dualTol at the end of this particular iteration
		double sum = 0.0;
		if ( iteration_count > 1 ) {
			for ( int k = 0; k < deviceTermCount; k++ ) {
				sum = sum + pow( ( powerBuffer[ k ] - powerBuffer1[ k ] ), 2.0 ); 
				//matrixResultOut << "\npowerBuffer: " << powerBuffer[ k ] << "\npowerBuffer1: " << powerBuffer1[ k ] << endl;
			}
			for ( int i = 0; i < nodeNumber; i++ ) {
				sum = sum + pow( ( angleBuffer[ i ] - angleBuffer1[ i ] ), 2.0 );
				//matrixResultOut << "\nangleBuffer: " << angleBuffer[ i ] << "\nangleBuffer1: " << angleBuffer1[ i ] << endl;
			}
		}
		else {
			for ( int i = 0; i < nodeNumber; i++ )
				sum = sum + pow( ( angleBuffer[ i ] ), 2.0 ); 
			for ( int k = 0; k < deviceTermCount; k++ )
				sum = sum + pow( ( powerBuffer[ k ] - ptildeinitBuffer[ k ] ), 2.0 );
		}
		
		dualTol = ( Rho1 ) * sqrt( sum );
		//matrixResultOut << sqrt( sum ) << endl;
		if ( Verbose ) {
			matrixResultOut << "\nDual Tolerance at the end of this iteration is: " << dualTol << endl;
			matrixResultOut << "\nObjective value at the end of this iteration is ($): " << calcObjective << endl;
			matrixResultOut << "\n****************End of " << iteration_count << " -th iteration***********\n";
		}
		objectiveValue.push_back( calcObjective ); // record the objective values

		iteration_count++;
		//cout << iteration_count << endl;

	} // end of one iteration
	clock_t stop_s = clock();  // end
	matrixResultOut << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;
	matrixResultOut << "\nVirtual Execution Time (s): " << (static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC) - genActualTime + accumulate(genADMMMaxTimeVec.begin(), genADMMMaxTimeVec.end(), 0.0)<< endl;
	virtualExecTime=(static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC) - genActualTime + accumulate(genADMMMaxTimeVec.begin(), genADMMMaxTimeVec.end(), 0.0);
	matrixResultOut << "\nLast value of dual residual / Rho = " << dualTol / Rho1 << endl;
	matrixResultOut << "\nLast value of primal residual = " << primalTol << endl;
	matrixResultOut << "\nLast value of Rho = " << Rho1 << endl;
	matrixResultOut << "\nLast value of dual residual = " << dualTol << endl;
	matrixResultOut << "\nTotal Number of Iterations = " << iteration_count - 1 << endl;	
	//cout << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;

	/**PRINT MW**/
	ofstream devProdOut( devProdString, ios::out ); // create a new file powerResult.txt to output the results	
	// exit program if unable to create file
	if ( !devProdOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	devProdOut << "Gen#" << "\t" << "Conn." << "\t" << "MW" << endl;
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) {
		devProdOut << generatorIterator->getGenID() << "\t" << generatorIterator->getGenNodeID() << "\t" <<    generatorIterator->genPower() * 100 << endl;
	}
	devProdOut << "T.line#" << "\t" << "From" << "\t" << "To" << "\t" << "From MW" << "\t" << "To MW" << endl;
	for ( translIterator = translObject.begin(); translIterator != translObject.end(); translIterator++ ) {
		devProdOut << translIterator->getTranslID() << "\t" << translIterator->getTranslNodeID1() << "\t" << translIterator->getTranslNodeID2() << "\t" << translIterator->translPower1() * 100 << "\t" << translIterator->translPower2() * 100 << endl;
	}

	/**PRINT ITERATION COUNTS**/
	ofstream iterationResultOut( iterationResultString, ios::out ); // create a new file itresult.txt to output the results	
	// exit program if unable to create file
	if ( !iterationResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	iterationResultOut << "\nIteration Count: " << endl;
	vector< int >::iterator iterationCountIterator; 
	for ( iterationCountIterator = iterationGraph.begin(); iterationCountIterator != iterationGraph.end(); iterationCountIterator++ )  		{
		iterationResultOut << *iterationCountIterator << endl;
	}

	/**PRINT LMPs**/
	ofstream lmpResultOut( lmpResultString, ios::out ); // create a new file itresult.txt to output the results	
	// exit program if unable to create file
	if ( !lmpResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	lmpResultOut << "\nLocational Marginal Prices for Real Power at nodes ($/MWh): " << endl;
	
	//for ( int j = 0; j < firstIndex; ++j ) {
		//lmpResultOut << "After " << ( j + 1 ) * 100 << " iterations, LMPs are:" << endl;
		for ( int i = 0; i < nodeNumber; ++i ) {
			lmpResultOut << i + 1 << "\t" << LMP[ i ] << endl; // print the LMP values
		}
	//}
	
	/**PRINT OBJECTIVE VALUES**/
	ofstream objectiveResultOut( objectiveResultString, ios::out ); // create a new file objective.txt to output the results	
	// exit program if unable to create file
	if ( !objectiveResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	objectiveResultOut << "\nObjective value: " << endl;
	vector< double >::iterator objectiveIterator; 
	for ( objectiveIterator = objectiveValue.begin(); objectiveIterator != objectiveValue.end(); objectiveIterator++ )  {
		objectiveResultOut << *objectiveIterator << endl;
	}
	matrixResultOut << "\nLast value of Objective = " << *(objectiveIterator-1) << endl;

	/**PRINT PRIMAL RESIDUAL**/
	ofstream primalResultOut( primalResultString, ios::out ); // create a new file primresult.txt to output the results	
	// exit program if unable to create file
	if ( !primalResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	primalResultOut << "\nPrimal Residual: " << endl;
	vector< double >::iterator primalToleranceIterator;
	for ( primalToleranceIterator = primTolGraph.begin(); primalToleranceIterator != primTolGraph.end(); primalToleranceIterator++ )  		{
		primalResultOut << *primalToleranceIterator << endl;
	}
	
	/**PRINT DUAL RESIDUAL**/
	ofstream dualResultOut( dualResultString, ios::out ); // create a new file dualresult.txt to output the results	
	// exit program if unable to create file
	if ( !dualResultOut ) {
		cerr << "File could not be opened" << endl;
		exit( 1 );
	}
	
	dualResultOut << "\nDual Residual: " << endl;
	vector< double >::iterator dualToleranceIterator;
	for ( dualToleranceIterator = dualTolGraph.begin(); dualToleranceIterator != dualTolGraph.end(); dualToleranceIterator++ )  		
	{
		dualResultOut << *dualToleranceIterator << endl;
	}
} // end runSimulation

double Network::returnVirtualExecTime(){return virtualExecTime;}

void Network::runSimAPPGurobiBase(int outerIter, double LambdaOuter[], double powDiffOuter[], int countOfAPPIter, double appLambda[], double diffOfPow[], double powSelfBel[], double powNextBel[], double powPrevBel[], GRBEnv* environmentGUROBI) { // runs the APP coarse grain Gurobi OPF for base case
	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double betaSC =200.0;
	double gammaSC =100.0;
	double externalGamma =100.0;
	double PgAPPSC[genNumber];
	double PgAPPNext[genNumber];
	double PgAPPPrev[genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		PgAPPSC[(genIterator->getGenID()-1)]=-powSelfBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPNext[(genIterator->getGenID()-1)]=-powNextBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPPrev[(genIterator->getGenID()-1)]=-powPrevBel[intervalID*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/Summary_of_Result_Log_BaseCase" + to_string(scenarioIndex) + "_Scen"+to_string(intervalID)+"_Inter.txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (6 * genNumber + 2 * translNumber + nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, upper and lower ramping constraints, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
	int dimCol;
	if (intervalID == 0) {
        	dimCol = (2*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 0)) {
        	dimCol = (3*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 1)) {
        	dimCol = (2*genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	GRBVar decvar[dimCol+1];
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	double BAPPNew[genNumber];
	double LambdaAPPNew[genNumber];
	for ( int i = 0; i < genNumber; ++i ) {
		BAPPNew[i]=0; 
		LambdaAPPNew[i]=0;
	}
	for ( int i = 0; i < genNumber; ++i ) {
		 for (int counterCont = 0; counterCont < contingencyCount; ++counterCont) {
			BAPPNew[i]+=diffOfPow[counterCont*genNumber+i]; 
			LambdaAPPNew[i]+=appLambda[counterCont*genNumber+i];
		}
	}
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)])+LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*(powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))+(LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*BAPPNew[(genIterator->getGenID()-1)])+LambdaAPPNew[(genIterator->getGenID()-1)]*(decvar[colCount])+(externalGamma)*((decvar[colCount])*(-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))-(LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		obj += 0*(decvar[colCount]);	
		++colCount;
	}
	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/PgenFile_BaseCase" + to_string(scenarioIndex) + "_Scen"+to_string(intervalID)+"_Inter.txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		outPutFile << "\nGeneration\t" << rCount << "\n";
		int genListLength = (nodeIterator)->getGenLength(); // get the number
		lhs[rCount]=0;
		if (intervalID == 0){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[3*((nodeIterator)->getGenSer(cCount))-2]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (int cCount = 1; cCount <= genListLength; ++cCount){
				lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
				outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
			}
		}
		outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
		if (intervalID == 0){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[2*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[3*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[2*genNumber+rCount]);
			outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		}
		outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
		int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
		if (intervalID == 0){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
				if (((nodeIterator)->getConnReact(cCount))<=0)
					lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				else
					lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
				outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

			}
		}
		busCount.push_back(rCount);
		if (((nodeIterator)->getLoadVal())==0) {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
		}
		else {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
		}
		outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
		outPutFile << rCount << "\t";
		if (((nodeIterator)->getLoadVal())==0)
			outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		else
			outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next node object
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
			outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	int scaler;
	if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1)))
		scaler = 2;
	if ((intervalID != 0) && (lastFlag == 0))
		scaler = 3;
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}
	// Coefficients corresponding to lower ramp rate limits
	outPutFile << "\nCoefficients corresponding to lower ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper ramp rate limits
	outPutFile << "\nCoefficients corresponding to upper ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	//cout << "\nSimulation in Progress. Wait !!! ....." << endl;
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		//cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/AngleResult_BaseCase.txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/TranFlow_BaseCase.txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		//cout << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		if (intervalID == 0){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = genIterator->getPgenPrev(); // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = 0; // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			internalAngleOut << (nodeIterator)->getNodeID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
			++arrayInd;			
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "MW FLOW" << "\n";
		if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1)))
			scaler = 2;
		if ((intervalID != 0) && (lastFlag == 0))
			scaler = 3;
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler*genNumber +(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler*genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		//cout << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
}
void Network::runSimAPPGurobiCont(int outerIter, double LambdaOuter[], double powDiffOuter[], int countOfAPPIter, double appLambda[], double diffOfPow[], GRBEnv* environmentGUROBI) { // runs the APP coarse grain Gurobi OPF for contingency scenarios	
	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double betaSC =200.0;
	double gammaSC =-100.0;
	double PgAPPSC[genNumber];
	double lambdaNewAPP[contingencyCount*genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		if (countOfAPPIter==1)
			PgAPPSC[(genIterator->getGenID()-1)]=0;
		else
			PgAPPSC[(genIterator->getGenID()-1)] = -pSelfBufferGUROBI[(genIterator->getGenID()-1)];
		lambdaNewAPP[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)]=-appLambda[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/Summary_of_Result_Log" + to_string(scenarioIndex) + ".txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (2 * genNumber + 2 * translNumber + nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
        int dimCol = (genNumber+nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
	//cout << "\nGurobi model created" << endl;
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	//cout << "\nGurobi model created and name set" << endl;
	GRBVar decvar[dimCol+1];
	//cout << "\nGurobi decision variables created" << endl;
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	//cout << "\nGurobi decision variables to be assigned" << endl;
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	//cout << "\nGurobi dummy decision variable created" << endl;
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
		++colCount;
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(gammaSC)*((decvar[colCount])*diffOfPow[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)])+appLambda[(scenarioIndex-1)*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
		++colCount;
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//	
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		obj += 0*(decvar[colCount]);	
		++colCount;
	}

	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/PgenFile" + to_string(scenarioIndex) + ".txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
		outPutFile << "\nGeneration\t" << rCount << "\n";
		int genListLength = (nodeIterator)->getGenLength(); // get the number
		lhs[rCount]=0;
		for (int cCount = 1; cCount <= genListLength; ++cCount){
			lhs[rCount] += 1*(decvar[(nodeIterator)->getGenSer(cCount)]);
			outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
		}
		outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
		lhs[rCount] += (((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)))*(decvar[genNumber+rCount]);
		outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(0))-((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getFromReact(0)) << "\t" << -((nodeIterator)->getToReact(0)) << endl;
		outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
		int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
		for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
			if (((nodeIterator)->getConnReact(cCount))<=0)
				lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[genNumber+((nodeIterator)->getConnSer(cCount))]);
			else
				lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[genNumber+((nodeIterator)->getConnSer(cCount))]);
			outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

		}
		busCount.push_back(rCount);
		if (((nodeIterator)->getLoadVal())==0) {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
		}
		else {
			modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
		}
		outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
		outPutFile << rCount << "\t";
		if (((nodeIterator)->getLoadVal())==0)
			outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		else
			outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next node object
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[rCount - nodeNumber];
		modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
		outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[rCount - (genNumber + nodeNumber)];
		modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
		outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[genNumber + (tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << genNumber + (tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}	
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	//cout << "\nSimulation in Progress. Wait !!! ....." << endl;
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		//cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/AngleResult" + to_string(scenarioIndex) + ".txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_Quasi_Decent_GUROBI/TranFlow" + to_string(scenarioIndex) + ".txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		//cout << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
			powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
			++arrayInd;
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
			internalAngleOut << (nodeIterator)->getNodeID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
			++arrayInd;			
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "MW FLOW" << "\n";
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << (1/((tranIterator)->getReactance()))*((decvar[genNumber +(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		//cout << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
}

void Network::runSimulationCentral(int outerIter, double LambdaOuter[], double powDiffOuter[], double powSelfBel[], double powNextBel[], double powPrevBel[], GRBEnv* environmentGUROBI)
{	// CREATION OF THE MIP SOLVER INSTANCE //
	clock_t begin = clock(); // start the timer
	vector<int>::iterator diffZNIt; // Iterator for diffZoneNodeID
	vector<Generator>::iterator genIterator; // Iterator for Powergenerator objects
	vector<transmissionLine>::iterator tranIterator; // Iterator for Transmission line objects
	vector<Load>::iterator loadIterator; // Iterator for load objects
	vector<Node>::iterator nodeIterator; // Iterator for node objects
	double externalGamma =5.0;
	double betaSC =10.0;
	double PgAPPSC[genNumber];
	double PgAPPNext[genNumber];
	double PgAPPPrev[genNumber];
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		PgAPPSC[(genIterator->getGenID()-1)]=-powSelfBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPNext[(genIterator->getGenID()-1)]=-powNextBel[intervalID*genNumber+(genIterator->getGenID()-1)];
		PgAPPPrev[(genIterator->getGenID()-1)]=-powPrevBel[intervalID*genNumber+(genIterator->getGenID()-1)];
	}
	string outSummaryFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/Summary_of_Result_Log"+to_string(intervalID)+".txt";
	ofstream outPutFile(outSummaryFileName, ios::out); // Create Output File to output the Summary of Results
	if (!outPutFile){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}

        int dimRow = (6 * genNumber + 2*translNumber + 2*contingencyCount*(translNumber-1) + (contingencyCount+1)*nodeNumber); // Total number of rows of the A matrix (number of structural constraints of the QP) first term to account for lower and upper generating limits, second term for lower and upper line limits for transmission lines, the third term to account for nodal power balance constraints
	int dimCol;
	if (intervalID == 0) {
        	dimCol = (2*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 0)) {
        	dimCol = (3*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	if ((intervalID != 0) && (lastFlag == 1)) {
        	dimCol = (2*genNumber+(contingencyCount+1)*nodeNumber); // Total number of columns of the QP (number of Decision Variables) first term to account for power generation MW outputs, second term for voltage phase angles for nodes
	}
	outPutFile << "\nTotal Number of Structural Constraints (Rows) is: " << dimRow << endl;
	outPutFile << "\nTotal Number of Decision Variables (Columns) is: " << dimCol << endl;
	// Instantiate GUROBI Problem model
	GRBModel *modelCentQP = new GRBModel(*environmentGUROBI);
    	modelCentQP->set(GRB_StringAttr_ModelName, "assignment");
	modelCentQP->set(GRB_IntParam_OutputFlag, 0);
	GRBVar decvar[dimCol+1];
	double z; // variable to store the objective value

	// SPECIFICATION OF PROBLEM PARAMETERS //
	// Dummy Decision Variable //
	decvar[0] = modelCentQP->addVar(0.0, 1.0, 0.0, GRB_CONTINUOUS);
	//Decision Variable Definitions, Bounds, and Objective Function Co-efficients//
	int colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for next interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){ 
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
			//Columns corresponding to Power Generation continuous variables for different generators for previous interval//
			decvar[colCount] = modelCentQP->addVar(0.0, GRB_INFINITY, 0.0, GRB_CONTINUOUS);
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Power Generation continuous variables for different generators: " << colCount << endl;

	//Columns corresponding to Voltage Phase Angles continuous variables for different nodes//
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {	
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			decvar[colCount] = modelCentQP->addVar((0), (44/7), 0.0, GRB_CONTINUOUS);	
			++colCount;
		}
	}
	outPutFile << "\nTotal number of columns after accounting for Voltage Phase Angles continuous variables for different intrazonal nodes: " << colCount << endl;
	outPutFile << "\nTotal Number of columns for generation, angles: " << colCount-1 << endl;
	outPutFile << "\nDecision Variables and Objective Function defined" << endl;
	outPutFile << "\nTotal Number of columns: " << colCount-1 << endl;
	//Setting Objective//
	GRBQuadExpr obj = 0.0;
	// Objective Contribution from Dummy Decision Variable //
	obj += 0*(decvar[0]);
	colCount = 1;
	//Columns corresponding to Power Generation continuous variables for different generators//
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)])+LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*(powDiffOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))+(LambdaOuter[2*intervalID*genNumber+(genIterator->getGenID()-1)]-LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPNext[(genIterator->getGenID()-1)])+(LambdaOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(powDiffOuter[(2*intervalID+1)*genNumber+(genIterator->getGenID()-1)]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			obj += (genIterator->getQuadCoeff())*(decvar[colCount])*(decvar[colCount])+(genIterator->getLinCoeff())*(decvar[colCount])+(genIterator->getConstCoeff())+(betaSC/2)*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPSC[(genIterator->getGenID()-1)])+(externalGamma)*((decvar[colCount])*(-powDiffOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)]))-(LambdaOuter[(2*(intervalID-1)+1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount]);
			++colCount;
			obj += (betaSC/2)*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])*(decvar[colCount]+PgAPPPrev[(genIterator->getGenID()-1)])-(LambdaOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)])*(decvar[colCount])+(externalGamma)*(decvar[colCount])*(-powDiffOuter[2*(intervalID-1)*genNumber+(genIterator->getGenID()-1)]);
		}
	}
	//Columns corresponding to Voltage Phase Angles continuous variables for different intrazonal nodes//
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {	
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			obj += 0*(decvar[colCount]);	
			++colCount;
		}
	}
	modelCentQP->setObjective(obj, GRB_MINIMIZE);
	//Row Definitions: Specification of b<=Ax<=b//
	GRBLinExpr lhs[dimRow+1];
	//Row Definitions and Bounds Corresponding to Constraints/
	// Constraints corresponding to supply-demand balance
	string outPGenFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/PgenFile"+to_string(intervalID)+".txt"; 
	ofstream powerGenOut(outPGenFileName, ios::out);
	if (!powerGenOut){
		cerr << "\nCouldn't open the file" << endl;
		exit(1);
	}
	//Non-Zero entries of A matrix (Constraint/Coefficient matrix entries)//
	// Coefficients for the supply-demand balance constraints
	outPutFile << "\nNon-zero elements of A matrix" << endl;
	outPutFile << "\nRow Number\tColumn Number\tNon-zero Entry\tFrom Reactance\tToReactance" << endl;
	outPutFile << "\nCoefficients for the supply-demand balance constraints" << endl;
	// Dummy Constraint //
	lhs[0] = 0*(decvar[0]);
	modelCentQP->addConstr(lhs[0], GRB_EQUAL, 0);
	int rCount = 1; // Initialize the row count
	vector<int> busCount; // vector for storing the node/bus serial
	outPutFile << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	//cout << "Constraints corresponding to Supply-Demand Balance right hand side" << endl;
	for (int scenCount = 0; scenCount <= contingencyCount; ++scenCount) {
		cout << "\nScenario\t" << scenCount << "\n";
		for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
			//cout << "\nNode\t" << nodeIterator->getNodeID() << "\n";
			outPutFile << "\nGeneration\t" << rCount << "\n";
			int genListLength = (nodeIterator)->getGenLength(); // get the number
			lhs[rCount]=0;
			if (intervalID == 0){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[3*((nodeIterator)->getGenSer(cCount))-2]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				for (int cCount = 1; cCount <= genListLength; ++cCount){
					lhs[rCount] += 1*(decvar[2*((nodeIterator)->getGenSer(cCount))-1]);
					outPutFile << "\n" << rCount << "\t" << (nodeIterator)->getGenSer(cCount) << "\t" << 1.0 << endl;
				}
			}
			outPutFile << "\nIntrazonal Node Angles\t" << rCount << "\n";
			//cout << "\nIntrazonal Node Angles\t" << rCount << "\n";
			if (intervalID == 0){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[2*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[3*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				lhs[rCount] += (((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)))*(decvar[2*genNumber+rCount]);
				outPutFile << "\n" << rCount << "\t" << genNumber+rCount << "\t" << -((nodeIterator)->getToReact(scenCount))-((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getFromReact(scenCount)) << "\t" << -((nodeIterator)->getToReact(scenCount)) << endl;
			}
			outPutFile << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
			//cout << "\nConnected Intrazonal Node Angles\t" << rCount << "\n";
			int connNodeListLength = (nodeIterator)->getConNodeLength(); // get the number of intra-zonal nodes connected to this node
			if (intervalID == 0){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			if ((intervalID != 0) && (lastFlag == 0)){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[3*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			if ((intervalID != 0) && (lastFlag == 1)){
				for (int cCount = 1; cCount <= connNodeListLength; ++cCount){
					if (((nodeIterator)->getConnReact(cCount))<=0)
						lhs[rCount] -= (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					else
						lhs[rCount] += (((nodeIterator)->getConnReact(cCount)))*(decvar[2*genNumber+((nodeIterator)->getConnSer(cCount))]);
					outPutFile << "\n" << rCount << "\t" << genNumber+((nodeIterator)->getConnSer(cCount)) << "\t" <<  (-((nodeIterator)->getConnReact(cCount))) << "\n";

				}
			}
			//cout << "\nThe scenario compensated connected node " << genNumber+scenCount*nodeNumber+((nodeIterator)->getConnSerScen(scenCount)) << " and connected serial is " << ((nodeIterator)->getConnSerScen(scenCount)) << endl;
			lhs[rCount] += ((nodeIterator)->getConnReactCompensate(scenCount))*(decvar[genNumber+scenCount*nodeNumber+((nodeIterator)->getConnSerScen(scenCount))]);
			//busCount.push_back(rCount);
			if (((nodeIterator)->getLoadVal())==0) {
				modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, ((nodeIterator)->getLoadVal()));
			}
			else {
				modelCentQP->addConstr(lhs[rCount], GRB_EQUAL, -((nodeIterator)->getLoadVal()));
			}
			outPutFile << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
			//cout << "Connected load to node " << rCount << " is " << (nodeIterator)->getLoadVal()*100 << " MW" << endl;
			outPutFile << rCount << "\t";
			if (((nodeIterator)->getLoadVal())==0)
				outPutFile << ((nodeIterator)->getLoadVal())*100 << " MW" << endl;
			else
				outPutFile << -((nodeIterator)->getLoadVal())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next node object
		}
	}
	// Coefficients corresponding to lower generation limits
	outPutFile << "\nCoefficients corresponding to lower generation limits\n";
	//cout << "\nCoefficients corresponding to lower generation limits\n";
	int scaler1, scaler2;
	if ((intervalID == 0) || ((intervalID != 0) && (lastFlag == 1))) {
		scaler1 = 2;
		scaler2=1;
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		scaler1 = 3;
		scaler2=2;
	}
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[scaler1*(genIterator->getGenID())-scaler2];
		modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getPMin()));
		outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getPMin() << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMin())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to upper generation limits
	outPutFile << "\nCoefficients corresponding to upper generation limits\n";
	for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
		lhs[rCount] = 0;
		lhs[rCount] += decvar[scaler1*(genIterator->getGenID())-scaler2];
		modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getPMax()));
		outPutFile << rCount << "\t" << (rCount - (genNumber + nodeNumber)) << "\t" << 1.0 << "\t" << ((genIterator)->getPMax()) << endl;
		outPutFile << rCount << "\t";
		outPutFile << ((genIterator)->getPMax())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next generator object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber +(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object		
	}	
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
		lhs[rCount] = 0;
		lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID1()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + (tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
		lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber +(tranIterator)->getTranslNodeID2()]);
		outPutFile << "\n" << rCount << "\t" << scaler1*genNumber +(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
		modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
		outPutFile << rCount << "\t";
		outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
		++rCount; // Increment the row count to point to the next transmission line object
	}
	// Coefficients corresponding to intra-zone Line Forward Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Forward Flow Limit Constraints\n";
	for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			if ((tranIterator)->getOutageScenario()!=scenCount) {
				lhs[rCount] = 0;
				lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
				lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
				modelCentQP->addConstr(lhs[rCount] <= ((tranIterator)->getFlowLimit()));
				outPutFile << rCount << "\t";
				outPutFile << ((tranIterator)->getFlowLimit())*100 << " MW" << endl;
				++rCount; // Increment the row count to point to the next transmission line object
			}		
		}	
	}
	// Coefficients corresponding to intra-zone Line Reverse Flow Limit Constraints
	outPutFile << "\nCoefficients corresponding to intra-zone Line Reverse Flow Limit Constraints\n";
	for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			if ((tranIterator)->getOutageScenario()!=scenCount) {
				lhs[rCount] = 0;
				lhs[rCount] += (1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1() << "\t" << 1/((tranIterator)->getReactance()) << "\t" << 1/((tranIterator)->getReactance()) << "\n";
				lhs[rCount] += (-1/((tranIterator)->getReactance()))*(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]);
				outPutFile << "\n" << rCount << "\t" << scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2() << "\t" << -1/((tranIterator)->getReactance()) << "\t" << "-" << "\t" << -1/((tranIterator)->getReactance()) << "\n";
				modelCentQP->addConstr(lhs[rCount] >= -((tranIterator)->getFlowLimit()));
				outPutFile << rCount << "\t";
				outPutFile << -((tranIterator)->getFlowLimit())*100 << " MW" << endl;
				++rCount; // Increment the row count to point to the next transmission line object
			}
		}
	}	
	// Coefficients corresponding to lower ramp rate limits
	outPutFile << "\nCoefficients corresponding to lower ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] >= ((genIterator)->getRMin()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMin() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMin())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	// Coefficients corresponding to upper ramp rate limits
	outPutFile << "\nCoefficients corresponding to upper ramp rate limits\n";
	if (intervalID == 0){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())]-decvar[2*(genIterator->getGenID())-1];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-((genIterator)->getPgenPrev());
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 0)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-1]-decvar[3*(genIterator->getGenID())-2];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[3*(genIterator->getGenID())-2]-decvar[3*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	if ((intervalID != 0) && (lastFlag == 1)){
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
		for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
			lhs[rCount] = 0;
			lhs[rCount] += decvar[2*(genIterator->getGenID())-1]-decvar[2*(genIterator->getGenID())];
			modelCentQP->addConstr(0*lhs[rCount] <= ((genIterator)->getRMax()));
			outPutFile << rCount << "\t" << (rCount - nodeNumber) << "\t" << 1.0 << "\t" << (genIterator)->getRMax() << endl;
			outPutFile << rCount << "\t";
			outPutFile << ((genIterator)->getRMax())*100 << " MW" << endl;
			++rCount; // Increment the row count to point to the next generator object
		}
	}
	outPutFile << "\nConstraint bounds (rows) Specified" << endl;
	outPutFile << "\nTotal number of rows: " << rCount - 1 << endl;
	outPutFile << "\nCoefficient Matrix specified" << endl;
	clock_t end1 = clock(); // stop the timer
	double elapsed_secs1 = double(end1 - begin) / CLOCKS_PER_SEC; // Calculate the time required to populate the constraint matrix and objective coefficients
	outPutFile << "\nTotal time taken to define the rows, columns, objective and populate the coefficient matrix = " << elapsed_secs1 << " s " << endl;
	// RUN THE OPTIMIZATION SIMULATION ALGORITHM //
	modelCentQP->optimize(); // Solves the optimization problem
	int stat = modelCentQP->get(GRB_IntAttr_Status); // Outputs the solution status of the problem 

	// DISPLAY THE SOLUTION DETAILS //
	if (stat == GRB_INFEASIBLE){
		outPutFile << "\nThe solution to the problem is INFEASIBLE." << endl;
		cout << "\nThe solution to the problem is INFEASIBLE." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_INF_OR_UNBD) {
		outPutFile << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		cout << "\nNO FEASIBLE or BOUNDED solution to the problem exists." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_UNBOUNDED) {
		outPutFile << "\nThe solution to the problem is UNBOUNDED." << endl;
		cout << "\nThe solution to the problem is UNBOUNDED." << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
	} else if (stat == GRB_OPTIMAL) {
		outPutFile << "\nThe solution to the problem is OPTIMAL." << endl;
		cout << "\nThe solution to the problem is OPTIMAL." << endl;

		//Get the Optimal Objective Value results//
		z = modelCentQP->get(GRB_DoubleAttr_ObjVal);

		// Open separate output files for writing results of different variables
		string outIntAngFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/AngleResult"+to_string(intervalID)+".txt";
		string outTranFlowFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Load_Variation/output/APP_GUROBI_Centralized_SCOPF/TranFlow"+to_string(intervalID)+".txt";
		ofstream internalAngleOut(outIntAngFileName, ios::out); //switchStateOut
		ofstream tranFlowOut(outTranFlowFileName, ios::out);
		outPutFile << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		powerGenOut << "\nThe Optimal Objective value (Generation Dispatch cost) is: " << z << endl;
		vector<double> x; // Vector for storing decision variable output 
		x.push_back(0); // Initialize the decision Variable vector

		//Display Power Generation
		powerGenOut << "\n****************** GENERATORS' POWER GENERATION LEVELS (MW) *********************" << endl;
		powerGenOut << "GENERATOR ID" << "\t" << "GENERATOR MW" << "\n";
		int arrayInd = 1;
		if (intervalID == 0){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = genIterator->getPgenPrev(); // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 0)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
			}
		}
		if ((intervalID != 0) && (lastFlag == 1)){
			for (genIterator = genObject.begin(); genIterator != genObject.end(); ++genIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pSelfBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				++arrayInd;
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				pPrevBufferGUROBI[ genIterator->getGenID()-1 ] = (decvar[arrayInd]).get(GRB_DoubleAttr_X); // Store the most recent generation MW belief in the array
				powerGenOut << (genIterator)->getGenID() << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				pNextBufferGUROBI[ genIterator->getGenID()-1 ] = 0; // Store the most recent generation MW belief in the array
				++arrayInd;
			}
		}
		powerGenOut << "Finished writing Power Generation" << endl;

		// Display Internal node voltage phase angle variables
		internalAngleOut << "\n****************** INTERNAL NODE VOLTAGE PHASE ANGLE VALUES *********************" << endl;
		internalAngleOut << "NODE ID" << "\t" << "CONTINGENCY SCENARIO" << "\t" << "VOLTAGE PHASE ANGLE" << "\n";
		for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
			for (nodeIterator = nodeObject.begin(); nodeIterator != nodeObject.end(); ++nodeIterator){
				x.push_back((decvar[arrayInd]).get(GRB_DoubleAttr_X));
				internalAngleOut << (nodeIterator)->getNodeID() << "\t" << scenCount << "\t" << ((decvar[arrayInd]).get(GRB_DoubleAttr_X)) << endl;		
				++arrayInd;			
			}
		}
		internalAngleOut << "Finished writing Internal Node Voltage Phase Angles" << endl;
		// Display Internal Transmission lines' Flows
		tranFlowOut << "\n****************** INTERNAL TRANSMISSION LINES FLOWS *********************" << endl;
		tranFlowOut << "TRANSMISSION LINE ID" << "\t" << "CONTINGENCY SCENARIO" << "\t" << "MW FLOW" << "\n";
		for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
			tranFlowOut << (tranIterator)->getTranslID() << "\t" << "Base-Case" << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler1*genNumber + (tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler1*genNumber + (tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
		}
		for (int scenCount = 1; scenCount <= contingencyCount; ++scenCount) {
			for (tranIterator = translObject.begin(); tranIterator != translObject.end(); ++tranIterator){
				if ((tranIterator)->getOutageScenario()!=scenCount) {
					tranFlowOut << (tranIterator)->getTranslID() << "\t" << scenCount << "\t" << (1/((tranIterator)->getReactance()))*((decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID1()]).get(GRB_DoubleAttr_X)-(decvar[scaler1*genNumber + scenCount*nodeNumber+(tranIterator)->getTranslNodeID2()]).get(GRB_DoubleAttr_X))*100 << " MW" << endl;
				}
			}
		}
		tranFlowOut << "Finished writing Internal Transmission lines' MW Flows" << endl;
		delete modelCentQP; // Free the memory of the GUROBI Problem Model
		clock_t end2 = clock(); // stop the timer
		double elapsed_secs2 = double(end2 - begin) / CLOCKS_PER_SEC; // Calculate the Total Time
		outPutFile << "\nTotal time taken to solve the MILP Line Construction Decision Making Problem instance and retrieve the results = " << elapsed_secs2 << " s " << endl;
		internalAngleOut.close();
		tranFlowOut.close();
	}
	// Close the different output files
	outPutFile.close();
	powerGenOut.close();
}

double *Network::getPowSelf()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pSelfBuffer[ bufferIndex ] = generatorIterator->genPower(); // Store the most recent generation MW belief in the array
	}
	return pSelfBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowPrev()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pPrevBuffer[ bufferIndex ] = generatorIterator->genPowerPrev(); // Store the most recent generation MW belief in the array
	}
	return pPrevBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowNext()
{
	vector< Generator >::iterator generatorIterator; // Iterator for generators	
	for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
		int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
		pNextBuffer[ bufferIndex ] = generatorIterator->genPowerNext(int nextScen); // Store the most recent generation MW belief in the array
	}
	return pNextBuffer;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

def getPowFlowNext(self, continCounter, supernetCount, rndInterCount, lineCount):

def getPowFlowSelf(self, lineCount):
"""
double *Network::getPowSelfGUROBI()
{
	return pSelfBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

double *Network::getPowNextGUROBI()
{
	return pNextBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its next generation values from the most recently finished APP iteration

double *Network::getPowPrevGUROBI()
{
	if (intervalID==0) {
		vector< Generator >::iterator generatorIterator; // Iterator for generators	
		for ( generatorIterator = genObject.begin(); generatorIterator != genObject.end(); generatorIterator++ ) { // iterate on the set of generators
			int bufferIndex = generatorIterator->getGenID() - 1; // Position defined by the generator ID
			pPrevBufferGUROBI[ bufferIndex ] = generatorIterator->genPowerPrev(); // Store the most recent generation MW belief in the array
		}
		return pPrevBufferGUROBI;
	}
	else
		return pPrevBufferGUROBI;
} // returns the values of what this particular coarse grain thinks about its previous generation values from the most recently finished APP iteration
"""
