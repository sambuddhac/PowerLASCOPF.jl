# Fix for Syntax Error at Line 346

## The Problem

Line 346 has a syntax error:
```python
"• Policy: r"\pi(a|s)"",
          ^
SyntaxError: unexpected character after line continuation character
```

This happened because the `r` prefix was placed INSIDE the string instead of BEFORE the opening quote.

## The Fix

### Step 1: Open the file
Open `powerlascopf_pomdp.py` in your text editor

### Step 2: Find line 346
Look for a line that looks like this:
```python
"• Policy: r"\pi(a|s)"",
```

### Step 3: Understand the problem
The issue is that you have:
- An opening quote: `"`
- Some text: `• Policy: `
- Then another `r"` which is WRONG

### Step 4: Fix it properly

**WRONG (current):**
```python
"• Policy: r"\pi(a|s)"",
```

**CORRECT (what it should be):**
```python
"• Policy: \\pi(a|s)",
```

OR if this is in a MathTex:
```python
r"\pi(a|s)"
```

### Understanding the Types of Strings

#### Type 1: Regular strings with escaped backslashes
```python
text = "The policy is \\pi(a|s)"  # Need double backslash
```

#### Type 2: Raw strings (for MathTex)
```python
formula = r"\pi(a|s)"  # Raw string, single backslash, no inner quotes
```

#### Type 3: Mixed (DON'T DO THIS)
```python
# WRONG - This causes syntax error:
text = "Policy: r"\pi""  # ❌ Can't nest quotes like this
```

## Complete Fix for Line 346

If line 346 is in a Text object:
```python
# BEFORE (WRONG):
"• Policy: r"\pi(a|s)"",

# AFTER (CORRECT):
"• Policy: \\pi(a|s)",
```

If line 346 is for MathTex/Tex, the whole thing should be:
```python
# BEFORE (WRONG):
MathTex("• Policy: r"\pi(a|s)"")

# AFTER (CORRECT):
MathTex(r"\pi(a|s)")
```

## Quick Search and Replace

Open the file and use your editor's find/replace:

### Find these WRONG patterns:
```
r"\pi
r'\pi
r"\\pi
r'\\pi
```

And replace with the appropriate LaTeX:
```
\\pi
```

## Using the Fix Script

Instead of manual editing, run:
```bash
python fix_greek_syntax.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/multi_object_visualization/powerlascopf_pomdp.py
```

This will automatically fix all the malformed strings.

## After Fixing

Test the syntax is valid:
```bash
python -m py_compile powerlascopf_pomdp.py
```

If no errors, then run Manim:
```bash
manim -pql powerlascopf_pomdp.py YourSceneName
```

## Common Mistakes to Avoid

❌ **WRONG:**
```python
"text with r"\pi""           # Nested quotes - SYNTAX ERROR
MathTex("π(a|s)")            # Unicode - LATEX ERROR
text = r"Some \n text"       # Raw strings ignore \n
```

✅ **CORRECT:**
```python
"text with \\pi"             # Escaped backslash
MathTex(r"\pi(a|s)")         # Raw string for LaTeX
text = "Some \n text"        # Regular string for \n
```
