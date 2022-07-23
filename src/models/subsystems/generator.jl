module Generator
#functions for Generator module
using Node
mutable struct Generator(object)
	# constructor begins
	def __init__(self, idOfGen, interval, lastFlag, contScenarioCount, PCScenarioCount, baseCont, dummyZero, accuracy, nodeConng, 
                 	**paramOfGenFirstBase, **paramOfGenDZBase, **paramOfGenFirst, 
			**paramOfGenSecondBase, **paramOfGenFirstCont, **paramOfGenDZCont, 
			**paramOfGenSecondCont, **paramOfGenCont, countOfContingency, genTotal):
		self.genID = idOfGen
		self.numberOfGenerators = genTotal
		self.dispatchInterval = interval
		self.flagLast = lastFlag
		self.dummyZeroIntFlag = dummyZero
		self.contSolverAccuracy = accuracy
		self.scenarioContCount = contScenarioCount
		self.postContScenCount = PCScenarioCount
		self.baseContScenario = baseCont
		self.connNodegPtr = nodeConng
		self.genSolverFirstBase = paramOfGenFirstBase
		self.genSolverDZBase = paramOfGenDZBase
		self.genSolverFirst = paramOfGenFirst
		self.genSolverSecondBase = paramOfGenSecondBase
		self.genSolverDZCont = paramOfGenDZCont
		self.genSolverFirstCont = paramOfGenFirstCont
		self.genSolverSecondCont = paramOfGenSecondCont
		self.genSolverCont = paramOfGenCont
		self.contCountGen = countOfContingency
		"""For testingprint("Initializing the parameters of the generator with ID: " << genID )
		"""
		self.connNodegPtr.setgConn(idOfGen) # increments the generation connection variable to node
		self.PgenPrev = genSolverFirstBase.getPgPrev()
		self.setGenData() # calls setGenData member function to set the parameter values

function getGenID() # function getGenID begins
	return genID # returns the ID of the generator object
end
	   
function getGenNodeID() # function getGenNodeID begins
	return getNodeID() # returns the ID number of the node to which the generator object is connected
end

function setGenData() # start setGenData function
	Pg = 0.0 # Initialize power iterate
	PgenNextPtr = NULL
	Thetag = 0.0 # Initialize angle iterate
	v = 0.0 # Initialize the Lagrange multiplier corresponding voltage angle constraint to zero
end

