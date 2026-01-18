from graphviz import Digraph

dot = Digraph('intervals', format='pdf')
dot.attr(rankdir='LR', size='20,10', dpi='300')
dot.attr('node', shape='box', style='filled,rounded')

intervals = [
    ('first', '''GenFirstBaseInterval
═══════════════════════
ADMM Network Consensus:
+ lambda_1, lambda_2: Array
+ rho: Float64
+ Pg_N_avg: Float64

APP Time Coupling:
+ B, D: Array
+ beta, gamma: Float64
+ Pg_nu, Pg_prev: Float64

Contingency Coupling:
+ BSC: Array[N]
+ gamma_sc: Float64
+ cont_count: Int64'''),
    ('middle', '''GenMiddleBaseInterval
═══════════════════════
(All First fields)
+ prev_interval: GenIntervals
+ next_interval: GenIntervals

Couples t-1, t, t+1'''),
    ('last', '''GenLastBaseInterval
═══════════════════════
(All First fields)
+ prev_interval: GenIntervals
+ terminal_constraint: Bool

Final time step''')
]

for node_id, label in intervals:
    dot.node(node_id, label, fillcolor='#F3E5F5', color='#7B1FA2', penwidth='3')

dot.edge('first', 'middle', label='PgNext\nAPP coupling', color='#7B1FA2', penwidth='3')
dot.edge('middle', 'last', label='PgNext\nAPP coupling', color='#7B1FA2', penwidth='3')

dot.render('03_intervals', cleanup=True)
print("✓ Created 03_intervals.pdf")