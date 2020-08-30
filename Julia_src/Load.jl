# Member functions for class Load.
import os
import subprocess
import pandas as pd
import numpy as np
import json
import sys
import traceback
from Python_src.log import log
from Python_src.profiler import Profiler
from Python_src.node import Node

class Load(object):
	def __init__(self, idOfLoad, nodeConnl, Load_P): #constructor begins
		self.loadID = idOfLoad
		self.Pl = Load_P
		self.connNodelPtr = nodeConnl
		self.Thetal = 0.0
		#print("\nInitializing the parameters of the load with ID: {}".format(self.loadID))
		self.connNodelPtr.setlConn(idOfLoad, self.Pl) #increments the load connection variable to node
		self.setLoadData() #calls setLoadData member function to set the parameter values
		#constructor ends

	#def __del__(self): #destructor
		#print("\nThe load object having ID {} have been destroyed.\n".format(self.loadID))
		#end of destructor

	def getLoadID(self): #function getLoadID begins
		return self.loadID #returns the ID of the load object
		#end of getLoadID function

	def getLoadNodeID(self): #function getLoadNodeID begins
		return self.connNodelPtr.getNodeID() #returns the ID number of the node to which the load object is connected
		#end of getLoadNodeID function

	def setLoadData(self): #start setLoadLimits function
		self.v = 0.0 #Initialize the Lagrange multiplier corresponding voltage angle constraint to zero
		#end setLoadLimits function

	def pinitMessage(self): #function pinitMessage begins
		pinit = 0.0 #declare and initialize pinit
		pinit = pinit + self.connNodelPtr.npinitMessage(self.Pl) #passes to node object the power value to calculate the initial Pav
		#function pinitMessage ends

	def lpowerangleMessage(self, lRho, vprevavg, Aprevavg, vprev ): #function lpowerangleMessage begins
		self.Thetal = vprevavg + Aprevavg - vprev
		self.connNodelPtr.powerangleMessage(self.Pl, self.v, self.Thetal) #passes to node object the corresponding iterates of power, angle and v 
		#function lpowerangleMessage ends

	def calcPtilde(self): #function calcPtilde begins
		P_avg = self.connNodelPtr.PavMessage() #Gets average power from the corresponding node object
		Ptilde = self.Pl - P_avg #calculates the difference between power iterate and average
		return Ptilde #returns the difference
		#function calcPtilde ends

	def calcPavInit(self): #function calcPavInit begins
		return (self.Pl - self.connNodelPtr.devpinitMessage()) #seeks the initial Ptilde from the node 
		#function calcPavInit ends

	def getu(self): #function getu begins
		u = self.connNodelPtr.uMessage() #gets the value of the price corresponding to power balance from node
		#print("u: {}".format(u))
		return u #returns the price
		#function getu ends

	def calcThetatilde(self): #function calcThetatilde begins
		Theta_avg = self.connNodelPtr.ThetaavMessage() #get the average voltage angle at the particular node
		Theta_tilde = self.Thetal - Theta_avg #calculate the deviation between the voltage angle of the device and the average
		return Theta_tilde #return the deviation
		#function calcThetatilde ends

	def calcvtilde(self): #function calcvtilde begins
		v_avg = self.connNodelPtr.vavMessage() #get the average of the Lagrange multiplier corresponding to voltage angle balance 
		v_tilde = self.v - v_avg #calculate the deviation of the node Lagrange multiplier to the average
		return v_tilde #return the deviation 
		#function calcvtilde ends

	def getv(self): #function getv begins
		#print("v_initial: {}".format(v))
		self.v = self.v + self.calcThetatilde() #Calculate the value of the Lagrange multiplier corresponding to angle constraint
		#print("v_final: {}".format(v))
		return self.v #Calculate the value of the Lagrange multiplier corresponding to angle constraint
		#function getv ends	
	
