import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

fig = plt.figure(figsize=(16, 20), dpi=300)
ax = fig.add_subplot(111)
ax.set_xlim(0, 16)
ax.set_ylim(0, 20)
ax.axis('off')

# [The complete Python code I provided above - approximately 200 lines]

plt.savefig('PowerLASCOPF_Architecture.png', format='png', bbox_inches='tight', dpi=300)
plt.savefig('PowerLASCOPF_Architecture.pdf', format='pdf', bbox_inches='tight', dpi=300)
print("Done! Files created: PowerLASCOPF_Architecture.png and .pdf")