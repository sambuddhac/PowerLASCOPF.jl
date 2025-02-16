mutable struct Node{T<:Bus} <: Subsystem
	node_type::T
	node_id::Int
	g_conn_number::Int
	t_conn_number::Int
	l_conn_number::Int
	P_avg::Float64
	theta_avg::Float64
	conn_load_val::Float64
	u::Float64
	v_avg::Float64
	P_dev_count::Int
	P_init_avg::Float64
	contingency_scenarios::Int
	node_flag::Int
	gen_serial_num::Vector{Int}
	from_react::Float64
	to_react::Float64
	react_cont::Vector{Float64}
	conn_node_list::Vector{Node}
	conn_react_rec::Vector{Float64}
	tran_from_serial::Vector{Int}
	tran_to_serial::Vector{Int}
	load_serial_num::Vector{Int}
	cont_scen_list::Vector{Int}
	scen_node_list::Vector{Int}

    	function Node(node_id::Int, number_of_scenarios::Int)
		node = Node(node_id, number_of_scenarios)
		
		node.node_id = node_id
		node.g_conn_number = 0
		node.t_conn_number = 0
		node.l_conn_number = 0
		node.node_flag = 0
		node.from_react = 0.0
		node.to_react = 0.0
		node.p_dev_count = 0
		node.p_avg = 0.0
		node.theta_avg = 0.0
		node.u = 0.0
		node.v_avg = 0.0
		node.P_init_avg = 0.0
		return node
    	end
end

get_node_id(node::Node) = node.node_id

function setgconn(node::Node, serial_of_gen::Int)
	node.g_conn_number += 1
	push!(node.gen_serial_num, serial_of_gen)
end
get_gen_length(node::Node) = node.g_conn_number
getGenSer(node::Node, colCount::Int) = node.gen_serial_num[colCount]
    
function sett_conn(node::Node, tran_id::Int, dir::Int, react::Float64, rank_of_other::Int, scenario_tracker::Int)
	node.t_conn_number += 1
	if scenarioTracker != 0
	    push!(node.cont_scen_list, scenarioTracker)
	end
	if dir == 1
	    push!(node.tran_from_serial, tranID)
	    node.from_react += 1 / react
	    if scenarioTracker != 0
		push!(node.react_cont, -1 / react)
		push!(node.scen_node_list, rankOfOther)
	    end
	    pos = findfirst(x -> x == rankOfOther, node.conn_node_list)
	    if pos != nothing
		node.conn_react_rec[pos] -= 1 / react
	    else
		push!(node.conn_node_list, rankOfOther)
		push!(node.conn_react_rec, -1 / react)
	    end
	else
	    push!(node.tran_to_serial, tranID)
	    node.to_react -= 1 / react
	    if scenarioTracker != 0
		push!(node.react_cont, 1 / react)
		push!(node.scen_node_list, rankOfOther)
	    end
	    pos = findfirst(x -> x == rankOfOther, node.conn_node_list)
	    if pos != nothing
		node.conn_react_rec[pos] += 1 / react
	    else
		push!(node.conn_node_list, rankOfOther)
		push!(node.conn_react_rec, 1 / react)
	    end
	end
end
function getto_react(node::Node, scenarioTracker::Int)
	pos = findfirst(x -> x == scenarioTracker, node.cont_scen_list)
	if pos != nothing
	    if node.react_cont[pos] > 0
		return node.to_react + node.react_cont[pos]
	    else
		return node.to_react
	    end
	end
	return node.to_react
end
function getfrom_react(node::Node, scenarioTracker::Int)
	pos = findfirst(x -> x == scenarioTracker, node.cont_scen_list)
	if pos != nothing
	    if node.react_cont[pos] <= 0
		return node.from_react + node.react_cont[pos]
	    else
		return
    





