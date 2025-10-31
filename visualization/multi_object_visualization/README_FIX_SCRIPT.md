# Rectangle Corner Radius Fix Script

This script automatically fixes the Manim `Rectangle` corner_radius compatibility issue by replacing `Rectangle` with `RoundedRectangle` when `corner_radius` is used.

## Problem

The error occurs when you use `corner_radius` parameter with `Rectangle`:
```python
box = Rectangle(width=8, height=1, corner_radius=0.1)  # ❌ Causes error
```

Error message:
```
TypeError: Mobject.__init__() got an unexpected keyword argument 'corner_radius'
```

## Solution

The script replaces `Rectangle` with `RoundedRectangle`:
```python
box = RoundedRectangle(width=8, height=1, corner_radius=0.1)  # ✅ Works!
```

## Usage

### Basic Usage

Process your entire project directory:
```bash
python fix_rectangle_corner_radius.py /path/to/your/project
```

Process a single file:
```bash
python fix_rectangle_corner_radius.py /path/to/your/file.py
```

Process current directory:
```bash
python fix_rectangle_corner_radius.py
```

### Dry Run (Preview Changes)

See what would be changed without modifying files:
```bash
python fix_rectangle_corner_radius.py --dry-run /path/to/your/project
```

## What the Script Does

1. **Scans** all Python files in the specified directory (recursively)
2. **Identifies** `Rectangle` calls that use the `corner_radius` parameter
3. **Replaces** `Rectangle` with `RoundedRectangle`
4. **Adds** `RoundedRectangle` to the imports if not already present
5. **Creates** backup files (`.backup_TIMESTAMP` extension) before making changes

## Examples

### For Your Specific Files

Based on your error messages, you need to fix these files:

```bash
# Fix all files in your PowerLASCOPF visualization directory
python fix_rectangle_corner_radius.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/

# Or fix specific files
python fix_rectangle_corner_radius.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/multi_object_visualization/powerlascopf_main.py
python fix_rectangle_corner_radius.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/multi_object_visualization/powerlascopf_pomdp.py
python fix_rectangle_corner_radius.py /Users/sc87/code/OPF_LASCOPF_Staple/PowerLASCOPF/visualization/multi_object_visualization/powerlascopf_admm.py
```

## Safety Features

- **Backups**: Original files are backed up with a timestamp before modification
- **Dry run**: Use `--dry-run` to preview changes before applying them
- **Selective processing**: Only files with `Rectangle` + `corner_radius` are modified
- **Smart import handling**: Adds imports only when needed

## Example Output

```
Found 3 Python file(s) to scan
======================================================================

Processing: powerlascopf_main.py
  ✓ Backup created: powerlascopf_main.py.backup_20231030_143022
  ✓ File updated successfully

Processing: powerlascopf_pomdp.py
  ✓ Backup created: powerlascopf_pomdp.py.backup_20231030_143022
  ✓ File updated successfully

Processing: powerlascopf_admm.py
  ✓ Backup created: powerlascopf_admm.py.backup_20231030_143022
  ✓ File updated successfully

======================================================================
SUMMARY
======================================================================
Total files scanned: 3
Files modified: 3

✓ All files processed successfully!
  Backups have been created with .backup_TIMESTAMP extension
```

## Restoring from Backup

If something goes wrong, you can restore from the backup files:

```bash
# Restore a single file
cp powerlascopf_main.py.backup_20231030_143022 powerlascopf_main.py

# Or use a script to restore all backups
find . -name "*.backup_*" -exec bash -c 'cp "$0" "${0%.backup_*}"' {} \;
```

## Requirements

- Python 3.6 or higher
- No external dependencies (uses only standard library)

## Troubleshooting

### Script doesn't find any files
- Make sure you're pointing to the correct directory
- Check that your Python files have the `.py` extension

### Import not added correctly
- Manually add `from manim import RoundedRectangle` to the top of your file
- Or add `RoundedRectangle` to an existing `from manim import ...` statement

### Still getting errors after running script
- Check if there are other instances of `Rectangle` with `corner_radius` in different locations
- Make sure you ran the script on all relevant files
- Try running Manim again - the script creates backups, so you can safely re-run it

## Note

This script is specifically designed to fix the Manim `corner_radius` compatibility issue. It does not modify `Rectangle` calls that don't use `corner_radius`.
