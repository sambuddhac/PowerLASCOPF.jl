import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Circle
from datetime import datetime

fig = plt.figure(figsize=(14, 10), dpi=300)
ax = fig.add_subplot(111)
ax.set_xlim(0, 14)
ax.set_ylim(0, 10)
ax.axis('off')

# Title
title_box = FancyBboxPatch((0.5, 8.5), 13, 1.2, boxstyle="round,pad=0.1",
                           facecolor='#4facfe', edgecolor='none', alpha=0.9)
ax.add_patch(title_box)
ax.text(7, 9.3, 'CAISO Contingency Modeling Enhancements', 
        fontsize=26, fontweight='bold', ha='center', color='white')
ax.text(7, 8.8, 'Initiative Timeline (2013-2017)', 
        fontsize=16, ha='center', color='white', alpha=0.9)

# Timeline events
events = [
    ('Mar 11, 2013', 'Issue Paper Posted', 'Issue Paper with Technical Paper released', '#f093fb'),
    ('Mar 25, 2013', 'Issue Paper Meeting', 'Web meeting to discuss issue paper', '#f5576c'),
    ('May 15, 2013', 'Straw Proposal', 'First Straw Proposal posted', '#667eea'),
    ('May 21, 2013', 'Straw Proposal Meeting', 'In-person meeting on straw proposal', '#764ba2'),
    ('Jun 18, 2013', 'Revised Straw Proposal', 'Revised Straw Proposal posted', '#667eea'),
    ('Jun 21, 2013', 'Revised Straw Meeting', 'Call to discuss revised straw proposal', '#764ba2'),
    ('Mar 14, 2014', 'Second Revised Straw', 'Second Revised Straw Proposal posted', '#667eea'),
    ('Mar 18, 2014', 'Second Revised Meeting', 'Call on second revised straw proposal', '#764ba2'),
    ('Nov 20, 2015', 'Third Revised Straw', 'Third Revised Straw Proposal posted', '#667eea'),
    ('Dec 9, 2015', 'Third Revised Meeting', 'In-person meeting on third revised straw', '#764ba2'),
    ('Mar 7, 2016', 'CRR Discussion Paper', 'CRR Alternatives Discussion Paper posted', '#43e97b'),
    ('Aug 11, 2017', 'Draft Final Proposal', 'Draft Final Proposal posted', '#f5576c'),
    ('Aug 22, 2017', 'Draft Final Meeting', 'In-person meeting with presentations', '#764ba2'),
    ('Dec 14, 2017', 'Board Approval', 'Board of Governors approval - COMPLETED', '#00f2fe')
]

# Draw timeline
y_start = 7
y_spacing = 0.45

for i, (date, title, desc, color) in enumerate(events):
    y_pos = y_start - i * y_spacing
    
    # Circle marker
    circle = Circle((1.2, y_pos), 0.15, facecolor=color, edgecolor='white', linewidth=2, zorder=10)
    ax.add_patch(circle)
    
    # Event box
    box_width = 11
    event_box = FancyBboxPatch((2, y_pos-0.15), box_width, 0.3,
                               boxstyle="round,pad=0.02",
                               facecolor=color, edgecolor='none', alpha=0.2)
    ax.add_patch(event_box)
    
    # Date
    ax.text(1.2, y_pos-0.35, date, fontsize=8, ha='center', 
            color='#4a5568', fontweight='bold')
    
    # Title
    ax.text(2.3, y_pos+0.05, title, fontsize=10, fontweight='bold', 
            va='center', color=color)
    
    # Description
    ax.text(2.3, y_pos-0.08, desc, fontsize=8, va='center', 
            color='#4a5568', style='italic')

# Vertical line connecting events
ax.plot([1.2, 1.2], [y_start+0.15, y_start - (len(events)-1)*y_spacing - 0.15], 
        color='#cbd5e0', linewidth=3, zorder=1)

# Status box
status_box = FancyBboxPatch((0.5, 0.3), 13, 1.5, boxstyle="round,pad=0.1",
                            facecolor='#f7fafc', edgecolor='#4facfe', linewidth=3)
ax.add_patch(status_box)
ax.text(7, 1.5, 'Initiative Status', fontsize=14, fontweight='bold', ha='center', color='#2d3748')
ax.text(7, 1.2, 'Started: March 26, 2013', fontsize=10, ha='center', color='#4a5568')
ax.text(7, 0.95, 'Board Approval: December 14, 2017', fontsize=10, ha='center', color='#4a5568')
ax.text(7, 0.7, 'Status: COMPLETED', fontsize=11, ha='center', color='#00f2fe', fontweight='bold')
ax.text(7, 0.45, 'Lead: Perry Servedio', fontsize=9, ha='center', color='#4a5568', style='italic')

# Legend
legend_y = 8.2
ax.text(0.7, legend_y, 'Key:', fontsize=10, fontweight='bold', color='#2d3748')
legend_items = [
    ('Proposal', '#667eea'),
    ('Meeting', '#764ba2'),
    ('Decision', '#00f2fe'),
    ('Analysis', '#43e97b')
]
for i, (label, color) in enumerate(legend_items):
    x_pos = 1.5 + i*1.8
    circle = Circle((x_pos, legend_y), 0.08, facecolor=color, edgecolor='white', linewidth=1)
    ax.add_patch(circle)
    ax.text(x_pos+0.15, legend_y, label, fontsize=8, va='center', color='#4a5568')

plt.tight_layout()
plt.savefig('CAISO_CME_Timeline.png', format='png', bbox_inches='tight', dpi=300)
plt.savefig('CAISO_CME_Timeline.pdf', format='pdf', bbox_inches='tight', dpi=300)
print("Timeline created: CAISO_CME_Timeline.png and CAISO_CME_Timeline.pdf")