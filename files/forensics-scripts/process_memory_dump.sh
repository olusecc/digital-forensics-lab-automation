#!/bin/bash
# Volatility3 Memory Analysis Script
set -e

MEMORY_DUMP="$1"
OUTPUT_DIR="$2"
CASE_ID="$3"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <memory_dump> <output_dir> <case_id>"
    exit 1
fi

echo "[$(date)] Starting memory analysis for case: $CASE_ID"

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "/data/processed/volatility"

# Validate memory dump exists
if [ ! -f "$MEMORY_DUMP" ]; then
    echo "ERROR: Memory dump not found: $MEMORY_DUMP"
    exit 1
fi

# Calculate file hash
echo "[$(date)] Calculating memory dump hash..."
sha256sum "$MEMORY_DUMP" > "$OUTPUT_DIR/memory_hash.txt"
MEMORY_HASH=$(sha256sum "$MEMORY_DUMP" | cut -d' ' -f1)

# Run Volatility3 plugins
echo "[$(date)] Running Volatility3 analysis..."

# System information
volatility3 -f "$MEMORY_DUMP" windows.info > "$OUTPUT_DIR/sysinfo.txt" 2>/dev/null || echo "System info failed"

# Process analysis
volatility3 -f "$MEMORY_DUMP" windows.pslist > "$OUTPUT_DIR/processes.txt" 2>/dev/null || echo "Process list failed"
volatility3 -f "$MEMORY_DUMP" windows.pstree > "$OUTPUT_DIR/process_tree.txt" 2>/dev/null || echo "Process tree failed"
volatility3 -f "$MEMORY_DUMP" windows.cmdline > "$OUTPUT_DIR/cmdline.txt" 2>/dev/null || echo "Command line failed"

# Network analysis
volatility3 -f "$MEMORY_DUMP" windows.netstat > "$OUTPUT_DIR/network_connections.txt" 2>/dev/null || echo "Network connections failed"

# Malware detection
volatility3 -f "$MEMORY_DUMP" windows.malfind > "$OUTPUT_DIR/malfind.txt" 2>/dev/null || echo "Malfind failed"

# Convert results to JSON
echo "[$(date)] Converting to JSON format..."
python3 /opt/forensics/scripts/volatility_to_json.py "$OUTPUT_DIR" "$CASE_ID" "$MEMORY_HASH"

echo "[$(date)] Memory analysis completed for case: $CASE_ID"