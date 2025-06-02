@kwdef mutable struct PowerGenerator{T<:Union{ThermalGen,RenewableGen,HydroGen},U<:GenIntervals}<:Generator
	gen_id::Int64
	number_of_generators::Int64
	dispatch_interval::Int64
	flag_last::Bool
	dummy_zero_int_flag::Int64
	cont_solver_accuracy::Int64
	scenario_cont_count::Int64
	post_cont_scen_count::Int64
	base_cont_scenario::Int64
	conn_nodeg_ptr::Node
	gen_solver::GenSolver{T,U}
	cont_count_gen::Int64
	gen_total::Int64
	P_gen_prev::Float64
	Pg::Float64
	P_gen_next::Float64
	theta_g::Float64
	v::Float64

	# constructor begins
	function PowerGenerator(id_of_gen::Int64, interval::Int64, last_flag::Bool, cont_scenario_count::Int64, gensolver::GenSolver{T,U}, 
		idOfGen::Int64, PC_scenario_count::Int64, baseCont::Int64, dummyZero::Int64, accuracy::Int64, nodeConng::Node, 
		countOfContingency::Int64, gen_total::Int64,
		PC_scenario_count::Int64, baseCont, dummyZero, accuracy, nodeConng, countOfContingency, gen_total) where T<:Union{ThermalGen,RenewableGen,HydroGen}, U<:GenIntervals
		self = new()
		self.gen_id = id_of_gen
		self.number_of_generators = gen_total
		self.dispatch_interval = interval
		self.flag_last = last_flag
		self.dummy_zero_int_flag = dummyZero
		self.cont_solver_accuracy = accuracy
		self.scenario_cont_count = cont_scenario_count
		self.post_cont_scen_count = PC_scenario_count
		self.base_cont_scenario = baseCont
		self.conn_nodeg_ptr = nodeConng
		self.cont_count_gen = countOfContingency
		self.gen_solver = gensolver
		self.conn_nodeg_ptr.setgConn(idOfGen) # increments the generation connection variable to node
		self.P_gen_prev = genSolverFirstBase.getPgPrev()
		self.setGenData() # calls setGenData member function to set the parameter values
		return self
	end # constructor ends
end # struct PowerGenerator ends

function getGenID() # function getGenID begins
	return genID # returns the ID of the generator object
end
	   
function getGenNodeID() # function getGenNodeID begins
	return getNodeID() # returns the ID number of the node to which the generator object is connected
end

function setGenData() # start setGenData function
	Pg = 0.0 # Initialize power iterate
	P_gen_nextPtr = NULL
	theta_g = 0.0 # Initialize angle iterate
	v = 0.0 # Initialize the Lagrange multiplier corresponding voltage angle constraint to zero
end

