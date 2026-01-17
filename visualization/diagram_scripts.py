# Save as: generate_lascopf_diagrams.py
# Run: python generate_lascopf_diagrams.py
# Requires: pip install graphviz

from graphviz import Digraph

def create_diagram_1_foundation():
    """Layer 1: IS Foundation & PSY Base Types"""
    dot = Digraph(comment='Layer 1: Foundation', format='pdf')
    dot.attr(rankdir='TB', size='16,20', dpi='300', bgcolor='white')
    dot.attr('node', shape='record', style='filled,rounded', fontname='Arial')
    dot.attr('edge', fontname='Arial')
    
    # IS Base
    dot.node('IS_Base', 
             '''<
             <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#E3F2FD">
             <TR><TD COLSPAN="2"><B><FONT POINT-SIZE="18">IS.InfrastructureSystemsComponent</FONT></B></TD></TR>
             <TR><TD ALIGN="LEFT">+ name: String</TD><TD ALIGN="LEFT">UUID identification</TD></TR>
             <TR><TD ALIGN="LEFT">+ available: Bool</TD><TD ALIGN="LEFT">Availability status</TD></TR>
             <TR><TD ALIGN="LEFT">+ bus: Bus</TD><TD ALIGN="LEFT">Connected bus</TD></TR>
             <TR><TD ALIGN="LEFT">+ ext: Dict</TD><TD ALIGN="LEFT">Metadata storage</TD></TR>
             <TR><TD ALIGN="LEFT">+ internal: IS.Internal</TD><TD ALIGN="LEFT">Time series container</TD></TR>
             </TABLE>
             >''',
             shape='none')
    
    # PSY Generators
    generators = [
        ('PSY_Thermal', 'PSY.ThermalStandard', [
            '+ active_power: Float64',
            '+ reactive_power: Float64',
            '+ active_power_limits: (min, max)',
            '+ <B><FONT COLOR="red">operation_cost: ThermalGenerationCost</FONT></B>'
        ]),
        ('PSY_Renewable', 'PSY.RenewableDispatch', [
            '+ rating: Float64',
            '+ power_factor: Float64',
            '+ tech_type: TechType (WIND/SOLAR)',
            '+ <B><FONT COLOR="red">operation_cost: RenewableGenerationCost</FONT></B>'
        ]),
        ('PSY_Hydro', 'PSY.HydroEnergyReservoir', [
            '+ storage_capacity: Float64',
            '+ inflow: Float64',
            '+ initial_storage: Float64',
            '+ <B><FONT COLOR="red">operation_cost: HydroGenerationCost</FONT></B>'
        ]),
        ('PSY_Storage', 'PSY.GenericBattery', [
            '+ energy_capacity: Float64',
            '+ charge_efficiency: Float64',
            '+ discharge_efficiency: Float64',
            '+ <B><FONT COLOR="red">operation_cost: StorageCost</FONT></B>'
        ])
    ]
    
    for node_id, title, fields in generators:
        fields_html = ''.join(f'<TR><TD ALIGN="LEFT">{f}</TD></TR>' for f in fields)
        dot.node(node_id,
                f'''<
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#FFEBEE">
                <TR><TD><B><FONT POINT-SIZE="16">{title}</FONT></B></TD></TR>
                <TR><TD BGCOLOR="#E3F2FD"><I>Inherits: IS.Component</I></TD></TR>
                {fields_html}
                </TABLE>
                >''',
                shape='none')
        dot.edge('IS_Base', node_id, label='inherits', style='dashed', color='#1976D2', penwidth='2')
    
    dot.render('01_foundation_layer', cleanup=True)
    print("✓ Created: 01_foundation_layer.pdf")

