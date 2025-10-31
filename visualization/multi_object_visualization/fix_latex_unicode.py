#!/usr/bin/env python3
"""
Script to fix LaTeX Unicode character issues in Manim MathTex.

This script will:
1. Find MathTex/Tex calls with Unicode characters
2. Replace Unicode symbols with LaTeX commands
3. Create backups of modified files
"""

import os
import re
import shutil
from pathlib import Path
from datetime import datetime


# Common Unicode to LaTeX mappings
UNICODE_TO_LATEX = {
    # Greek letters (lowercase)
    'α': r'\alpha',
    'β': r'\beta',
    'γ': r'\gamma',
    'δ': r'\delta',
    'ε': r'\epsilon',
    'ζ': r'\zeta',
    'η': r'\eta',
    'θ': r'\theta',
    'ι': r'\iota',
    'κ': r'\kappa',
    'λ': r'\lambda',
    'μ': r'\mu',
    'ν': r'\nu',
    'ξ': r'\xi',
    'π': r'\pi',
    'ρ': r'\rho',
    'σ': r'\sigma',
    'τ': r'\tau',
    'υ': r'\upsilon',
    'φ': r'\phi',
    'χ': r'\chi',
    'ψ': r'\psi',
    'ω': r'\omega',
    
    # Greek letters (uppercase)
    'Α': r'\Alpha',
    'Β': r'\Beta',
    'Γ': r'\Gamma',
    'Δ': r'\Delta',
    'Ε': r'\Epsilon',
    'Ζ': r'\Zeta',
    'Η': r'\Eta',
    'Θ': r'\Theta',
    'Ι': r'\Iota',
    'Κ': r'\Kappa',
    'Λ': r'\Lambda',
    'Μ': r'\Mu',
    'Ν': r'\Nu',
    'Ξ': r'\Xi',
    'Π': r'\Pi',
    'Ρ': r'\Rho',
    'Σ': r'\Sigma',
    'Τ': r'\Tau',
    'Υ': r'\Upsilon',
    'Φ': r'\Phi',
    'Χ': r'\Chi',
    'Ψ': r'\Psi',
    'Ω': r'\Omega',
    
    # Mathematical operators
    '×': r'\times',
    '÷': r'\div',
    '±': r'\pm',
    '∓': r'\mp',
    '≤': r'\leq',
    '≥': r'\geq',
    '≠': r'\neq',
    '≈': r'\approx',
    '∞': r'\infty',
    '∂': r'\partial',
    '∇': r'\nabla',
    '∫': r'\int',
    '∑': r'\sum',
    '∏': r'\prod',
    '√': r'\sqrt',
    '∈': r'\in',
    '∉': r'\notin',
    '⊂': r'\subset',
    '⊃': r'\supset',
    '∪': r'\cup',
    '∩': r'\cap',
    '∀': r'\forall',
    '∃': r'\exists',
    '→': r'\rightarrow',
    '←': r'\leftarrow',
    '⇒': r'\Rightarrow',
    '⇐': r'\Leftarrow',
    '⇔': r'\Leftrightarrow',
}


def find_mathtex_with_unicode(content):
    """Find MathTex/Tex calls that contain Unicode characters."""
    # Pattern to match MathTex or Tex calls with string arguments
    patterns = [
        r'MathTex\s*\([^)]*\)',
        r'Tex\s*\([^)]*\)',
    ]
    
    matches = []
    for pattern in patterns:
        for match in re.finditer(pattern, content, re.DOTALL):
            match_text = match.group(0)
            # Check if contains any Unicode characters we need to replace
            if any(char in match_text for char in UNICODE_TO_LATEX.keys()):
                matches.append((match.start(), match.end(), match_text))
    
    return matches


def replace_unicode_in_string(text):
    """Replace Unicode characters with LaTeX commands in a string."""
    for unicode_char, latex_cmd in UNICODE_TO_LATEX.items():
        text = text.replace(unicode_char, latex_cmd)
    return text


def fix_mathtex_calls(content):
    """Fix MathTex/Tex calls by replacing Unicode with LaTeX commands."""
    # Find all string literals in MathTex/Tex calls
    # Match patterns like MathTex("π(a|s)") or MathTex('π(a|s)')
    
    def replace_in_call(match):
        call_text = match.group(0)
        
        # Find all string literals within this call (both " and ')
        def replace_string_literal(string_match):
            quote = string_match.group(1)
            content_text = string_match.group(2)
            # Replace Unicode in the content
            fixed_content = replace_unicode_in_string(content_text)
            return f'{quote}{fixed_content}{quote}'
        
        # Replace both double and single quoted strings
        fixed_call = re.sub(r'(["\'])((?:(?!\1).)*)\1', replace_string_literal, call_text)
        return fixed_call
    
    # Match MathTex or Tex calls
    pattern = r'\b(?:MathTex|Tex)\s*\([^)]*\)'
    fixed_content = re.sub(pattern, replace_in_call, content, flags=re.DOTALL)
    
    return fixed_content