function gpowerangleMessage(outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, 
                           	P_gen_prevAPP, PgenAPP, PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal, 
				DAPPExternal, LambAPP1External, LambAPP2External, LambAPP3External, 
				LambAPP4External, BAPP, LambAPP1)
		BAPPNew = zeros(Float64, cont_count_gen)
		LambdaAPPNew = zeros(Float64, cont_count_gen)
		BAPPExtNew = zeros(Float64, cont_count_gen+1)
		DAPPExtNew = zeros(Float64, cont_count_gen+1)
		LambdaAPP1ExtNew = zeros(Float64, cont_count_gen+1)
		LambdaAPP2ExtNew = zeros(Float64, cont_count_gen+1)
		PgNextAPPNew = zeros(Float64, cont_count_gen+1)
		if base_cont_scenario == 0 # Use the solver for base cases
			if dummy_zero_int_flag == 1 # If dummy zero interval is considered
				if (dispatchInterval== 0) and (flag_last == 0): # For the dummy zeroth interval
					for counterCont in 1:cont_count_gen
						BAPPNew[counterCont] = BAPP[counterCont*numberOfGenerators+(genID-1)]
						LambdaAPPNew[counterCont] = LambAPP1[counterCont*numberOfGenerators+(genID-1)]
					BAPPExtNew = BAPPExternal 
					LambdaAPP1ExtNew = LambAPP1External
					DAPPExtNew = DAPPExternal
					LambdaAPP2ExtNew = LambAPP2External
					PgNextAPPNew = P_gen_nextAPP[(genID-1)]
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
    theta_g_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    ug_N=0, # Dual variable for net power balance for base case and contingencies
    vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    PgNu=0, PgNuInner=0, PgNextNu=0, # Previous iterates of the corresponding decision variable values
    PgPrev=0, # Generator's output in the previous interval
    BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    solChoice=1, #Choice of the solver
					self.Pg = genSolverFirstBase.getPSol() #get the Generator Power iterate
					self.P_gen_next = genSolverFirstBase.getPNextSol()
					self.P_gen_prev = genSolverFirstBase.getPgPrev()
				self.theta_g = *(genSolverFirstBase.getThetaPtr())
			}
			if (dispatchInterval!=0) and (flag_last==0): # For the first interval
			   for counterCont in range(cont_count_gen):
			      BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)] 
			      LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)]
		       for counterCont in range(cont_count_gen+1):
			      BAPPExtNew[counterCont]=BAPPExternal[counterCont] 
			      LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont]
			      DAPPExtNew[counterCont]=DAPPExternal[counterCont] 
		          LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont]
			      PgNextAPPNew[counterCont]=P_gen_nextAPP[counterCont]
				genSolverDZBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, P_gen_prevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, BAPPNew, LambdaAPPNew ) #calls the Generator optimization solver
				Pg = genSolverDZBase.getPSol() #get the Generator Power iterate
				P_gen_nextPtr = genSolverDZBase.getPNextSol()
				P_gen_prev = genSolverDZBase.getPPrevSol()
				theta_g = *(genSolverDZBase.getThetaPtr())
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				P_gen_next = genSolverSecondBase.getPNextSol();
				P_gen_prev = genSolverSecondBase.getPPrevSol();
				theta_g = *(genSolverSecondBase.getThetaPtr());
			}
		}
		if ( dummy_zero_int_flag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
					BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
					DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
				}
				genSolverFirst.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverFirst.getPSol(); // get the Generator Power iterate
				P_gen_nextPtr = genSolverFirst.getPNextSol();
				P_gen_prev = genSolverFirst.getPgPrev();
				theta_g = *(genSolverFirst.getThetaPtr());
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				P_gen_next = genSolverSecondBase.getPNextSol();
				P_gen_prev = genSolverSecondBase.getPPrevSol();
				theta_g = *(genSolverSecondBase.getThetaPtr());
			}
		}
	}
	else { // If a contingency scenario
		if ( dummy_zero_int_flag == 1 ) { // If dummy zero interval is considered
			if ((dispatchInterval==0) && (flag_last==0)) { // For the dummy zeroth interval
				genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				theta_g = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
			}
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont];
						PgNextAPPNew[counterCont]=P_gen_nextAPP[counterCont];
					}
					genSolverDZCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, P_gen_prevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverDZCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverDZCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal);
					DAPPExtNew[0]=*DAPPExternal;
					genSolverSecondCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverSecondCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
		}
		if ( dummy_zero_int_flag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval==0) && (flag_last==0)) { // For the dummy zeroth interval **/ Will not be used in this case**/
				genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				theta_g = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
			}
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
					}
					genSolverFirstCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverFirstCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverFirstCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal)
					DAPPExtNew[0]=*DAPPExternal
					genSolverSecondCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverSecondCont.getThetaPtr());
					#log.info("\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
		}			
	}
	self.conn_nodeg_ptr.powerangleMessage(self.Pg, self.v, self.theta_g ) #passes to node object the corresponding iterates of power, angle, v, and number of scenarios
	#function gpowerangleMessage ends

	def genPower(self): #function genPower begins
		return self.Pg #returns the Pg iterate
	#function genPower ends

	def genPowerPrev(self): #function genPower begins
		if self.dispatchInterval==0:
			return genSolverFirstBase.getPgPrev() #returns the Pg iterate
		else:
			return self.P_gen_prev
	#function genPower ends

	def genPowerNext(self, nextScen): #const // function genPower begins
		if self.flag_last==1:
			return self.Pg #returns the Pg iterate
		elif self.dispatchInterval!=0 and self.flag_last==0:
			return self.P_gen_nextPtr[nextScen]
		else:
			return self.P_gen_next
	#function genPower ends

	def objectiveGen(self): #function objectiveGen begins
		if self.base_cont_scenario == 0: #Use the solver for base cases
			if self.dummy_zero_int_flag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					return genSolverDZBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
			elif self.dummy_zero_int_flag == 0: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					return genSolverFirst.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
		elif self.base_cont_scenario != 0:
			if self.dummy_zero_int_flag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverDZCont.getObj()
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
			elif self.dummy_zero_int_flag == 0: #If dummy zero interval is not considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval **/ Will not be used in this case**/
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverFirstCont.getObj()
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					if self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
	#function objectiveGen ends

	def objectiveGenGUROBI(self): #Objective from GUROBI ADMM
		return self.objOpt #returns the evaluated objective
	#function objectiveGen ends

	def calcPtilde(self): #function calcPtilde begins
		P_avg = self.conn_nodeg_ptr.PavMessage() #Gets average power from the corresponding node object
		Ptilde = self.Pg - P_avg #calculates the difference between power iterate and average
		return Ptilde #returns the difference
	#function calcPtilde ends

	def calcPavInit(self): #function calcPavInit begins
		return self.conn_nodeg_ptr.devpinitMessage() #seeks the initial Ptilde from the node
	#function calcPavInit ends

	def getu(self): #function getu begins
		u = self.conn_nodeg_ptr.uMessage() #gets the value of the price corresponding to power balance from node
		#log.info("u: {}".format(u))
		return u #returns the price
	#function getu ends

	def calcThetatilde(self): #function calcThetatilde begins
		#log.info("theta_g: {}".format(theta_g))
		Theta_avg = self.conn_nodeg_ptr.ThetaavMessage() #get the average voltage angle at the particular node
		#log.info("Theta_avg: ".format(Theta_avg))
		Theta_tilde = self.theta_g - Theta_avg #claculate the deviation between the voltage angle of the device and the average
		return Theta_tilde #return the deviation
	#function calcThetatilde ends

	def calcvtilde(self): #function calcvtilde begins
		v_avg = self.conn_nodeg_ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
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
double Generator::getP_gen_prev(){return genSolverFirstBase.getPgPrev();}
double Generator::getP_gen_next(){return genSolverFirstBase.getPNextSol();}
double Generator::getRMax(){return genSolverFirstBase.getRMax();}
double Generator::getRMin(){return genSolverFirstBase.getRMin();}

