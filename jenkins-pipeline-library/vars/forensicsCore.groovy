// Digital Forensics Processing Functions for Jenkins
// Contains all forensic tool integrations and processing logic

def initEvidence(String caseId, String evidenceType, String evidencePath) {
    script {
        def timestamp = new Date().format('yyyy-MM-dd_HH-mm-ss')
        def workingDir = "${env.FORENSICS_WORKSPACE}/${caseId}/${evidenceType}_${timestamp}"
        
        // Create working directory structure
        sh """
            mkdir -p ${workingDir}/{input,output,temp,logs}
            echo "Evidence Type: ${evidenceType}" > ${workingDir}/metadata.txt
            echo "Evidence Path: ${evidencePath}" >> ${workingDir}/metadata.txt
            echo "Processing Started: ${timestamp}" >> ${workingDir}/metadata.txt
            echo "Case ID: ${caseId}" >> ${workingDir}/metadata.txt
        """
        
        env.WORKING_DIR = workingDir
        echo "✅ Initialized evidence processing workspace: ${workingDir}"
        return workingDir
    }
}

def validateEvidence(String evidencePath) {
    script {
        echo "🔍 Validating evidence integrity: ${evidencePath}"
        
        // Check if file exists and is readable
        sh """
            if [ ! -f "${evidencePath}" ]; then
                echo "ERROR: Evidence file not found: ${evidencePath}"
                exit 1
            fi
            
            if [ ! -r "${evidencePath}" ]; then
                echo "ERROR: Evidence file not readable: ${evidencePath}"
                exit 1
            fi
        """
        
        // Generate file hashes for integrity verification
        def hashes = sh(
            script: """
                echo "=== File Integrity Verification ==="
                echo "File: ${evidencePath}"
                echo "Size: \$(stat -f%z "${evidencePath}" 2>/dev/null || stat -c%s "${evidencePath}")"
                echo "MD5: \$(md5sum "${evidencePath}" | cut -d' ' -f1)"
                echo "SHA1: \$(sha1sum "${evidencePath}" | cut -d' ' -f1)"
                echo "SHA256: \$(sha256sum "${evidencePath}" | cut -d' ' -f1)"
            """,
            returnStdout: true
        ).trim()
        
        // Save hashes to working directory
        writeFile file: "${env.WORKING_DIR}/evidence_hashes.txt", text: hashes
        echo "✅ Evidence validation completed"
        return hashes
    }
}

def generateMetadata(String evidencePath, String caseId) {
    script {
        echo "📋 Generating evidence metadata"
        
        def metadata = sh(
            script: """
                echo "=== Evidence Metadata ==="
                echo "File: ${evidencePath}"
                echo "Type: \$(file "${evidencePath}")"
                echo "Size: \$(stat -f%z "${evidencePath}" 2>/dev/null || stat -c%s "${evidencePath}") bytes"
                echo "Created: \$(stat -f%SB "${evidencePath}" 2>/dev/null || stat -c%y "${evidencePath}")"
                echo "Modified: \$(stat -f%Sm "${evidencePath}" 2>/dev/null || stat -c%y "${evidencePath}")"
                echo "Permissions: \$(stat -f%Mp%Lp "${evidencePath}" 2>/dev/null || stat -c%a "${evidencePath}")"
                
                # Additional file analysis
                if command -v hexdump >/dev/null; then
                    echo "Header (hex): \$(hexdump -C "${evidencePath}" | head -3)"
                fi
                
                if command -v strings >/dev/null; then
                    echo "Strings preview: \$(strings "${evidencePath}" | head -10)"
                fi
            """,
            returnStdout: true
        ).trim()
        
        writeFile file: "${env.WORKING_DIR}/evidence_metadata.txt", text: metadata
        echo "✅ Evidence metadata generated"
        return metadata
    }
}

def processDiskImage(String evidencePath, String caseId, String analysisLevel = 'standard') {
    script {
        echo "💽 Processing disk image with ${analysisLevel} analysis"
        
        def outputDir = "${env.WORKING_DIR}/output"
        def logFile = "${env.WORKING_DIR}/logs/disk_processing.log"
        
        // Run Autopsy analysis
        sh """
            echo "Starting Autopsy disk image analysis..." >> ${logFile}
            cd ${outputDir}
            
            # Create Autopsy case
            python3 /opt/autopsy/bin/autopsy_cli.py \\
                --case-name "${caseId}_disk_analysis" \\
                --case-dir ${outputDir}/autopsy \\
                --image "${evidencePath}" \\
                --analysis-level ${analysisLevel} \\
                >> ${logFile} 2>&1
        """
        
        // Run Sleuth Kit analysis
        sh """
            echo "Running Sleuth Kit analysis..." >> ${logFile}
            mkdir -p ${outputDir}/sleuthkit
            
            # File system analysis
            fsstat "${evidencePath}" > ${outputDir}/sleuthkit/filesystem_info.txt 2>&1 || true
            
            # Generate timeline
            if [ "${analysisLevel}" != "basic" ]; then
                fls -r -m / "${evidencePath}" > ${outputDir}/sleuthkit/timeline.csv 2>&1 || true
            fi
            
            # Extract file list
            fls -r "${evidencePath}" > ${outputDir}/sleuthkit/file_list.txt 2>&1 || true
        """
        
        // Process results for ELK ingestion
        processForELK("disk", outputDir, caseId)
        
        echo "✅ Disk image processing completed"
        return outputDir
    }
}

