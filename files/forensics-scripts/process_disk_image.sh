#!/bin/bash
# Autopsy Disk Image Processing Script
set -e

CASE_ID="$1"
IMAGE_FILE="$2"
OUTPUT_DIR="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <case_id> <image_file> <output_dir>"
    exit 1
fi

echo "[$(date)] Starting disk image processing for case: $CASE_ID"

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "/data/processed/autopsy"

# Validate image file exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: Image file not found: $IMAGE_FILE"
    exit 1
fi

# Calculate file hash for integrity
echo "[$(date)] Calculating file hash..."
sha256sum "$IMAGE_FILE" > "$OUTPUT_DIR/image_hash.txt"
FILE_HASH=$(sha256sum "$IMAGE_FILE" | cut -d' ' -f1)

# Generate filesystem timeline using Sleuth Kit
echo "[$(date)] Generating filesystem timeline..."
export PATH="/opt/forensics/sleuthkit/bin:$PATH"
fls -r -p -m "/" "$IMAGE_FILE" > "$OUTPUT_DIR/timeline.bodyfile" 2>/dev/null || echo "Warning: fls had errors"
mactime -b "$OUTPUT_DIR/timeline.bodyfile" > "$OUTPUT_DIR/timeline.csv" 2>/dev/null || echo "Warning: mactime had errors"

# Extract file metadata
echo "[$(date)] Extracting file listings..."
fls -r -p "$IMAGE_FILE" > "$OUTPUT_DIR/file_listing.txt" 2>/dev/null || echo "Warning: file listing had errors"

# Search for interesting file types
echo "[$(date)] Searching for interesting files..."
if [ -f "$OUTPUT_DIR/file_listing.txt" ]; then
    grep -E '\.(doc|docx|pdf|jpg|jpeg|png|exe|dll|zip|rar|txt|log)$' "$OUTPUT_DIR/file_listing.txt" > "$OUTPUT_DIR/interesting_files.txt" || echo "No interesting files found"
fi

# Convert results to JSON for Elasticsearch
echo "[$(date)] Converting to JSON format..."
python3 /opt/forensics/scripts/autopsy_to_json.py "$OUTPUT_DIR" "$CASE_ID" "$FILE_HASH"

echo "[$(date)] Disk image processing completed for case: $CASE_ID"