mutable struct Generator
	gen_id::Int64
	number_of_generators::Int64
	dispatch_interval::Int64
	self.flag_last = lastFlag
	self.dummy_zero_int_flag = dummyZero
	self.cont_solver_accuracy = accuracy
	self.scenario_cont_count = contScenarioCount
	self.post_cont_scen_count = PCScenarioCount
	self.base_cont_scenario = baseCont
	self.conn_nodeg_ptr = nodeConng
	self.genSolverFirstBase = paramOfGenFirstBase
	self.genSolverDZBase = paramOfGenDZBase
	self.genSolverFirst = paramOfGenFirst
	self.genSolverSecondBase = paramOfGenSecondBase
	self.genSolverDZCont = paramOfGenDZCont
	self.genSolverFirstCont = paramOfGenFirstCont
	self.genSolverSecondCont = paramOfGenSecondCont
	self.genSolverCont = paramOfGenCont
	self.cont_count_gen = countOfContingency
	# constructor begins
	function __init__(self, idOfGen, interval, lastFlag, contScenarioCount, PCScenarioCount, baseCont, dummyZero, accuracy, nodeConng, 
                 	**paramOfGenFirstBase, **paramOfGenDZBase, **paramOfGenFirst, 
			**paramOfGenSecondBase, **paramOfGenFirstCont, **paramOfGenDZCont, 
			**paramOfGenSecondCont, **paramOfGenCont, countOfContingency, gen_total):
		self.genID = idOfGen
		self.numberOfGenerators = gen_total
		self.dispatchInterval = interval
		self.flag_last = lastFlag
		self.dummy_zero_int_flag = dummyZero
		self.cont_solver_accuracy = accuracy
		self.scenario_cont_count = contScenarioCount
		self.post_cont_scen_count = PCScenarioCount
		self.base_cont_scenario = baseCont
		self.conn_nodeg_ptr = nodeConng
		self.genSolverFirstBase = paramOfGenFirstBase
		self.genSolverDZBase = paramOfGenDZBase
		self.genSolverFirst = paramOfGenFirst
		self.genSolverSecondBase = paramOfGenSecondBase
		self.genSolverDZCont = paramOfGenDZCont
		self.genSolverFirstCont = paramOfGenFirstCont
		self.genSolverSecondCont = paramOfGenSecondCont
		self.genSolverCont = paramOfGenCont
		self.cont_count_gen = countOfContingency
		"""For testingprint("Initializing the parameters of the generator with ID: " << genID )
		"""
		self.conn_nodeg_ptr.setgConn(idOfGen) # increments the generation connection variable to node
		self.P_gen_prev = genSolverFirstBase.getPgPrev()
		self.setGenData() # calls setGenData member function to set the parameter values