def processMemoryDump(String evidencePath, String caseId, String analysisLevel = 'standard') {
    script {
        echo "🧠 Processing memory dump with ${analysisLevel} analysis"
        
        def outputDir = "${env.WORKING_DIR}/output"
        def logFile = "${env.WORKING_DIR}/logs/memory_processing.log"
        
        // Run Volatility3 analysis
        sh """
            echo "Starting Volatility3 memory analysis..." >> ${logFile}
            cd ${outputDir}
            mkdir -p volatility3
            
            # Activate forensics Python environment
            source /var/lib/jenkins/forensics/forensics-env/bin/activate
            
            # Basic analysis
            python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.info > volatility3/system_info.txt 2>&1 || true
            python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.pslist > volatility3/process_list.txt 2>&1 || true
            python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.netstat > volatility3/network_connections.txt 2>&1 || true
            
            if [ "${analysisLevel}" != "basic" ]; then
                # Advanced analysis
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.malfind > volatility3/malfind.txt 2>&1 || true
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.filescan > volatility3/file_scan.txt 2>&1 || true
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.handles > volatility3/handles.txt 2>&1 || true
            fi
            
            if [ "${analysisLevel}" == "comprehensive" ]; then
                # Comprehensive analysis
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.registry.hivelist > volatility3/registry_hives.txt 2>&1 || true
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.cmdline > volatility3/command_lines.txt 2>&1 || true
                python3 /opt/volatility3/vol.py -f "${evidencePath}" windows.dumpfiles --virtaddr 0x1000 > volatility3/extracted_files.txt 2>&1 || true
            fi
        """
        
        // Process results for ELK ingestion
        processForELK("memory", outputDir, caseId)
        
        echo "✅ Memory dump processing completed"
        return outputDir
    }
}

def processMobileData(String evidencePath, String caseId, String analysisLevel = 'standard') {
    script {
        echo "📱 Processing mobile data with ${analysisLevel} analysis"
        
        def outputDir = "${env.WORKING_DIR}/output"
        def logFile = "${env.WORKING_DIR}/logs/mobile_processing.log"
        
        // Run Andriller analysis
        sh """
            echo "Starting Andriller mobile analysis..." >> ${logFile}
            cd ${outputDir}
            mkdir -p andriller
            
            # Activate forensics Python environment
            source /var/lib/jenkins/forensics/forensics-env/bin/activate
            
            # Run Andriller processing
            python3 /opt/andriller/andriller.py \\
                --input "${evidencePath}" \\
                --output andriller/ \\
                --case-id "${caseId}" \\
                --analysis-level ${analysisLevel} \\
                >> ${logFile} 2>&1 || true
        """
        
        // Process results for ELK ingestion
        processForELK("mobile", outputDir, caseId)
        
        echo "✅ Mobile data processing completed"
        return outputDir
    }
}

def processMalwareSample(String evidencePath, String caseId, String analysisLevel = 'standard') {
    script {
        echo "🦠 Processing malware sample with ${analysisLevel} analysis"
        
        def outputDir = "${env.WORKING_DIR}/output"
        def logFile = "${env.WORKING_DIR}/logs/malware_processing.log"
        
        // Static analysis
        sh """
            echo "Starting static malware analysis..." >> ${logFile}
            cd ${outputDir}
            mkdir -p malware/{static,dynamic}
            
            # File type and basic info
            file "${evidencePath}" > malware/static/file_type.txt
            
            # Hashes
            md5sum "${evidencePath}" > malware/static/hashes.txt
            sha1sum "${evidencePath}" >> malware/static/hashes.txt
            sha256sum "${evidencePath}" >> malware/static/hashes.txt
            
            # Strings extraction
            strings "${evidencePath}" > malware/static/strings.txt 2>&1 || true
            
            # Hex dump (first 1MB)
            xxd "${evidencePath}" | head -1000 > malware/static/hexdump.txt 2>&1 || true
        """
        
        // Yara scanning if available
        sh """
            if command -v yara >/dev/null && [ -d /opt/yara-rules ]; then
                echo "Running Yara rule scanning..." >> ${logFile}
                yara -r /opt/yara-rules/ "${evidencePath}" > ${outputDir}/malware/static/yara_matches.txt 2>&1 || true
            fi
        """
        
        // TODO: CAPE Sandbox integration would go here
        // For now, we'll simulate dynamic analysis results
        sh """
            echo "Dynamic analysis placeholder - CAPE Sandbox integration pending" > ${outputDir}/malware/dynamic/cape_analysis.txt
            echo "Sample: ${evidencePath}" >> ${outputDir}/malware/dynamic/cape_analysis.txt
            echo "Analysis Level: ${analysisLevel}" >> ${outputDir}/malware/dynamic/cape_analysis.txt
        """
        
        // Process results for ELK ingestion
        processForELK("malware", outputDir, caseId)
        
        echo "✅ Malware sample processing completed"
        return outputDir
    }
}

