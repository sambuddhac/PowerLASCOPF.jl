# Member functions for class transmissionLine
import os
import subprocess
import pandas as pd
import numpy as np
import json
import sys
import traceback
from Python_src.node import Node

mutable struct transmissionLine
	translID::Int64
	connNodet1Ptr::Node
	connNodet2Ptr::Node
	ptMax::Float64
	reacT::Float64
	resT::Float64
	contScenTracker::Float64
end

function assign_conn_nodes()
	fromNode = self.connNodet1Ptr.getNodeID()
	toNode = self.connNodet2Ptr.getNodeID()
	self.connNodet1Ptr.settConn(self.translID, 1, self.reacT, toNode, self.contScenTracker) #increments the txr line connection variable to node 1
	self.connNodet2Ptr.settConn(self.translID, -1, self.reacT, fromNode, self.contScenTracker) #increments the txr line connection variable to node 2
	self.setTranData() #calls setTranData member function to set the parameter values
end

function getOutageScenario(self):
	return self.contScenTracker #returns scenario in which the line is outaged
end

function getTranslID(self): #function gettranslID begins
	return self.translID #returns the ID of the generator object
end

function getTranslNodeID1(self) #function getGenNodeID begins
	return self.connNodet1Ptr.getNodeID() #returns the ID number of the node to which the generator object is connected
	# end of getGenNodeID function
end

function getFlowLimit(self) #function getFlowLimit begins
	return self.ptMax #returns the Maximum power flow limit
	#end of getFlowLimit function
end

function getTranslNodeID2(self) #function getGenNodeID begins
	return self.connNodet2Ptr.getNodeID() #returns the ID number of the node to which the generator object is connected
	#end of getGenNodeID function
end

function setTranData(self) #member function to set parameter values of transmission lines
	self.Thetat1 = 0.0 #Initialize the angle iterate at end-1
	self.Thetat2 = 0.0 #Initialize the angle iterate at end-2
	self.Pt1 = 0.0 #Initialize the power iterate at end-1
	self.Pt2 = 0.0 #Initialize the power iterate at end-2
	self.v1 = 0.0 #Initialize the Lagrange multiplier corresponding to end-1 voltage angle constraint to zero
	self.v2 = 0.0 #Initialize the Lagrange multiplier corresponding to end-2 voltage angle constraint to zero
	#end function for setting parameter values
end

