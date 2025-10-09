# Member functions for class transmissionLine

using PowerSystems

# Import necessary types from extended_system (for legacy compatibility)
# Define abstract types for PowerLASCOPF hierarchy

@kwdef mutable struct transmissionLine{T<:PSY.ACBranch} <: Device
	transl_type::T
	solver_line_base::LineSolverBase
	transl_id::Int64 = 0
	conn_nodet1_ptr::Node
	conn_nodet2_ptr::Node
	# ADMM+APP algorithm state variables (not redundant with PSY.ACBranch)
	cont_scen_tracker::Float64 = 0.0
	thetat1::Float64 = 0.0
	thetat2::Float64 = 0.0 
	pt1::Float64 = 0.0
	pt2::Float64 = 0.0
	v1::Float64 = 0.0
	v2::Float64 = 0.0
end

transmissionLine(transl_type, solver_line_base, conn_nodet1_ptr, conn_nodet2_ptr) = transmissionLine(;transl_type, solver_line_base=solver_line_base, conn_nodet1_ptr=conn_nodet1_ptr, conn_nodet2_ptr=conn_nodet2_ptr)

# Legacy constructor for compatibility with old calling patterns
function transmissionLine(transl_id::Int, conn_nodet1_ptr::Node, conn_nodet2_ptr::Node, pt_max::Float64, react::Float64, rest::Float64, cont_scen_tracker::Float64)
    # Create a basic PSY.Line object from the provided parameters
    # In production code, this should be replaced with actual PSY.ACBranch objects from the system
    
    # Create minimal bus objects for the Arc
    bus1 = PSY.Bus(get_node_id(conn_nodet1_ptr), "Legacy_Bus_$(get_node_id(conn_nodet1_ptr))", "PQ", 0, 1.0, (min=0.9, max=1.1), 230, nothing, nothing)
    bus2 = PSY.Bus(get_node_id(conn_nodet2_ptr), "Legacy_Bus_$(get_node_id(conn_nodet2_ptr))", "PQ", 0, 1.0, (min=0.9, max=1.1), 230, nothing, nothing)
    
    arc = PSY.Arc(from=bus1, to=bus2)
    
    # Create PSY.Line with the provided parameters
    psy_line = PSY.Line(
        "Legacy_Line_$transl_id",  # name
        true,                       # available
        0.0,                       # active_power_flow
        0.0,                       # reactive_power_flow
        arc,                       # arc
        rest,                      # r (resistance)
        react,                     # x (reactance)
        (from=0.0, to=0.0),       # b (susceptance)
        pt_max,                    # rate
        (min=-pt_max, max=pt_max) # angle_limits
    )
    
    # Create a default LineSolverBase
    solver_base = LineSolverBase(
        lambda_txr = [0.0],
        interval_type = MockLineInterval(),
        E_coeff = [1.0],
        Pt_next_nu = [0.0],
        BSC = [0.0],
        E_temp_coeff = reshape([0.1], 1, 1),
        RND_int = 1,
        cont_count = 1
    )
    
    # Create the transmissionLine object
    return transmissionLine(
        transl_type = psy_line,
        solver_line_base = solver_base,
        transl_id = transl_id,
        conn_nodet1_ptr = conn_nodet1_ptr,
        conn_nodet2_ptr = conn_nodet2_ptr,
        cont_scen_tracker = cont_scen_tracker,
        thetat1 = 0.0,
        thetat2 = 0.0,
        pt1 = 0.0,
        pt2 = 0.0,
        v1 = 0.0,
        v2 = 0.0
    )
end

# Accessor functions to get data from the PSY.ACBranch object (eliminates redundancy)
get_reactance(transline::transmissionLine) = PSY.get_x(transline.transl_type)
get_resistance(transline::transmissionLine) = PSY.get_r(transline.transl_type)
get_flow_limit(transline::transmissionLine) = PSY.get_rate(transline.transl_type)
get_available(transline::transmissionLine) = PSY.get_available(transline.transl_type)

# Legacy accessor function (for compatibility)
getReactance(transline::transmissionLine) = get_reactance(transline)


function assign_conn_nodes(transline::transmissionLine)
	from_node = get_node_id(transline.conn_nodet1_ptr)
	to_node = get_node_id(transline.conn_nodet2_ptr)
	reactance = get_reactance(transline)
	set_t_conn!(transline.conn_nodet1_ptr, transline.transl_id, 1, reactance, to_node, transline.cont_scen_tracker) #increments the txr line connection variable to node 1
	set_t_conn!(transline.conn_nodet2_ptr, transline.transl_id, -1, reactance, from_node, transline.cont_scen_tracker) #increments the txr line connection variable to node 2
	set_tran_data(transline) #calls setTranData member function to set the parameter values