def processForELK(String evidenceType, String outputDir, String caseId) {
    script {
        echo "📊 Processing results for ELK ingestion"
        
        // Convert results to JSON format for Logstash
        sh """
            cd ${outputDir}
            mkdir -p elk_json
            
            # Create base event structure
            cat > elk_json/base_event.json << EOF
{
    "case_id": "${caseId}",
    "evidence_type": "${evidenceType}",
    "timestamp": "\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
    "processing_node": "\$(hostname)",
    "jenkins_build": "${env.BUILD_NUMBER}"
}
EOF
        """
        
        // Send to Logstash via HTTP
        sh """
            if command -v curl >/dev/null; then
                find ${outputDir} -name "*.txt" -o -name "*.csv" | while read file; do
                    echo "Sending \$file to ELK..." >> ${env.WORKING_DIR}/logs/elk_ingestion.log
                    # TODO: Implement actual Logstash HTTP input
                    # curl -X POST "${env.ELK_URL}/_bulk" -H "Content-Type: application/json" --data-binary @\$file
                done
            fi
        """
        
        echo "✅ ELK processing completed"
    }
}

def extractIOCs(String evidencePath, String evidenceType) {
    script {
        echo "🎯 Extracting IOCs from evidence"
        
        def iocs = []
        
        // Extract different IOC types based on evidence type
        def iocData = sh(
            script: """
                case "${evidenceType}" in
                    "disk"|"memory")
                        # Extract IP addresses
                        grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}' "${evidencePath}" 2>/dev/null | head -100 || true
                        
                        # Extract domain names
                        grep -oE '[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}' "${evidencePath}" 2>/dev/null | head -100 || true
                        
                        # Extract email addresses
                        grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}' "${evidencePath}" 2>/dev/null | head -50 || true
                        ;;
                    "malware")
                        # Extract file hashes
                        strings "${evidencePath}" | grep -oE '[a-fA-F0-9]{32}|[a-fA-F0-9]{40}|[a-fA-F0-9]{64}' | head -50 || true
                        ;;
                esac
            """,
            returnStdout: true
        ).trim()
        
        // Process extracted IOCs
        iocData.split('\n').each { ioc ->
            if (ioc.trim()) {
                iocs << [
                    value: ioc.trim(),
                    type: detectIOCType(ioc.trim()),
                    source: evidencePath,
                    extraction_method: "automated"
                ]
            }
        }
        
        echo "✅ Extracted ${iocs.size()} IOCs"
        return iocs
    }
}

def detectIOCType(String ioc) {
    if (ioc.matches(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)) {
        return "ip"
    } else if (ioc.contains("@")) {
        return "email"
    } else if (ioc.matches(/^[a-fA-F0-9]{32}$/)) {
        return "md5_hash"
    } else if (ioc.matches(/^[a-fA-F0-9]{40}$/)) {
        return "sha1_hash"
    } else if (ioc.matches(/^[a-fA-F0-9]{64}$/)) {
        return "sha256_hash"
    } else if (ioc.contains(".")) {
        return "domain"
    } else {
        return "unknown"
    }
}

def cleanup(String caseId, String evidenceType) {
    script {
        echo "🧹 Cleaning up temporary files"
        
        // Clean temporary files but preserve important results
        sh """
            if [ -d "${env.WORKING_DIR}/temp" ]; then
                rm -rf ${env.WORKING_DIR}/temp/*
            fi
            
            # Compress logs for archival
            if [ -d "${env.WORKING_DIR}/logs" ]; then
                tar -czf ${env.WORKING_DIR}/logs_archive.tar.gz -C ${env.WORKING_DIR} logs/
            fi
        """
        
        echo "✅ Cleanup completed"
    }
}
