#!/usr/bin/env python3
"""
Fixed version: Properly handles MathTex strings with Greek characters.
This version correctly handles the quote syntax.
"""

import sys
import re
from pathlib import Path

def fix_file(filepath):
    """Fix the file by properly converting Greek characters in MathTex calls."""
    print(f"Processing: {filepath}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Create backup
        backup_path = str(filepath) + '.backup'
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"✓ Backup created: {backup_path}")
        
        modified = False
        new_lines = []
        
        for i, line in enumerate(lines, 1):
            original_line = line
            
            # Pattern 1: MathTex with Greek in double quotes
            # Look for MathTex("...π...") and replace with MathTex(r"...\pi...")
            if 'MathTex' in line or 'Tex' in line:
                # Handle double-quoted strings with π
                if '"' in line and 'π' in line:
                    # Find the MathTex/Tex call
                    match = re.search(r'(MathTex|Tex)\s*\(\s*"([^"]*π[^"]*)"', line)
                    if match:
                        full_match = match.group(0)
                        tex_content = match.group(2)
                        # Replace π with \pi in the content
                        fixed_content = tex_content.replace('π', r'\pi')
                        # Create the fixed version with raw string
                        fixed_match = f'{match.group(1)}(r"{fixed_content}"'
                        line = line.replace(full_match, fixed_match)
                        print(f"  Line {i}: Fixed MathTex with π")
                        modified = True
                
                # Handle single-quoted strings with π
                elif "'" in line and 'π' in line:
                    match = re.search(r"(MathTex|Tex)\s*\(\s*'([^']*π[^']*)'", line)
                    if match:
                        full_match = match.group(0)
                        tex_content = match.group(2)
                        fixed_content = tex_content.replace('π', r'\pi')
                        fixed_match = f"{match.group(1)}(r'{fixed_content}'"
                        line = line.replace(full_match, fixed_match)
                        print(f"  Line {i}: Fixed MathTex with π")
                        modified = True
                
                # Handle other Greek letters
                greek_map = {
                    'θ': r'\theta',
                    'α': r'\alpha',
                    'β': r'\beta',
                    'γ': r'\gamma',
                    'δ': r'\delta',
                    'σ': r'\sigma',
                    'ω': r'\omega',
                    'λ': r'\lambda',
                    'μ': r'\mu',
                    'ε': r'\epsilon',
                }
                
                for greek, latex in greek_map.items():
                    if greek in line:
                        # Double quotes
                        match = re.search(rf'(MathTex|Tex)\s*\(\s*"([^"]*{greek}[^"]*)"', line)
                        if match:
                            full_match = match.group(0)
                            tex_content = match.group(2)
                            fixed_content = tex_content.replace(greek, latex)
                            fixed_match = f'{match.group(1)}(r"{fixed_content}"'
                            line = line.replace(full_match, fixed_match)
                            print(f"  Line {i}: Fixed MathTex with {greek}")
                            modified = True
                        
                        # Single quotes
                        match = re.search(rf"(MathTex|Tex)\s*\(\s*'([^']*{greek}[^']*)'", line)
                        if match:
                            full_match = match.group(0)
                            tex_content = match.group(2)
                            fixed_content = tex_content.replace(greek, latex)
                            fixed_match = f"{match.group(1)}(r'{fixed_content}'"
                            line = line.replace(full_match, fixed_match)
                            print(f"  Line {i}: Fixed MathTex with {greek}")
                            modified = True
            
            # Pattern 2: Fix incorrectly escaped strings like "• Policy: r"\pi(a|s)""
            # This is the syntax error you're seeing
            if r'r"\pi' in line or r"r'\pi" in line:
                # This means someone already tried to fix it but got the quotes wrong
                # Pattern: "...r"\pi(a|s)"..." should be "...\\pi(a|s)..."
                line = re.sub(r'"([^"]*?)r"\\pi([^"]*?)"([^"]*?)"', r'r"\1\\pi\2\3"', line)
                line = re.sub(r"'([^']*?)r'\\pi([^']*?)'([^']*?)'", r"r'\1\\pi\2\3'", line)
                print(f"  Line {i}: Fixed malformed raw string")
                modified = True
            
            new_lines.append(line)
        
        if not modified:
            print("  No changes needed")
            return False
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        
        print(f"✓ File fixed successfully!")
        return True
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python fix_greek_syntax.py <filepath>")
        print("\nExample:")
        print("  python fix_greek_syntax.py powerlascopf_pomdp.py")
        sys.exit(1)
    
    filepath = Path(sys.argv[1])
    
    if not filepath.exists():
        print(f"Error: File '{filepath}' not found")
        sys.exit(1)
    
    success = fix_file(filepath)
    sys.exit(0 if success else 1)
