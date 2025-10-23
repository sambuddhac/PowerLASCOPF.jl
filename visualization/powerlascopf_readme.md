# PowerLASCOPF Animation Suite

3Blue1Brown-style Manim animations for the PowerLASCOPF actor-critic reinforcement learning system for Security-Constrained Optimal Power Flow (SCOPF).

## 📁 File Structure

```
powerlascopf_animations/
├── neural_networks.py              # Basic neural network animations
├── powerlascopf_main.py           # Main workflow and system overview
├── powerlascopf_actor_critic.py   # Actor-critic architecture details
├── powerlascopf_pomdp.py          # POMDP interface and belief updates
├── powerlascopf_admm.py           # ADMM-APP solver visualization
└── README.md                       # This file
```

## 🎬 Available Animations

### 1. Neural Networks (neural_networks.py)
Basic neural network visualizations across three frameworks:

- **FluxNetwork** - Simple Flux.jl 3-layer network
- **PyTorchNetwork** - PyTorch with BatchNorm & Dropout
- **TensorFlowNetwork** - Keras Functional API
- **AllNetworksComparison** - Side-by-side framework comparison
- **ForwardPropagation** - Detailed forward pass visualization
- **BatchNormExplanation** - BatchNorm mathematical breakdown
- **DropoutVisualization** - How 10% dropout works
- **ActivationFunctions** - ReLU, Tanh, Softmax comparison
- **ArchitectureEvolution** - History from 1958 to modern networks
- **ParameterCount** - Parameter calculation walkthrough
- **TrainingVsInference** - Mode differences
- **RAGApplicationHint** - Connection to RAG systems

### 2. Main Workflow (powerlascopf_main.py)
High-level system architecture and workflow:

- **SystemOverview** - Three main components (POMDP, Actor-Critic, ADMM-APP)
- **CompleteWorkflow** - Step-by-step workflow stages
- **DataFlowAnimation** - Data flow through the entire system

### 3. Actor-Critic Networks (powerlascopf_actor_critic.py)
Detailed actor-critic architecture across frameworks:

- **ActorCriticOverview** - Dual network system overview
- **FluxActorCritic** - Flux.jl implementation
- **PyTorchActorCritic** - PyTorch with regularization
- **TensorFlowActorCritic** - TensorFlow/Keras functional API
- **AllFrameworksComparison** - Framework comparison
- **TrainingDynamics** - Training process and loss curves

### 4. POMDP Interface (powerlascopf_pomdp.py)
POMDP formulation and belief updates:

- **POMDPOverview** - POMDP 7-tuple definition
- **BeliefUpdate** - Bayesian belief update visualization
- **ObservationModel** - Observation modeling for power systems
- **POMDPvsFullyObservable** - Comparison with MDP
- **PolicyTypes** - State-based, observation-based, belief-based policies
- **BeliefMDP** - POMDP as belief MDP transformation
- **POMDPForPowerSystems** - Specific SCOPF formulation

### 5. ADMM-APP Solver (powerlascopf_admm.py)
Distributed optimization visualization:

- **ADMMOverview** - ADMM decomposition overview
- **ADMMAlgorithm** - Algorithm steps and augmented Lagrangian
- **APPMethod** - Asynchronous Proximal Point method
- **DistributedOptimization** - Agent coordination visualization
- **ConvergenceVisualization** - Convergence curves
- **ADMMvsCentralized** - Comparison with centralized methods
- **RealWorldApplication** - Real power grid application
- **PerformanceMetrics** - Performance characteristics

## 🚀 Quick Start

### Installation

```bash
# Install Manim Community Edition
pip install manim

# Or with conda
conda install -c conda-forge manim
```

### Basic Usage

```bash
# Render a single scene (low quality, preview)
manim -pql powerlascopf_main.py SystemOverview

# High quality render
manim -pqh powerlascopf_main.py SystemOverview

# 4K quality
manim -pqk powerlascopf_main.py SystemOverview

# Save as GIF
manim -pql powerlascopf_main.py SystemOverview --format=gif
```

### Quality Flags
- `-ql` - Low quality (854x480, 15fps) - Fast preview
- `-qm` - Medium quality (1280x720, 30fps)
- `-qh` - High quality (1920x1080, 60fps)
- `-qk` - 4K quality (3840x2160, 60fps)
- `-p` - Preview after rendering
- `-a` - Render all scenes in the file

## 📚 Complete Tutorial Sequence

To create a comprehensive video tutorial, render scenes in this order:

### Part 1: System Overview (15 minutes)
```bash
manim -pqh powerlascopf_main.py SystemOverview
manim -pqh powerlascopf_main.py CompleteWorkflow
manim -pqh powerlascopf_main.py DataFlowAnimation
```

### Part 2: POMDP Foundation (20 minutes)
```bash
manim -pqh powerlascopf_pomdp.py POMDPOverview
manim -pqh powerlascopf_pomdp.py BeliefUpdate
manim -pqh powerlascopf_pomdp.py ObservationModel
manim -pqh powerlascopf_pomdp.py POMDPvsFullyObservable
manim -pqh powerlascopf_pomdp.py PolicyTypes
```

