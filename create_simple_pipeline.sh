#!/bin/bash
# Create Simple Forensics Pipeline Job

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Creating simple forensics pipeline job..."

# Create a simple pipeline job
cat > /tmp/simple-forensics-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Simple forensics pipeline for testing</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>CASE_NUMBER</name>
          <description>Case number</description>
          <defaultValue>CASE-001</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    stages {
        stage('Start Analysis') {
            steps {
                echo "Starting forensics analysis for case: ${params.CASE_NUMBER}"
                sh 'mkdir -p /var/lib/jenkins/forensics/reports/${CASE_NUMBER}'
                sh 'echo "Analysis started at $(date)" > /var/lib/jenkins/forensics/reports/${CASE_NUMBER}/analysis.log'
            }
        }
        stage('Complete Analysis') {
            steps {
                echo "Completing analysis..."
                sh 'echo "Analysis completed at $(date)" >> /var/lib/jenkins/forensics/reports/${CASE_NUMBER}/analysis.log'
            }
        }
    }
    post {
        success {
            echo "Forensics analysis completed successfully!"
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

# Create the job
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'Simple-Forensics-Pipeline' < /tmp/simple-forensics-pipeline.xml

echo "✅ Simple forensics pipeline created!"
echo "🚀 Triggering test build..."

# Trigger a build
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS build 'Simple-Forensics-Pipeline' -p CASE_NUMBER=TEST-001

echo "✅ Pipeline test initiated!"
echo "🔗 Check status at: http://34.136.254.74:8080/job/Simple-Forensics-Pipeline/"