#!/usr/bin/env python3
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
		self.contingency_scenarios = numberOfScenarios
		#print("\nInitializing the parameters of the node with ID: {}".format(nodeID))
		#initialize the connected devices to zero for node
		self.g_conn_number = 0 #number of generators connected to a particular node
		self.t_conn_number = 0 #number of transmission lines connected to a particular node
		self.l_conn_number = 0 #number of loads connected to a particular node
		self.node_flag = 0 #flag to indicate if a particular node has been accounted for by any one device connected to it for calculation of u 
		self.from_react = 0.0 #Initialize the from reactance
		self.to_react = 0.0 #Initialize the to reactance
		self.P_dev_count = 0 #initialize number of devices connectedto a node to zero
		self.P_avg = 0.0 #Initialize average power to zero
		self.theta_avg = 0.0 #initialize average angle to zero
		self.u = 0.0 #initialize power balance price to zero
		self.v_avg = 0.0 #initialize average value of voltage angle price to zero
		self.P_init_avg = 0.0 #initialize initial average power to zero
		self.gen_serial_num = []
		self.cont_scen_list = []
		self.tran_from_serial = []
		self.tran_to_serial = []
		self.load_serial_num = []
		self.react_cont = []
		self.scen_node_list = []
		self.conn_node_list = []
		self.conn_react_rec = []
		#constructor ends

	#def __del__(self): #destructor
		#print("\nThe node object having ID {} have been destroyed.\n".format(nodeID))
		#end of destructor

	def getNodeID(self): #function getNodeID begins
		return self.nodeID #returns node ID to the caller 
		#end of function getNodeID

	def setgConn(self, serialOfGen):
		self.g_conn_number += 1 #increment the number of generators connected by one whenever a generator is connected to the node
		self.gen_serial_num.append(serialOfGen) #records the serial number of the generator connected to the node 

	def getGenLength(self):
		return self.g_conn_number #returns the number of connected generators

	def getGenSer(self, colCount):
		return self.gen_serial_num[colCount - 1]

	def settConn(self, tranID, dir, react, rankOfOther, scenarioTracker):
		t_conn_number += 1 #increment the number of txr lines connected by one whenever a txr line is connected to the node
		if self.scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
			self.cont_scen_list.append(scenarioTracker) #Store those scenario numbers in the cont_scen_list vector
		if dir == 1:
			self.tran_from_serial.append(tranID)
			self.from_react += (1/react)
			if scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
				self.react_cont.append(-(1/react))
				self.scen_node_list.append(rankOfOther)
			elif rankOfOther in self.conn_node_list: # If predecided Gen value is given for this particular Powergenerator
				pos = self.conn_node_list.index(rankOfOther) #find the position of the Powergenerator in the chart of predecided values
				self.conn_react_rec[pos] -= 1/react
			else:
				self.conn_node_list.append(rankOfOther)
				self.conn_react_rec.append(-1/react)
		else:
			self.tran_to_serial.append(tranID)
			self.to_react -= (1/react)
			if scenarioTracker != 0: #If the lines connected to this node are outaged in some contingency scenarios
				self.react_cont.append(1/react)
				self.scen_node_list.append(rankOfOther)
			elif rankOfOther in self.conn_node_list: #If predecided Gen value is given for this particular Powergenerator
				pos = self.conn_node_list.index(rankOfOther) #find the position of the Powergenerator in the chart of predecided values
				self.conn_react_rec[pos] += 1/react
			else:
				self.conn_node_list.append(rankOfOther)
				self.conn_react_rec.append(1/react)

	def getto_react(self, scenarioTracker):
		if scenarioTracker in self.cont_scen_list:
			pos = self.cont_scen_list.index(scenarioTracker)
			if self.react_cont[pos] > 0:
				return self.to_react + self.react_cont[pos]
			else:
				return self.to_react
		return self.to_react #return the total reciprocal of reactances for which this is the to node

	def getfrom_react(self, scenarioTracker):
		if scenarioTracker in self.cont_scen_list:
			pos = self.cont_scen_list.index(scenarioTracker)
			if self.react_cont[pos] <= 0:
				return self.from_react + self.react_cont[pos]
			else:
				return self.from_react
		return self.from_react #return the total reciprocal of reactances for which this is the from node

	def getConNodeLength(self):
		return self.conn_node_list.size() #returns the length of the vector containing the connected intra-zonal nodes

	def getConnSer(self, colCount):
		return self.conn_node_list[colCount-1] #returns the serial number of the connected internal node at this position

	def getConnSerScen(self, scenarioTracker):
		if scenarioTracker in self.cont_scen_list:
			pos = self.cont_scen_list.index(scenarioTracker)
			return self.scen_node_list[pos]
		else:
			return 0 #returns the serial number of the connected internal node at this position

	def getConnReact(self, colCount):
	    return self.conn_react_rec[colCount-1] #returns the serial number of the connected internal node at this position

	def getConnReactCompensate(self, scenarioTracker):
	    if scenarioTracker in self.cont_scen_list:
		    pos = self.cont_scen_list.index(scenarioTracker)
		    return self.react_cont[pos]
	    else:
		    return 0 #returns the serial number of the connected internal node at this position

	def setlConn(self, lID, loadVal):
		self.l_conn_number += 1 #increment the number of loads connected by one whenever a load is connected to the node
		self.load_serial_num.append(lID)
		self.conn_load_val = loadVal #total connected loads

	def getLoadVal(self):
		return self.conn_load_val #Returns the value of the connected load

	def npinitMessage(self, Pload): #function npinitMessage begins
		self.P_init_avg += Pload / (self.g_conn_number + self.t_conn_number + self.l_conn_number) #calculate average power
		return self.P_init_avg #return initial average power
		#function npinitMessage ends

	def devpinitMessage(self): #function devpinitMessage begins
		return self.P_init_avg #return the initial average node power imbalance to the devices
		#function devpinitMessage ends

	def powerangleMessage(self, Power, AngPrice, Angle): #function powerangleMessage begins
		self.P_avg += Power / (self.g_conn_number + self.t_conn_number + self.l_conn_number) #calculate average power
		#v_avg = v_avg + AngPrice / ( g_conn_number + t_conn_number + l_conn_number ) #calculate average voltage angle price
		self.theta_avg += Angle / (self.g_conn_number + self.t_conn_number + self.l_conn_number) #calculate average voltage angle
		self.P_dev_count += 1 #increment device count by one indicating that a particular device connected to the node has been taken into account
		#function powerangleMessage ends

	def PavMessage(self): #function PavMessage begins
		if self.P_dev_count == self.g_conn_number + self.t_conn_number + self.l_conn_number: #if all the devices are taken care of return the average power
			return self.P_avg
		#function PavMessage ends

	def uMessage(self): #function uMessage begins
		if self.node_flag != 0:
			#cout << node_flag << endl;
			return self.u
		else:
			if self.P_dev_count == self.g_conn_number + self.t_conn_number + self.l_conn_number:
				self.u = self.u + self.P_avg
				#cout << node_flag << endl;
				node_flag += 1 #this node has already been accounted for
				return self.u # if all the devices are taken care of calculate and return the power price
		#function uMessage ends

	def ThetaavMessage(self): #function ThetaavMessage begins
		if self.P_dev_count == self.g_conn_number + self.t_conn_number + self.l_conn_number:
			return self.theta_avg #if all the devices are taken care of return the average angle
		# function ThetaavMessage ends

	def vavMessage(self): #function vavMessage begins
		if self.P_dev_count == self.g_conn_number + self.t_conn_number + self.l_conn_number:
			return self.v_avg #if all the devices are taken care of return the average angle price
		#function vavMessage ends

	def reset(self): #function reset begins
		self.P_dev_count = 0
		self.P_avg = 0.0
		self.v_avg = 0.0
		self.theta_avg = 0.0
		self.node_flag = 0
        #function reset ends
"""
    def getGenSer(self, colCount):
	    return self.gen_serial_num.at(colCount-1)

    def getto_react(self, contingency):
	    return self.to_react.at(contingency) #return the total reciprocal of reactances for which this is the to node

    def getfrom_react(self, contingency):
	    return self.from_react.at(contingency) #return the total reciprocal of reactances for which this is the from node

    def getConNodeLength(self, contingency):
	    return self.conn_node_list.size() #returns the length of the vector containing the connected intra-zonal nodes

    def getConnSer(self, colCount):
	    return self.conn_node_list[colCount-1] #returns the serial number of the connected internal node at this position

    def getConnReact(self, colCount):
        return self.conn_react_rec[colCount-1] #returns the serial number of the connected internal node at this position
"""

