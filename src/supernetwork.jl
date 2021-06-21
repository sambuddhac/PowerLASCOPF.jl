#!/usr/bin/env python3
# Supernetwork source code for implementing APMP (Auxiliary Proximal Message Passing) Algorithm for the SCOPF in serial mode
import julia
import os
import subprocess
import math
import pandas as pd
import numpy as np
import json
import sys
import traceback
from Python_src.log import log
from Python_src.profiler import Profiler
# include definitions for classes generator, load, transmission line, network and node
from Python_src.network import Network
julia.install()  # only have to run this the first time you use the julia package (of if you change python path)

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

class superNetwork(object):
	def __init__(self, networkID, choiceSolver, rhoTuning, postContScen, dispInterval, dispIntervalClass, lastFlag, nextChoice, dummyDispInt, continSolAccuracy, outagedLine, RNDIntervals, RSDIntervals): #function main begins program execution
		self.netID = networkID #Network ID number to indicate the type of the system with specifying the number of buses/nodes
		self.contNetVector = []
		self.solverChoice = choiceSolver #Solver choice among CVXGEN-ADMM-PMP+APP fully distributed, GUROBI-ADMM-PMP+APP fully distributed, or GUROBI APP half distributed
		self.setRhoTuning = rhoTuning #parameter to select adaptive rho, fixed rho, and type of adaptive rho}
		self.postContingency = postContScen #future next-to-upcoming-dispatch intervals for pos-contingency cases, 0 for no contingency, assumed to have actually taken place
		self.intervalCount = dispInterval #count of the dispatch interval to which the particular network instance for the coarse grain belongs
		self.intervalClass = dispIntervalClass #class of the dispatch interval to which the particular network instance for the coarse grain belongs i.e. dummy (0)/forthcoming(1)/subsequent(2)
		self.RNDintervals = RNDIntervals #Initialize restoration to normal duration
		self.RSDintervals = RSDIntervals #Initialize restoration to secure duration
		self.lastInterval = lastFlag #Flas to indicate if the network belongs to last interval: 0=not last interval; 1=last interval
		log.info("\n*** NETWORK INITIALIZATION STAGE BEGINS ***\n")
		networkInstance = Network(self.netID, self.postContingency, 0, 0, 0, self.solverChoice, dummyDispInt, continSolAccuracy, self.intervalCount, self.lastInterval, nextChoice, outagedLine) #create network object corresponding to the base case
		self.numberOfCont = networkInstance.retContCount() #gets the number of contingency scenarios in the variable numberOfCont
		self.contNetVector.append(networkInstance) #push to the vector of network instances
		if (self.intervalCount<=0) or (self.intervalCount==(self.RNDintervals+self.RSDintervals)):
			for i in range(self.numberOfCont):
				if (i + 1) != self.postContingency: #As long as the index of scenarios is not the same as that of the post-contingency index of the base case in 2nd interval
					self.lineOutaged = self.contNetVector[0].indexOfLineOut(i + 1) #gets the serial number of transmission line outaged in this scenario 
					if self.lineOutaged != outagedLine:
						#create the network instances for the contingency scenarios, which includes as many networks as the number of contingency scenarios
						self.contNetVector.append(Network(self.netID, self.postContingency, i + 1, self.lineOutaged, 1, self.solverChoice, dummyDispInt, continSolAccuracy, self.intervalCount, self.lastInterval, nextChoice, outagedLine)) #push to the vector of network instances

		log.info("\n*** NETWORK INITIALIZATION STAGE ENDS ***\n")

		self.numberOfGenerators = self.contNetVector[0].getGenNumber() #get the number of generators in the system
		self.numberOfTransLines = self.contNetVector[0].getTranNumber() #get the number of transmission lines in the system
		self.consLagDim = self.numberOfCont * self.numberOfGenerators #Dimension of the vectors of APP Lagrange Multipliers and Power Generation Consensus

	def __del__(self): #Destructor
		log.info("\nDispatch interval super-network object for dispatch interval {} destroyed".format(self.intervalCount))

	def getvirtualNetExecTime(self):
		return self.virtualNetExecTime

	def indexOfLineOut(self, postScenar):
		return self.contNetVector[0].indexOfLineOut(postScenar) #Retruns the serial number of the line that is outaged in a particular post-contingency scenario 

	def retContCount(self):
		return self.numberOfCont #gets the number of contingency scenarios in the variable numberOfCont

	def runSimulation(self, outerIter, LambdaOuter, powDiffOuter, powSelfBel, powNextBel, powPrevBel, lambdaLine, powerDiffLine, powSelfFlowBel, powNextFlowBel): #runs the distributed SCOPF simulations using ADMM-PMP with CVXGEN custom solver
		lambdaAPP = np.zeros(self.consLagDim, float) #Array of APP Lagrange Multipliers for achieving consensus among the values of power generated, as guessed by scenarios
		powDiff = np.zeros(self.consLagDim, float) #Array of lack of consensus between generation values, as guessed by scenarios
		self.alphaAPP = 100.0 #APP Parameter/Path-length
		self.iterCountAPP = 1 #Iteration counter for APP coarse grain decomposition algorithm
		self.finTol = 1000.0 #Initial Guess of the Final tolerance of the APP iteration/Stopping criterion
		if self.solverChoice == 1 or self.solverChoice == 2: #APMP Fully distributed, Bi-layer (N-1) SCOPF Simulation 
			"""string outputAPPFileName;
			if (solverChoice==1)
				outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_GUROBI/resultAPP-SCOPF_Interval:"+to_string(intervalCount)+"PCScen:"+to_string(postContingency)+".txt";
			if (solverChoice==2)
				outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/ADMM_PMP_CVXGEN/resultAPP-SCOPF_Interval:"+to_string(intervalCount)+"PCScen:"+to_string(postContingency)+".txt";
			matrixResultAPPOut = dict() #create a new file result.txt to output the results

			// exit program if unable to create file
			if ( !matrixResultAPPOut ) {
				cerr << "File could not be opened" << endl;
				exit( 1 );
			}   
			matrixResultAPPOut[0]={'Initial Value of the Tolerance to kick-start the APP outer iterations':finTol}

			matrixResultAPPOut << "APP Iteration Count" << "\t" << "APP Tolerance" << "\n";	
			clock_t start_s = clock(); // begin keeping track of the time
			log.info("\n*** APMP ALGORITHM BASED COARSE+FINE GRAINED BILAYER DECENTRALIZED/DISTRIBUTED SCOPF (SERIAL IMPLEMENTATION) BEGINS ***\n")
			log.info("\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")"""

			#*********************************************AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************//	
			#do { // APP Coarse grain iterations start
			self.largestNetTimeVec = []
			actualNetTime = 0
			if (self.intervalCount==0) or (self.intervalCount==(self.RNDintervals+self.RSDintervals)): #Solve full SCOPF only for the present/forthcoming, dummy, and last intervals
				for self.iterCountAPP in range(1, 11, 1): #*&& (finTol>=0.7)*/); ++iterCountAPP ) { // Start the inner APP iterations among base-case and contngency scenarios for SCOPFs
					self.singleNetTimeVec = []
					for netSimCount in range(self.numberOfCont+1): #Iterate over the base-case and contingency scenarios
						if (netSimCount == 0) or ((netSimCount > 0)and(netSimCount!=self.postContingency)): #Calculate for the base-case or contingency scenarios (or, remaining contingency scenarios, for post-contingency base-case)
							if (self.postContingency > 0)and(netSimCount>self.postContingency): #If the base case is an outage case and the contingency scenario considered has index value greater than that of the outage case, then skip one index, and compensate for the skiped one in netSimCount
								log.info("\nStart of {} -th Innermost APP iteration for {} -th base/contingency scenario".format(self.iterCountAPP, self.netSimCount+1))
								self.contNetVector[netSimCount-1].runSimulation(outerIter, LambdaOuter, powDiffOuter, self.setRhoTuning, self.iterCountAPP, lambdaAPP, powDiff, powSelfBel, powNextBel, powPrevBel, lambdaLine, powerDiffLine, powSelfFlowBel, powNextFlowBel)#, environmentGUROBI) #start simulation
								singleNetTime = self.contNetVector[netSimCount-1].returnVirtualExecTime()
								actualNetTime += singleNetTime
								self.singleNetTimeVec.append(singleNetTime)
							else: #If either the base case (outaged or not outaged) or contingency scenario with index less than that of the outage case
								log.info("\nStart of {} -th Innermost APP iteration for {} -th base/contingency scenario".format(self.iterCountAPP, self.netSimCount+1))
								self.contNetVector[netSimCount].runSimulation(outerIter, LambdaOuter, powDiffOuter, self.setRhoTuning, self.iterCountAPP, lambdaAPP, powDiff, powSelfBel, powNextBel, powPrevBel, lambdaLine, powerDiffLine, powSelfFlowBel, powNextFlowBel)#, environmentGUROBI); // start simulation
								singleNetTime = self.contNetVector[netSimCount].returnVirtualExecTime()
								actualNetTime += singleNetTime
								self.singleNetTimeVec.append(singleNetTime)
					largestNetTime = max(self.singleNetTimeVec)
					self.largestNetTimeVec.append(largestNetTime)
					if self.postContingency > 0: #For outaged case
						for i in range(self.numberOfCont):
							if (i+1) < self.postContingency:
								for j in range(self.numberOfGenerators):
									powDiff[i*self.numberOfGenerators+j]=self.contNetVector[0].getPowSelf(j)-self.contNetVector[i+1].getPowSelf(j) #what base thinks about itself Vs. what contingency thinks about base
							elif (i+1) > self.postContingency:
								for j in range(self.numberOfGenerators):
									powDiff[i*self.numberOfGenerators+j]=self.contNetVector[0].getPowSelf(j)-self.contNetVector[i].getPowSelf(j) #what base thinks about itself Vs. what contingency thinks about base
					else: #For non-outaged case or base-case
						for i in range(1, self.numberOfCont+1, 1):
							for j in range(self.numberOfGenerators):
								#full SCOPF disagreements only for the present/forthcoming, dummy, and last intervals
								powDiff[(i-1)*self.numberOfGenerators+j]=self.contNetVector[0].getPowSelf(j)-self.contNetVector[i].getPowSelf(j) #what base thinks about itself Vs. what contingency thinks about base
					#Tuning the alphaAPP
					if (self.iterCountAPP > 5) and (self.iterCountAPP <= 10):
						self.alphaAPP = 75.0
					elif (self.iterCountAPP > 10) and (self.iterCountAPP <= 15):
						self.alphaAPP = 2.5
					elif (self.iterCountAPP > 15) and (self.iterCountAPP <= 20):
						self.alphaAPP = 1.25
					elif (self.iterCountAPP > 20):
						self.alphaAPP = 0.5
					for i in range(self.numberOfCont):
						for j in range(self.numberOfGenerators):
							lambdaAPP[i*self.numberOfGenerators+j] += self.alphaAPP * (powDiff[i*self.numberOfGenerators+j]) #what I think about myself Vs. what next door fellow thinks about me
					tolAPP = 0.0
					for i in range(self.consLagDim):
						tolAPP += pow(powDiff[i], 2)
						matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+i+1] = {'Lack of consensus among power in {}-th interval'.format(i):powDiff[i]}
					finTol = math.sqrt(tolAPP)
					matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+consLagDim+1] = {'APP Iteration Count':iterCountAPP,
																						'APP Tolerance':finTol}
				#++iterCountAPP; // increment the APP iteration counter
			#} while (finTol>=0.5); //Check the termination criterion of the APP iterations
			elif (self.intervalCount>=1) and (self.intervalCount<=(self.RNDintervals-1)):
				log.info("\nStart of {} -th Innermost APP iteration for {} -th base/contingency scenario".format(iterCountAPP, netSimCount+1))
				self.contNetVector[0].runSimulation(outerIter, LambdaOuter, powDiffOuter, setRhoTuning, iterCountAPP, lambdaAPP, powDiff, powSelfBel, powNextBel, powPrevBel)#start simulation
				singleNetTime = self.contNetVector[0].returnVirtualExecTime()
				actualNetTime += singleNetTime
				self.singleNetTimeVec.append(singleNetTime)
			elif (self.intervalCount>=self.RNDintervals) and (self.intervalCount<(self.RNDintervals+self.RSDintervals)):
				log.info("\nStart of {} -th Innermost APP iteration for {} -th base/contingency scenario".format(iterCountAPP, netSimCount+1))
				self.contNetVector[0].runSimulation(outerIter, LambdaOuter, powDiffOuter, setRhoTuning, iterCountAPP, lambdaAPP, powDiff, powSelfBel, powNextBel, powPrevBel)#start simulation
				singleNetTime = self.contNetVector[0].returnVirtualExecTime()
				actualNetTime += singleNetTime
				self.singleNetTimeVec.append(singleNetTime)
			#***************************************END OF AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************//
			log.info("\n*** SCOPF SIMULATION ENDS ***\n")
			#cout << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;
			log.info("\nFinal Value of APP Tolerance {}".format(finTol))
			stop_s = profiler.get_interval()  #end
			log.info("\n*** LASCOPF FOR POST-CONTINGENCY RESTORATION CONTROLLING LINE TEMPERATURE SIMULATION NETWORK LAYER ENDS ***\n")
			log.info("\nExecution Supernetwork layer time (s): {:..2f} ".format(stop_s))
			log.info("\nVirtual Supernetwork Execution time (s): {:..2f} ".format(stop_s  - actualNetTime + sum(largestNetTimeVec)))
			matrixResultAPPOut[(iterCountAPP-1)*(consLagDim+1)+1] = {'Virtual Supernetwork layer Execution time (s)':stop_s - actualNetTime + sum(largestNetTimeVec),
						  									 'Execution Supernetwork layer time (s)': stop_s}
			"""
		elif self.solverChoice==3: #Centralized (N-1) SCOPF Simulation
		    string outputAPPFileName = "/home/samie/code/ADMM_Based_Proximal_Message_Passing_Distributed_OPF/LASCOPF_Post_Contingency_Restoration/output/APP_Quasi_Decent_GUROBI/resultAPP-SCOPF_Interval"+to_string(intervalCount)+"PCScen:"+to_string(postContingency)+".txt";
		    matrixResultAPPOut = dict() #create a new file result.txt to output the results

		    // exit program if unable to create file
		    if ( !matrixResultAPPOut ) {
			    cerr << "File could not be opened" << endl;
			    exit( 1 );
		    }   
		    matrixResultAPPOut[0]={'Initial Value of the Tolerance to kick-start the APP outer iterations':finTol}

		    matrixResultAPPOut << "APP Iteration Count" << "\t" << "APP Tolerance" << "\n";	
		    clock_t start_s = clock(); // begin keeping track of the time
		    log.info("\n*** APMP ALGORITHM BASED COARSE+FINE GRAINED BILAYER DECENTRALIZED/DISTRIBUTED SCOPF (SERIAL IMPLEMENTATION) BEGINS ***\n")
		    log.info("\n*** SIMULATION IN PROGRESS; PLEASE DON'T CLOSE ANY WINDOW OR OPEN ANY OUTPUT FILE YET ... ***\n")
		    #*********************************************AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************/	
		    #do { // APP Coarse grain iterations start
		    self.largestNetTimeVec = []
		    actualNetTime = 0
		    #do {
		    for self.iterCountAPP in range(1,10): #*&& (finTol>=0.7)*/); ++iterCountAPP ) { // Start the inner APP iterations among base-case and contngency scenarios for SCOPFs
			    self.singleNetTimeVec = []
			    self.contNetVector[0].runSimAPPGurobiBase(outerIter, LambdaOuter, powDiffOuter, iterCountAPP, lambdaAPP, powDiff, powSelfBel, powNextBel, powPrevBel, environmentGUROBI); // start simulation
			    double singleNetTime = contNetVector[0]->returnVirtualExecTime();
			    actualNetTime += singleNetTime;
			    singleNetTimeVec.push_back(singleNetTime);
			    for ( int netSimCount = 1; netSimCount < (numberOfCont+1); ++netSimCount ) {
				    if (netSimCount>postContingency) {
					    contNetVector[netSimCount-1]->runSimAPPGurobiCont(outerIter, LambdaOuter, powDiffOuter, iterCountAPP, lambdaAPP, powDiff, environmentGUROBI); // start simulation
					    singleNetTime = contNetVector[netSimCount-1]->returnVirtualExecTime();
					    actualNetTime += singleNetTime;
					    singleNetTimeVec.push_back(singleNetTime);
				    }
				    else {
					    contNetVector[netSimCount]->runSimAPPGurobiCont(outerIter, LambdaOuter, powDiffOuter, iterCountAPP, lambdaAPP, powDiff, environmentGUROBI); // start simulation
					    singleNetTime = contNetVector[netSimCount]->returnVirtualExecTime();
					    actualNetTime += singleNetTime;
					    singleNetTimeVec.push_back(singleNetTime);
				    }
			    }
			    double largestNetTime = *max_element(singleNetTimeVec.begin(), singleNetTimeVec.end());
			    largestNetTimeVec.push_back(largestNetTime);
			    for ( int i = 0; i < numberOfCont; ++i ) {
				    if ((i+1) < postContingency) {
					    for ( int j = 0; j < numberOfGenerators; ++j ) {
						    powDiff[i*numberOfGenerators+j]=*(contNetVector[0]->getPowSelfGUROBI()+j)-*(contNetVector[i+1]->getPowSelfGUROBI()+j); // what base thinks about itself Vs. what contingency thinks about base
					    }
				    }
				    if ((i+1) > postContingency) {
					    for ( int j = 0; j < numberOfGenerators; ++j ) {
						    powDiff[i*numberOfGenerators+j]=*(contNetVector[0]->getPowSelfGUROBI()+j)-*(contNetVector[i]->getPowSelfGUROBI()+j); // what base thinks about itself Vs. what contingency thinks about base
					    }
				    }
			    }
			    // Tuning the alphaAPP by a discrete-time PID Controller
			    if ( ( iterCountAPP > 5 ) && ( iterCountAPP <= 10 ) )
				    alphaAPP = 75.0;
			    if ( ( iterCountAPP > 10 ) && ( iterCountAPP <= 15 ) )
				    alphaAPP = 2.5;
			    if ( ( iterCountAPP > 15 ) && ( iterCountAPP <= 20 ) )
				    alphaAPP = 1.25;
			    if ( ( iterCountAPP > 20 ) )
				    alphaAPP = 0.5;
			    for ( int i = 0; i < numberOfCont; ++i ) {
				    for ( int j = 0; j < numberOfGenerators; ++j ) {
					    lambdaAPP[i*numberOfGenerators+j] = lambdaAPP[i*numberOfGenerators+j] + alphaAPP * (powDiff[i*numberOfGenerators+j]); // what I think about myself Vs. what next door fellow thinks about me
				    }
			    }
			    double tolAPP = 0.0;
			    for ( int i = 0; i < consLagDim; ++i ) {
				    tolAPP = tolAPP + pow(powDiff[i], 2);
			    }
			    finTol = sqrt(tolAPP);
			    matrixResultAPPOut << iterCountAPP << "\t" << finTol << "\n";
			    //++iterCountAPP; // increment the APP iteration counter
		    //} while (finTol>=0.05); //Check the termination criterion of the APP iterations
		    }
		    //****************************************END OF AUXILIARY PROBLEM PRINCIPLE (APP) COARSE GRAINED DECOMPOSITION COMPONENT******************************************************/
		    cout << "\n*** SCOPF SIMULATION ENDS ***\n" << endl;
		    clock_t stop_s = clock();  // end
		    matrixResultAPPOut << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;
		    cout << "\nExecution time (s): " << static_cast<double>( stop_s - start_s ) / CLOCKS_PER_SEC << endl;
		    cout << "\nFinal Value of APP Tolerance " << finTol << endl; 
		    cout << "\n*** (N-1) SCOPF SIMULATION ENDS ***\n" << endl
			"""
		elif self.solverChoice==4: #Centralized (N-1) SCOPF Simulation
			contNetVector[0].runSimulationCentral(outerIter, LambdaOuter, powDiffOuter, powSelfBel, powNextBel, powPrevBel, environmentGUROBI) #start simulation
	    
		else:
			cout << "\nInvalid choice of solution method and algorithm." << endl

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
	def getPowSelf(self, generCount):
		return self.contNetVector[0].getPowSelf(generCount)
		#returns the difference in the values of what I think about myself Vs. what next door fellow thinks about me

	def getPowPrev(self, generCount):
		return self.contNetVector[0].getPowPrev(generCount)
		#returns what I think about previous dispatch interval generators
	def getPowNext(self, contingencyCounter, dispIntCount, generCount):
		if dispIntCount == 1:
			return self.contNetVector[0].getPowNext(contingencyCounter, dispIntCount, generCount)
		else:
			return self.contNetVector[0].getPowNext(contingencyCounter, dispIntCount, generCount) #returns what I think about next door fellow 
	def getGenNumber(self): #Function getGenNumber begins
		return self.numberOfGenerators
		#end of getGenNumber function

	def getPowFlowNext(self, continCounter, supernetCount, rndInterCount, lineCount):
		if self.intervalClass == 1:
			return self.contNetVector[0].getPowFlowNext(continCounter, supernetCount, rndInterCount, lineCount)
		else:
			return 0

	def getPowFlowSelf(self, lineCount):
		if self.intervalClass == 2:
			return self.contNetVector[0].getPowFlowSelf(lineCount)
		else:
			return 0

	def getTransNumber(self): #Function getTransNumber() begins
		return self.numberOfTransLines
