#!/bin/bash
# Andriller Mobile Analysis Script
set -e

MOBILE_DATA="$1"
OUTPUT_DIR="$2"
CASE_ID="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <mobile_data_path> <output_dir> <case_id>"
    exit 1
fi

echo "[$(date)] Starting mobile analysis for case: $CASE_ID"

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "/data/processed/andriller"

# Run Andriller extraction
echo "[$(date)] Running Andriller analysis..."
andriller -e "$MOBILE_DATA" -o "$OUTPUT_DIR" || echo "Andriller analysis completed with warnings"

# Convert results to JSON
echo "[$(date)] Converting to JSON format..."
python3 /opt/forensics/scripts/andriller_to_json.py "$OUTPUT_DIR" "$CASE_ID"

echo "[$(date)] Mobile analysis completed for case: $CASE_ID"