end

function get_outage_scenario(transline::transmissionLine)
	return transline.cont_scen_tracker #returns scenario in which the line is outaged
end

function get_transl_id(transline::transmissionLine) #function gettranslID begins
	return transline.transl_id #returns the ID of the generator object
end

function get_transl_node_id1(transline::transmissionLine) #function getGenNodeID begins
	return get_node_id(transline.conn_nodet1_ptr) #returns the ID number of the node to which the generator object is connected
	# end of getGenNodeID function
end

function get_transl_node_id2(transline::transmissionLine) #function getGenNodeID begins
	return get_node_id(transline.conn_nodet2_ptr) #returns the ID number of the node to which the generator object is connected
	#end of getGenNodeID function
end

function set_tran_data(transline::transmissionLine) #member function to set parameter values of transmission lines
	transline.thetat1 = 0.0 #Initialize the angle iterate at end-1
	transline.thetat2 = 0.0 #Initialize the angle iterate at end-2
	transline.pt1 = 0.0 #Initialize the power iterate at end-1
	transline.pt2 = 0.0 #Initialize the power iterate at end-2
	transline.v1 = 0.0 #Initialize the Lagrange multiplier corresponding to end-1 voltage angle constraint to zero
	transline.v2 = 0.0 #Initialize the Lagrange multiplier corresponding to end-2 voltage angle constraint to zero
	#end function for setting parameter values
end