function get_gen_id() # function getGenID begins
	return gen_id # returns the ID of the generator object
end
	   
function get_gen_node_id() # function getGenNodeID begins
	return self.conn_nodeg_ptr.getNodeID() # returns the ID number of the node to which the generator object is connected
end

function set_gen_data() # start setGenData function
	Pg = 0.0 # Initialize power iterate
	P_gen_nextPtr = NULL
	theta_g = 0.0 # Initialize angle iterate
	v = 0.0 # Initialize the Lagrange multiplier corresponding voltage angle constraint to zero
end

function gpowerangle_message(outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, 
                           	P_gen_prevAPP, PgenAPP, PgenAPPInner, P_gen_nextAPP, AAPPExternal, BAPPExternal, 
				DAPPExternal, LambAPP1External, LambAPP2External, LambAPP3External, 
				LambAPP4External, BAPP, LambAPP1)
	BAPPNew = np.zeros(cont_count_gen, float)
	LambdaAPPNew = np.zeros(cont_count_gen, float)
	BAPPExtNew = np.zeros(cont_count_gen+1, float)
	DAPPExtNew = np.zeros(cont_count_gen+1, float)
	LambdaAPP1ExtNew = np.zeros(cont_count_gen+1, float)
	LambdaAPP2ExtNew = np.zeros(cont_count_gen+1, float)
	PgNextAPPNew = np.zeros(cont_count_gen+1, float)
	if base_cont_scenario == 0 # Use the solver for base cases
		if dummy_zero_int_flag == 1 # If dummy zero interval is considered
			if (dispatchInterval== 0) and (flag_last == 0) # For the dummy zeroth interval
				for counterCont in range(cont_count_gen)
					BAPPNew[counterCont] = BAPP[counterCont*numberOfGenerators+(genID-1)]
					LambdaAPPNew[counterCont] = LambAPP1[counterCont*numberOfGenerators+(genID-1)]
				BAPPExtNew = BAPPExternal 
				LambdaAPP1ExtNew = LambAPP1External
				DAPPExtNew = DAPPExternal
				LambdaAPP2ExtNew = LambAPP2External
				PgNextAPPNew = P_gen_nextAPP[(genID-1)]
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
    	theta_g_N_avg=0, # Net average bus voltage angle from last iteration for base case and contingencies
    	ug_N=0, # Dual variable for net power balance for base case and contingencies
    	vg_N=0, #  Dual variable for net angle balance for base case and contingencies
    	Vg_N_avg=0, # Average of dual variable for net angle balance from last to last iteration for base case and contingencies
    	PgNu=0, PgNuInner=0, PgNextNu=0, # Previous iterates of the corresponding decision variable values
    	PgPrev=0, # Generator's output in the previous interval
    	BSC::Array, # Cumulative disagreement between the generator output values for the previous and next intervals by the present, next, and the previous intervals, at the previous iteration
    	solChoice=1, #Choice of the solver
					self.Pg = genSolverFirstBase.getPSol() #get the Generator Power iterate
					self.P_gen_next = genSolverFirstBase.getPNextSol()
					self.P_gen_prev = genSolverFirstBase.getPgPrev()
				self.theta_g = *(genSolverFirstBase.getThetaPtr())
			}
			if (dispatchInterval!=0) and (flag_last==0): # For the first interval
			   for counterCont in range(cont_count_gen):
			      BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)] 
			      LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)]
		       for counterCont in range(cont_count_gen+1):
			      BAPPExtNew[counterCont]=BAPPExternal[counterCont] 
			      LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont]
			      DAPPExtNew[counterCont]=DAPPExternal[counterCont] 
		          LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont]
			      PgNextAPPNew[counterCont]=P_gen_nextAPP[counterCont]
				genSolverDZBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, P_gen_prevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, BAPPNew, LambdaAPPNew ) #calls the Generator optimization solver
				Pg = genSolverDZBase.getPSol() #get the Generator Power iterate
				P_gen_nextPtr = genSolverDZBase.getPNextSol()
				P_gen_prev = genSolverDZBase.getPPrevSol()
				theta_g = *(genSolverDZBase.getThetaPtr())
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				P_gen_next = genSolverSecondBase.getPNextSol();
				P_gen_prev = genSolverSecondBase.getPPrevSol();
				theta_g = *(genSolverSecondBase.getThetaPtr());
			}
		}
		if ( dummy_zero_int_flag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
					BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
					DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
				}
				genSolverFirst.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverFirst.getPSol(); // get the Generator Power iterate
				P_gen_nextPtr = genSolverFirst.getPNextSol();ASDFKL
				P_gen_prev = genSolverFirst.getPgPrev();
				theta_g = *(genSolverFirst.getThetaPtr());
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				for (int counterCont = 0; counterCont < cont_count_gen; ++counterCont) {
					BAPPNew[counterCont]=BAPP[counterCont*numberOfGenerators+(genID-1)]; 
					LambdaAPPNew[counterCont]=LambAPP1[counterCont*numberOfGenerators+(genID-1)];
				}
				BAPPExtNew[0]=-(*BAPPExternal);
				DAPPExtNew[0]=*DAPPExternal;
				genSolverSecondBase.mainsolve( outerAPPIt, APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External,  BAPPNew, LambdaAPPNew ); // calls the Generator optimization solver
				Pg = genSolverSecondBase.getPSol(); // get the Generator Power iterate
				P_gen_next = genSolverSecondBase.getPNextSol();
				P_gen_prev = genSolverSecondBase.getPPrevSol();
				theta_g = *(genSolverSecondBase.getThetaPtr());
			}
		}
	}
	else { // If a contingency scenario
		if ( dummy_zero_int_flag == 1 ) { // If dummy zero interval is considered
			if ((dispatchInterval==0) && (flag_last==0)) { // For the dummy zeroth interval
				genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				theta_g = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
			}
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont];
						PgNextAPPNew[counterCont]=P_gen_nextAPP[counterCont];
					}
					genSolverDZCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, P_gen_prevAPP, AAPPExternal, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverDZCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverDZCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal);
					DAPPExtNew[0]=*DAPPExternal;
					genSolverSecondCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverSecondCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
		}
		if ( dummy_zero_int_flag == 0 ) { // If dummy zero interval is not considered
			if ((dispatchInterval==0) && (flag_last==0)) { // For the dummy zeroth interval **/ Will not be used in this case**/
				genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
				Pg = genSolverCont.getPSol(); // get the Generator Power iterate
				theta_g = *(genSolverCont.getThetaPtr());
				//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
			}
			if ((dispatchInterval!=0) && (flag_last==0)) { // For the first interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if (cont_solver_accuracy != 0) {// If the exhaustive calculation for contingency scenarios not desired
					for (int counterCont = 0; counterCont <= cont_count_gen; ++counterCont) {
						BAPPExtNew[counterCont]=BAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP1ExtNew[counterCont]=LambAPP1External[counterCont*numberOfGenerators+(genID-1)];
						DAPPExtNew[counterCont]=DAPPExternal[counterCont*numberOfGenerators+(genID-1)]; 
						LambdaAPP2ExtNew[counterCont]=LambAPP2External[counterCont*numberOfGenerators+(genID-1)];
					}
					genSolverFirstCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, PgNextAPPNew, BAPPExtNew, DAPPExtNew, LambdaAPP1ExtNew, LambdaAPP2ExtNew, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverFirstCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverFirstCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
			if ((dispatchInterval!=0) && (flag_last==1)) { // For the second (or, in this case, the last) interval
				if (cont_solver_accuracy == 0) {// If the exhaustive calculation for contingency scenarios is not desired
					genSolverCont.mainsolve( APPItCount, gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPPInner, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverCont.getThetaPtr());
					//*cout << "\nThiterate from generator: " << *(theta_g+i) << endl;
				}
				if self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
					BAPPExtNew[0]=-(*BAPPExternal)
					DAPPExtNew[0]=*DAPPExternal
					genSolverSecondCont.mainsolve( gsRho, P_gen_prev, Pgenavg, Powerprice, Angpriceavg, Angavg, Angprice, PgenAPP, PgenAPPInner, P_gen_prevAPP, AAPPExternal, BAPPExtNew[0], LambAPP3External, LambAPP4External, -BAPP[(scenario_cont_count-1)*numberOfGenerators+(genID-1)], LambAPP1[(scenario_cont_count-1)*numberOfGenerators+(genID-1)] ); // calls the Generator optimization solver
					Pg = genSolverSecondCont.getPSol(); // get the Generator Power iterate
					theta_g = *(genSolverSecondCont.getThetaPtr());
					#log.info("\nThiterate from generator: " << *(theta_g+i) << endl;
				}
			}
		}			
	}
	self.conn_nodeg_ptr.powerangleMessage(self.Pg, self.v, self.theta_g ) #passes to node object the corresponding iterates of power, angle, v, and number of scenarios
	#function gpowerangleMessage ends

