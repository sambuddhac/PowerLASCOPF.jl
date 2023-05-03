# Member functions for class transmissionLine

mutable struct transmissionLine <: Device
	translID::Int64
	connNodet1Ptr::Node
	connNodet2Ptr::Node
	ptMax::Float64
	reacT::Float64
	resT::Float64
	contScenTracker::Float64
end

function assign_conn_nodes()
	fromNode = transline.connNodet1Ptr.getNodeID()
	toNode = transline.connNodet2Ptr.getNodeID()
	transline.connNodet1Ptr.settConn(transline.translID, 1, transline.reacT, toNode, transline.contScenTracker) #increments the txr line connection variable to node 1
	transline.connNodet2Ptr.settConn(transline.translID, -1, transline.reacT, fromNode, transline.contScenTracker) #increments the txr line connection variable to node 2
	transline.setTranData() #calls setTranData member function to set the parameter values
end

function getOutageScenario(transline::transmissionLine)
	return transline.contScenTracker #returns scenario in which the line is outaged
end

function getTranslID(transline::transmissionLine) #function gettranslID begins
	return transline.translID #returns the ID of the generator object
end

function getTranslNodeID1(transline::transmissionLine) #function getGenNodeID begins
	return transline.connNodet1Ptr.getNodeID() #returns the ID number of the node to which the generator object is connected
	# end of getGenNodeID function
end

function getFlowLimit(transline::transmissionLine) #function getFlowLimit begins
	return transline.ptMax #returns the Maximum power flow limit
	#end of getFlowLimit function
end

function getTranslNodeID2(transline::transmissionLine) #function getGenNodeID begins
	return transline.connNodet2Ptr.getNodeID() #returns the ID number of the node to which the generator object is connected
	#end of getGenNodeID function
end

function setTranData(transline::transmissionLine) #member function to set parameter values of transmission lines
	transline.Thetat1 = 0.0 #Initialize the angle iterate at end-1
	transline.Thetat2 = 0.0 #Initialize the angle iterate at end-2
	transline.Pt1 = 0.0 #Initialize the power iterate at end-1
	transline.Pt2 = 0.0 #Initialize the power iterate at end-2
	transline.v1 = 0.0 #Initialize the Lagrange multiplier corresponding to end-1 voltage angle constraint to zero
	transline.v2 = 0.0 #Initialize the Lagrange multiplier corresponding to end-2 voltage angle constraint to zero
	#end function for setting parameter values
end

