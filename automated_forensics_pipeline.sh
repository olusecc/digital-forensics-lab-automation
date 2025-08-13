#!/bin/bash
# Enhanced Jenkins Pipeline with Forensic Tools Integration

# This script demonstrates how each tool can be integrated into the Jenkins pipeline

CASE_NUMBER="$1"
EVIDENCE_PATH="$2"
EVIDENCE_TYPE="$3"  # disk, memory, mobile, file
CASE_DIR="/var/lib/jenkins/forensics/cases/${CASE_NUMBER}"

echo "🔬 Starting automated forensics analysis for case: $CASE_NUMBER"
echo "Evidence: $EVIDENCE_PATH"
echo "Type: $EVIDENCE_TYPE"

# Create structured output directories
mkdir -p "$CASE_DIR"/{sleuthkit,volatility,yara,cape,andriller,autopsy}

# Function to log results to Elasticsearch
log_to_elk() {
    local tool="$1"
    local stage="$2"
    local result="$3"
    local details="$4"
    
    curl -X POST "http://34.123.164.154:9200/forensics-analysis/_doc/" \
    -H "Content-Type: application/json" \
    -d "{
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\",
        \"case_number\": \"$CASE_NUMBER\",
        \"tool\": \"$tool\",
        \"stage\": \"$stage\",
        \"result\": \"$result\",
        \"details\": \"$details\",
        \"evidence_type\": \"$EVIDENCE_TYPE\"
    }"
}

