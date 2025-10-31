#!/bin/bash

# Bash script to run all Manim animations and combine them into one video
# Usage: ./run_all_manim.sh [directory_with_python_files]

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Set the directory containing Python files (default to current directory)
MANIM_DIR="${1:-.}"

# Check if directory exists
if [ ! -d "$MANIM_DIR" ]; then
    print_message "Error: Directory '$MANIM_DIR' does not exist!" "$RED"
    exit 1
fi

print_message "========================================" "$BLUE"
print_message "Manim Animation Batch Processor" "$BLUE"
print_message "========================================" "$BLUE"
echo ""

# Navigate to the directory
cd "$MANIM_DIR" || exit 1

# Create a temporary directory for video list
TEMP_DIR=$(mktemp -d)
VIDEO_LIST="$TEMP_DIR/video_list.txt"

# Counter for successful renders
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_FILES=()

# Find all Python files and sort them alphabetically
print_message "Searching for Python files in: $MANIM_DIR" "$YELLOW"
echo ""

# Array to store video files for concatenation
declare -a VIDEO_FILES

# Process each Python file in alphabetical order
while IFS= read -r -d '' py_file; do
    filename=$(basename "$py_file")
    print_message "========================================" "$BLUE"
    print_message "Processing: $filename" "$GREEN"
    print_message "========================================" "$BLUE"
    
    # Run manim with 4K quality (-qk)
    if manim -qk "$py_file"; then
        print_message "✓ Successfully rendered: $filename" "$GREEN"
        ((SUCCESS_COUNT++))
        
        # Find the most recently created mp4 file in media/videos
        # Manim typically creates: media/videos/filename/2160p60/SceneName.mp4
        latest_video=$(find media/videos -name "*.mp4" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
        
        if [ -n "$latest_video" ]; then
            VIDEO_FILES+=("$latest_video")
            echo "file '$PWD/$latest_video'" >> "$VIDEO_LIST"
            print_message "  → Video saved: $latest_video" "$YELLOW"
        fi
    else
        print_message "✗ Failed to render: $filename" "$RED"
        ((FAILED_COUNT++))
        FAILED_FILES+=("$filename")
    fi
    echo ""
done < <(find "$MANIM_DIR" -maxdepth 1 -name "*.py" -type f -print0 | sort -z)

# Summary
print_message "========================================" "$BLUE"
print_message "Rendering Summary" "$BLUE"
print_message "========================================" "$BLUE"
print_message "✓ Successful: $SUCCESS_COUNT" "$GREEN"
print_message "✗ Failed: $FAILED_COUNT" "$RED"

if [ ${#FAILED_FILES[@]} -gt 0 ]; then
    print_message "\nFailed files:" "$RED"
    for failed_file in "${FAILED_FILES[@]}"; do
        print_message "  - $failed_file" "$RED"
    done
fi

echo ""

# Combine videos if there are any successful renders
if [ ${#VIDEO_FILES[@]} -gt 0 ]; then
    print_message "========================================" "$BLUE"
    print_message "Combining Videos" "$BLUE"
    print_message "========================================" "$BLUE"
    
    COMBINED_VIDEO="media/videos/combined_animation_4k.mp4"
    
    if [ ${#VIDEO_FILES[@]} -eq 1 ]; then
        print_message "Only one video found. Copying to combined output..." "$YELLOW"
        cp "${VIDEO_FILES[0]}" "$COMBINED_VIDEO"
        print_message "✓ Video saved as: $COMBINED_VIDEO" "$GREEN"
    else
        print_message "Combining ${#VIDEO_FILES[@]} videos..." "$YELLOW"
        
        # Check if ffmpeg is installed
        if ! command -v ffmpeg &> /dev/null; then
            print_message "Error: ffmpeg is not installed. Cannot combine videos." "$RED"
            print_message "Please install ffmpeg to combine videos." "$YELLOW"
        else
            # Use ffmpeg to concatenate videos
            if ffmpeg -f concat -safe 0 -i "$VIDEO_LIST" -c copy "$COMBINED_VIDEO" -y; then
                print_message "✓ Successfully combined all videos!" "$GREEN"
                print_message "✓ Combined video saved as: $COMBINED_VIDEO" "$GREEN"
                
                # Get file size
                FILESIZE=$(du -h "$COMBINED_VIDEO" | cut -f1)
                print_message "  File size: $FILESIZE" "$YELLOW"
            else
                print_message "✗ Failed to combine videos" "$RED"
            fi
        fi
    fi
else
    print_message "No videos were successfully rendered. Nothing to combine." "$RED"
fi

# Cleanup
rm -rf "$TEMP_DIR"

print_message "\n========================================" "$BLUE"
print_message "Processing Complete!" "$GREEN"
print_message "========================================" "$BLUE"

# Exit with appropriate code
if [ $FAILED_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