function tpowerangleMessage(transline::transmissionLine, tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1,  Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2) #function tpowerangleMessage begins
	#tranSolver.mainsolve( tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1, Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2 ); // calls the transmission line optimization solver
	end1A = transline.reacT * (Pprevit1 - Pnetavg1 - uprev1) #end-1 power parameter (refer to the derivation)
	end1B = (vprevavg1 + Aprevavg1 - vprev1) #end-1 voltage angle parameter (refer to the derivation)
	end2C = transline.reacT * (Pprevit2 - Pnetavg2 - uprev2) #end-2 power parameter (refer to the derivation)
	end2D = (vprevavg2 + Aprevavg2 - vprev2) #end-2 angle parameter (refer to the derivation)
	#double Pt1 = tranSolver.getPSol1(); // get the transmission line end-1 Power iterate
	#double Thetat1 = tranSolver.getThetaSol1(); // get the transmission line end-1 voltage angle iterate
	#double Pt2 = tranSolver.getPSol2(); // get the transmission line end-2 Power iterate
	#double Thetat2 = tranSolver.getThetaSol2(); // get the transmission line end-2 voltage angle iterate
	if transline.getTranslNodeID1() == 1 #if end-1 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
		transline.Thetat1 = 0.0
		Diff = ((transline.reacT ** 2) * end2D + end1A - end2C) / ( 2.0 + transline.reacT ** 2  ) #difference between the bus voltage angles
	else
		if transline.getTranslNodeID2() == 1 # if end-2 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
			transline.Thetat1 = ((transline.reacT ** 2.0) * end1B - end1A + end2C) / (2.0 + (transline.reacT ** 2))
		else #if none of the ends is the slack bus, consider both the voltage angles as decision variables and calculate them
			transline.Thetat1 = ((2.0 + (transline.reacT ** 2)) * end1B  - end1A + end2C + (2.0 * end2D)) / (4.0 + (transline.reacT ** 2)) #Thetat1 iterate
			Diff = ( ( 2.0 * end1A ) - (transline.reacT ** 2) * end1B - ( 2.0 * end2C ) + (transline.reacT ** 2) * end2D ) / ( 4.0 + (transline.reacT ** 2) ) #Magnitude of the difference between the angles at the ends of the transmission line
		end
	end
	Limit = transline.reacT * transline.ptMax #Upper limit of the power flow limit scaled by reactance
	Obj1 = ( Limit - end1A ) * ( Limit - end1A ) + ( Limit + end2C ) * ( Limit + end2C ) + transline.reacT * transline.reacT * ( transline.Thetat1 - end1B ) * ( transline.Thetat1 - end1B ) + transline.reacT * transline.reacT * ( transline.Thetat1 + Limit - end2D ) * ( transline.Thetat1 + Limit - end2D ) #Objective on assumption that difference between angles is equal to upper limit allowed
	Obj2 = ( -Limit - end1A ) * ( -Limit - end1A ) + ( -Limit + end2C ) * ( -Limit + end2C ) + transline.reacT * transline.reacT * ( transline.Thetat1 - end1B ) * ( transline.Thetat1 - end1B ) + transline.reacT * transline.reacT * ( transline.Thetat1 - Limit - end2D ) * ( transline.Thetat1 - Limit - end2D ) #Objective on assumption that difference between angles is equal to lower limit allowed
		if ( Diff <= Limit ) and ( Diff >= -Limit ): #If the power flow and consequently the angle difference is well within allowed limits
			Obj3 = ( Diff - end1A ) * ( Diff - end1A ) + ( Diff + end2C ) * ( Diff + end2C ) + transline.reacT * transline.reacT * ( transline.Thetat1 - end1B ) * ( transline.Thetat1 - end1B ) + transline.reacT * transline.reacT * ( transline.Thetat1 + Diff - end2D ) * ( transline.Thetat1 + Diff - end2D ) #Objective on assumption that Difference between angles lies well within the allowed limits
			Obj = (Obj1 if Obj1 < Obj3 else Obj3) if Obj1 < Obj2 else (Obj2 if Obj2 < Obj3 else Obj3)
			if Obj == Obj1:# if Diff == Limit gives the lowest objective
				if transline.getTranslNodeID2() == 1: #check if end-2 is slack bus
					transline.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
					transline.Thetat1 = transline.Thetat2 - Limit #adjust the end-1 angle accordingly
				else: #if end-2 is not the slack bus
					transline.Thetat2 = transline.Thetat1 + Limit #adjust the end-2 angle accordingly
			else:
				if Obj == Obj2: #if Diff == -Limit gives the lowest objective
					if transline.getTranslNodeID2() == 1: #check if end-2 is slack bus
						transline.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
						transline.Thetat1 = transline.Thetat2 + Limit #adjust the end-1 angle accordingly
					else: #if end-2 is not the slack bus
						transline.Thetat2 = transline.Thetat1 - Limit #adjust the end-2 angle accordingly
				else: #if an intermediate value of Diff gives the lowest objective
					if getTranslNodeID2() == 1: #check if end-2 is slack bus
						transline.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
						transline.Thetat1 = transline.Thetat2 - Diff #adjust the end-1 angle accordingly
					else: #if end-2 is not the slack bus
						transline.Thetat2 = transline.Thetat1 + Diff #adjust the end-2 angle accordingly
		else: #if value of Diff that minimizes the objective falls outside the range
			Obj = Obj1 if Obj1 < Obj2 else Obj2 #check the objective value at the two limit points
			if Obj == Obj1: # if Diff == Limit gives the lowest objective
				if transline.getTranslNodeID2() == 1: #check if end-2 is the slack bus
					transline.Thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					transline.Thetat1 = transline.Thetat2 - Limit #adjust the angle of end-1 accordingly
				else: #if end-2 is not the slack bus
					transline.Thetat2 = transline.Thetat1 + Limit #adjust the end-2 angle accordingly
			else: #if Diff == -Limit gives the lowest objective
				if transline.getTranslNodeID2() == 1: # check if end-2 is the slack bus
					transline.Thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					transline.Thetat1 = transline.Thetat2 + Limit #adjust the angle of end-1 accordingly
				else: #if end-2 is not the slack bus
					transline.Thetat2 = transline.Thetat1 - Limit #adjust the end-2 angle accordingly
		#whichever objective is the minimum, consider that value of angle difference as the optimizer
		transline.Pt2 = (transline.Thetat1 - transline.Thetat2) / transline.reacT #get the transmission line end-2 Power iterate
		transline.Pt1 = (transline.Thetat2 - transline.Thetat1) / transline.reacT #get the transmission line end-2 voltage angle iterate
		transline.connNodet1Ptr.powerangleMessage(transline.Pt1, transline.v1, transline.Thetat1) #passes to node object at end 1 the corresponding iterates of power, angle and v
		transline.connNodet2Ptr.powerangleMessage(transline.Pt2, transline.v2, transline.Thetat2) #passes to node object at end 2 the corresponding iterates of power, angle and v
		#function tpowerangleMessage ends
