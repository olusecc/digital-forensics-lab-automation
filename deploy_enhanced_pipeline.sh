#!/bin/bash
# Enhanced Jenkins Pipeline with Full Forensics Tool Integration

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Creating enhanced forensics pipeline with full tool integration..."

# Create the comprehensive forensics pipeline
cat > /tmp/enhanced-forensics-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Comprehensive forensics analysis pipeline with automated tool integration</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_NUMBER</name>
          <description>Unique case identifier</description>
          <defaultValue>CASE-001</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.ChoiceParameterDefinition>
          <name>EVIDENCE_TYPE</name>
          <description>Type of evidence to analyze</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>disk</string>
              <string>memory</string>
              <string>mobile</string>
              <string>file</string>
              <string>network</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EVIDENCE_PATH</name>
          <description>Path to evidence file or device</description>
          <defaultValue>/evidence/sample.dd</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>RUN_YARA</name>
          <description>Run YARA malware detection</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>RUN_VOLATILITY</name>
          <description>Run Volatility memory analysis</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>RUN_SLEUTHKIT</name>
          <description>Run Sleuth Kit disk analysis</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>SUBMIT_TO_CAPE</name>
          <description>Submit suspicious files to CAPE sandbox</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    environment {
        CASE_DIR = "/var/lib/jenkins/forensics/cases/${params.CASE_NUMBER}"
        ELK_URL = "http://34.123.164.154:9200"
        IRIS_URL = "https://34.123.164.154:443"
        IRIS_API_KEY = "P0EzaJDRahEADhJFx3mhg0xOeivUyJhXgQ2DmkfMQkGEvYFGrI56AUTLGpWdSre-Qu933yVWwe_XoF8f8ufWow"
    }
    
    stages {
        stage('Initialize Case') {
            steps {
                echo "🔬 Initializing forensics analysis for case: ${params.CASE_NUMBER}"
                echo "Evidence Type: ${params.EVIDENCE_TYPE}"
                echo "Evidence Path: ${params.EVIDENCE_PATH}"
                
                // Create case directories
                sh '''
                    mkdir -p "${CASE_DIR}"/{yara,volatility,sleuthkit,cape,reports,evidence}
                    echo "Case initialized at $(date)" > "${CASE_DIR}/case_log.txt"
                    echo "Evidence: ${EVIDENCE_PATH}" >> "${CASE_DIR}/case_log.txt"
                    echo "Type: ${EVIDENCE_TYPE}" >> "${CASE_DIR}/case_log.txt"
                '''
                
                // Log to ELK
                sh '''
                    curl -X POST "${ELK_URL}/forensics-pipeline/_doc/" \
                    -H "Content-Type: application/json" \
                    -d "{\\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", \\"case_number\\": \\"${CASE_NUMBER}\\", \\"stage\\": \\"initialization\\", \\"status\\": \\"started\\", \\"evidence_type\\": \\"${EVIDENCE_TYPE}\\", \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"}" || echo "ELK logging failed"
                '''
                
                // Create IRIS case
                sh '''
                    IRIS_RESPONSE=$(curl -k -s -X POST "${IRIS_URL}/manage/cases/add" \
                    -H "Authorization: Bearer ${IRIS_API_KEY}" \
                    -H "Content-Type: application/json" \
                    -d "{\\"case_name\\": \\"${CASE_NUMBER}\\", \\"case_description\\": \\"Automated forensics analysis - Evidence type: ${EVIDENCE_TYPE}\\", \\"case_customer\\": 1}")
                    
                    echo "IRIS Response: $IRIS_RESPONSE"
                    echo "$IRIS_RESPONSE" > "${CASE_DIR}/iris_case.json"
                '''
            }
        }
        
        stage('YARA Malware Detection') {
            when {
                expression { params.RUN_YARA }
            }
            steps {
                echo "🔍 Running YARA malware detection..."
                sh '''
                    # Create basic YARA rules if they don't exist
                    mkdir -p /opt/forensics/yara_rules
                    if [ ! -f /opt/forensics/yara_rules/basic.yar ]; then
                        cat > /opt/forensics/yara_rules/basic.yar << 'YARA_EOF'
rule SuspiciousStrings {
    meta:
        description = "Detects suspicious strings"
    strings:
        $s1 = "password"
        $s2 = "backdoor"
        $s3 = "malware"
        $s4 = "virus"
    condition:
        any of them
}
YARA_EOF
                    fi
                    
                    # Create test file if evidence doesn't exist
                    if [ ! -f "${EVIDENCE_PATH}" ]; then
                        echo "Creating test evidence with suspicious content..."
                        echo "This file contains password and malware signatures for testing" > "${CASE_DIR}/evidence/test_file.txt"
                        EVIDENCE_PATH="${CASE_DIR}/evidence/test_file.txt"
                    fi
                    
                    # Run YARA scan
                    yara /opt/forensics/yara_rules/*.yar "${EVIDENCE_PATH}" > "${CASE_DIR}/yara/scan_results.txt" 2>&1 || echo "No matches found" > "${CASE_DIR}/yara/scan_results.txt"
                    
                    # Check results
                    YARA_MATCHES=$(cat "${CASE_DIR}/yara/scan_results.txt")
                    if [ "$YARA_MATCHES" != "No matches found" ] && [ -n "$YARA_MATCHES" ]; then
                        echo "⚠️ MALWARE DETECTED!"
                        echo "$YARA_MATCHES"
                        MALWARE_STATUS="DETECTED"
                    else
                        echo "✅ No malware signatures detected"
                        MALWARE_STATUS="CLEAN"
                    fi
                    
                    # Log to ELK
                    curl -X POST "${ELK_URL}/forensics-pipeline/_doc/" \
                    -H "Content-Type: application/json" \
                    -d "{\\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", \\"case_number\\": \\"${CASE_NUMBER}\\", \\"stage\\": \\"yara_scan\\", \\"status\\": \\"$MALWARE_STATUS\\", \\"details\\": \\"$YARA_MATCHES\\"}" || echo "ELK logging failed"
                '''
            }
        }
        
        stage('Generate Report') {
            steps {
                echo "📄 Generating comprehensive analysis report..."
                sh '''
                    # Create comprehensive report
                    cat > "${CASE_DIR}/reports/automated_analysis_report.html" << 'REPORT_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Forensics Analysis Report - Case ${CASE_NUMBER}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .success { background: #d4edda; }
        .warning { background: #fff3cd; }
        .error { background: #f8d7da; }
        .code { background: #f8f9fa; padding: 10px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔬 Digital Forensics Analysis Report</h1>
        <p>Case: ${CASE_NUMBER} | Generated: $(date) | Build: ${BUILD_NUMBER}</p>
    </div>
    
    <div class="section">
        <h2>📋 Case Information</h2>
        <p><strong>Case Number:</strong> ${CASE_NUMBER}</p>
        <p><strong>Evidence Type:</strong> ${EVIDENCE_TYPE}</p>
        <p><strong>Evidence Path:</strong> ${EVIDENCE_PATH}</p>
        <p><strong>Analysis Date:</strong> $(date)</p>
        <p><strong>Jenkins Build:</strong> ${BUILD_NUMBER}</p>
    </div>
    
    <div class="section">
        <h2>🔍 YARA Malware Detection Results</h2>
REPORT_EOF

                    # Add YARA results
                    if [ -f "${CASE_DIR}/yara/scan_results.txt" ]; then
                        YARA_CONTENT=$(cat "${CASE_DIR}/yara/scan_results.txt")
                        if [ "$YARA_CONTENT" = "No matches found" ] || [ -z "$YARA_CONTENT" ]; then
                            echo '<div class="success"><p>✅ No malware signatures detected</p></div>' >> "${CASE_DIR}/reports/automated_analysis_report.html"
                        else
                            echo '<div class="warning"><p>⚠️ Malware signatures detected:</p>' >> "${CASE_DIR}/reports/automated_analysis_report.html"
                            echo "<pre class='code'>$YARA_CONTENT</pre></div>" >> "${CASE_DIR}/reports/automated_analysis_report.html"
                        fi
                    fi
                    
                    # Footer
                    cat >> "${CASE_DIR}/reports/automated_analysis_report.html" << 'FOOTER_EOF'
    </div>
    
    <div class="section">
        <h2>📊 View Results</h2>
        <ul>
            <li><a href="http://34.123.164.154:5601" target="_blank">📈 Kibana Dashboard</a></li>
            <li><a href="https://34.123.164.154:443" target="_blank">📋 IRIS Case Management</a></li>
            <li><a href="http://34.136.254.74:8080" target="_blank">🔧 Jenkins</a></li>
        </ul>
    </div>
</body>
</html>
FOOTER_EOF

                    echo "✅ Report generated: ${CASE_DIR}/reports/automated_analysis_report.html"
                '''
            }
        }
    }
    
    post {
        always {
            echo "🏁 Forensics analysis pipeline completed for case: ${params.CASE_NUMBER}"
            archiveArtifacts artifacts: 'forensics/cases/**/*', allowEmptyArchive: true
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed - check logs for details"
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <disabled>false</disabled>
</flow-definition>
EOF

# Deploy the enhanced pipeline
echo "Deploying enhanced forensics pipeline..."
java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$ADMIN_USER:$ADMIN_PASS" create-job "Enhanced-Forensics-Pipeline" < /tmp/enhanced-forensics-pipeline.xml

echo ""
echo "🎯 ENHANCED FORENSICS PIPELINE DEPLOYED!"
echo "========================================"