# YARA Scanning (HIGHLY AUTOMATABLE - Perfect for pipeline)
if [ -f "$EVIDENCE_PATH" ]; then
    echo "🔍 Running YARA malware detection..."
    YARA_RESULTS=$(yara /opt/forensics/yara_rules/*.yar "$EVIDENCE_PATH" 2>/dev/null || echo "No matches")
    echo "$YARA_RESULTS" > "$CASE_DIR/yara/scan_results.txt"
    
    if [ "$YARA_RESULTS" != "No matches" ]; then
        log_to_elk "yara" "malware_detection" "MALWARE_DETECTED" "$YARA_RESULTS"
        echo "⚠️  MALWARE DETECTED: $YARA_RESULTS"
    else
        log_to_elk "yara" "malware_detection" "clean" "No malware signatures detected"
    fi
fi

# Volatility Memory Analysis (HIGHLY AUTOMATABLE)
if [ "$EVIDENCE_TYPE" = "memory" ]; then
    echo "🧠 Running Volatility memory analysis..."
    
    # Process list
    volatility3 -f "$EVIDENCE_PATH" windows.pslist --output-file "$CASE_DIR/volatility/processes.json" --output json
    log_to_elk "volatility" "process_analysis" "completed" "Process list extracted"
    
    # Network connections
    volatility3 -f "$EVIDENCE_PATH" windows.netscan --output-file "$CASE_DIR/volatility/network.json" --output json
    log_to_elk "volatility" "network_analysis" "completed" "Network connections analyzed"
    
    # Malware detection
    volatility3 -f "$EVIDENCE_PATH" windows.malfind --output-file "$CASE_DIR/volatility/malfind.json" --output json
    log_to_elk "volatility" "malware_hunt" "completed" "Memory malware scan completed"
    
    # DLL list for forensic analysis
    volatility3 -f "$EVIDENCE_PATH" windows.dlllist --output-file "$CASE_DIR/volatility/dlls.json" --output json
fi

# Sleuth Kit File System Analysis (HIGHLY AUTOMATABLE)
if [ "$EVIDENCE_TYPE" = "disk" ]; then
    echo "💾 Running Sleuth Kit disk analysis..."
    
    # File system timeline
    fls -r -m C: "$EVIDENCE_PATH" > "$CASE_DIR/sleuthkit/filesystem_timeline.csv"
    log_to_elk "sleuthkit" "timeline_creation" "completed" "File system timeline created"
    
    # Partition information
    mmls "$EVIDENCE_PATH" > "$CASE_DIR/sleuthkit/partition_info.txt"
    
    # Deleted files recovery
    fls -d -r "$EVIDENCE_PATH" > "$CASE_DIR/sleuthkit/deleted_files.txt"
    log_to_elk "sleuthkit" "deleted_file_scan" "completed" "Deleted files identified"
fi

# CAPE Sandbox Analysis (MOSTLY AUTOMATABLE)
if [ "$EVIDENCE_TYPE" = "file" ] && [ "$YARA_RESULTS" != "No matches" ]; then
    echo "🏖️ Submitting to CAPE sandbox for dynamic analysis..."
    
    # Submit to CAPE (requires CAPE API to be running)
    if systemctl is-active --quiet cape; then
        CAPE_TASK_ID=$(python3 /opt/CAPEv2/utils/submit.py --file "$EVIDENCE_PATH" --tags "$CASE_NUMBER,automated" | grep "Task ID" | awk '{print $NF}')
        
        if [ -n "$CAPE_TASK_ID" ]; then
            echo "📝 CAPE Task ID: $CAPE_TASK_ID"
            echo "$CAPE_TASK_ID" > "$CASE_DIR/cape/task_id.txt"
            log_to_elk "cape" "submission" "submitted" "Task ID: $CAPE_TASK_ID"
            
            # Note: CAPE analysis takes time - would need separate job to collect results
            echo "⏳ CAPE analysis submitted - results will be available later"
        fi
    else
        log_to_elk "cape" "submission" "failed" "CAPE service not running"
    fi
fi

# Andriller Mobile Analysis (PARTIALLY AUTOMATABLE)
if [ "$EVIDENCE_TYPE" = "mobile" ]; then
    echo "📱 Running Andriller mobile analysis..."
    
    # This requires the device to be connected and unlocked
    if [ -b "$EVIDENCE_PATH" ]; then  # Block device (actual mobile device)
        andriller -d "$EVIDENCE_PATH" --output "$CASE_DIR/andriller/" 2>&1 | tee "$CASE_DIR/andriller/extraction.log"
        log_to_elk "andriller" "mobile_extraction" "attempted" "Mobile data extraction attempted"
    else
        echo "⚠️  Mobile analysis requires physical device connection"
        log_to_elk "andriller" "mobile_extraction" "skipped" "No mobile device detected"
    fi
fi

# Autopsy Analysis (MOSTLY AUTOMATABLE but limited CLI)
if [ "$EVIDENCE_TYPE" = "disk" ]; then
    echo "🔍 Initiating Autopsy analysis..."
    
    # Create Autopsy case (if autopsy CLI is available)
    AUTOPSY_CASE_DIR="$CASE_DIR/autopsy"
    mkdir -p "$AUTOPSY_CASE_DIR"
    
    # Note: Autopsy is primarily GUI-based, limited CLI automation
    # This would require custom scripting or Autopsy Python modules
    echo "📋 Autopsy case directory created: $AUTOPSY_CASE_DIR"
    echo "⚠️  Autopsy analysis requires manual intervention for best results"
    log_to_elk "autopsy" "case_creation" "manual_required" "Autopsy case prepared for manual analysis"
fi

# Generate automated report
echo "📄 Generating automated analysis report..."
cat > "$CASE_DIR/automated_analysis_report.txt" << EOF
===============================================
AUTOMATED FORENSICS ANALYSIS REPORT
===============================================
Case Number: $CASE_NUMBER
Evidence: $EVIDENCE_PATH
Evidence Type: $EVIDENCE_TYPE
Analysis Date: $(date)
Jenkins Build: $BUILD_NUMBER

AUTOMATED ANALYSIS RESULTS:
===============================================

YARA Malware Detection:
$(cat "$CASE_DIR/yara/scan_results.txt" 2>/dev/null || echo "Not performed")

Volatility Memory Analysis:
$([ -f "$CASE_DIR/volatility/processes.json" ] && echo "✅ Process analysis completed" || echo "❌ Not performed")
$([ -f "$CASE_DIR/volatility/network.json" ] && echo "✅ Network analysis completed" || echo "❌ Not performed")

Sleuth Kit Disk Analysis:
$([ -f "$CASE_DIR/sleuthkit/filesystem_timeline.csv" ] && echo "✅ Timeline created" || echo "❌ Not performed")
$([ -f "$CASE_DIR/sleuthkit/deleted_files.txt" ] && echo "✅ Deleted files scanned" || echo "❌ Not performed")

CAPE Sandbox:
$([ -f "$CASE_DIR/cape/task_id.txt" ] && echo "✅ Submitted for analysis (Task ID: $(cat "$CASE_DIR/cape/task_id.txt"))" || echo "❌ Not submitted")

MANUAL ANALYSIS REQUIRED:
===============================================
- Autopsy comprehensive disk analysis
- CAPE sandbox results interpretation
- Mobile device deep analysis (if applicable)
- Expert timeline correlation
- Legal evidence documentation

RECOMMENDATIONS:
===============================================
1. Review automated findings in Kibana dashboard
2. Conduct manual Autopsy analysis for comprehensive results
3. Monitor CAPE sandbox for behavioral analysis completion
4. Correlate findings across all tools for complete picture

EOF

# Final ELK logging
log_to_elk "automation_engine" "analysis_complete" "completed" "Automated analysis pipeline finished"

echo ""
echo "🎯 AUTOMATED ANALYSIS COMPLETE!"
echo "================================"
echo "📁 Case Directory: $CASE_DIR"
echo "📊 View results in Kibana: http://34.123.164.154:5601"
echo "📋 View case in IRIS: https://34.123.164.154:443"
echo ""
echo "⚠️  IMPORTANT: Automated analysis provides initial findings."
echo "   Manual expert analysis required for comprehensive investigation."
echo ""
