from graphviz import Digraph

dot = Digraph('solvers', format='pdf')
dot.attr(rankdir='TB', size='16,12', dpi='300')
dot.attr('node', shape='box', style='filled,rounded')

solvers = [
    ('gensolver', '''GenSolver
════════════════════════
+ interval_type: GenFirstBaseInterval
+ cost_curve: ExtendedThermal...
+ model: JuMP.Model
+ variables: Dict
+ constraints: Dict
────────────────────────
Main generator optimizer'''),
    ('linesolver', '''LineSolver
════════════════════════
+ interval_type: LineIntervals
+ line: PSY.Line
+ model: JuMP.Model
+ flow_variables: Dict
────────────────────────
Power flow constraints'''),
    ('loadsolver', '''LoadSolver
════════════════════════
+ interval_type: LoadIntervals
+ load: PSY.PowerLoad
+ model: JuMP.Model
+ curtailment_vars: Dict
────────────────────────
Demand response''')
]

for node_id, label in solvers:
    dot.node(node_id, label, fillcolor='#FFF3E0', color='#F57C00', penwidth='3')

dot.node('jump', '''JuMP.Model + Ipopt
══════════════════
Nonlinear optimization
Interior point method
Returns Pg*, θg*''',
         fillcolor='#C8E6C9', color='#388E3C', penwidth='3')

for solver_id, _ in solvers:
    dot.edge(solver_id, 'jump', label='optimize!', color='#388E3C', penwidth='2')

dot.render('05_solvers', cleanup=True)
print("✓ Created 05_solvers.pdf")