# LaTeX Unicode Character Fix Script

This script automatically fixes LaTeX compilation errors in Manim by replacing Unicode characters with proper LaTeX commands in `MathTex` and `Tex` objects.

## Problem

The error occurs when you use Unicode characters directly in MathTex:
```python
formula_text = MathTex("π(a|s)")  # ❌ Causes LaTeX error
```

Error message:
```
LaTeX Error: Unicode character π (U+03C0)
ValueError: latex error converting to dvi
```

## Solution

The script replaces Unicode characters with LaTeX commands:
```python
formula_text = MathTex(r"\pi(a|s)")  # ✅ Works!
```

## Usage

### Basic Usage

Process your entire project directory:
```bash
python fix_latex_unicode.py /path/to/your/project
```

Process a single file:
```bash
python fix_latex_unicode.py /path/to/your/file.py
```

Process current directory:
```bash
python fix_latex_unicode.py
```

### Dry Run (Preview Changes)

See what would be changed without modifying files:
```bash
python fix_latex_unicode.py --dry-run /path/to/your/project
```

### Show Available Mappings

See all Unicode characters that can be converted:
```bash
python fix_latex_unicode.py --show-mappings
```

## What the Script Does

1. **Scans** all Python files in the specified directory (recursively)
2. **Identifies** `MathTex` and `Tex` calls containing Unicode characters
3. **Replaces** Unicode characters with LaTeX commands
4. **Creates** backup files (`.backup_TIMESTAMP` extension) before making changes

## Supported Unicode Characters

The script handles common mathematical Unicode characters:

### Greek Letters (lowercase)
- α → \alpha, β → \beta, γ → \gamma, δ → \delta
- ε → \epsilon, ζ → \zeta, η → \eta, θ → \theta
- π → \pi, ρ → \rho, σ → \sigma, τ → \tau
- φ → \phi, χ → \chi, ψ → \psi, ω → \omega
- (and more...)

### Greek Letters (uppercase)
- Γ → \Gamma, Δ → \Delta, Θ → \Theta, Λ → \Lambda
- Π → \Pi, Σ → \Sigma, Φ → \Phi, Ω → \Omega
- (and more...)

### Mathematical Operators
- × → \times, ÷ → \div, ± → \pm
- ≤ → \leq, ≥ → \geq, ≠ → \neq, ≈ → \approx
- ∞ → \infty, ∂ → \partial, ∇ → \nabla
- ∫ → \int, ∑ → \sum, ∏ → \prod, √ → \sqrt

### Set Theory & Logic
- ∈ → \in, ∉ → \notin, ⊂ → \subset, ⊃ → \supset
- ∪ → \cup, ∩ → \cap, ∀ → \forall, ∃ → \exists

### Arrows
- → → \rightarrow, ← → \leftarrow
- ⇒ → \Rightarrow, ⇐ → \Leftarrow, ⇔ → \Leftrightarrow

Run `python fix_latex_unicode.py --show-mappings` for the complete list.

## Examples

### For Your Specific Error

Based on your error message with π(a|s):

```bash
# Fix the specific file
python fix_latex_unicode.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/multi_object_visualization/powerlascopf_pomdp.py

# Or fix all files in the directory
python fix_latex_unicode.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/
```

### Before and After

**Before:**
```python
self.create_policy_box(
    "State-Based Policy",
    "π(a|s)",  # ❌ Unicode character
    "Assumes full observability"
)
```

**After:**
```python
self.create_policy_box(
    "State-Based Policy",
    r"\pi(a|s)",  # ✅ LaTeX command
    "Assumes full observability"
)
```

## Example Output

```
Found 3 Python file(s) to scan
======================================================================

Processing: powerlascopf_pomdp.py
  Found 3 MathTex/Tex call(s) with Unicode characters
  → MathTex("π(a|s)", font_size=28, color=WHITE)
  → MathTex("π(a|b,o)", font_size=28, color=WHITE)
  → MathTex("θ*", font_size=28, color=WHITE)
  ✓ Backup created: powerlascopf_pomdp.py.backup_20231030_170500
  ✓ File updated successfully

======================================================================
SUMMARY
======================================================================
Total files scanned: 3
Files modified: 1

✓ All files processed successfully!
  Backups have been created with .backup_TIMESTAMP extension
```

## Safety Features

- **Backups**: Original files are backed up with a timestamp before modification
- **Dry run**: Use `--dry-run` to preview changes before applying them
- **Selective processing**: Only files with MathTex/Tex + Unicode are modified
- **Preserves code structure**: Only changes string contents within MathTex/Tex calls

## Combining with Previous Fix

If you've already fixed the `corner_radius` issue, you can run both scripts:

```bash
# First, fix the Rectangle corner_radius issue
python fix_rectangle_corner_radius.py /path/to/project

# Then, fix the LaTeX Unicode issue
python fix_latex_unicode.py /path/to/project
```

Or run them in sequence:
```bash
python fix_rectangle_corner_radius.py /path/to/project && python fix_latex_unicode.py /path/to/project
```

## Restoring from Backup

If something goes wrong, restore from backup files:

```bash
# Restore a single file
cp powerlascopf_pomdp.py.backup_20231030_170500 powerlascopf_pomdp.py

# Or restore all backups
find . -name "*.backup_*" -exec bash -c 'cp "$0" "${0%.backup_*}"' {} \;
```

## Requirements

- Python 3.6 or higher
- No external dependencies (uses only standard library)

## Troubleshooting

### Still getting LaTeX errors after running script

1. **Check if the character is supported**: Run `python fix_latex_unicode.py --show-mappings` to see all supported characters
2. **Manual fix needed**: If your Unicode character isn't in the list, you'll need to manually replace it or add it to the `UNICODE_TO_LATEX` dictionary in the script
3. **Raw strings**: Make sure your LaTeX strings use raw strings (r"...") to prevent Python from interpreting backslashes

### Script doesn't find any files

- Make sure you're pointing to the correct directory
- Check that your Python files have the `.py` extension
- Verify that you have MathTex or Tex calls in your files

### Adding custom Unicode mappings

Edit the `UNICODE_TO_LATEX` dictionary in `fix_latex_unicode.py`:

```python
UNICODE_TO_LATEX = {
    # Add your custom mappings
    '∝': r'\propto',
    '∼': r'\sim',
    # ... existing mappings ...
}
```

## Common LaTeX Commands Reference

If you need to use LaTeX commands directly in your code:

```python
# Greek letters
MathTex(r"\alpha, \beta, \gamma, \pi, \theta, \omega")

# Operators
MathTex(r"x \times y \div z")
MathTex(r"a \leq b \geq c")

# Calculus
MathTex(r"\int_0^\infty f(x) dx")
MathTex(r"\frac{\partial f}{\partial x}")

# Subscripts and superscripts
MathTex(r"x_1, x^2, x_i^j")

# Functions
MathTex(r"\sin(x), \cos(x), \log(x)")
```

## Note

This script specifically targets `MathTex` and `Tex` objects. Regular Python strings and `Text` objects are not modified, as they don't require LaTeX compilation and can handle Unicode directly.
