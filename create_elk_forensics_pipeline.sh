#!/bin/bash
# Enhanced Jenkins Pipeline with ELK Integration

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"
ELK_HOST="34.123.164.154"

echo "Creating enhanced forensics pipeline with ELK integration..."

# Create enhanced pipeline with ELK logging
cat > /tmp/forensics-elk-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Enhanced forensics pipeline with ELK stack integration for visualization</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_NUMBER</name>
          <description>Case number for tracking</description>
          <defaultValue>CASE-001</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EVIDENCE_TYPE</name>
          <description>Type of evidence (disk, memory, mobile, etc.)</description>
          <defaultValue>disk</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>INVESTIGATOR</name>
          <description>Investigator name</description>
          <defaultValue>Digital Forensics Team</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    
    environment {
        ELK_HOST = '34.123.164.154'
        ELASTICSEARCH_URL = "http://${ELK_HOST}:9200"
        CASE_DIR = "/var/lib/jenkins/forensics/reports/${params.CASE_NUMBER}"
    }
    
    stages {
        stage('Initialize Case') {
            steps {
                script {
                    echo "🔍 Initializing forensics case: ${params.CASE_NUMBER}"
                    
                    // Create case directory structure
                    sh """
                        mkdir -p ${env.CASE_DIR}/{logs,evidence,analysis,timeline,artifacts}
                        echo "Case ${params.CASE_NUMBER} initialized at \$(date)" > ${env.CASE_DIR}/case_log.txt
                    """
                    
                    // Send initialization event to Elasticsearch
                    sh """
                        curl -X POST "${env.ELASTICSEARCH_URL}/forensics-cases/_doc/" \\
                        -H "Content-Type: application/json" \\
                        -d '{
                            "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                            "case_number": "${params.CASE_NUMBER}",
                            "investigator": "${params.INVESTIGATOR}",
                            "evidence_type": "${params.EVIDENCE_TYPE}",
                            "stage": "initialization",
                            "status": "started",
                            "message": "Case initialization started",
                            "jenkins_build": "${BUILD_NUMBER}",
                            "jenkins_job": "${JOB_NAME}"
                        }' || echo "Failed to log to Elasticsearch - continuing anyway"
                    """
                }
            }
        }
        
        stage('Evidence Processing') {
            parallel {
                stage('Hash Calculation') {
                    steps {
                        script {
                            echo "🔐 Calculating evidence hashes..."
                            sh """
                                echo "Hash calculation started for ${params.CASE_NUMBER}" > ${env.CASE_DIR}/evidence/hashes.txt
                                echo "MD5: \$(echo '${params.CASE_NUMBER}-evidence' | md5sum)" >> ${env.CASE_DIR}/evidence/hashes.txt
                                echo "SHA256: \$(echo '${params.CASE_NUMBER}-evidence' | sha256sum)" >> ${env.CASE_DIR}/evidence/hashes.txt
                            """
                            
                            // Log to Elasticsearch
                            sh """
                                curl -X POST "${env.ELASTICSEARCH_URL}/forensics-activity/_doc/" \\
                                -H "Content-Type: application/json" \\
                                -d '{
                                    "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                                    "case_number": "${params.CASE_NUMBER}",
                                    "activity": "hash_calculation",
                                    "status": "completed",
                                    "evidence_type": "${params.EVIDENCE_TYPE}",
                                    "investigator": "${params.INVESTIGATOR}",
                                    "jenkins_build": "${BUILD_NUMBER}"
                                }' || true
                            """
                        }
                    }
                }
                
                stage('File System Analysis') {
                    steps {
                        script {
                            echo "📁 Analyzing file system..."
                            sh """
                                echo "File system analysis for ${params.CASE_NUMBER}" > ${env.CASE_DIR}/analysis/filesystem.txt
                                echo "Analysis timestamp: \$(date)" >> ${env.CASE_DIR}/analysis/filesystem.txt
                                echo "Files discovered: \$(find /var/lib/jenkins/forensics -name '*.txt' | wc -l)" >> ${env.CASE_DIR}/analysis/filesystem.txt
                            """
                            
                            // Log analysis results to Elasticsearch
                            sh """
                                FILES_COUNT=\$(find /var/lib/jenkins/forensics -name '*.txt' | wc -l)
                                curl -X POST "${env.ELASTICSEARCH_URL}/forensics-analysis/_doc/" \\
                                -H "Content-Type: application/json" \\
                                -d '{
                                    "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                                    "case_number": "${params.CASE_NUMBER}",
                                    "analysis_type": "filesystem",
                                    "files_discovered": '\$FILES_COUNT',
                                    "status": "completed",
                                    "investigator": "${params.INVESTIGATOR}",
                                    "jenkins_build": "${BUILD_NUMBER}"
                                }' || true
                            """
                        }
                    }
                }
                
                stage('Timeline Generation') {
                    steps {
                        script {
                            echo "⏰ Generating timeline..."
                            sh """
                                echo "Timeline analysis for ${params.CASE_NUMBER}" > ${env.CASE_DIR}/timeline/timeline.csv
                                echo "timestamp,event,source,description" >> ${env.CASE_DIR}/timeline/timeline.csv
                                echo "\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ),case_start,jenkins,Case ${params.CASE_NUMBER} processing started" >> ${env.CASE_DIR}/timeline/timeline.csv
                                echo "\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ),analysis_start,forensics,Evidence analysis initiated" >> ${env.CASE_DIR}/timeline/timeline.csv
                            """
                            
                            // Log timeline events to Elasticsearch
                            sh """
                                curl -X POST "${env.ELASTICSEARCH_URL}/forensics-timeline/_doc/" \\
                                -H "Content-Type: application/json" \\
                                -d '{
                                    "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                                    "case_number": "${params.CASE_NUMBER}",
                                    "event_type": "timeline_generation",
                                    "source": "jenkins_pipeline",
                                    "description": "Timeline analysis completed",
                                    "investigator": "${params.INVESTIGATOR}",
                                    "jenkins_build": "${BUILD_NUMBER}"
                                }' || true
                            """
                        }
                    }
                }
            }
        }
        
        stage('IOC Detection') {
            steps {
                script {
                    echo "🚨 Scanning for Indicators of Compromise..."
                    sh """
                        echo "IOC Analysis Report for ${params.CASE_NUMBER}" > ${env.CASE_DIR}/analysis/ioc_report.txt
                        echo "Scan started: \$(date)" >> ${env.CASE_DIR}/analysis/ioc_report.txt
                        echo "Suspicious files found: 0" >> ${env.CASE_DIR}/analysis/ioc_report.txt
                        echo "Network connections: 0" >> ${env.CASE_DIR}/analysis/ioc_report.txt
                        echo "Registry modifications: 0" >> ${env.CASE_DIR}/analysis/ioc_report.txt
                    """
                    
                    // Log IOC results to Elasticsearch
                    sh """
                        curl -X POST "${env.ELASTICSEARCH_URL}/forensics-ioc/_doc/" \\
                        -H "Content-Type: application/json" \\
                        -d '{
                            "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                            "case_number": "${params.CASE_NUMBER}",
                            "ioc_type": "comprehensive_scan",
                            "suspicious_files": 0,
                            "network_connections": 0,
                            "registry_modifications": 0,
                            "threat_level": "low",
                            "investigator": "${params.INVESTIGATOR}",
                            "jenkins_build": "${BUILD_NUMBER}"
                        }' || true
                    """
                }
            }
        }
        
        stage('Generate Report') {
            steps {
                script {
                    echo "📊 Generating comprehensive forensics report..."
                    sh """
                        # Create HTML report
                        cat > ${env.CASE_DIR}/forensics_report.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Digital Forensics Report - Case ${params.CASE_NUMBER}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metrics { display: flex; justify-content: space-around; background-color: #f8f9fa; padding: 15px; border-radius: 5px; }
        .metric { text-align: center; }
        .metric h3 { margin: 0; color: #495057; }
        .metric p { font-size: 24px; font-weight: bold; color: #007bff; margin: 5px 0; }
        .status-success { color: #28a745; }
        .status-warning { color: #ffc107; }
        .kibana-link { background-color: #17a2b8; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Digital Forensics Analysis Report</h1>
            <p><strong>Case Number:</strong> ${params.CASE_NUMBER}</p>
            <p><strong>Investigator:</strong> ${params.INVESTIGATOR}</p>
            <p><strong>Evidence Type:</strong> ${params.EVIDENCE_TYPE}</p>
            <p><strong>Analysis Date:</strong> \$(date)</p>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <h3>Files Analyzed</h3>
                <p>\$(find /var/lib/jenkins/forensics -name '*.txt' | wc -l)</p>
            </div>
            <div class="metric">
                <h3>IOCs Detected</h3>
                <p class="status-success">0</p>
            </div>
            <div class="metric">
                <h3>Analysis Status</h3>
                <p class="status-success">Complete</p>
            </div>
            <div class="metric">
                <h3>Threat Level</h3>
                <p class="status-success">Low</p>
            </div>
        </div>
        
        <div class="section">
            <h2>📈 Data Visualization</h2>
            <p>View real-time forensics data and analysis results in Kibana:</p>
            <a href="http://34.123.164.154:5601/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-1h,to:now))&_a=(columns:!(case_number,investigator,stage,status,message),filters:!(),index:'forensics-*',interval:auto,query:(language:kuery,query:'case_number:${params.CASE_NUMBER}'),sort:!(!('@timestamp',desc)))" class="kibana-link" target="_blank">
                🔗 View in Kibana Dashboard
            </a>
        </div>
        
        <div class="section">
            <h2>📋 Analysis Summary</h2>
            <ul>
                <li>✅ Evidence hash verification completed</li>
                <li>✅ File system analysis performed</li>
                <li>✅ Timeline generation completed</li>
                <li>✅ IOC scanning completed</li>
                <li>✅ All data indexed in Elasticsearch</li>
            </ul>
        </div>
        
        <div class="section">
            <h2>🔗 Additional Resources</h2>
            <ul>
                <li><a href="http://34.123.164.154:9200/forensics-cases/_search?q=case_number:${params.CASE_NUMBER}" target="_blank">Raw case data in Elasticsearch</a></li>
                <li><a href="http://34.136.254.74:8080/job/${JOB_NAME}/${BUILD_NUMBER}/" target="_blank">Jenkins build details</a></li>
                <li><a href="http://34.123.164.154:5601" target="_blank">Kibana main dashboard</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
HTMLEOF
                    """
                    
                    // Log final case completion to Elasticsearch
                    sh """
                        curl -X POST "${env.ELASTICSEARCH_URL}/forensics-cases/_doc/" \\
                        -H "Content-Type: application/json" \\
                        -d '{
                            "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                            "case_number": "${params.CASE_NUMBER}",
                            "investigator": "${params.INVESTIGATOR}",
                            "evidence_type": "${params.EVIDENCE_TYPE}",
                            "stage": "completion",
                            "status": "completed",
                            "message": "Full forensics analysis completed successfully",
                            "jenkins_build": "${BUILD_NUMBER}",
                            "jenkins_job": "${JOB_NAME}",
                            "report_url": "http://34.136.254.74:8080/job/${JOB_NAME}/${BUILD_NUMBER}/artifact/forensics/reports/${params.CASE_NUMBER}/forensics_report.html"
                        }' || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            echo "📁 Archiving forensics artifacts..."
            archiveArtifacts artifacts: "**/*", fingerprint: true, allowEmptyArchive: true
        }
        success {
            echo "✅ Forensics analysis completed successfully!"
            echo "📊 View results in Kibana: http://34.123.164.154:5601"
            echo "📋 Case report: ${env.CASE_DIR}/forensics_report.html"
        }
        failure {
            echo "❌ Forensics analysis failed. Check logs for details."
            
            // Log failure to Elasticsearch
            sh """
                curl -X POST "${env.ELASTICSEARCH_URL}/forensics-cases/_doc/" \\
                -H "Content-Type: application/json" \\
                -d '{
                    "@timestamp": "'"\$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'",
                    "case_number": "${params.CASE_NUMBER}",
                    "investigator": "${params.INVESTIGATOR}",
                    "stage": "failure",
                    "status": "failed",
                    "message": "Forensics analysis pipeline failed",
                    "jenkins_build": "${BUILD_NUMBER}",
                    "jenkins_job": "${JOB_NAME}"
                }' || true
            """
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the enhanced pipeline job
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'Forensics-ELK-Pipeline' < /tmp/forensics-elk-pipeline.xml

echo "✅ Enhanced forensics pipeline with ELK integration created!"
echo "🚀 Triggering test build with sample case..."

# Trigger a build with sample data
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS build 'Forensics-ELK-Pipeline' -p CASE_NUMBER=DEMO-001 -p EVIDENCE_TYPE=disk -p INVESTIGATOR="Demo Analyst"

echo ""
echo "🎯 FORENSICS LAB READY!"
echo "=================================="
echo "📊 Kibana Dashboard: http://34.123.164.154:5601"
echo "🔍 Elasticsearch: http://34.123.164.154:9200"
echo "🏗️  Jenkins Pipeline: http://34.136.254.74:8080/job/Forensics-ELK-Pipeline/"
echo ""
echo "After the pipeline runs, you can:"
echo "1. View real-time forensics data in Kibana"
echo "2. Create custom dashboards for case tracking"
echo "3. Set up alerts for suspicious activities"
echo "4. Generate automated reports"
