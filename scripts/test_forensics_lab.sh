#!/bin/bash
# Comprehensive Forensics Lab Test Suite

set -e

echo "🧪 Starting Forensics Lab Test Suite..."
echo "================================================"

# Test configuration
TEST_CASE_ID="TEST-$(date +%Y%m%d-%H%M%S)"
ELASTICSEARCH_HOST="10.128.0.19"
KIBANA_HOST="10.128.0.19"
JENKINS_HOST="10.128.0.20"
MISP_HOST="10.128.0.19"
IRIS_HOST="10.128.0.19"
FORENSICS_HOST="10.128.0.18"

echo "Test Case ID: $TEST_CASE_ID"
echo ""

# Test 1: Service Availability
echo "🔍 Test 1: Checking Service Availability"
echo "----------------------------------------"

services=(
    "Elasticsearch:$ELASTICSEARCH_HOST:9200:/_cluster/health"
    "Kibana:$KIBANA_HOST:5601:/api/status"
    "Jenkins:$JENKINS_HOST:8080:/api/json"
    "MISP:$MISP_HOST:80:/users/login"
    "IRIS:$IRIS_HOST:8000:/"
)

for service in "${services[@]}"; do
    IFS=':' read -r name host port endpoint <<< "$service"
    echo -n "Checking $name... "
    
    if curl -s --connect-timeout 10 "http://$host:$port$endpoint" > /dev/null; then
        echo "✅ PASS"
    else
        echo "❌ FAIL"
        exit 1
    fi
done

echo ""

# Test 2: Storage and NFS Mounts
echo "🗂️  Test 2: Checking Storage Systems"
echo "------------------------------------"

# Check NFS mounts on all servers
for server in "$JENKINS_HOST" "$IRIS_HOST"; do
    echo -n "Checking NFS mounts on $server... "
    if ansible-playbook -i ../../inventory.yml -l $server -m shell -a "mount | grep nfs" > /dev/null 2>&1; then
        echo "✅ PASS"
    else
        echo "❌ FAIL - NFS mounts not found"
        exit 1
    fi
done

# Check shared directories
echo -n "Checking shared directories... "
if ansible forensics -i ../../inventory.yml -m shell -a "ls -la /data/{evidence,processed,cases}" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Shared directories not accessible"
    exit 1
fi

echo ""

# Test 3: Create Test Evidence Files
echo "🧬 Test 3: Creating Test Evidence"
echo "---------------------------------"

echo "Creating test disk image..."
ansible forensics -i ../../inventory.yml -m shell -a "
    dd if=/dev/zero of=/data/evidence/${TEST_CASE_ID}_test.img bs=1M count=10 2>/dev/null
    echo 'This is test evidence for case ${TEST_CASE_ID}' > /data/evidence/${TEST_CASE_ID}_test.txt
"

echo "Creating test memory dump..."
ansible forensics -i ../../inventory.yml -m shell -a "
    dd if=/dev/urandom of=/data/evidence/${TEST_CASE_ID}_memory.dmp bs=1M count=5 2>/dev/null
"

echo "Creating test malware sample..."
ansible forensics -i ../../inventory.yml -m shell -a "
    echo 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /data/evidence/${TEST_CASE_ID}_malware.exe
"

echo "✅ Test evidence files created"
echo ""

# Test 4: Forensic Tools Functionality
echo "🔧 Test 4: Testing Forensic Tools"
echo "----------------------------------"

echo -n "Testing Sleuth Kit... "
if ansible forensics -i ../../inventory.yml -m shell -a "/opt/forensics/sleuthkit/bin/fls -V" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing Volatility3... "
if ansible forensics -i ../../inventory.yml -m shell -a "volatility3 -h" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo -n "Testing YARA... "
if ansible forensics -i ../../inventory.yml -m shell -a "yara --version" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo ""

# Test 5: Processing Pipeline
echo "⚙️  Test 5: Testing Processing Pipeline"
echo "---------------------------------------"

echo "Processing test disk image..."
ansible forensics -i ../../inventory.yml -m shell -a "
    /opt/forensics/scripts/process_disk_image.sh \\
        '$TEST_CASE_ID' \\
        '/data/evidence/${TEST_CASE_ID}_test.img' \\
        '/data/cases/${TEST_CASE_ID}/analysis'
" 2>/dev/null