function genPower(self): #function genPower begins
		return self.Pg #returns the Pg iterate
	#function genPower ends

function genPowerPrev(self): #function genPower begins
		if self.dispatchInterval==0:
			return genSolverFirstBase.getPgPrev() #returns the Pg iterate
		else:
			return self.P_gen_prev
	#function genPower ends

function genPowerNext(self, nextScen): #const // function genPower begins
		if self.flag_last==1:
			return self.Pg #returns the Pg iterate
		elif self.dispatchInterval!=0 and self.flag_last==0:
			return self.P_gen_nextPtr[nextScen]
		else:
			return self.P_gen_next
	#function genPower ends

function objectiveGen(self): #function objectiveGen begins
		if self.base_cont_scenario == 0: #Use the solver for base cases
			if self.dummy_zero_int_flag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					return genSolverDZBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
			elif self.dummy_zero_int_flag == 0: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverFirstBase.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					return genSolverFirst.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					return genSolverSecondBase.getObj() #returns the evaluated objective
		elif self.base_cont_scenario != 0:
			if self.dummy_zero_int_flag == 1: #If dummy zero interval is considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverDZCont.getObj()
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
			elif self.dummy_zero_int_flag == 0: #If dummy zero interval is not considered
				if self.dispatchInterval==0 and self.flag_last==0: #For the dummy zeroth interval **/ Will not be used in this case**/
					return genSolverCont.getObj() #returns the evaluated objective
				elif self.dispatchInterval!=0 and self.flag_last==0: #For the first interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					elif self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios not desired
						return genSolverFirstCont.getObj()
				elif self.dispatchInterval!=0 and self.flag_last==1: #For the second (or, in this case, the last) interval
					if self.cont_solver_accuracy == 0: #If the exhaustive calculation for contingency scenarios is not desired
						return genSolverCont.getObj() #returns the evaluated objective
					if self.cont_solver_accuracy != 0: #If the exhaustive calculation for contingency scenarios is desired
						return genSolverSecondCont.getObj() #returns the evaluated objective
	#function objectiveGen ends

