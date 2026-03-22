from graphviz import Digraph

dot = Digraph('foundation', format='pdf', engine='dot')
dot.attr(rankdir='TB', size='16,20', dpi='300')
dot.attr('node', shape='box', style='filled,rounded', fontname='Arial', fontsize='12')

# Title
dot.node('title', 'Layer 1: IS Foundation & PSY Generators', 
         shape='plaintext', fontsize='24', fontname='Arial Bold')

# IS Base
dot.node('IS', '''InfrastructureSystemsComponent
─────────────────────────
+ name: String
+ available: Bool  
+ bus: Bus
+ ext: Dict
+ internal: IS.Internal
─────────────────────────
UUID, time series, metadata''',
         fillcolor='#E3F2FD', color='#1976D2', penwidth='3')

# PSY Generators
psy_gens = [
    ('thermal', 'ThermalStandard', '''+ active_power
+ reactive_power
+ active_power_limits
+ operation_cost:
  ThermalGenerationCost'''),
    ('renewable', 'RenewableDispatch', '''+ rating
+ power_factor
+ tech_type
+ operation_cost:
  RenewableGenerationCost'''),
    ('hydro', 'HydroEnergyReservoir', '''+ storage_capacity
+ inflow
+ initial_storage
+ operation_cost:
  HydroGenerationCost'''),
    ('storage', 'GenericBattery', '''+ energy_capacity
+ charge_efficiency
+ discharge_efficiency
+ operation_cost:
  StorageCost''')
]

for node_id, title, fields in psy_gens:
    label = f'{title}\n{"─"*len(title)}\n{fields}'
    dot.node(node_id, label, fillcolor='#FFEBEE', color='#D32F2F', penwidth='3')
    dot.edge('IS', node_id, label='inherits', style='dashed', color='#1976D2', penwidth='2')

dot.render('01_foundation_layer', cleanup=True)
print("✓ Created 01_foundation_layer.pdf")