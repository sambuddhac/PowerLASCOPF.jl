# CVaR Visualization for LASCOPF - User Guide

## Overview

This Manim animation illustrates the Conditional Value at Risk (CVaR) concept from your IEEE paper on "Line Temperature Constrained Post-Contingency States Representation & Redispatch for Restoration by Risk-Minimizing Stochastic Optimization."

## Animation Scenes

### Main Animation: `CVaRVisualization`

This is a comprehensive 4-scene animation that covers:

1. **Weather Scenarios** (Scene 1)
   - Shows how weather conditions (sunny vs. cloudy) affect:
     - Variable Renewable Energy (VRE) generation (solar/wind)
     - Load demand consumption
   - Visual: Weather icons → Different outcomes

2. **Cost Distribution** (Scene 2)
   - Displays probability distribution of generation costs across weather scenarios
   - Shows individual scenario points on the distribution
   - Represents the stochastic nature of the problem

3. **CVaR Concept** (Scene 3)
   - Introduces Value at Risk (VaR, denoted as Ψ)
   - Highlights the tail risk region (α-percentile)
   - Shows CVaR as the expected value in the tail region
   - Formula: CVaR = Ψ + (1/α)𝔼[V]

4. **Objective Function** (Scene 4)
   - Shows the complete LASCOPF objective function
   - Highlights the trade-off between expected cost and tail risk
   - Explains the β_CVaR parameter
   - Shows constraints: V^sc ≥ Ψ - C^sc, V^sc ≥ 0

### Simplified Animation: `SimplifiedCVaRDemo`

A streamlined version focusing on the visual representation:
- Clear probability distribution
- Expected value line (𝔼[C])
- VaR threshold (Ψ)
- Tail region (shaded in red)
- CVaR indicator
- Final objective function

## How to Render

### Prerequisites
```bash
pip install manim
```

### Rendering Commands

**Full animation (low quality, preview):**
```bash
manim -pql cvar_animation.py CVaRVisualization
```

**Full animation (high quality):**
```bash
manim -pqh cvar_animation.py CVaRVisualization
```

**Simplified version (recommended for presentations):**
```bash
manim -pql cvar_animation.py SimplifiedCVaRDemo
```

**4K quality (for publication):**
```bash
manim -pqk cvar_animation.py SimplifiedCVaRDemo
```

## Key Concepts Illustrated

### 1. Stochastic Optimization
The animation shows how multiple weather scenarios (sc ∈ SC) create a probability distribution of costs, representing:
- Load consumption variations
- VRE (solar, wind, hydro) generation variations

### 2. Risk Measures

**Value at Risk (VaR, Ψ):**
- The cost threshold at the (1-α) confidence level
- Example: α = 0.10 means 90% of scenarios have costs below Ψ

**Conditional Value at Risk (CVaR):**
- Expected cost given that we're in the tail region (worst α% of scenarios)
- More conservative than VaR
- Convex, which makes optimization tractable

### 3. Objective Function

```
min_{P_g} [(1-β_CVaR)𝔼[C] + β_CVaR·CVaR]
```

Where:
- **P_g**: Generator power outputs (decision variables)
- **𝔼[C]**: Expected generation cost across all scenarios
- **CVaR**: Tail risk measure
- **β_CVaR**: Trade-off parameter
  - Large β → More risk-averse (focus on worst-case scenarios)
  - Small β → Focus on expected cost

### 4. Connection to LASCOPF

The animation illustrates equation (7a) from your paper:

```
min (1-β_CVaR)E(C) + β_CVaR(Ψ + (1/α_CVaR)(E(V)))
```

Subject to:
- V^sc ≥ Ψ - C^sc (defines tail region)
- V^sc ≥ 0
- Power flow constraints
- Temperature constraints (eq. 4a, 9a)
- Ramp constraints
- (N-1-1) security constraints

## Customization Options

### Modify Distribution Parameters

In the code, you can adjust the cost distribution:

```python
def cost_pdf(x):
    mu, sigma, alpha = 5, 1.5, 2  # Change these values
    # mu: mean cost
    # sigma: standard deviation
    # alpha: skewness parameter
```

### Adjust Risk Parameters

```python
alpha = 0.10  # Tail risk region (10%)
var_value = 7.0  # VaR threshold
cvar_value = 7.8  # CVaR value
```

### Change Colors

```python
# Distribution: BLUE_C
# VaR line: RED
# CVaR: ORANGE  
# Expected value: GREEN
# Tail region: RED with opacity
```

## Integration with Your Paper

### Relevant Equations

The animation directly illustrates:

1. **Equation (6a-6e)**: Cost components and CVaR formulation
2. **Equation (7a)**: The main objective function
3. **Equation (8a-8b)**: CVaR constraints

### Physical Interpretation

For the LASCOPF problem:
- **Weather scenarios** → Different load & VRE profiles
- **Cost distribution** → Generation costs across scenarios and contingencies
- **Tail events** → Worst-case weather + contingency combinations
- **CVaR minimization** → Ensures system can handle extreme events while maintaining:
  - (N-1-1) security
  - Line temperature constraints
  - Generator ramping limits
  - Restoration within Γ_MRD intervals

## Tips for Presentations

1. **Start with SimplifiedCVaRDemo** - cleaner for initial explanation
2. **Use CVaRVisualization** - for detailed technical presentations
3. **Pause between scenes** - let audience absorb concepts
4. **Add voice-over** explaining:
   - How weather uncertainty affects power systems
   - Why tail risk matters for reliability
   - How this enables optimal dispatch with security

## Export Options

### For PowerPoint/Keynote
```bash
manim -pqh --format=mp4 cvar_animation.py SimplifiedCVaRDemo
```

### For LaTeX Beamer
```bash
manim -pqh --format=mov cvar_animation.py SimplifiedCVaRDemo
```

### Individual Frames (for figures)
```bash
manim -sqh --format=png cvar_animation.py SimplifiedCVaRDemo
```

## Technical Notes

### Color Scheme (3Blue1Brown style)
- Background: Dark (default Manim)
- Primary graph: Blue (#58C4DD)
- Risk indicators: Red/Orange
- Expected values: Green
- Clean, minimalist aesthetic

### Animation Speed
- Each wait() is 1 second by default
- Adjust `self.wait(2)` to `self.wait(3)` for slower pace
- Remove wait() calls for faster transitions

### Fonts
- Uses Manim's default font (similar to 3B1B)
- Math rendered with LaTeX
- Clean, readable text

## Troubleshooting

**Issue: Animation too slow**
- Reduce wait() durations
- Use -ql flag for faster preview rendering

**Issue: Math not rendering**
- Ensure LaTeX is installed
- Check MathTex strings for typos

**Issue: Colors not displaying**
- Update Manim: `pip install --upgrade manim`
- Check terminal supports colors

## Related Concepts in Your Paper

This animation complements:
- **Section I**: Introduction to LASCOPF
- **Section IV**: Centralized optimization formulation
- **Equations (6)-(7)**: Objective function and CVaR
- **Figure 1**: APMP algorithm structure (could create separate animation)

## Future Enhancements

Consider creating animations for:
1. Temperature evolution on transmission lines (Eq. 2a-2b)
2. APMP decomposition structure (Figure 1)
3. Generator ramping and restoration
4. (N-1-1) contingency scenarios

---

**Questions or customization requests?** The code is well-commented and modular for easy modification!
