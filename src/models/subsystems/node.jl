# Member functions for class Node
import os
import subprocess
import pandas as pd
import numpy as np
import json
import sys
import traceback

class Node(object):
	def __init__(self, idOfNode, numberOfScenarios): #constructor begins
		self.nodeID = idOfNode
		self.contingencyScenarios = numberOfScenarios
		#print("\nInitializing the parameters of the node with ID: {}".format(nodeID))
		#initialize the connected devices to zero for node
		self.gConnNumber = 0 #number of generators connected to a particular node
		self.tConnNumber = 0 #number of transmission lines connected to a particular node
		self.lConnNumber = 0 #number of loads connected to a particular node
		self.nodeFlag = 0 #flag to indicate if a particular node has been accounted for by any one device connected to it for calculation of u 
		self.fromReact = 0.0 #Initialize the from reactance
		self.toReact = 0.0 #Initialize the to reactance
		self.PDevCount = 0 #initialize number of devices connectedto a node to zero
		self.P_avg = 0.0 #Initialize average power to zero
		self.Theta_avg = 0.0 #initialize average angle to zero
		self.u = 0.0 #initialize power balance price to zero
		self.v_avg = 0.0 #initialize average value of voltage angle price to zero
		self.Pinitavg = 0.0 #initialize initial average power to zero
		self.genSerialNum = []
		self.contScenList = []
		self.tranFromSerial = []
		self.tranToSerial = []
		self.loadSerialNum = []
		self.ReactCont = []
		self.scenNodeList = []
		self.connNodeList = []
		self.connReactRec = []
		#constructor ends

	#def __del__(self): #destructor
		#print("\nThe node object having ID {} have been destroyed.\n".format(nodeID))
		#end of destructor

	def getNodeID(self): #function getNodeID begins
		return self.nodeID #returns node ID to the caller 
		#end of function getNodeID

	def setgConn(self, serialOfGen):
		self.gConnNumber += 1 #increment the number of generators connected by one whenever a generator is connected to the node
		self.genSerialNum.append(serialOfGen) #records the serial number of the generator connected to the node 

	def getGenLength(self):
		return self.gConnNumber #returns the number of connected generators

	def getGenSer(self, colCount):
		return self.genSerialNum[colCount - 1]

	def settConn(self, tranID, dir, react, rankOfOther, scenarioTracker):
		tConnNumber += 1 #increment the number of txr lines connected by one whenever a txr line is connected to the node
		if self.scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
			self.contScenList.append(scenarioTracker) #Store those scenario numbers in the contScenList vector
		if dir == 1:
			self.tranFromSerial.append(tranID)
			self.fromReact += (1/react)
			if scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
				self.ReactCont.append(-(1/react))
				self.scenNodeList.append(rankOfOther)
			elif rankOfOther in self.connNodeList: # If predecided Gen value is given for this particular Powergenerator
				pos = self.connNodeList.index(rankOfOther) #find the position of the Powergenerator in the chart of predecided values
				self.connReactRec[pos] -= 1/react
			else:
				self.connNodeList.append(rankOfOther)
				self.connReactRec.append(-1/react)
		else:
			self.tranToSerial.append(tranID)
			self.toReact -= (1/react)
			if scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
				self.ReactCont.append(1/react)
				self.scenNodeList.append(rankOfOther)
			elif rankOfOther in self.connNodeList: #If predecided Gen value is given for this particular Powergenerator
				pos = self.connNodeList.index(rankOfOther) #find the position of the Powergenerator in the chart of predecided values
				self.connReactRec[pos] += 1/react
			else:
				self.connNodeList.append(rankOfOther)
				self.connReactRec.append(1/react)

	def getToReact(self, scenarioTracker):
		if scenarioTracker in self.contScenList:
			pos = self.contScenList.index(scenarioTracker)
			if self.ReactCont[pos] > 0:
				return self.toReact + self.ReactCont[pos]
			else:
				return self.toReact
		return self.toReact #return the total reciprocal of reactances for which this is the to node

	def getFromReact(self, scenarioTracker):
		if scenarioTracker in self.contScenList:
			pos = self.contScenList.index(scenarioTracker)
			if self.ReactCont[pos] <= 0:
				return self.fromReact + self.ReactCont[pos]
			else:
				return self.fromReact
		return self.fromReact #return the total reciprocal of reactances for which this is the from node

	def getConNodeLength(self):
		return self.connNodeList.size() #returns the length of the vector containing the connected intra-zonal nodes

	def getConnSer(self, colCount):
		return self.connNodeList[colCount-1] #returns the serial number of the connected internal node at this position

	def getConnSerScen(self, scenarioTracker):
		if scenarioTracker in self.contScenList:
			pos = self.contScenList.index(scenarioTracker)
			return self.scenNodeList[pos]
		else:
			return 0 #returns the serial number of the connected internal node at this position

	def getConnReact(self, colCount):
	    return self.connReactRec[colCount-1] #returns the serial number of the connected internal node at this position

	def getConnReactCompensate(self, scenarioTracker):
	    if scenarioTracker in self.contScenList:
		    pos = self.contScenList.index(scenarioTracker)
		    return self.ReactCont[pos]
	    else:
		    return 0 #returns the serial number of the connected internal node at this position

	def setlConn(self, lID, loadVal):
		self.lConnNumber += 1 #increment the number of loads connected by one whenever a load is connected to the node
		self.loadSerialNum.append(lID)
		self.connLoadVal = loadVal #total connected loads

	def getLoadVal(self):
		return self.connLoadVal #Returns the value of the connected load

	def npinitMessage(self, Pload): #function npinitMessage begins
		self.Pinitavg += Pload / (self.gConnNumber + self.tConnNumber + self.lConnNumber) #calculate average power
		return self.Pinitavg #return initial average power
		#function npinitMessage ends

	def devpinitMessage(self): #function devpinitMessage begins
		return self.Pinitavg #return the initial average node power imbalance to the devices
		#function devpinitMessage ends

	def powerangleMessage(self, Power, AngPrice, Angle): #function powerangleMessage begins
		self.P_avg += Power / (self.gConnNumber + self.tConnNumber + self.lConnNumber) #calculate average power
		#v_avg = v_avg + AngPrice / ( gConnNumber + tConnNumber + lConnNumber ) #calculate average voltage angle price
		self.Theta_avg += Angle / (self.gConnNumber + self.tConnNumber + self.lConnNumber) #calculate average voltage angle
		self.PDevCount += 1 #increment device count by one indicating that a particular device connected to the node has been taken into account
		#function powerangleMessage ends

	def PavMessage(self): #function PavMessage begins
		if self.PDevCount == self.gConnNumber + self.tConnNumber + self.lConnNumber: #if all the devices are taken care of return the average power
			return self.P_avg
		#function PavMessage ends

	def uMessage(self): #function uMessage begins
		if self.nodeFlag != 0:
			#cout << nodeFlag << endl;
			return self.u
		else:
			if self.PDevCount == self.gConnNumber + self.tConnNumber + self.lConnNumber:
				self.u = self.u + self.P_avg
				#cout << nodeFlag << endl;
				nodeFlag += 1 #this node has already been accounted for
				return self.u # if all the devices are taken care of calculate and return the power price
		#function uMessage ends

	def ThetaavMessage(self): #function ThetaavMessage begins
		if self.PDevCount == self.gConnNumber + self.tConnNumber + self.lConnNumber:
			return self.Theta_avg #if all the devices are taken care of return the average angle
		# function ThetaavMessage ends

	def vavMessage(self): #function vavMessage begins
		if self.PDevCount == self.gConnNumber + self.tConnNumber + self.lConnNumber:
			return self.v_avg #if all the devices are taken care of return the average angle price
		#function vavMessage ends

	def reset(self): #function reset begins
		self.PDevCount = 0
		self.P_avg = 0.0
		self.v_avg = 0.0
		self.Theta_avg = 0.0
		self.nodeFlag = 0
        #function reset ends
"""
    def getGenSer(self, colCount):
	    return self.genSerialNum.at(colCount-1)

    def getToReact(self, contingency):
	    return self.toReact.at(contingency) #return the total reciprocal of reactances for which this is the to node

    def getFromReact(self, contingency):
	    return self.fromReact.at(contingency) #return the total reciprocal of reactances for which this is the from node

    def getConNodeLength(self, contingency):
	    return self.connNodeList.size() #returns the length of the vector containing the connected intra-zonal nodes

    def getConnSer(self, colCount):
	    return self.connNodeList[colCount-1] #returns the serial number of the connected internal node at this position

    def getConnReact(self, colCount):
        return self.connReactRec[colCount-1] #returns the serial number of the connected internal node at this position
"""