### Part 3: Actor-Critic Networks (25 minutes)
```bash
manim -pqh powerlascopf_actor_critic.py ActorCriticOverview
manim -pqh powerlascopf_actor_critic.py FluxActorCritic
manim -pqh powerlascopf_actor_critic.py PyTorchActorCritic
manim -pqh powerlascopf_actor_critic.py TensorFlowActorCritic
manim -pqh powerlascopf_actor_critic.py AllFrameworksComparison
manim -pqh powerlascopf_actor_critic.py TrainingDynamics
```

### Part 4: ADMM-APP Solver (20 minutes)
```bash
manim -pqh powerlascopf_admm.py ADMMOverview
manim -pqh powerlascopf_admm.py ADMMAlgorithm
manim -pqh powerlascopf_admm.py APPMethod
manim -pqh powerlascopf_admm.py DistributedOptimization
manim -pqh powerlascopf_admm.py ConvergenceVisualization
manim -pqh powerlascopf_admm.py ADMMvsCentralized
```

### Part 5: Neural Network Deep Dive (15 minutes)
```bash
manim -pqh neural_networks.py AllNetworksComparison
manim -pqh neural_networks.py ForwardPropagation
manim -pqh neural_networks.py DropoutVisualization
manim -pqh neural_networks.py BatchNormExplanation
```

## 🎨 Customization

### Modify Network Architectures

```python
# In powerlascopf_actor_critic.py
actor = NeuralNetworkMobject(
    layer_sizes=[128, 256, 128, 64],  # Change layer sizes
    layer_colors=[GREEN, BLUE, BLUE, ORANGE],  # Change colors
    layer_spacing=1.8,  # Adjust spacing
    show_all_edges=True  # Show all connections
)
```

### Change Animation Speed

```python
# Slower animations
self.play(animation, run_time=3.0)

# Faster animations
self.play(animation, run_time=0.5)
```

### Modify Colors

```python
# Use custom colors
CUSTOM_BLUE = "#1E88E5"
CUSTOM_RED = "#D32F2F"

# Or use Manim's built-in colors
from manim import BLUE_E, RED_E, GREEN_E
```

## 🔧 Troubleshooting

### Common Issues

**1. Code text overlapping**
- Already fixed in the provided code
- Adjust `scale()` and `shift()` parameters if needed

**2. Not all neurons connected**
- Set `show_all_edges=True` in `NeuralNetworkMobject`
- Already set as default in the provided code

**3. Font issues**
```python
# If Monospace font doesn't work, try:
Text(code_line, font="Courier")
# Or remove font parameter:
Text(code_line)
```

**4. Slow rendering**
- Use `-ql` flag for previews
- Reduce `run_time` in animations
- Simplify complex scenes

## 📊 Output Files

Rendered videos are saved to:
```
media/videos/[filename]/[quality]/[SceneName].mp4
```

Example:
```
media/videos/powerlascopf_main/1080p60/SystemOverview.mp4
```

## 🎓 Educational Use

These animations are designed for:
- **Research presentations** - Conference talks, seminars
- **Course materials** - Graduate courses on RL, power systems
- **Documentation** - Visual guides for PowerLASCOPF
- **Onboarding** - Help new contributors understand the system
- **YouTube tutorials** - Educational content creation

## 📝 Citations

If you use these animations in academic work, please cite:

```bibtex
@software{powerlascopf_animations,
  title={PowerLASCOPF Animation Suite},
  author={Your Name},
  year={2024},
  note={3Blue1Brown-style Manim animations for actor-critic RL in power systems}
}
```

## 🤝 Contributing

To add new animations:

1. Choose the appropriate file based on content
2. Follow the existing scene structure
3. Use consistent color schemes:
   - GREEN: POMDP/RL components
   - BLUE: Actor/Neural networks
   - PURPLE: Critic/Value functions
   - ORANGE: ADMM/Solver components
   - YELLOW: Highlights/Important info

## 📖 References

- **PowerLASCOPF**: https://github.com/sambuddhac/PowerLASCOPF.jl
- **Manim Documentation**: https://docs.manim.community/
- **3Blue1Brown**: https://www.3blue1brown.com/
- **POMDPs.jl**: https://github.com/JuliaPOMDP/POMDPs.jl

## 📄 License

These animations are provided for educational and research purposes. Modify and use as needed for your PowerLASCOPF documentation and presentations.

## 🔗 Related Resources

- PowerLASCOPF Documentation: [Link to docs]
- Chakrabarti's Dissertation: [Link to thesis]
- ADMM Tutorial: Boyd et al. "Distributed Optimization and Statistical Learning via ADMM"
- POMDP Tutorial: Kaelbling et al. "Planning and Acting in Partially Observable Stochastic Domains"

---

**Need help?** Open an issue on the PowerLASCOPF repository or check the Manim community forums.

**Want more animations?** The modular structure makes it easy to add new scenes following the existing patterns.