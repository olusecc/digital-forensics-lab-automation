#!/bin/bash
# Jenkins Pipeline Setup Script

JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="ForensicsLab2025!"
CLI_JAR="/var/lib/jenkins/cli/jenkins-cli.jar"

echo "Installing required Jenkins plugins..."

# Install Pipeline plugins
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS install-plugin workflow-aggregator
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS install-plugin pipeline-stage-view
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS install-plugin git
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS install-plugin build-timeout
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS install-plugin timestamper

echo "Restarting Jenkins to activate plugins..."
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS restart

echo "Waiting for Jenkins to restart..."
sleep 60

echo "Creating forensics pipeline job..."

# Create a simple freestyle job first to test
cat > /tmp/simple-test-job.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Simple test job for forensics lab</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <builders>
    <hudson.tasks.Shell>
      <command>#!/bin/bash
echo "Digital Forensics Lab Test Job"
echo "Running on: $(hostname)"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Jenkins forensics directory contents:"
ls -la /var/lib/jenkins/forensics/
echo "Pipeline library contents:"
ls -la /var/lib/jenkins/pipeline-library/vars/
echo "Test completed successfully!"
      </command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF

java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS create-job 'Forensics-Lab-Test' < /tmp/simple-test-job.xml

echo "Triggering test build..."
java -jar $CLI_JAR -s $JENKINS_URL -auth $ADMIN_USER:$ADMIN_PASS build 'Forensics-Lab-Test'

echo "Setup completed!"
echo "You can now access Jenkins at: http://34.136.254.74:8080"
echo "Login with: admin / ForensicsLab2025!"
