from graphviz import Digraph

dot = Digraph('extended', format='pdf')
dot.attr(rankdir='TB', size='16,14', dpi='300')
dot.attr('node', shape='box', style='filled,rounded')

extended = [
    ('ext_thermal', 'ExtendedThermalGenerationCost', 'thermal_gen_cost', 'interval'),
    ('ext_renewable', 'ExtendedRenewableGenerationCost', 'renew_gen_cost', 'interval'),
    ('ext_hydro', 'ExtendedHydroGenerationCost', 'hydro_gen_cost', 'interval'),
    ('ext_storage', 'ExtendedStorageGenerationCost', 'storage_cost', 'interval')
]

# PSY costs (same for all)
dot.node('thermal_gen_cost', 'ThermalGenerationCost\n(PSY)', 
         fillcolor='#FFEBEE', color='#D32F2F')
dot.node('renew_gen_cost', 'RenewableGenerationCost\n(PSY)', 
         fillcolor='#FFEBEE', color='#D32F2F')
dot.node('hydro_gen_cost', 'HydroGenerationCost\n(PSY)', 
         fillcolor='#FFEBEE', color='#D32F2F')
dot.node('storage_cost', 'StorageCost\n(PSY)', 
         fillcolor='#FFEBEE', color='#D32F2F')

# Interval (same for all)
dot.node('interval', '''GenFirstBaseInterval
λ, ρ, β, γ, BSC, ...''', 
         fillcolor='#F3E5F5', color='#7B1FA2')

# Extended costs
for ext_id, ext_name, cost_id, interval_id in extended:
    label = f'''{ext_name}
{'='*30}
+ thermal_cost_core: {cost_id.replace('_', ' ').title()}
+ regularization_term: GenFirstBaseInterval
{'='*30}
PSY economics + ADMM/APP'''
    dot.node(ext_id, label, fillcolor='#E8F5E9', color='#388E3C', penwidth='3')
    dot.edge(cost_id, ext_id, label='embeds', color='#D32F2F', style='dashed', penwidth='2')
    dot.edge(interval_id, ext_id, label='embeds', color='#7B1FA2', style='dashed', penwidth='2')

dot.render('04_extended_costs', cleanup=True)
print("✓ Created 04_extended_costs.pdf")