function gpowerangleMessage(outerAPPIt, APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, 
                           	PgenPrevAPP, PgenAPP, PgenAPPInner, PgenNextAPP, AAPPExternal, BAPPExternal, 
				DAPPExternal, LambAPP1External, LambAPP2External, LambAPP3External, 
				LambAPP4External, BAPP, LambAPP1)
		BAPPNew = zeros(Float64, contCountGen)
		LambdaAPPNew = zeros(Float64, contCountGen)
		BAPPExtNew = zeros(Float64, contCountGen+1)
		DAPPExtNew = zeros(Float64, contCountGen+1)
		LambdaAPP1ExtNew = zeros(Float64, contCountGen+1)
		LambdaAPP2ExtNew = zeros(Float64, contCountGen+1)
		PgNextAPPNew = zeros(Float64, contCountGen+1)
		if baseContScenario == 0 # Use the solver for base cases
			if dummyZeroIntFlag == 1 # If dummy zero interval is considered
				if (dispatchInterval== 0) and (flagLast == 0): # For the dummy zeroth interval
					for counterCont in 1:contCountGen
						BAPPNew[counterCont] = BAPP[counterCont*numberOfGenerators+(genID-1)]
						LambdaAPPNew[counterCont] = LambAPP1[counterCont*numberOfGenerators+(genID-1)]
					BAPPExtNew = BAPPExternal 
					LambdaAPP1ExtNew = LambAPP1External
					DAPPExtNew = DAPPExternal
					LambdaAPP2ExtNew = LambAPP2External
					PgNextAPPNew = PgenNextAPP[(genID-1)]
					try:# calls the Generator optimization solver
						julSol.genSolverFirstBase(LambAPP1ExtNew[0], LambAPP2ExtNew[0], BAPPExtNew[0], 
									DAPPExtNew[0], **genKwarg)
    lambda_1, lambda_2, # APP Lagrange Multiplier corresponding to the complementary slackness for across the dispatch intervals
    B, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration 
    D;  # Disagreement between the generator output values for the next interval by the present and the next interval, at the previous iteration
    ContCount=1,  #Number of contingency scenarios
    rho=1, # ADMM tuning parameter
    beta=1, # APP tuning parameter for across the dispatch intervals
    betaInner=1, # APP tuning parameter for across the dispatch intervals
    gamma=1, # APP tuning parameter for across the dispatch intervals
    gammaSC=1, # APP tuning parameter
    lambda_1SC::Array, # APP Lagrange Multiplier corresponding to the complementary slackness
    RgMax=100, RgMin=-100, # Generator maximum ramp up and ramp down limits
    PgMax=100, PgMin=0, # Generator Limits
    c2=1, c1=1, c0=1, # Generator cost coefficients, quadratic, liear and constant terms respectively
    Pg_N_init=0, # Generator injection from last iteration for base case and contingencies
    Pg_N_avg=0, # Net average power from last iteration for base case and contingencies
    Thetag_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N=0, # Dual variable for net power balance for base case and contingencies
    vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu=0, PgNuInner=0, PgNextNu=0, # Previous iterates of the corresponding decision variable values
    PgPrev=0, # Generator's output in the previous interval
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    solChoice=1, #Choice of the solver
					self.Pg = genSolverFirstBase.getPSol() #get the Generator Power iterate
					self.PgenNext = genSolverFirstBase.getPNextSol()
					self.PgenPrev = genSolverFirstBase.getPgPrev()
				self.Thetag = *(genSolverFirstBase.getThetaPtr())
			}
			if (dispatchInterval!=0) and (flagLast==0): # For the first interval
			   for counterCont in range(contCountGen):
			      BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)] 
			      LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)]
		       for counterCont in range(contCountGen+1):
			      BAPPExtNew[counterCont]=BAPPExternal[counterCont] 
			      LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont]
			      DAPPExtNew[counterCont]=DAPPExternal[counterCont] 
		          LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont]
			      PgNextAPPNew[counterCont]=PgenNextAPP[counterCont]
				genSolverDZBase.mainsolve( outerAPPIt, APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, PgenPrevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, BAPPNew, LambdaAPPNew ) #calls the Generator optimization solver
				Pg = genSolverDZBase.getPSol() #get the Generator Power iterate
				PgenNextPtr = genSolverDZBase.getPNextSol()
				PgenPrev = genSolverDZBase.getPPrevSol()
				Thetag = *(genSolverDZBase.getThetaPtr())
			}
			if ((dispatchInterval!=0) && (flagLast==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < contCountGen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgenPrevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				PgenNext = genSolverSecondBase.getPNextSol();
				PgenPrev = genSolverSecondBase.getPPrevSol();
				Thetag = *(genSolverSecondBase.getThetaPtr());
			}
		}
		if ( dummyZeroIntFlag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval!=0) && (flagLast==0)) { // For the first interval
				for (int counterCont = 0; counterCont < contCountGen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				for (int counterCont = 0; counterCont <= contCountGen; ++counterCont) {
					BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
					DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
				}
				genSolverFirst.mainsolve( outerAPPIt, APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverFirst.getPSol(); // get the Generator Power iterate
				PgenNextPtr = genSolverFirst.getPNextSol();
				PgenPrev = genSolverFirst.getPgPrev();
				Thetag = *(genSolverFirst.getThetaPtr());
			}
			if ((dispatchInterval!=0) && (flagLast==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < contCountGen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgenPrevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				PgenNext = genSolverSecondBase.getPNextSol();
				PgenPrev = genSolverSecondBase.getPPrevSol();
				Thetag = *(genSolverSecondBase.getThetaPtr());
			}
		}
	}
	else { // If a contingency scenario
		if ( dummyZeroIntFlag == 1 ) { // If dummy zero interval is considered
			if ((dispatchInterval==0) && (flagLast==0)) { // For the dummy zeroth interval
				genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				Thetag = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
			}
			if ((dispatchInterval!=0) && (flagLast==0)) { // For the first interval
				if (contSolverAccuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
				if (contSolverAccuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= contCountGen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont];
						PgNextAPPNew[counterCont]=PgenNextAPP[counterCont];
					}
					genSolverDZCont.mainsolve( gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, PgenPrevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverDZCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverDZCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flagLast==1)) { // For the second (or, in this case, the last) interval
				if (contSolverAccuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
				if (contSolverAccuracy != 0) {// If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal);
					DAPPExtNew[0]=*DAPPExternal;
					genSolverSecondCont.mainsolve( gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgenPrevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverSecondCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
			}
		}
		if ( dummyZeroIntFlag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval==0) && (flagLast==0)) { // For the dummy zeroth interval **/ Will not be used in this case**/
				genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				Thetag = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
			}
			if ((dispatchInterval!=0) && (flagLast==0)) { // For the first interval
				if (contSolverAccuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
				if (contSolverAccuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= contCountGen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
					}
					genSolverFirstCont.mainsolve( gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverFirstCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverFirstCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flagLast==1)) { // For the second (or, in this case, the last) interval
				if (contSolverAccuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(Thetag+i) << endl;
				}
				if self.contSolverAccuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal)
					DAPPExtNew[0]=*DAPPExternal
					genSolverSecondCont.mainsolve( gsRho, Pgenprev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgenPrevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenarioContCount-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenarioContCount-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					Thetag = *(genSolverSecondCont.getThetaPtr());
					#log.info("\nThiterate from generator: " << *(Thetag+i) << endl;
				}
			}
		}			
	}
	self.connNodegPtr.powerangleMessage(self.Pg, self.v, self.Thetag ) #passes to node object the corresponding iterates of power, angle, v, and number of scenarios
	#function gpowerangleMessage ends

	def genPower(self): #function genPower begins
		return self.Pg #returns the Pg iterate
	#function genPower ends

	def genPowerPrev(self): #function genPower begins
		if self.dispatchInterval==0:
			return genSolverFirstBase.getPgPrev() #returns the Pg iterate
		else:
			return self.PgenPrev
	#function genPower ends

	def genPowerNext(self, nextScen): #const // function genPower begins
		if self.flagLast==1:
			return self.Pg #returns the Pg iterate
		elif self.dispatchInterval!=0 and self.flagLast==0:
			return self.PgenNextPtr[nextScen]
		else:
			return self.PgenNext
	#function genPower ends

	def objectiveGen(self): #function objectiveGen begins
		if self.baseContScenario == 0: #Use the solver for base cases
			if self.dummyZeroIntFlag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flagLast==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==0: #For the first interval
					return genSolverDZBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
			elif self.dummyZeroIntFlag == 0: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flagLast==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==0: #For the first interval
					return genSolverFirst.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
		elif self.baseContScenario != 0:
			if self.dummyZeroIntFlag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flagLast==0: #For the dummy zeroth interval
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==0: #For the first interval
					if self.contSolverAccuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.contSolverAccuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverDZCont.getObj()
				elif self.dispatchInterval!=0 and self.flagLast==1: #For the second (or, in this case, the last) interval
					if self.contSolverAccuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.contSolverAccuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
			elif self.dummyZeroIntFlag == 0: #If dummy zero interval is not considered
				if self.dispatchInterval==0 and self.flagLast==0: #For the dummy zeroth interval **/ Will not be used in this case**/
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flagLast==0: #For the first interval
					if self.contSolverAccuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.contSolverAccuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverFirstCont.getObj()
				elif self.dispatchInterval!=0 and self.flagLast==1: #For the second (or, in this case, the last) interval
					if self.contSolverAccuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					if self.contSolverAccuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
	#function objectiveGen ends

	def objectiveGenGUROBI(self): #Objective from GUROBI ADMM
		return self.objOpt #returns the evaluated objective
	#function objectiveGen ends

	def calcPtilde(self): #function calcPtilde begins
		P_avg = self.connNodegPtr.PavMessage() #Gets average power from the corresponding node object
		Ptilde = self.Pg - P_avg #calculates the difference between power iterate and average
		return Ptilde #returns the difference
	#function calcPtilde ends

	def calcPavInit(self): #function calcPavInit begins
		return self.connNodegPtr.devpinitMessage() #seeks the initial Ptilde from the node
	#function calcPavInit ends

	def getu(self): #function getu begins
		u = self.connNodegPtr.uMessage() #gets the value of the price corresponding to power balance from node
		#log.info("u: {}".format(u))
		return u #returns the price
	#function getu ends

	def calcThetatilde(self): #function calcThetatilde begins
		#log.info("Thetag: {}".format(Thetag))
		Theta_avg = self.connNodegPtr.ThetaavMessage() #get the average voltage angle at the particular node
		#log.info("Theta_avg: ".format(Theta_avg))
		Theta_tilde = self.Thetag - Theta_avg #claculate the deviation between the voltage angle of the device and the average
		return Theta_tilde #return the deviation
	#function calcThetatilde ends

	def calcvtilde(self): #function calcvtilde begins
		v_avg = self.connNodegPtr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
		#log.info("v_avg: {}".format(v_avg))
		v_tilde = self.v - v_avg #calculate the deviation of the node Lagrange multiplier to the average
		return v_tilde #return the deviation
	#function calcvtilde ends

	def getv(self): #function getv begins
		#log.info("v_initial: {}".format(v))
		self.v += self.calcThetatilde() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
		#log.info("v_final: {}".format(v))
		return self.v #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#function getv ends		
double Generator::getPMax(){return genSolverFirstBase.getPMax();}
double Generator::getPMin(){return genSolverFirstBase.getPMin();}
double Generator::getQuadCoeff(){return genSolverFirstBase.getQuadCoeff();}
double Generator::getLinCoeff(){return genSolverFirstBase.getLinCoeff();}
double Generator::getConstCoeff(){return genSolverFirstBase.getConstCoeff();}
double Generator::getPgenPrev(){return genSolverFirstBase.getPgPrev();}
double Generator::getPgenNext(){return genSolverFirstBase.getPNextSol();}
double Generator::getRMax(){return genSolverFirstBase.getRMax();}
double Generator::getRMin(){return genSolverFirstBase.getRMin();}
