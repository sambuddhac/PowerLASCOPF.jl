#!/usr/bin/env python3
# Member functions for class Network
# include definitions for classes generator, load, transmission line, network and node
from Python_src.generator import Generator
from Python_src.tranline import transmissionLine
from Python_src.load import Load
from Python_src.node import Node

profiler = Profiler()

if sys.platform in ["darwin", "linux"]:
	log.info("Using Julia executable in {}".format(str(subprocess.check_output(["which", "julia"]), 'utf-8').strip('\n')))
elif sys.platform in ["win32", "win64", "cygwin"]:
	log.info("Using Julia executable in {}".format(str(subprocess.check_output(["which", "julia"]), 'utf-8').strip('\n')))

log.info("\nLoading Julia...")
profiler.start()
julSol = julia.Julia()
julSol.using("Pkg")
julSol.eval('Pkg.activate(".")')
julSol.include(os.path.join("JuMP_src", "LASCOPFSolCentralized.jl")) # definition of Gensolver class for base case scenario first interval
log.info(("\nJulia took {:..2f} seconds to start and include LASCOPF models.".format(profiler.get_interval())))


class Network(object):
	MAX_ITER = 80002
	#LINE_CAP = 100.00
	def __init__(self, val, postContScen, scenarioContingency, lineOutaged, prePostScenario, solverChoice, dummy, accuracy, intervalNum, lasIntFlag, nextChoice, outagedLine):
		self.networkID = val #constructor begins; initialize networkID  and Rho through constructor initializer list
		self.Rho = 1.0
		self.scenarioIndex = scenarioContingency #this is always zero for a base-case network instance, even if that corresponds to an outaged base case, or in other words, if postContScen is not zero
		self.postContScenario = postContScen
		self.prePostContScen = prePostScenario
		self.dummyZ = dummy
		self.Accuracy = accuracy
		self.OutagedLine = lineOutaged
		self.contingencyCount = 0
		self.intervalID = intervalNum
		self.lastFlag = lasIntFlag
		self.baseOutagedLine = outagedLine
		self.solverChoice = solverChoice
		#Initializes the number and fields of Transmission lines, Generators, Loads, Nodes, and Device Terminals.
		self.translNumber = 0
		self.translFields = 0
		self.genNumber = 0
		self.genFields = 0
		self.loadNumber = 0
		self.loadFields = 0
		self.deviceTermCount = 0
		self.nodeNumber = 0
		self.assignedNodeSer = 0
		self.divConvMWPU = 100.0 # Divisor, which is set to 100 for all other systems, except two bus system, for which it is set to 1
		self.outagedLine = []
		self.connNodeNumList = []
		self.nodeValList = []
		setNetworkVariables(self.networkID, nextChoice) #sets the variables of the networkID
		# end constructor

	def __del__(self): # destructor
		log.info("\nNetwork instance: {} for this simulation destroyed. You can now open the output files to view the results of the simulation".format(networkID))
		# end destructor
	def getGenNumber(self):
		return self.genNumber #returns the number of Generators in the network
	def retContCount(self):
		return self.contingencyCount #returns the number of contingency scenarios

	def indexOfLineOut(self, contScen):
		return self.outagedLine[contScen-1] #returns the serial number of the outaged line

	def setNetworkVariables(self, networkID, nextChoice): #Function setNetworkVariables starts to initialize the parameters and variables
		Verbose = False #disable intermediate result display. If you want, make it "true"

		self.nodeNumber = networkID #set the number of nodes of the network

		if  self.nodeNumber == 14: # 14 Bus case	
			self.genFile = open(os.path.join("data", "Gen14.json"))		
			self.tranFile = open(os.path.join("data", "Tran14.json"))
			self.loadFile = open(os.path.join("data", "Load14.json"))
		elif  self.nodeNumber == 30: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen30.json"))
			self.tranFile = open(os.path.join("data", "Tran30.json"))
			self.loadFile = open(os.path.join("data", "Load30.json"))
		elif  self.nodeNumber == 57: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen57.json"))
			self.tranFile = open(os.path.join("data", "Tran57.json"))
			self.loadFile = open(os.path.join("data", "Load57.json"))
		elif  self.nodeNumber == 118: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen118.json"))
			self.tranFile = open(os.path.join("data", "Tran118.json"))
			self.loadFile = open(os.path.join("data", "Load118.json"))
		elif  self.nodeNumber == 300: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen300.json"))
			self.tranFile = open(os.path.join("data", "Tran300.json"))
			self.loadFile = open(os.path.join("data", "Load300.json"))
		elif  self.nodeNumber == 3: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen3A.json"))
			self.tranFile = open(os.path.join("data", "Tran3A.json"))
			self.loadFile = open(os.path.join("data", "Load3A.json"))
		elif  self.nodeNumber == 5: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen5.json"))
			self.tranFile = open(os.path.join("data", "Tran5.json"))
			self.loadFile = open(os.path.join("data", "Load5.json"))
		elif  self.nodeNumber == 2: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen2.json"))
			self.tranFile = open(os.path.join("data", "Tran2.json"))
			self.loadFile = open(os.path.join("data", "Load2.json"))
		elif  self.nodeNumber == 48: # 30 Bus case
			self.genFile = open(os.path.join("data", "Gen48.json"))
			self.tranFile = open(os.path.join("data", "Tran48.json"))
			self.loadFile = open(os.path.join("data", "Load48.json"))
			
		else: # catch all other entries
			log.info("\nSorry, invalid case. Can't do simulation at this moment.")
			#exit switch
		if self.nodeNumber == 2:
			self.divConvMWPU = 1.0

		# Transmission Lines
		matrixFirstFile = json.load(tranFile) #opens the file of Transmission line
		matrixTranList = []
		#Transmission line matrix
		#read the Transmission line matrix
		for item in matrixFirstFile:
			matrixTran = {"fromNode": None, "toNode": None, "Resistance": None, "Reactance": None, "ContingencyMarked": None, "Capacity": None}
			matrixTran['fromNode'] = item['fromNode']
			matrixTran['toNode'] = item['toNode']
			matrixTran['Resistance'] = item['Resistance']
			matrixTran['Reactance'] = item['Reactance']
			matrixTran['ContingencyMarked'] = item['ContingencyMarked']
			matrixTran['Capacity'] = item['Capacity']
			matrixTranList.append(matrixTran)

		#Count the total number of contingency scenarios
		for item in matrixFirstFile:
			self.contingencyCount += item['ContingencyMarked'] #count the number of contingency scenarios
		  
		if self.prePostContScen == 0:
			for index in range(len(matrixTranList)):
				if matrixTranList[index]['ContingencyMarked'] == 1:
					self.outagedLine.append(index + 1)

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
	def runSimulation(self, outerIter, LambdaOuter, powDiffOuter, setRhoTuning, countOfAPPIter, appLambda, diffOfPow, powSelfBel, powNextBel, powPrevBel, lambdaLine, powerDiffLine, powSelfFlowBel, powNextFlowBel): #Function runSimulation begins
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
		W, Wprev #Present and previous values of W for the PID controller for modifying Rho
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
				pSelfBeleifInner[i] = *(getPowSelf()+i) #Belief about the generator MW output of the generators in this dispatch interval from the previous APP iteration powSelfBel[intervalID*genNumber+i]
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
	
		if Verbose:
			matrixResultOut << "\nThe initial value of primal tolerance to kick-start iterations is: " << primalTol << "\nThe initial value of dual tolerance to kick-start iterations is: " << dualTol << endl

		#int first = 0
		genActualTime = 0
		genADMMMaxTimeVec.clear()
		#Starting of the ADMM Based Proximal Message Passing Algorithm Iterations
		#for iteration_count in range(1:MAX_ITER-1):
		while( ( ( primalTol >= 0.06 ) or ( dualTol >= 0.6 ) ) and (iteration_count < MAX_ITER) ): #( iteration_count <= 122 )
	
			if Verbose:
				matrixResultOut << "\nThe value of primal tolerance before this iteration is: " << primalTol << "\nThe value of dual tolerance before this iteration is: " << dualTol << endl;
				matrixResultOut << "\n**********Start of " << iteration_count << " -th iteration***********\n"
			#Recording data for plotting graphs
		
			iterationGraph.append(iteration_count) #stores the iteration count to be graphed
			primTolGraph.append(primalTol) #stores the primal tolerance value to be graphed
			PrimTolGraph.append(PrimalTol)
			dualTolGraph.append(dualTol) #stores the dual tolerance value to be graphed
			#Initialize the average node angle imbalance price (v) vector from last to last interation, V_avg
			"""
			if iteration_count <= 2:
				for i in range(self.nodeNumber):
					V_avg[ i ] = 0.0 #initialize to zero for the first and second iterations if the initial values are zero
			else:
				for j in range(self.nodeNumber):
					V_avg[ j ] = vBuffer1[ j ] #initialize to the average node v from last to last iteration for 3rd iteration on		
			"""
			#Initialize average v, average theta, ptilde, average P before the start of a particular iteration
			if iteration_count >= 2:
				angleBuffer1[ 0 ] = 0.0 #set the first node as the slack node, the average voltage angle is always zero
				for i in range(self.nodeNumber):
					#vBuffer1[ i ] = vBuffer2[ i ]#Save to vBuffer1, the average v from last iteration for use in next iteration
					angleBuffer1[ i ] = angleBuffer[ i ] #Save to angleBuffer1, the average node voltage angle from last iteration

				for j in range(self.deviceTermCount):
					powerBuffer1[ j ] = powerBuffer[ j ] #Save to powerBuffer1, the Ptilde for each device term. from last itern		
			else:
				Wprev = 0.0 #for the first iteration
				for i in range(self.nodeNumber):			
					angleBuffer1[ i ] = 0.0 #Set average node voltage angle to zero for 1st iteration

				for nodeIterator in self.nodeObject:
					bufferIndex = nodeIterator.getNodeID() - 1
					pavBuffer[ bufferIndex ] = nodeIterator.devpinitMessage() #Average node power injection before 1st iteration
				for j in range(self.deviceTermCount):
					powerBuffer1[ j ] = ptildeinitBuffer[ j ] #Save to powerBuffer1, the Ptilde before the 1st iteration
			genSingleTimeVec.clear();
			#vector< Generator >::const_iterator generatorIterator; // Distributed Optimizations; Generators' Opt. Problems
			calcObjective = 0.0 #initialize the total generator cost for this iteration
			for generatorIterator in self.genObject:
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

	def returnVirtualExecTime(self):
		return self.virtualExecTime

	def runSimAPPGurobiBase(self, outerIter, LambdaOuter, powDiffOuter, countOfAPPIter, appLambda, diffOfPow, powSelfBel, powNextBel, powPrevBel): #runs the APP coarse grain Gurobi OPF for base case


	def runSimAPPGurobiCont(self, outerIter, LambdaOuter, powDiffOuter, countOfAPPIter, appLambda, diffOfPow): #runs the APP coarse grain Gurobi OPF for contingency scenarios	


	def runSimulationCentral(self, outerIter, LambdaOuter, powDiffOuter, powSelfBel, powNextBel, powPrevBel):

	def getPowSelf(self):
		for generatorIterator in self.genObject: #iterate on the set of generators
			bufferIndex = generatorIterator.getGenID() - 1 #Position defined by the generator ID
			self.pSelfBuffer[ bufferIndex ] = generatorIterator.genPower() #Store the most recent generation MW belief in the array
		return self.pSelfBuffer
	#returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

	def getPowPrev(self):
		for generatorIterator in self.genObject: #iterate on the set of generators
			bufferIndex = generatorIterator.getGenID() - 1 #Position defined by the generator ID
			self.pPrevBuffer[ bufferIndex ] = generatorIterator.genPowerPrev() #Store the most recent generation MW belief in the array
		return self.pPrevBuffer
	#returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

	def getPowNext(self, nextScen):	
		for generatorIterator in self.genObject: #iterate on the set of generators
			bufferIndex = self.generatorIterator.getGenID() - 1 #Position defined by the generator ID
			self.pNextBuffer[ bufferIndex ] = generatorIterator.genPowerNext(nextScen) #Store the most recent generation MW belief in the array
		return self.pNextBuffer
	#returns the values of what this particular coarse grain thinks about its own generation values from the most recently finished APP iteration

	def getPowFlowNext(self, continCounter, supernetCount, rndInterCount, lineCount):

	def getPowFlowSelf(self, lineCount):
