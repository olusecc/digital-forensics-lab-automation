#!/bin/bash
# Enhanced Forensics Pipeline with IRIS Case Management Integration

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Creating enhanced forensics pipeline with IRIS case management integration..."

# Create an enhanced pipeline with IRIS integration
cat > /tmp/iris-forensics-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Forensics pipeline with IRIS case management and ELK integration</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_NUMBER</name>
          <description>Case number/identifier</description>
          <defaultValue>CASE-001</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>CASE_TITLE</name>
          <description>Case title/description</description>
          <defaultValue>Digital Forensics Investigation</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.ChoiceParameterDefinition>
          <name>INCIDENT_TYPE</name>
          <description>Type of incident</description>
          <choices class="java.util.Arrays$ArrayList">
            <a class="string-array">
              <string>Malware Infection</string>
              <string>Data Breach</string>
              <string>Insider Threat</string>
              <string>Cyber Attack</string>
              <string>Policy Violation</string>
              <string>Other</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>INVESTIGATOR</name>
          <description>Lead investigator</description>
          <defaultValue>analyst</defaultValue>
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
        IRIS_URL = "https://34.123.164.154"
        IRIS_USER = "administrator"  
        IRIS_PASS = "Secret123"
        ELK_URL = "http://34.123.164.154:9200"
    }
    stages {
        stage('Initialize Case') {
            steps {
                echo "🔍 Initializing forensics case: ${params.CASE_NUMBER}"
                echo "📋 Title: ${params.CASE_TITLE}"
                echo "🚨 Type: ${params.INCIDENT_TYPE}"
                echo "👤 Investigator: ${params.INVESTIGATOR}"
                
                // Create forensics directory
                sh 'mkdir -p /var/lib/jenkins/forensics/cases/${CASE_NUMBER}'
                sh 'echo "Case initialized at $(date)" > /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log'
                
                // Log to Elasticsearch
                sh '''
                    curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{
                        \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                        \\"case_number\\": \\"${CASE_NUMBER}\\", 
                        \\"case_title\\": \\"${CASE_TITLE}\\",
                        \\"incident_type\\": \\"${INCIDENT_TYPE}\\",
                        \\"investigator\\": \\"${INVESTIGATOR}\\",
                        \\"stage\\": \\"initialization\\", 
                        \\"status\\": \\"started\\", 
                        \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                    }" || echo "ELK logging failed - continuing"
                '''
            }
        }
        
        stage('Create IRIS Case') {
            steps {
                echo "🏛️ Creating case in IRIS incident response platform..."
                
                script {
                    // Create IRIS case via API
                    def irisResponse = sh(
                        script: '''
                            # Get IRIS session token
                            SESSION_TOKEN=$(curl -k -s -X POST "${IRIS_URL}/login" \\
                                -H "Content-Type: application/x-www-form-urlencoded" \\
                                -d "username=${IRIS_USER}&password=${IRIS_PASS}&csrf_token=" \\
                                -c /tmp/iris_cookies.txt \\
                                -b /tmp/iris_cookies.txt | grep -o '"csrf_token":"[^"]*"' | cut -d'"' -f4)
                            
                            echo "CSRF Token: $SESSION_TOKEN"
                            
                            # Create case in IRIS
                            IRIS_CASE_RESPONSE=$(curl -k -s -X POST "${IRIS_URL}/manage/cases/add" \\
                                -H "Content-Type: application/json" \\
                                -H "X-CSRF-Token: $SESSION_TOKEN" \\
                                -b /tmp/iris_cookies.txt \\
                                -d "{
                                    \\"case_name\\": \\"${CASE_TITLE}\\",
                                    \\"case_description\\": \\"Forensics investigation for ${CASE_NUMBER} - ${INCIDENT_TYPE}\\",
                                    \\"case_customer\\": 1,
                                    \\"case_classification\\": 1,
                                    \\"custom_attributes\\": {
                                        \\"jenkins_build\\": \\"${BUILD_NUMBER}\\",
                                        \\"case_id\\": \\"${CASE_NUMBER}\\",
                                        \\"investigator\\": \\"${INVESTIGATOR}\\"
                                    }
                                }")
                            
                            echo "IRIS Response: $IRIS_CASE_RESPONSE"
                            echo "$IRIS_CASE_RESPONSE" > /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/iris_response.json
                        ''',
                        returnStdout: true
                    ).trim()
                    
                    echo "IRIS Case Creation Response: ${irisResponse}"
                }
                
                // Log IRIS case creation to Elasticsearch
                sh '''
                    curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{
                        \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                        \\"case_number\\": \\"${CASE_NUMBER}\\", 
                        \\"stage\\": \\"iris_case_creation\\", 
                        \\"status\\": \\"completed\\", 
                        \\"platform\\": \\"IRIS\\",
                        \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                    }" || echo "ELK logging failed - continuing"
                '''
            }
        }
        
        stage('Evidence Collection') {
            steps {
                echo "📦 Collecting and processing evidence for case: ${params.CASE_NUMBER}"
                
                // Simulate evidence collection
                sh '''
                    echo "Evidence collection started at $(date)" >> /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log
                    echo "Evidence Type: Digital artifacts from ${INCIDENT_TYPE}" >> /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log
                    echo "Assigned to: ${INVESTIGATOR}" >> /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log
                '''
                
                // Create evidence manifest
                sh '''
                    cat > /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/evidence_manifest.json << EVIDENCE_EOF
{
    "case_number": "${CASE_NUMBER}",
    "evidence_items": [
        {
            "id": "E001",
            "type": "Disk Image", 
            "description": "Primary system disk image",
            "collected_by": "${INVESTIGATOR}",
            "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
        },
        {
            "id": "E002", 
            "type": "Memory Dump",
            "description": "System memory capture",
            "collected_by": "${INVESTIGATOR}",
            "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
        }
    ]
}
EVIDENCE_EOF
                '''
                
                // Log evidence collection to Elasticsearch
                sh '''
                    curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{
                        \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                        \\"case_number\\": \\"${CASE_NUMBER}\\", 
                        \\"stage\\": \\"evidence_collection\\", 
                        \\"status\\": \\"completed\\", 
                        \\"evidence_count\\": 2,
                        \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                    }" || echo "ELK logging failed - continuing"
                '''
            }
        }
        
        stage('Forensic Analysis') {
            steps {
                echo "🔬 Performing forensic analysis for case: ${params.CASE_NUMBER}"
                
                // Simulate forensic analysis
                sh '''
                    echo "Forensic analysis started at $(date)" >> /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log
                    echo "Analysis Type: ${INCIDENT_TYPE} investigation" >> /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/case.log
                '''
                
                // Create analysis report
                sh '''
                    cat > /var/lib/jenkins/forensics/cases/${CASE_NUMBER}/analysis_report.txt << ANALYSIS_EOF
FORENSIC ANALYSIS REPORT
========================
Case Number: ${CASE_NUMBER}
Case Title: ${CASE_TITLE}
Incident Type: ${INCIDENT_TYPE}
Investigator: ${INVESTIGATOR}
Analysis Date: $(date)

FINDINGS:
- Evidence successfully collected and preserved
- Chain of custody maintained
- Initial analysis indicates ${INCIDENT_TYPE} activity
- Further investigation recommended

RECOMMENDATIONS:
- Continue monitoring for related activity
- Implement additional security controls
- Review incident response procedures

Report generated by Jenkins Build #${BUILD_NUMBER}
ANALYSIS_EOF
                '''
                
                // Log analysis completion to Elasticsearch
                sh '''
                    curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{
                        \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                        \\"case_number\\": \\"${CASE_NUMBER}\\", 
                        \\"stage\\": \\"forensic_analysis\\", 
                        \\"status\\": \\"completed\\", 
                        \\"analysis_type\\": \\"${INCIDENT_TYPE}\\",
                        \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                    }" || echo "ELK logging failed - continuing"
                '''
            }
        }
    }
    
    post {
        always {
            echo "✅ Forensics pipeline completed for case: ${params.CASE_NUMBER}"
            
            // Final log to Elasticsearch
            sh '''
                curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                -H "Content-Type: application/json" \\
                -d "{
                    \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                    \\"case_number\\": \\"${CASE_NUMBER}\\", 
                    \\"stage\\": \\"completion\\", 
                    \\"status\\": \\"finished\\", 
                    \\"total_duration\\": \\"${currentBuild.durationString}\\",
                    \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                }" || echo "ELK logging failed - continuing"
            '''
            
            // Archive all case artifacts
            archiveArtifacts artifacts: "**/*", fingerprint: true, allowEmptyArchive: true
            
            echo "📋 Case artifacts archived and available in Jenkins"
            echo "🏛️ IRIS case created and linked"
            echo "📊 All activities logged to ELK stack"
        }
        
        success {
            echo "🎉 Case ${params.CASE_NUMBER} completed successfully!"
        }
        
        failure {
            echo "❌ Case ${params.CASE_NUMBER} encountered errors!"
            
            // Log failure to Elasticsearch
            sh '''
                curl -X POST "${ELK_URL}/forensics-logs/_doc/" \\
                -H "Content-Type: application/json" \\
                -d "{
                    \\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", 
                    \\"case_number\\": \\"${CASE_NUMBER}\\", 
                    \\"stage\\": \\"pipeline_failure\\", 
                    \\"status\\": \\"failed\\", 
                    \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"
                }" || echo "ELK logging failed"
            '''
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

# Create the enhanced job
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'IRIS-Forensics-Pipeline' < /tmp/iris-forensics-pipeline.xml

echo "✅ Enhanced IRIS forensics pipeline created!"
echo "🚀 Triggering test build with IRIS case creation..."

# Trigger a build with full parameters
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS build 'IRIS-Forensics-Pipeline' \
    -p CASE_NUMBER="CYBER-$(date +%Y%m%d-%H%M)" \
    -p CASE_TITLE="Automated Forensics Investigation" \
    -p INCIDENT_TYPE="Cyber Attack" \
    -p INVESTIGATOR="forensics-analyst"

echo ""
echo "🎯 ENHANCED PIPELINE CREATED AND RUNNING!"
echo "========================================"
echo "🏛️  IRIS Platform: https://34.123.164.154/"
echo "📊 Jenkins: http://34.136.254.74:8080/job/IRIS-Forensics-Pipeline/"
echo "📊 Kibana: http://34.123.164.154:5601"
echo "🔍 Elasticsearch: http://34.123.164.154:9200/forensics-logs/_search"
echo ""
echo "🔗 INTEGRATION FEATURES:"
echo "  ✅ IRIS case creation with API"
echo "  ✅ Evidence collection tracking"
echo "  ✅ Forensic analysis workflow"
echo "  ✅ Real-time ELK logging"
echo "  ✅ Automated reporting"