function tpowerangle_message(transline::transmissionLine, tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1,  Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2) #function tpowerangleMessage begins
	#tranSolver.mainsolve( tRho, Pprevit1, Pnetavg1, uprev1, vprevavg1, Aprevavg1, vprev1, Pprevit2, Pnetavg2, uprev2, vprevavg2, Aprevavg2, vprev2 ); // calls the transmission line optimization solver
	reactance = get_reactance(transline)
	flow_limit = get_flow_limit(transline)
	
	end1A = reactance * (Pprevit1 - Pnetavg1 - uprev1) #end-1 power parameter (refer to the derivation)
	end1B = (vprevavg1 + Aprevavg1 - vprev1) #end-1 voltage angle parameter (refer to the derivation)
	end2C = reactance * (Pprevit2 - Pnetavg2 - uprev2) #end-2 power parameter (refer to the derivation)
	end2D = (vprevavg2 + Aprevavg2 - vprev2) #end-2 angle parameter (refer to the derivation)
	#double Pt1 = tranSolver.getPSol1(); // get the transmission line end-1 Power iterate
	#double Thetat1 = tranSolver.getThetaSol1(); // get the transmission line end-1 voltage angle iterate
	#double Pt2 = tranSolver.getPSol2(); // get the transmission line end-2 Power iterate
	#double Thetat2 = tranSolver.getThetaSol2(); // get the transmission line end-2 voltage angle iterate
	if get_transl_node_id1(transline) == 1 #if end-1 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
		transline.thetat1 = 0.0
		Diff = ((reactance ^ 2) * end2D + end1A - end2C) / ( 2.0 + reactance ^ 2  ) #difference between the bus voltage angles
	else
		if get_transl_node_id2(transline) == 1 # if end-2 is the bus-1, or, slack bus, fix the voltage angle of that end to 0
			transline.thetat1 = ((reactance ^ 2.0) * end1B - end1A + end2C) / (2.0 + (reactance ^ 2))
		else #if none of the ends is the slack bus, consider both the voltage angles as decision variables and calculate them
			transline.thetat1 = ((2.0 + (reactance ^ 2)) * end1B  - end1A + end2C + (2.0 * end2D)) / (4.0 + (reactance ^ 2)) #Thetat1 iterate
			Diff = ( ( 2.0 * end1A ) - (reactance ^ 2) * end1B - ( 2.0 * end2C ) + (reactance ^ 2) * end2D ) / ( 4.0 + (reactance ^ 2) ) #Magnitude of the difference between the angles at the ends of the transmission line
		end
	end
	Limit = reactance * flow_limit #Upper limit of the power flow limit scaled by reactance
	Obj1 = ( Limit - end1A ) * ( Limit - end1A ) + ( Limit + end2C ) * ( Limit + end2C ) + reactance * reactance * ( transline.thetat1 - end1B ) * ( transline.thetat1 - end1B ) + reactance * reactance * ( transline.thetat1 + Limit - end2D ) * ( transline.thetat1 + Limit - end2D ) #Objective on assumption that difference between angles is equal to upper limit allowed
	Obj2 = ( -Limit - end1A ) * ( -Limit - end1A ) + ( -Limit + end2C ) * ( -Limit + end2C ) + reactance * reactance * ( transline.thetat1 - end1B ) * ( transline.thetat1 - end1B ) + reactance * reactance * ( transline.thetat1 - Limit - end2D ) * ( transline.thetat1 - Limit - end2D ) #Objective on assumption that difference between angles is equal to lower limit allowed
		if ( Diff <= Limit ) && ( Diff >= -Limit ) #If the power flow and consequently the angle difference is well within allowed limits
			Obj3 = ( Diff - end1A ) * ( Diff - end1A ) + ( Diff + end2C ) * ( Diff + end2C ) + reactance * reactance * ( transline.thetat1 - end1B ) * ( transline.thetat1 - end1B ) + reactance * reactance * ( transline.thetat1 + Diff - end2D ) * ( transline.thetat1 + Diff - end2D ) #Objective on assumption that Difference between angles lies well within the allowed limits
			Obj = (Obj1 < Obj3 ? Obj1 : Obj3) < Obj2 ? (Obj1 < Obj3 ? Obj1 : Obj3) : (Obj2 < Obj3 ? Obj2 : Obj3)
			if Obj == Obj1 # if Diff == Limit gives the lowest objective
				if get_transl_node_id2(transline) == 1 #check if end-2 is slack bus
					transline.thetat2 = 0.0 #in that case fix the corresponding angle to zero
					transline.thetat1 = transline.thetat2 - Limit #adjust the end-1 angle accordingly
				else #if end-2 is not the slack bus
					transline.thetat2 = transline.thetat1 + Limit #adjust the end-2 angle accordingly
				end
			else
				if Obj == Obj2 #if Diff == -Limit gives the lowest objective
					if get_transl_node_id2(transline) == 1 #check if end-2 is slack bus
						transline.thetat2 = 0.0 #in that case fix the corresponding angle to zero
						transline.thetat1 = transline.thetat2 + Limit #adjust the end-1 angle accordingly
					else #if end-2 is not the slack bus
						transline.thetat2 = transline.thetat1 - Limit #adjust the end-2 angle accordingly
					end
				else #if an intermediate value of Diff gives the lowest objective
					if get_transl_node_id2(transline) == 1 #check if end-2 is slack bus
						transline.thetat2 = 0.0 #in that case fix the corresponding angle to zero
						transline.thetat1 = transline.thetat2 - Diff #adjust the end-1 angle accordingly
					else #if end-2 is not the slack bus
						transline.thetat2 = transline.thetat1 + Diff #adjust the end-2 angle accordingly
					end
				end
			end
		else #if value of Diff that minimizes the objective falls outside the range
			Obj = Obj1 < Obj2 ? Obj1 : Obj2 #check the objective value at the two limit points
			if Obj == Obj1 # if Diff == Limit gives the lowest objective
				if get_transl_node_id2(transline) == 1 #check if end-2 is the slack bus
					transline.thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					transline.thetat1 = transline.thetat2 - Limit #adjust the angle of end-1 accordingly
				else #if end-2 is not the slack bus
					transline.thetat2 = transline.thetat1 + Limit #adjust the end-2 angle accordingly
				end
			else #if Diff == -Limit gives the lowest objective
				if get_transl_node_id2(transline) == 1 # check if end-2 is the slack bus
					transline.thetat2 = 0.0 #in that case set the voltage angle of that end to zero
					transline.thetat1 = transline.thetat2 + Limit #adjust the angle of end-1 accordingly
				else #if end-2 is not the slack bus
					transline.thetat2 = transline.thetat1 - Limit #adjust the end-2 angle accordingly
				end
			end
		end
		#whichever objective is the minimum, consider that value of angle difference as the optimizer
		transline.pt2 = (transline.thetat1 - transline.thetat2) / reactance #get the transmission line end-2 Power iterate
		transline.pt1 = (transline.thetat2 - transline.thetat1) / reactance #get the transmission line end-2 voltage angle iterate
		power_angle_message!(transline.conn_nodet1_ptr, transline.pt1, transline.v1, transline.thetat1) #passes to node object at end 1 the corresponding iterates of power, angle and v
		power_angle_message!(transline.conn_nodet2_ptr, transline.pt2, transline.v2, transline.thetat2) #passes to node object at end 2 the corresponding iterates of power, angle and v
		#function tpowerangleMessage ends
end

function futureMessageBase(transline::transmissionLine, lambda_TXR, ECoeff, PgNextNu, BSC, ETempCoeff, lineTempCalc)
end
		
function tpowerFutureMessage(transline::transmissionLine, tRho)
end # For the upcoming interval, opinions about RND flows		

function translPower1(transline::transmissionLine) #function translPower1 begins
	return transline.pt1 #returns the pt1 iterate (fixed property name)
	#function translPower1 ends
end

function translPower2(transline::transmissionLine) #function translPower2 begins
	return transline.pt2 #returns the pt2 iterate (fixed property name)
	#function translPower2 ends