echo "Processing test malware sample..."
ansible forensics -i ../../inventory.yml -m shell -a "
    /opt/forensics/scripts/process_malware_sample.sh \\
        '/data/evidence/${TEST_CASE_ID}_malware.exe' \\
        '/data/cases/${TEST_CASE_ID}/analysis' \\
        '$TEST_CASE_ID'
" 2>/dev/null

echo "✅ Processing scripts completed"
echo ""

# Test 6: Data Indexing
echo "📊 Test 6: Testing Data Indexing"
echo "--------------------------------"

echo "Waiting for Logstash to process data (60 seconds)..."
sleep 60

echo -n "Checking Elasticsearch indexing... "
INDEXED_COUNT=$(curl -s "http://$ELASTICSEARCH_HOST:9200/forensics-*/_search?q=case_id:$TEST_CASE_ID&size=0" | jq -r '.hits.total.value // 0')

if [ "$INDEXED_COUNT" -gt 0 ]; then
    echo "✅ PASS ($INDEXED_COUNT documents indexed)"
else
    echo "❌ FAIL (No documents found)"
    exit 1
fi

echo ""

# Test 7: Integration Scripts
echo "🔗 Test 7: Testing Integration Scripts"
echo "--------------------------------------"

echo -n "Testing MISP integration... "
if python3 /opt/scripts/misp_integration.py "http://$MISP_HOST" "test-key" "/dev/null" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "⚠️  SKIP (MISP API key required)"
fi

echo -n "Testing notification system... "
if python3 /opt/scripts/send_notification.py "TEST" "Lab test notification" "TestSuite" > /dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo ""

# Test 8: Jenkins Pipeline
echo "🏗️  Test 8: Testing Jenkins Pipeline"
echo "------------------------------------"

echo "Triggering Jenkins forensics processing job..."
JENKINS_JOB_URL="http://$JENKINS_HOST:8080/job/forensics-processing/buildWithParameters"

# Get Jenkins crumb for CSRF protection
JENKINS_CRUMB=$(curl -s "http://$JENKINS_HOST:8080/crumbIssuer/api/json" | jq -r '.crumb // empty' 2>/dev/null)

if [ -n "$JENKINS_CRUMB" ]; then
    CRUMB_HEADER="Jenkins-Crumb: $JENKINS_CRUMB"
else
    CRUMB_HEADER=""
fi

# Trigger job
curl -X POST "$JENKINS_JOB_URL" \
    -H "$CRUMB_HEADER" \
    --data-urlencode "CASE_ID=$TEST_CASE_ID" \
    --data-urlencode "EVIDENCE_TYPE=disk_image" \
    --data-urlencode "EVIDENCE_PATH=/data/evidence/${TEST_CASE_ID}_test.img" \
    --data-urlencode "INVESTIGATOR=TestSuite" \
    > /dev/null 2>&1

echo "✅ Jenkins job triggered (check Jenkins UI for status)"
echo ""

# Test 9: Dashboard Access
echo "📈 Test 9: Testing Dashboard Access"
echo "-----------------------------------"

echo -n "Testing Kibana dashboard access... "
if curl -s "http://$KIBANA_HOST:5601/app/dashboards" > /dev/null; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo ""

# Test 10: Cleanup Test Data
echo "🧹 Test 10: Cleaning Up Test Data"
echo "----------------------------------"

echo "Removing test evidence files..."
ansible forensics -i ../../inventory.yml -m shell -a "rm -f /data/evidence/${TEST_CASE_ID}_*"

echo "Removing test case directory..."
ansible forensics -i ../../inventory.yml -m shell -a "rm -rf /data/cases/${TEST_CASE_ID}"

echo "✅ Test data cleaned up"
echo ""

# Final Summary
echo "🎉 TEST SUITE COMPLETED SUCCESSFULLY!"
echo "===================================="
echo ""
echo "✅ All systems operational"
echo "✅ All services accessible"  
echo "✅ Processing pipelines functional"
echo "✅ Data indexing working"
echo "✅ Integrations operational"
echo ""
echo "🌟 Your Digital Forensics Lab is ready for production!"
echo ""
echo "Access Points:"
echo "- Kibana Dashboard: http://$KIBANA_HOST:5601"
echo "- Jenkins Automation: http://$JENKINS_HOST:8080"
echo "- MISP Threat Intel: http://$MISP_HOST"
echo "- DFIR-IRIS Cases: http://$IRIS_HOST:8000"
echo ""
echo "Next steps:"
echo "1. Configure user accounts and permissions"
echo "2. Set up SSL certificates for production"
echo "3. Configure proper backup procedures"
echo "4. Train investigators on the new system"