function tpowerangleMessage(self, tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1,  Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2) #function tpowerangleMessage begins
		#tranSolver.mainsolve( tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1, Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2 ); // calls the transmission line optimization solver
		end1A = self.reacT * (Pprevit1 - Pnetavg1 - uprev1) #end-1 power parameter (refer to the derivation)
		end1B = (vprevavg1 + Aprevavg1 - vprev1) #end-1 voltage angle parameter (refer to the derivation)
		end2C = self.reacT * (Pprevit2 - Pnetavg2 - uprev2) #end-2 power parameter (refer to the derivation)
		end2D = (vprevavg2 + Aprevavg2 - vprev2) #end-2 angle parameter (refer to the derivation)
		#double Pt1 = tranSolver.getPSol1(); // get the transmission line end-1 Power iterate
		#double Thetat1 = tranSolver.getThetaSol1(); // get the transmission line end-1 voltage angle iterate
		#double Pt2 = tranSolver.getPSol2(); // get the transmission line end-2 Power iterate
		#double Thetat2 = tranSolver.getThetaSol2(); // get the transmission line end-2 voltage angle iterate
		if self.getTranslNodeID1() == 1: #if end-1 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
			self.Thetat1 = 0.0
			Diff = ((self.reacT ** 2) * end2D + end1A - end2C) / ( 2.0 + self.reacT ** 2  ) #difference between the bus voltage angles
		else:
			if self.getTranslNodeID2() == 1: # if end-2 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
				self.Thetat1 = ((self.reacT ** 2.0) * end1B - end1A + end2C) / (2.0 + (self.reacT ** 2))
			else: #if none of the ends is the slack bus, consider both the voltage angles as decision variables and calculate them
				self.Thetat1 = ((2.0 + (self.reacT ** 2)) * end1B  - end1A + end2C + (2.0 * end2D)) / (4.0 + (self.reacT ** 2)) #Thetat1 iterate
				Diff = ( ( 2.0 * end1A ) - (self.reacT ** 2) * end1B - ( 2.0 * end2C ) + (self.reacT ** 2) * end2D ) / ( 4.0 + (self.reacT ** 2) ) #Magnitude of the difference between the angles at the ends of the transmission line
		Limit = self.reacT * self.ptMax #Upper limit of the power flow limit scaled by reactance
		Obj1 = ( Limit - end1A ) * ( Limit - end1A ) + ( Limit + end2C ) * ( Limit + end2C ) + self.reacT * self.reacT * ( self.Thetat1 - end1B ) * ( self.Thetat1 - end1B ) + self.reacT * self.reacT * ( self.Thetat1 + Limit - end2D ) * ( self.Thetat1 + Limit - end2D ) #Objective on assumption that difference between angles is equal to upper limit allowed
		Obj2 = ( -Limit - end1A ) * ( -Limit - end1A ) + ( -Limit + end2C ) * ( -Limit + end2C ) + self.reacT * self.reacT * ( self.Thetat1 - end1B ) * ( self.Thetat1 - end1B ) + self.reacT * self.reacT * ( self.Thetat1 - Limit - end2D ) * ( self.Thetat1 - Limit - end2D ) #Objective on assumption that difference between angles is equal to lower limit allowed
		if ( Diff <= Limit ) and ( Diff >= -Limit ): #If the power flow and consequently the angle difference is well within allowed limits
			Obj3 = ( Diff - end1A ) * ( Diff - end1A ) + ( Diff + end2C ) * ( Diff + end2C ) + self.reacT * self.reacT * ( self.Thetat1 - end1B ) * ( self.Thetat1 - end1B ) + self.reacT * self.reacT * ( self.Thetat1 + Diff - end2D ) * ( self.Thetat1 + Diff - end2D ) #Objective on assumption that Difference between angles lies well within the allowed limits
			Obj = (Obj1 if Obj1 < Obj3 else Obj3) if Obj1 < Obj2 else (Obj2 if Obj2 < Obj3 else Obj3)
			if Obj == Obj1:# if Diff == Limit gives the lowest objective
				if self.getTranslNodeID2() == 1: #check if end-2 is slack bus
					self.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
					self.Thetat1 = self.Thetat2 - Limit #adjust the end-1 angle accordingly
				else: #if end-2 is not the slack bus
					self.Thetat2 = self.Thetat1 + Limit #adjust the end-2 angle accordingly
			else:
				if Obj == Obj2: #if Diff == -Limit gives the lowest objective
					if self.getTranslNodeID2() == 1: #check if end-2 is slack bus
						self.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
						self.Thetat1 = self.Thetat2 + Limit #adjust the end-1 angle accordingly
					else: #if end-2 is not the slack bus
						self.Thetat2 = self.Thetat1 - Limit #adjust the end-2 angle accordingly
				else: #if an intermediate value of Diff gives the lowest objective
					if getTranslNodeID2() == 1: #check if end-2 is slack bus
						self.Thetat2 = 0.0 #in that case fix the corresponding angle to zero
						self.Thetat1 = self.Thetat2 - Diff #adjust the end-1 angle accordingly
					else: #if end-2 is not the slack bus
						self.Thetat2 = self.Thetat1 + Diff #adjust the end-2 angle accordingly
		else: #if value of Diff that minimizes the objective falls outside the range
			Obj = Obj1 if Obj1 < Obj2 else Obj2 #check the objective value at the two limit points
			if Obj == Obj1: # if Diff == Limit gives the lowest objective
				if self.getTranslNodeID2() == 1: #check if end-2 is the slack bus
					self.Thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					self.Thetat1 = self.Thetat2 - Limit #adjust the angle of end-1 accordingly
				else: #if end-2 is not the slack bus
					self.Thetat2 = self.Thetat1 + Limit #adjust the end-2 angle accordingly
			else: #if Diff == -Limit gives the lowest objective
				if self.getTranslNodeID2() == 1: # check if end-2 is the slack bus
					self.Thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					self.Thetat1 = self.Thetat2 + Limit #adjust the angle of end-1 accordingly
				else: #if end-2 is not the slack bus
					self.Thetat2 = self.Thetat1 - Limit #adjust the end-2 angle accordingly
		#whichever objective is the minimum, consider that value of angle difference as the optimizer
		self.Pt2 = (self.Thetat1 - self.Thetat2) / self.reacT #get the transmission line end-2 Power iterate
		self.Pt1 = (self.Thetat2 - self.Thetat1) / self.reacT #get the transmission line end-2 voltage angle iterate
		self.connNodet1Ptr.powerangleMessage(self.Pt1, self.v1, self.Thetat1) #passes to node object at end 1 the corresponding iterates of power, angle and v
		self.connNodet2Ptr.powerangleMessage(self.Pt2, self.v2, self.Thetat2) #passes to node object at end 2 the corresponding iterates of power, angle and v
		#function tpowerangleMessage ends