def process_file(filepath, dry_run=False):
    """Process a single Python file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file has MathTex/Tex with Unicode
        matches = find_mathtex_with_unicode(content)
        if not matches:
            return False, "No MathTex/Tex with Unicode found"
        
        print(f"\n{'[DRY RUN] ' if dry_run else ''}Processing: {filepath}")
        print(f"  Found {len(matches)} MathTex/Tex call(s) with Unicode characters")
        
        # Show what will be changed
        for start, end, match_text in matches[:3]:  # Show first 3 matches
            preview = match_text[:100] + '...' if len(match_text) > 100 else match_text
            print(f"  → {preview}")
        
        if len(matches) > 3:
            print(f"  ... and {len(matches) - 3} more")
        
        # Create backup
        if not dry_run:
            backup_path = str(filepath) + '.backup_' + datetime.now().strftime('%Y%m%d_%H%M%S')
            shutil.copy2(filepath, backup_path)
            print(f"  ✓ Backup created: {backup_path}")
        
        # Fix the content
        new_content = fix_mathtex_calls(content)
        
        if not dry_run:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"  ✓ File updated successfully")
        else:
            print(f"  → Would replace Unicode characters with LaTeX commands")
        
        return True, "Success"
        
    except Exception as e:
        return False, f"Error: {str(e)}"


def find_python_files(directory):
    """Recursively find all Python files in directory."""
    python_files = []
    for root, dirs, files in os.walk(directory):
        # Skip common directories to ignore
        dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', 'venv', 'env', '.venv']]
        
        for file in files:
            if file.endswith('.py'):
                python_files.append(os.path.join(root, file))
    
    return python_files


def show_unicode_mappings():
    """Display available Unicode to LaTeX mappings."""
    print("\nAvailable Unicode to LaTeX Mappings:")
    print("=" * 70)
    
    categories = {
        'Greek (lowercase)': ['α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ', 'ι', 'κ', 'λ', 'μ', 'ν', 'ξ', 'π', 'ρ', 'σ', 'τ', 'υ', 'φ', 'χ', 'ψ', 'ω'],
        'Greek (uppercase)': ['Γ', 'Δ', 'Θ', 'Λ', 'Ξ', 'Π', 'Σ', 'Υ', 'Φ', 'Ψ', 'Ω'],
        'Operators': ['×', '÷', '±', '≤', '≥', '≠', '≈', '∞', '∂', '∇', '∫', '∑', '∏', '√'],
        'Set theory': ['∈', '∉', '⊂', '⊃', '∪', '∩'],
        'Logic': ['∀', '∃'],
        'Arrows': ['→', '←', '⇒', '⇐', '⇔'],
    }
    
    for category, chars in categories.items():
        print(f"\n{category}:")
        for char in chars:
            if char in UNICODE_TO_LATEX:
                print(f"  {char} → {UNICODE_TO_LATEX[char]}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Fix LaTeX Unicode character issues in Manim MathTex/Tex'
    )
    parser.add_argument(
        'path',
        nargs='?',
        default='.',
        help='Path to file or directory to process (default: current directory)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be changed without modifying files'
    )
    parser.add_argument(
        '--show-mappings',
        action='store_true',
        help='Show available Unicode to LaTeX mappings and exit'
    )
    
    args = parser.parse_args()
    
    if args.show_mappings:
        show_unicode_mappings()
        return 0
    
    path = Path(args.path)
    
    if not path.exists():
        print(f"Error: Path '{path}' does not exist")
        return 1
    
    # Collect files to process
    if path.is_file():
        if not str(path).endswith('.py'):
            print(f"Error: '{path}' is not a Python file")
            return 1
        files_to_process = [path]
    else:
        files_to_process = [Path(f) for f in find_python_files(path)]
    
    if not files_to_process:
        print(f"No Python files found in '{path}'")
        return 0
    
    print(f"Found {len(files_to_process)} Python file(s) to scan")
    print("=" * 70)
    
    # Process files
    modified_count = 0
    error_count = 0
    
    for filepath in files_to_process:
        success, message = process_file(filepath, dry_run=args.dry_run)
        if success:
            modified_count += 1
        elif "Error:" in message:
            error_count += 1
            print(f"\n✗ Error processing {filepath}: {message}")
    
    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total files scanned: {len(files_to_process)}")
    print(f"Files modified: {modified_count}")
    if error_count > 0:
        print(f"Errors: {error_count}")
    
    if args.dry_run and modified_count > 0:
        print("\nThis was a dry run. Run without --dry-run to apply changes.")
    elif modified_count > 0:
        print("\n✓ All files processed successfully!")
        print("  Backups have been created with .backup_TIMESTAMP extension")
    else:
        print("\nNo files needed modification.")
    
    return 0


if __name__ == '__main__':
    exit(main())