end

function calcPtilde1(transline::transmissionLine) #function calcPtilde1 begins
	P_avg1 = p_avg_message(transline.conn_nodet1_ptr) #Gets average power for end-1 from the corresponding node object
	if P_avg1 !== nothing
		Ptilde1 = transline.pt1 - P_avg1 #calculates the difference between power iterate and average
		return Ptilde1 #returns the difference
	else
		return 0.0
	end
	#function calcPtilde1 ends
end

function calcPavInit1(transline::transmissionLine) #function calcPavInit1 begins
	return dev_p_init_message(transline.conn_nodet1_ptr) #seeks the initial Ptilde from the node at end 1
	#function calcPavInit1 ends
end

function calcPtilde2(transline::transmissionLine) #function calcPtilde2 begins
	P_avg2 = p_avg_message(transline.conn_nodet2_ptr) #Gets average power for end-2 from the corresponding node object
	if P_avg2 !== nothing
		Ptilde2 = transline.pt2 - P_avg2 #calculates the difference between power iterate and average
		return Ptilde2 #returns the difference
	else
		return 0.0
	end
	#function calcPtilde2 ends
end

function calcPavInit2(transline::transmissionLine) #function calcPavInit2 begins
	return dev_p_init_message(transline.conn_nodet2_ptr) #seeks the initial Ptilde from the node at end 2
	#function calcPavInit2 ends
end

function getu1(transline::transmissionLine) #function getu1 begins
	u1 = u_message!(transline.conn_nodet1_ptr) #gets the value of the price corresponding to power balance from node
	#print("u1: {}".print(u1))
	return u1 !== nothing ? u1 : 0.0 #returns the price
	#function getu1 ends
end

function getu2(transline::transmissionLine) #function getu2 begins
	u2 = u_message!(transline.conn_nodet2_ptr) #gets the value of the price corresponding to power balance from node
	#print("u2: {}".format(u2))
	return u2 !== nothing ? u2 : 0.0 #returns the price
	#function getu2 ends
end

function calcThetatilde1(transline::transmissionLine) #function calcThetatilde1 begins
	Theta_avg1 = theta_avg_message(transline.conn_nodet1_ptr) #get the average voltage angle at the particular node
	if Theta_avg1 !== nothing
		Theta_tilde1 = transline.thetat1 - Theta_avg1 #claculate the deviation between the voltage angle of the device and the average
		return Theta_tilde1 #return the deviation
	else
		return 0.0
	end
	#function calcThetatilde1 ends
end

function calcThetatilde2(transline::transmissionLine) #function calcThetatilde2 begins
	Theta_avg2 = theta_avg_message(transline.conn_nodet2_ptr) #get the average voltage angle at the particular node
	if Theta_avg2 !== nothing
		Theta_tilde2 = transline.thetat2 - Theta_avg2 #claculate the deviation between the voltage angle of the device and the average
		return Theta_tilde2 #return the deviation
	else
		return 0.0
	end
	#function calcThetatilde2 ends
end

function calcvtilde1(transline::transmissionLine) #function calcvtilde1 begins
	v_avg1 = v_avg_message(transline.conn_nodet1_ptr) #get the average of the Lagrange multiplier corresponding to voltage angle balance
	if v_avg1 !== nothing
		v_tilde1 = transline.v1 - v_avg1 #calculate the deviation of the node Lagrange multiplier to the average
		return v_tilde1 #return the deviation
	else
		return 0.0
	end
	#function calcvtilde1 ends
end

function calcvtilde2(transline::transmissionLine) #function calcvtilde2 begins
	v_avg2 = v_avg_message(transline.conn_nodet2_ptr) #get the average of the Lagrange multiplier corresponding to voltage angle balance
	if v_avg2 !== nothing
		v_tilde2 = transline.v2 - v_avg2 #calculate the deviation of the node Lagrange multiplier to the average
		return v_tilde2 #return the deviation
	else
		return 0.0
	end
	#function calcvtilde2 ends
end

function getv1(transline::transmissionLine) #function getv1 begins
	#print("v1_initial: {}".format(v1))
	transline.v1 = transline.v1 + calcThetatilde1(transline) #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v1_final: {}".format(v1))
	return transline.v1 #return the voltage angle price
	#function getv1 ends
end

function getv2(transline::transmissionLine) #function getv2 begins
	#print("v2_initial: {}".format(v2))
	transline.v2 = transline.v2 + calcThetatilde2(transline) #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#print("v2_final: {}".format(v2))
	return transline.v2 #Calculate the value of the Lagrange multiplier corresponding to angle constraint
	#function getv2 ends
end

function getReactance(transline::transmissionLine)
	return get_reactance(transline)
end