function futureMessageBase(self, lambda_TXR, ECoeff, PgNextNu, BSC, ETempCoeff, **lineTempCalc)
end
		
function tpowerFutureMessage(self, tRho)
end # For the upcoming interval, opinions about RND flows		

function translPower1(self) #function translPower1 begins
	return self.Pt1 #returns the Pt1 iterate
	#function translPower1 ends
end

function translPower2(self) #function translPower2 begins
	return self.Pt2 #returns the Pt2 iterate
	#function translPower2 ends
end

function calcPtilde1(self) #function calcPtilde1 begins
	P_avg1 = self.connNodet1Ptr.PavMessage() #Gets average power for end-1 from the corresponding node object
	Ptilde1 = self.Pt1 - P_avg1 #calculates the difference between power iterate and average
	return Ptilde1 #returns the difference
	#function calcPtilde1 ends
end

function calcPavInit1(self) #function calcPavInit1 begins
	return self.connNodet1Ptr.devpinitMessage() #seeks the initial Ptilde from the node at end 1
	#function calcPavInit1 ends
end

function calcPtilde2(self) #function calcPtilde2 begins
	P_avg2 = self.connNodet2Ptr.PavMessage() #Gets average power for end-2 from the corresponding node object
	Ptilde2 = self.Pt2 - P_avg2 #calculates the difference between power iterate and average
	return Ptilde2 #returns the difference
	#function calcPtilde2 ends
end

function calcPavInit2(self) #function calcPavInit2 begins
	return self.connNodet2Ptr.devpinitMessage() #seeks the initial Ptilde from the node at end 2
	#function calcPavInit2 ends
end

function getu1(self) #function getu1 begins
	u1 = self.connNodet1Ptr.uMessage() #gets the value of the price corresponding to power balance from node
	#print("u1: {}".print(u1))
	return u1 #returns the price
	#function getu1 ends
end

function getu2(self) #function getu2 begins
	u2 = self.connNodet2Ptr.uMessage() #gets the value of the price corresponding to power balance from node
	#print("u2: {}".format(u2))
	return u2 #returns the price
	#function getu2 ends
end

function calcThetatilde1(self) #function calcThetatilde1 begins
	Theta_avg1 = self.connNodet1Ptr.ThetaavMessage() #get the average voltage angle at the particular node
	Theta_tilde1 = self.Thetat1 - Theta_avg1 #claculate the deviation between the voltage angle of the device and the average
	return Theta_tilde1 #return the deviation
	#function calcThetatilde1 ends
end

function calcThetatilde2(self) #function calcThetatilde2 begins
	Theta_avg2 = self.connNodet2Ptr.ThetaavMessage() #get the average voltage angle at the particular node
	Theta_tilde2 = self.Thetat2 - Theta_avg2 #claculate the deviation between the voltage angle of the device and the average
	return Theta_tilde2 #return the deviation
	#function calcThetatilde2 ends
end

function calcvtilde1(self) #function calcvtilde1 begins
	v_avg1 = self.connNodet1Ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
	v_tilde1 = self.v1 - v_avg1 #calculate the deviation of the node Lagrange multiplier to the average
	return v_tilde1 #return the deviation
	#function calcvtilde1 ends
end

function calcvtilde2(self) #function calcvtilde2 begins
	v_avg2 = self.connNodet2Ptr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance
	v_tilde2 = self.v2 - v_avg2 #calculate the deviation of the node Lagrange multiplier to the average
	return v_tilde2 #return the deviation
	#function calcvtilde2 ends
end

function getv1(self) #function getv1 begins
	#print("v1_initial: {}".format(v1))
	self.v1 = self.v1 + self.calcThetatilde1() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v1_final: {}".format(v1))
	return self.v1 #return the voltage angle price
	#function getv1 ends
end

function getv2(self) #function getv2 begins
	#print("v2_initial: {}".format(v2))
	self.v2 = self.v2 + self.calcThetatilde2() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v2_final: {}".format(v2))
	return self.v2 #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#function getv2 ends
end

function getReactance(self)
	return self.reacT
end
