#!/bin/bash
# Simple Forensics Pipeline with ELK Integration

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Creating simple forensics pipeline with ELK logging..."

# Create a working simple pipeline
cat > /tmp/simple-elk-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Simple forensics pipeline with ELK integration</description>
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
        stage('Initialize') {
            steps {
                echo "Starting forensics analysis for case: ${params.CASE_NUMBER}"
                sh 'mkdir -p /var/lib/jenkins/forensics/reports/${CASE_NUMBER}'
                sh 'echo "Analysis started at $(date)" > /var/lib/jenkins/forensics/reports/${CASE_NUMBER}/analysis.log'
                
                // Send data to Elasticsearch
                sh '''
                    curl -X POST "http://34.123.164.154:9200/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{\\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", \\"case_number\\": \\"${CASE_NUMBER}\\", \\"stage\\": \\"initialization\\", \\"status\\": \\"started\\", \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"}" || echo "ELK logging failed - continuing"
                '''
            }
        }
        stage('Process Evidence') {
            steps {
                echo "Processing evidence for case: ${params.CASE_NUMBER}"
                sh 'echo "Evidence processed at $(date)" >> /var/lib/jenkins/forensics/reports/${CASE_NUMBER}/analysis.log'
                
                // Log to Elasticsearch
                sh '''
                    curl -X POST "http://34.123.164.154:9200/forensics-logs/_doc/" \\
                    -H "Content-Type: application/json" \\
                    -d "{\\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", \\"case_number\\": \\"${CASE_NUMBER}\\", \\"stage\\": \\"processing\\", \\"status\\": \\"completed\\", \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"}" || echo "ELK logging failed - continuing"
                '''
            }
        }
    }
    post {
        always {
            echo "Forensics pipeline completed for case: ${params.CASE_NUMBER}"
            
            // Final log to Elasticsearch
            sh '''
                curl -X POST "http://34.123.164.154:9200/forensics-logs/_doc/" \\
                -H "Content-Type: application/json" \\
                -d "{\\"timestamp\\": \\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\\", \\"case_number\\": \\"${CASE_NUMBER}\\", \\"stage\\": \\"completion\\", \\"status\\": \\"finished\\", \\"jenkins_build\\": \\"${BUILD_NUMBER}\\"}" || echo "ELK logging failed - continuing"
            '''
            
            archiveArtifacts artifacts: "**/*", fingerprint: true, allowEmptyArchive: true
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
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'Simple-ELK-Forensics' < /tmp/simple-elk-pipeline.xml

echo "✅ Simple ELK forensics pipeline created!"
echo "🚀 Triggering test build..."

# Trigger a build
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS build 'Simple-ELK-Forensics' -p CASE_NUMBER=DEMO-001

echo ""
echo "🎯 PIPELINE CREATED AND RUNNING!"
echo "================================"
echo "📊 Jenkins: http://34.136.254.74:8080/job/Simple-ELK-Forensics/"
echo "📊 Kibana: http://34.123.164.154:5601"
echo "🔍 Elasticsearch: http://34.123.164.154:9200/forensics-logs/_search"
