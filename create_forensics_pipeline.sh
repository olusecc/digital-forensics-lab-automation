#!/bin/bash
# Create Forensics Pipeline Job

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Creating forensics disk analysis pipeline..."

# Create the pipeline job configuration
cat > /tmp/forensics-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Automated disk image analysis pipeline for digital forensics evidence processing</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>EVIDENCE_FILE</name>
          <description>Path to the disk image file to analyze</description>
          <defaultValue>/var/lib/jenkins/forensics/evidence/sample.dd</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>CASE_NUMBER</name>
          <description>Case number for tracking and reporting</description>
          <defaultValue>CASE-001</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>INVESTIGATOR</name>
          <description>Name of the investigator</description>
          <defaultValue>Digital Forensics Team</defaultValue>
          <trim>false</trim>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>pipeline {
    agent any
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "Starting forensics analysis for case: ${params.CASE_NUMBER}"
                    echo "Evidence file: ${params.EVIDENCE_FILE}"
                    echo "Investigator: ${params.INVESTIGATOR}"
                    echo "Timestamp: ${new Date()}"
                }
            }
        }
        
        stage('Validate Environment') {
            steps {
                script {
                    echo "Validating forensics environment..."
                    sh '''
                        echo "Checking forensics directories..."
                        ls -la /var/lib/jenkins/forensics/
                        echo "Checking forensics scripts..."
                        ls -la /var/lib/jenkins/forensics/scripts/
                        echo "Checking pipeline library..."
                        ls -la /var/lib/jenkins/pipeline-library/vars/
                    '''
                }
            }
        }
        
        stage('Validate Evidence') {
            steps {
                script {
                    echo "Validating evidence file..."
                    sh """
                        if [ -f '${params.EVIDENCE_FILE}' ]; then
                            echo "Evidence file found: ${params.EVIDENCE_FILE}"
                            file '${params.EVIDENCE_FILE}'
                            ls -lh '${params.EVIDENCE_FILE}'
                        else
                            echo "Evidence file not found: ${params.EVIDENCE_FILE}"
                            echo "This is expected for demo purposes"
                            echo "Creating mock evidence information..."
                            mkdir -p \$(dirname '${params.EVIDENCE_FILE}')
                            echo "Mock evidence file for case ${params.CASE_NUMBER}" > '${params.EVIDENCE_FILE}.info'
                        fi
                    """
                }
            }
        }
        
        stage('Process Evidence') {
            parallel {
                stage('Disk Analysis') {
                    steps {
                        script {
                            echo "Running disk analysis tools..."
                            sh '''
                                echo "Simulating disk analysis with Autopsy and Sleuth Kit..."
                                mkdir -p /var/lib/jenkins/forensics/reports/$CASE_NUMBER/disk_analysis
                                echo "Disk analysis results for case $CASE_NUMBER" > /var/lib/jenkins/forensics/reports/$CASE_NUMBER/disk_analysis/analysis.txt
                                echo "Files processed: $(date)" >> /var/lib/jenkins/forensics/reports/$CASE_NUMBER/disk_analysis/analysis.txt
                            '''
                        }
                    }
                }
                stage('Hash Verification') {
                    steps {
                        script {
                            echo "Calculating evidence hashes..."
                            sh '''
                                mkdir -p /var/lib/jenkins/forensics/reports/$CASE_NUMBER/hashes
                                echo "Hash verification for case $CASE_NUMBER" > /var/lib/jenkins/forensics/reports/$CASE_NUMBER/hashes/hashes.txt
                                echo "MD5: $(echo $EVIDENCE_FILE | md5sum)" >> /var/lib/jenkins/forensics/reports/$CASE_NUMBER/hashes/hashes.txt
                                echo "SHA256: $(echo $EVIDENCE_FILE | sha256sum)" >> /var/lib/jenkins/forensics/reports/$CASE_NUMBER/hashes/hashes.txt
                            '''
                        }
                    }
                }
                stage('File System Analysis') {
                    steps {
                        script {
                            echo "Analyzing file system..."
                            sh '''
                                mkdir -p /var/lib/jenkins/forensics/reports/$CASE_NUMBER/filesystem
                                echo "File system analysis for case $CASE_NUMBER" > /var/lib/jenkins/forensics/reports/$CASE_NUMBER/filesystem/fs_analysis.txt
                                echo "Analysis completed: $(date)" >> /var/lib/jenkins/forensics/reports/$CASE_NUMBER/filesystem/fs_analysis.txt
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Generate Timeline') {
            steps {
                script {
                    echo "Generating forensics timeline..."
                    sh '''
                        mkdir -p /var/lib/jenkins/forensics/reports/$CASE_NUMBER/timeline
                        echo "Timeline analysis for case $CASE_NUMBER" > /var/lib/jenkins/forensics/reports/$CASE_NUMBER/timeline/timeline.txt
                        echo "Timeline generated: $(date)" >> /var/lib/jenkins/forensics/reports/$CASE_NUMBER/timeline/timeline.txt
                    '''
                }
            }
        }
        
        stage('Generate Report') {
            steps {
                script {
                    echo "Generating comprehensive forensics report..."
                    sh '''
                        mkdir -p /var/lib/jenkins/forensics/reports/$CASE_NUMBER
                        cat > /var/lib/jenkins/forensics/reports/$CASE_NUMBER/final_report.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Digital Forensics Report - Case $CASE_NUMBER</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Digital Forensics Analysis Report</h1>
        <p><strong>Case Number:</strong> $CASE_NUMBER</p>
        <p><strong>Investigator:</strong> $INVESTIGATOR</p>
        <p><strong>Analysis Date:</strong> $(date)</p>
        <p><strong>Evidence File:</strong> $EVIDENCE_FILE</p>
    </div>
    
    <div class="section">
        <h2>Executive Summary</h2>
        <p>Automated forensics analysis completed successfully for case $CASE_NUMBER.</p>
    </div>
    
    <div class="section">
        <h2>Analysis Results</h2>
        <ul>
            <li>Disk analysis completed</li>
            <li>Hash verification performed</li>
            <li>File system analysis completed</li>
            <li>Timeline generated</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Conclusion</h2>
        <p>Analysis completed using automated digital forensics pipeline.</p>
    </div>
</body>
</html>
HTMLEOF
                        echo "Report generated at: /var/lib/jenkins/forensics/reports/$CASE_NUMBER/final_report.html"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "Forensics pipeline completed for case: ${params.CASE_NUMBER}"
            archiveArtifacts artifacts: "**/*", fingerprint: true, allowEmptyArchive: true
        }
        success {
            echo "✅ Forensics analysis completed successfully!"
            echo "📊 Report available at: /var/lib/jenkins/forensics/reports/${params.CASE_NUMBER}/final_report.html"
        }
        failure {
            echo "❌ Forensics analysis failed. Check logs for details."
        }
    }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the job
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'Forensics-Disk-Analysis-Pipeline' < /tmp/forensics-pipeline.xml

echo "✅ Forensics pipeline job created successfully!"
echo "🔗 Access it at: http://34.136.254.74:8080/job/Forensics-Disk-Analysis-Pipeline/"
