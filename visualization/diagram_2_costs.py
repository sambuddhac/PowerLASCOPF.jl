from graphviz import Digraph

dot = Digraph('costs', format='pdf')
dot.attr(rankdir='LR', size='18,12', dpi='300')
dot.attr('node', shape='box', style='filled,rounded')

costs = [
    ('thermal_cost', 'ThermalGenerationCost', '''+ variable: VariableCost
+ fixed: Float64
+ start_up: Float64
+ shut_down: Float64'''),
    ('renew_cost', 'RenewableGenerationCost', '''+ variable: VariableCost
+ fixed: Float64
+ curtailment_cost: Float64'''),
    ('hydro_cost', 'HydroGenerationCost', '''+ variable: VariableCost
+ fixed: Float64
+ water_value: Float64'''),
    ('storage_cost', 'StorageCost', '''+ charge_variable: VariableCost
+ discharge_variable: VariableCost
+ energy_cost: Float64''')
]

for node_id, title, fields in costs:
    dot.node(node_id, f'{title}\n{"─"*20}\n{fields}', 
             fillcolor='#FFEBEE', color='#D32F2F', penwidth='3')

dot.node('var_cost', '''VariableCost
────────────
Linear: a₁·P + a₀
Quadratic: a₂·P² + a₁·P + a₀
Piecewise: segments''',
         fillcolor='#E8F5E9', color='#388E3C', penwidth='3')

for cost_id, _, _ in costs:
    dot.edge(cost_id, 'var_cost', label='uses', style='dotted')

dot.render('02_cost_types', cleanup=True)
print("✓ Created 02_cost_types.pdf")