end

function futureMessageBase(transline::transmissionLine, lambda_TXR, ECoeff, PgNextNu, BSC, ETempCoeff, **lineTempCalc)
end
		
function tpowerFutureMessage(transline::transmissionLine, tRho)
end # For the upcoming interval, opinions about RND flows		

function translPower1(transline::transmissionLine) #function translPower1 begins
	return transline.Pt1 #returns the Pt1 iterate
	#function translPower1 ends
end

function translPower2(transline::transmissionLine) #function translPower2 begins
	return transline.Pt2 #returns the Pt2 iterate
	#function translPower2 ends
end

function calcPtilde1(transline::transmissionLine) #function calcPtilde1 begins
	P_avg1 = transline.connNodet1Ptr.PavMessage() #Gets average power for end-1 from the corresponding node object
	Ptilde1 = transline.Pt1 - P_avg1 #calculates the difference between power iterate and average
	return Ptilde1 #returns the difference
	#function calcPtilde1 ends
end

function calcPavInit1(transline::transmissionLine) #function calcPavInit1 begins
	return transline.connNodet1Ptr.devpinitMessage() #seeks the initial Ptilde from the node at end 1
	#function calcPavInit1 ends
end

function calcPtilde2(transline::transmissionLine) #function calcPtilde2 begins
	P_avg2 = transline.connNodet2Ptr.PavMessage() #Gets average power for end-2 from the corresponding node object
	Ptilde2 = transline.Pt2 - P_avg2 #calculates the difference between power iterate and average
	return Ptilde2 #returns the difference
	#function calcPtilde2 ends
end

function calcPavInit2(transline::transmissionLine) #function calcPavInit2 begins
	return transline.connNodet2Ptr.devpinitMessage() #seeks the initial Ptilde from the node at end 2
	#function calcPavInit2 ends
end

function getu1(transline::transmissionLine) #function getu1 begins
	u1 = transline.connNodet1Ptr.uMessage() #gets the value of the price corresponding to power balance from node
	#print("u1: {}".print(u1))
	return u1 #returns the price
	#function getu1 ends
end

function getu2(transline::transmissionLine) #function getu2 begins
	u2 = transline.connNodet2Ptr.uMessage() #gets the value of the price corresponding to power balance from node
	#print("u2: {}".format(u2))
	return u2 #returns the price
	#function getu2 ends
end

function calcThetatilde1(transline::transmissionLine) #function calcThetatilde1 begins
	Theta_avg1 = transline.connNodet1Ptr.ThetaavMessage() #get the average voltage angle at the particular node
	Theta_tilde1 = transline.Thetat1 - Theta_avg1 #claculate the deviation between the voltage angle of the device and the average
	return Theta_tilde1 #return the deviation
	#function calcThetatilde1 ends
end

function calcThetatilde2(transline::transmissionLine) #function calcThetatilde2 begins
	Theta_avg2 = transline.connNodet2Ptr.ThetaavMessage() #get the average voltage angle at the particular node
	Theta_tilde2 = transline.Thetat2 - Theta_avg2 #claculate the deviation between the voltage angle of the device and the average
	return Theta_tilde2 #return the deviation
	#function calcThetatilde2 ends
end

function calcvtilde1(transline::transmissionLine) #function calcvtilde1 begins
	v_avg1 = transline.connNodet1Ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
	v_tilde1 = transline.v1 - v_avg1 #calculate the deviation of the node Lagrange multiplier to the average
	return v_tilde1 #return the deviation
	#function calcvtilde1 ends
end

function calcvtilde2(transline::transmissionLine) #function calcvtilde2 begins
	v_avg2 = transline.connNodet2Ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
	v_tilde2 = transline.v2 - v_avg2 #calculate the deviation of the node Lagrange multiplier to the average
	return v_tilde2 #return the deviation
	#function calcvtilde2 ends
end

function getv1(transline::transmissionLine) #function getv1 begins
	#print("v1_initial: {}".format(v1))
	transline.v1 = transline.v1 + transline.calcThetatilde1() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v1_final: {}".format(v1))
	return transline.v1 #return the voltage angle price
	#function getv1 ends
end

function getv2(transline::transmissionLine) #function getv2 begins
	#print("v2_initial: {}".format(v2))
	transline.v2 = transline.v2 + transline.calcThetatilde2() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v2_final: {}".format(v2))
	return transline.v2 #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#function getv2 ends
end

function getReactance(transline::transmissionLine)
	return transline.reacT
end