function objectiveGenGUROBI(self): #Objective from GUROBI ADMM
		return self.objOpt #returns the evaluated objective
	#function objectiveGen ends

function calcPtilde(self): #function calcPtilde begins
		P_avg = self.conn_nodeg_ptr.PavMessage() #Gets average power from the corresponding node object
		Ptilde = self.Pg - P_avg #calculates the difference between power iterate and average
		return Ptilde #returns the difference
	#function calcPtilde ends

function calcPavInit(self): #function calcPavInit begins
		return self.conn_nodeg_ptr.devpinitMessage() #seeks the initial Ptilde from the node
	#function calcPavInit ends

function getu(self): #function getu begins
		u = self.conn_nodeg_ptr.uMessage() #gets the value of the price corresponding to power balance from node
		#log.info("u: {}".format(u))
		return u #returns the price
	#function getu ends

function calcThetatilde(self): #function calcThetatilde begins
		#log.info("theta_g: {}".format(theta_g))
		Theta_avg = self.conn_nodeg_ptr.ThetaavMessage() #get the average voltage angle at the particular node
		#log.info("Theta_avg: ".format(Theta_avg))
		Theta_tilde = self.theta_g - Theta_avg #claculate the deviation between the voltage angle of the device and the average
		return Theta_tilde #return the deviation
	#function calcThetatilde ends

function calcvtilde(self): #function calcvtilde begins
		v_avg = self.conn_nodeg_ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
		#log.info("v_avg: {}".format(v_avg))
		v_tilde = self.v - v_avg #calculate the deviation of the node Lagrange multiplier to the average
		return v_tilde #return the deviation
	#function calcvtilde ends

function getv(self): #function getv begins
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
double Generator::getP_gen_prev(){return genSolverFirstBase.getPgPrev();}
double Generator::getP_gen_next(){return genSolverFirstBase.getPNextSol();}
double Generator::getRMax(){return genSolverFirstBase.getRMax();}
double Generator::getRMin(){return genSolverFirstBase.getRMin();}

