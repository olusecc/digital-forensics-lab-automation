#!/bin/bash
# Script to create Jenkins jobs for Digital Forensics Automation

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="admin"  # Will be set during initial setup

# Wait for Jenkins to be fully ready
echo "Waiting for Jenkins to be fully initialized..."
until curl -s -u ${JENKINS_USER}:${JENKINS_PASSWORD} ${JENKINS_URL}/api/json >/dev/null 2>&1; do
    echo "Jenkins not ready yet, waiting..."
    sleep 10
done

echo "Jenkins is ready! Creating forensics jobs..."

# Create Disk Analysis Pipeline Job
cat > /tmp/disk-analysis-job.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Automated Disk Image Analysis Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_ID</name>
          <description>IRIS Case ID (required)</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EVIDENCE_PATH</name>
          <description>Path to disk image file (required)</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>INVESTIGATOR</name>
          <description>Lead investigator name</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.ChoiceParameterDefinition>
          <name>ANALYSIS_LEVEL</name>
          <description>Analysis depth</description>
          <choices>
            <string>basic</string>
            <string>standard</string>
            <string>comprehensive</string>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>URGENT</name>
          <description>Priority processing</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.80">
    <script>
      // Load pipeline from file
      node {
        def pipelineScript = readFile('/var/lib/jenkins/forensics/pipelines/Jenkinsfile-disk-analysis')
        evaluate(pipelineScript)
      }
    </script>
    <sandbox>false</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the job using Jenkins CLI
echo "Creating Disk Analysis Pipeline job..."
curl -X POST \
  -u ${JENKINS_USER}:${JENKINS_PASSWORD} \
  -H "Content-Type: application/xml" \
  -d @/tmp/disk-analysis-job.xml \
  "${JENKINS_URL}/createItem?name=forensics-disk-analysis"

# Create Evidence Intake Pipeline Job
cat > /tmp/evidence-intake-job.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Evidence Intake and Validation Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_ID</name>
          <description>Case ID</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>EVIDENCE_PATH</name>
          <description>Evidence file path</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.ChoiceParameterDefinition>
          <name>EVIDENCE_TYPE</name>
          <description>Type of evidence</description>
          <choices>
            <string>disk</string>
            <string>memory</string>
            <string>mobile</string>
            <string>malware</string>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>INVESTIGATOR</name>
          <description>Investigator name</description>
          <defaultValue></defaultValue>
          <trim>true</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.80">
    <script>
pipeline {
    agent any
    
    stages {
        stage('Evidence Intake') {
            steps {
                script {
                    echo "Starting evidence intake for case: ${params.CASE_ID}"
                    echo "Evidence type: ${params.EVIDENCE_TYPE}"
                    echo "Evidence path: ${params.EVIDENCE_PATH}"
                    echo "Investigator: ${params.INVESTIGATOR}"
                    
                    // Validate evidence file exists
                    if (params.EVIDENCE_PATH) {
                        sh "test -f '${params.EVIDENCE_PATH}' || (echo 'Evidence file not found' && exit 1)"
                    }
                    
                    // Generate evidence metadata
                    sh """
                        mkdir -p /var/lib/jenkins/forensics/evidence/${params.CASE_ID}
                        cd /var/lib/jenkins/forensics/evidence/${params.CASE_ID}
                        
                        echo "=== Evidence Metadata ===" > evidence_metadata.txt
                        echo "Case ID: ${params.CASE_ID}" >> evidence_metadata.txt
                        echo "Evidence Type: ${params.EVIDENCE_TYPE}" >> evidence_metadata.txt
                        echo "Evidence Path: ${params.EVIDENCE_PATH}" >> evidence_metadata.txt
                        echo "Investigator: ${params.INVESTIGATOR}" >> evidence_metadata.txt
                        echo "Intake Time: \$(date)" >> evidence_metadata.txt
                        
                        if [ -f "${params.EVIDENCE_PATH}" ]; then
                            echo "File Size: \$(stat -c%s '${params.EVIDENCE_PATH}') bytes" >> evidence_metadata.txt
                            echo "MD5 Hash: \$(md5sum '${params.EVIDENCE_PATH}' | cut -d' ' -f1)" >> evidence_metadata.txt
                            echo "SHA256 Hash: \$(sha256sum '${params.EVIDENCE_PATH}' | cut -d' ' -f1)" >> evidence_metadata.txt
                        fi
                    """
                }
            }
        }
        
        stage('Trigger Analysis') {
            steps {
                script {
                    def jobName = ""
                    switch(params.EVIDENCE_TYPE) {
                        case 'disk':
                            jobName = 'forensics-disk-analysis'
                            break
                        case 'memory':
                            jobName = 'forensics-memory-analysis'
                            break
                        case 'mobile':
                            jobName = 'forensics-mobile-analysis'
                            break
                        case 'malware':
                            jobName = 'forensics-malware-analysis'
                            break
                        default:
                            error("Unknown evidence type: ${params.EVIDENCE_TYPE}")
                    }
                    
                    echo "Triggering ${jobName} for evidence processing..."
                    
                    // For now, we'll just echo the trigger - actual trigger would be:
                    // build job: jobName, parameters: [
                    //     string(name: 'CASE_ID', value: params.CASE_ID),
                    //     string(name: 'EVIDENCE_PATH', value: params.EVIDENCE_PATH),
                    //     string(name: 'INVESTIGATOR', value: params.INVESTIGATOR)
                    // ]
                    
                    echo "Would trigger job: ${jobName}"
                    echo "With parameters:"
                    echo "  CASE_ID: ${params.CASE_ID}"
                    echo "  EVIDENCE_PATH: ${params.EVIDENCE_PATH}"
                    echo "  INVESTIGATOR: ${params.INVESTIGATOR}"
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Evidence intake completed successfully for case ${params.CASE_ID}"
        }
        failure {
            echo "❌ Evidence intake failed for case ${params.CASE_ID}"
        }
    }
}
    </script>
    <sandbox>false</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

echo "Creating Evidence Intake Pipeline job..."
curl -X POST \
  -u ${JENKINS_USER}:${JENKINS_PASSWORD} \
  -H "Content-Type: application/xml" \
  -d @/tmp/evidence-intake-job.xml \
  "${JENKINS_URL}/createItem?name=forensics-evidence-intake"

echo "Jenkins jobs created successfully!"
echo ""
echo "Access Jenkins at: http://localhost:8080"
echo "Initial setup password: check /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "After initial setup, manually create jobs using the XML files above or use the Jenkins UI."