def create_diagram_2_costs():
    """Layer 2: PSY Cost Types"""
    dot = Digraph(comment='Layer 2: Cost Types', format='pdf')
    dot.attr(rankdir='TB', size='18,12', dpi='300', bgcolor='white')
    dot.attr('node', shape='record', style='filled,rounded', fontname='Arial')
    
    costs = [
        ('Cost_Thermal', 'ThermalGenerationCost', [
            '+ variable: VariableCost{LinearCurve}',
            '+ fixed: Float64  # $/hr',
            '+ start_up: Float64  # $',
            '+ shut_down: Float64  # $'
        ], 'Coal, Gas, Nuclear generation'),
        ('Cost_Renewable', 'RenewableGenerationCost', [
            '+ variable: VariableCost{LinearCurve}',
            '+ fixed: Float64',
            '+ curtailment_cost: Float64  # $/MWh'
        ], 'Wind, Solar generation'),
        ('Cost_Hydro', 'HydroGenerationCost', [
            '+ variable: VariableCost{LinearCurve}',
            '+ fixed: Float64',
            '+ water_value: Float64  # $/m³'
        ], 'Hydroelectric generation'),
        ('Cost_Storage', 'StorageCost', [
            '+ charge_variable: VariableCost',
            '+ discharge_variable: VariableCost',
            '+ energy_cost: Float64  # $/MWh'
        ], 'Battery, pumped hydro')
    ]
    
    for node_id, title, fields, desc in costs:
        fields_html = ''.join(f'<TR><TD ALIGN="LEFT"><FONT FACE="monospace">{f}</FONT></TD></TR>' for f in fields)
        dot.node(node_id,
                f'''<
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#FFEBEE">
                <TR><TD><B><FONT POINT-SIZE="18" COLOR="#D32F2F">{title}</FONT></B></TD></TR>
                {fields_html}
                <TR><TD BGCOLOR="#FFF9C4"><I>{desc}</I></TD></TR>
                </TABLE>
                >''',
                shape='none')
    
    # Add VariableCost explanation
    dot.node('VariableCost',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#E8F5E9">
            <TR><TD><B><FONT POINT-SIZE="16">VariableCost</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">Linear: a₁·P + a₀</TD></TR>
            <TR><TD ALIGN="LEFT">Quadratic: a₂·P² + a₁·P + a₀</TD></TR>
            <TR><TD ALIGN="LEFT">Piecewise: segments[(MW, $/MWh)]</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    for cost_id, _, _, _ in costs:
        dot.edge(cost_id, 'VariableCost', label='uses', style='dotted', color='#388E3C')
    
    dot.render('02_cost_types_layer', cleanup=True)
    print("✓ Created: 02_cost_types_layer.pdf")

def create_diagram_3_intervals():
    """Layer 3: LASCOPF Interval Types"""
    dot = Digraph(comment='Layer 3: Interval Types', format='pdf')
    dot.attr(rankdir='LR', size='20,14', dpi='300', bgcolor='white')
    dot.attr('node', shape='record', style='filled,rounded', fontname='Arial')
    
    # GenFirstBaseInterval
    dot.node('Interval_First',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#F3E5F5">
            <TR><TD COLSPAN="2"><B><FONT POINT-SIZE="18" COLOR="#7B1FA2">GenFirstBaseInterval</FONT></B></TD></TR>
            <TR><TD BGCOLOR="#E1BEE7" COLSPAN="2"><B>ADMM Network Consensus</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ lambda_1: Array{Float64}</TD><TD>Dual variable (power balance)</TD></TR>
            <TR><TD ALIGN="LEFT">+ lambda_2: Array{Float64}</TD><TD>Dual variable (angle balance)</TD></TR>
            <TR><TD ALIGN="LEFT">+ rho: Float64</TD><TD>ADMM penalty parameter</TD></TR>
            <TR><TD ALIGN="LEFT">+ Pg_N_avg: Float64</TD><TD>Network average power</TD></TR>
            <TR><TD ALIGN="LEFT">+ thetag_N_avg: Float64</TD><TD>Network average angle</TD></TR>
            <TR><TD BGCOLOR="#E1BEE7" COLSPAN="2"><B>APP Time Coupling</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ B: Array{Float64}</TD><TD>Coupling matrix (current→next)</TD></TR>
            <TR><TD ALIGN="LEFT">+ D: Array{Float64}</TD><TD>Coupling matrix (prev→current)</TD></TR>
            <TR><TD ALIGN="LEFT">+ beta: Float64</TD><TD>APP penalty parameter</TD></TR>
            <TR><TD ALIGN="LEFT">+ gamma: Float64</TD><TD>APP penalty parameter</TD></TR>
            <TR><TD ALIGN="LEFT">+ Pg_nu: Float64</TD><TD>Auxiliary variable</TD></TR>
            <TR><TD ALIGN="LEFT">+ Pg_prev: Float64</TD><TD>Previous interval power</TD></TR>
            <TR><TD BGCOLOR="#E1BEE7" COLSPAN="2"><B>Contingency Coupling</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ BSC: Array{Float64}</TD><TD>Contingency coupling [N×1]</TD></TR>
            <TR><TD ALIGN="LEFT">+ gamma_sc: Float64</TD><TD>Security penalty</TD></TR>
            <TR><TD ALIGN="LEFT">+ lambda_1_sc: Array{Float64}</TD><TD>Security dual variables</TD></TR>
            <TR><TD ALIGN="LEFT">+ cont_count: Int64</TD><TD>Number of contingencies</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # GenMiddleBaseInterval
    dot.node('Interval_Middle',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#F3E5F5">
            <TR><TD><B><FONT POINT-SIZE="18" COLOR="#7B1FA2">GenMiddleBaseInterval</FONT></B></TD></TR>
            <TR><TD BGCOLOR="#E1BEE7"><B>All GenFirst fields</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ <B>prev_interval: GenIntervals</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ <B>next_interval: GenIntervals</B></TD></TR>
            <TR><TD BGCOLOR="#FFF9C4"><I>Couples time steps t-1, t, t+1</I></TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # GenLastBaseInterval
    dot.node('Interval_Last',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#F3E5F5">
            <TR><TD><B><FONT POINT-SIZE="18" COLOR="#7B1FA2">GenLastBaseInterval</FONT></B></TD></TR>
            <TR><TD BGCOLOR="#E1BEE7"><B>All GenFirst fields</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ <B>prev_interval: GenIntervals</B></TD></TR>
            <TR><TD ALIGN="LEFT">+ terminal_constraint: Bool</TD></TR>
            <TR><TD BGCOLOR="#FFF9C4"><I>Final time step with boundary</I></TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # Time sequence
    dot.edge('Interval_First', 'Interval_Middle', label='PgNext coupling\n(APP)', color='#7B1FA2', penwidth='3')
    dot.edge('Interval_Middle', 'Interval_Last', label='PgNext coupling\n(APP)', color='#7B1FA2', penwidth='3')
    
    # Algorithm explanation
    dot.node('Algorithm',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#FFF3E0">
            <TR><TD><B><FONT POINT-SIZE="16" COLOR="#F57C00">Nested ADMM/APP Algorithm</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT"><B>Outer (APP):</B> Time coupling via PgNext</TD></TR>
            <TR><TD ALIGN="LEFT"><B>Middle (ADMM):</B> Network consensus via Pg_N_avg</TD></TR>
            <TR><TD ALIGN="LEFT"><B>Inner (APP):</B> Security via BSC contingencies</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    dot.render('03_interval_types_layer', cleanup=True)
    print("✓ Created: 03_interval_types_layer.pdf")

def create_diagram_4_extended():
    """Layer 4: LASCOPF Extended Cost Types"""
    dot = Digraph(comment='Layer 4: Extended Costs', format='pdf')
    dot.attr(rankdir='TB', size='18,16', dpi='300', bgcolor='white')
    dot.attr('node', shape='record', style='filled,rounded', fontname='Arial')
    
    extended_costs = [
        ('Ext_Thermal', 'ExtendedThermalGenerationCost', 'Cost_Thermal', 'ThermalGenerationCost'),
        ('Ext_Renewable', 'ExtendedRenewableGenerationCost', 'Cost_Renewable', 'RenewableGenerationCost'),
        ('Ext_Hydro', 'ExtendedHydroGenerationCost', 'Cost_Hydro', 'HydroGenerationCost'),
        ('Ext_Storage', 'ExtendedStorageGenerationCost', 'Cost_Storage', 'StorageCost')
    ]
    
    for ext_id, ext_name, cost_id, cost_name in extended_costs:
        # PSY Cost (embedded)
        dot.node(cost_id,
                f'''<
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#FFEBEE">
                <TR><TD><B><FONT COLOR="#D32F2F">{cost_name}</FONT></B></TD></TR>
                <TR><TD>variable, fixed, etc.</TD></TR>
                </TABLE>
                >''',
                shape='none')
        
        # Interval (embedded)
        interval_id = f'{ext_id}_interval'
        dot.node(interval_id,
                '''<
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#F3E5F5">
                <TR><TD><B><FONT COLOR="#7B1FA2">GenFirstBaseInterval</FONT></B></TD></TR>
                <TR><TD>λ, ρ, β, γ, BSC, ...</TD></TR>
                </TABLE>
                >''',
                shape='none')
        
        # Extended Cost
        dot.node(ext_id,
                f'''<
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#E8F5E9">
                <TR><TD COLSPAN="2"><B><FONT POINT-SIZE="16" COLOR="#388E3C">{ext_name}</FONT></B></TD></TR>
                <TR><TD BGCOLOR="#FFEBEE"><B>thermal_cost_core:</B></TD><TD BGCOLOR="#FFEBEE">{cost_name}</TD></TR>
                <TR><TD BGCOLOR="#F3E5F5"><B>regularization_term:</B></TD><TD BGCOLOR="#F3E5F5">GenFirstBaseInterval</TD></TR>
                <TR><TD COLSPAN="2" BGCOLOR="#FFF9C4"><I>Combines PSY economics + ADMM/APP algorithm terms</I></TD></TR>
                </TABLE>
                >''',
                shape='none')
        
        dot.edge(cost_id, ext_id, label='embeds', color='#D32F2F', penwidth='2', style='dashed')
        dot.edge(interval_id, ext_id, label='embeds', color='#7B1FA2', penwidth='2', style='dashed')
    
    # Objective function explanation
    dot.node('Objective',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#E3F2FD">
            <TR><TD><B><FONT POINT-SIZE="16">Extended Cost Objective Function</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT"><B>Generation Cost:</B> variable(Pg) + fixed + start_up</TD></TR>
            <TR><TD ALIGN="LEFT"><B>ADMM Penalty:</B> (ρ/2)||Pg - Pg_N_avg||²</TD></TR>
            <TR><TD ALIGN="LEFT"><B>APP Coupling:</B> λ₁·Pg + (β/2)||Pg - Pg_nu||²</TD></TR>
            <TR><TD ALIGN="LEFT"><B>Security Coupling:</B> (γ_sc/2)Σᵢ||Pg - Pg_cont_i||²</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    for ext_id, _, _, _ in extended_costs:
        dot.edge(ext_id, 'Objective', style='dotted', color='gray')
    
    dot.render('04_extended_costs_layer', cleanup=True)
    print("✓ Created: 04_extended_costs_layer.pdf")

def create_diagram_5_solvers():
    """Layer 5: LASCOPF Solver Components"""
    dot = Digraph(comment='Layer 5: Solvers', format='pdf')
    dot.attr(rankdir='TB', size='18,14', dpi='300', bgcolor='white')
    dot.attr('node', shape='record', style='filled,rounded', fontname='Arial')
    
    # GenSolver
    dot.node('GenSolver',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#FFF3E0">
            <TR><TD COLSPAN="2"><B><FONT POINT-SIZE="20" COLOR="#F57C00">GenSolver</FONT></B></TD></TR>
            <TR><TD BGCOLOR="#F3E5F5"><B>interval_type:</B></TD><TD BGCOLOR="#F3E5F5">GenFirstBaseInterval</TD></TR>
            <TR><TD BGCOLOR="#E8F5E9"><B>cost_curve:</B></TD><TD BGCOLOR="#E8F5E9">Union{ExtendedThermal..., ...}</TD></TR>
            <TR><TD><B>model:</B></TD><TD>JuMP.Model</TD></TR>
            <TR><TD><B>variables:</B></TD><TD>Dict{Symbol, VariableRef}</TD></TR>
            <TR><TD><B>constraints:</B></TD><TD>Dict{Symbol, ConstraintRef}</TD></TR>
            <TR><TD COLSPAN="2" BGCOLOR="#E3F2FD"><I><B>Main optimization solver for generators</B></I></TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # Variables
    dot.node('Variables',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#E8EAF6">
            <TR><TD><B><FONT POINT-SIZE="16">Decision Variables</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">Pg: Active power output [MW]</TD></TR>
            <TR><TD ALIGN="LEFT">PgNext: Next interval power [MW]</TD></TR>
            <TR><TD ALIGN="LEFT">thetag: Generator bus angle [rad]</TD></TR>
            <TR><TD ALIGN="LEFT">ug: On/off status {0,1}</TD></TR>
            <TR><TD ALIGN="LEFT">vg: Start-up indicator {0,1}</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # Constraints
    dot.node('Constraints',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="8" BGCOLOR="#E8EAF6">
            <TR><TD><B><FONT POINT-SIZE="16">Constraints</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">Power limits: Pmin ≤ Pg ≤ Pmax</TD></TR>
            <TR><TD ALIGN="LEFT">Ramp up: PgNext - Pg ≤ R_up</TD></TR>
            <TR><TD ALIGN="LEFT">Ramp down: Pg - PgNext ≤ R_down</TD></TR>
            <TR><TD ALIGN="LEFT">Angle limits: θmin ≤ thetag ≤ θmax</TD></TR>
            <TR><TD ALIGN="LEFT">Min up/down time</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # LineSolver
    dot.node('LineSolver',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#FFF3E0">
            <TR><TD><B><FONT POINT-SIZE="18" COLOR="#F57C00">LineSolver</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">+ interval_type: LineIntervals</TD></TR>
            <TR><TD ALIGN="LEFT">+ line: PSY.Line</TD></TR>
            <TR><TD ALIGN="LEFT">+ model: JuMP.Model</TD></TR>
            <TR><TD ALIGN="LEFT">+ flow_variables: Dict</TD></TR>
            <TR><TD ALIGN="LEFT">+ angle_variables: Dict</TD></TR>
            <TR><TD BGCOLOR="#FFF9C4"><I>Power flow constraints P = B·θ</I></TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    # LoadSolver
    dot.node('LoadSolver',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#FFF3E0">
            <TR><TD><B><FONT POINT-SIZE="18" COLOR="#F57C00">LoadSolver</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">+ interval_type: LoadIntervals</TD></TR>
            <TR><TD ALIGN="LEFT">+ load: PSY.PowerLoad</TD></TR>
            <TR><TD ALIGN="LEFT">+ model: JuMP.Model</TD></TR>
            <TR><TD ALIGN="LEFT">+ curtailment_vars: Dict</TD></TR>
            <TR><TD BGCOLOR="#FFF9C4"><I>Demand response & load shedding</I></TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    dot.edge('GenSolver', 'Variables', label='creates', color='#1976D2', penwidth='2')
    dot.edge('GenSolver', 'Constraints', label='adds', color='#1976D2', penwidth='2')
    
    # JuMP + Ipopt
    dot.node('JuMP_Ipopt',
            '''<
            <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="10" BGCOLOR="#C8E6C9">
            <TR><TD><B><FONT POINT-SIZE="18">JuMP.Model + Ipopt</FONT></B></TD></TR>
            <TR><TD ALIGN="LEFT">Nonlinear optimization solver</TD></TR>
            <TR><TD ALIGN="LEFT">Interior point method</TD></TR>
            <TR><TD ALIGN="LEFT">Returns Pg*, θg*, objective value</TD></TR>
            </TABLE>
            >''',
            shape='none')
    
    for solver in ['GenSolver', 'LineSolver', 'LoadSolver']:
        dot.edge(solver, 'JuMP_Ipopt', label='optimize!', color='#388E3C', penwidth='2')
    
    dot.render('05_solver_components_layer', cleanup=True)
    print("✓ Created: 05_solver_components_layer.pdf")

def main():
    """Generate all diagrams"""
    print("Generating PowerLASCOPF.jl Layer Diagrams...")
    print("=" * 60)
    
    create_diagram_1_foundation()
    create_diagram_2_costs()
    create_diagram_3_intervals()
    create_diagram_4_extended()
    create_diagram_5_solvers()
    
    print("=" * 60)
    print("✓ All diagrams generated successfully!")
    print("\nGenerated files:")
    print("  01_foundation_layer.pdf      - IS & PSY base types")
    print("  02_cost_types_layer.pdf      - PSY cost structures")
    print("  03_interval_types_layer.pdf  - ADMM/APP intervals")
    print("  04_extended_costs_layer.pdf  - LASCOPF extended costs")
    print("  05_solver_components_layer.pdf - Solver components")
    print("\nTo convert to other formats:")
    print("  # PNG (300 DPI)")
    print("  convert -density 300 01_foundation_layer.pdf 01_foundation_layer.png")
    print("  # JPEG")
    print("  convert -density 300 01_foundation_layer.pdf 01_foundation_layer.jpg")

if __name__ == "__main__":
    main()
