#!/bin/bash
# Simple IRIS Integration Script for Forensics Cases

echo "🏛️ IRIS Integration for Digital Forensics"
echo "========================================"

# IRIS connection details
IRIS_URL="https://34.123.164.154"
IRIS_USER="administrator"
IRIS_PASS="Secret123"

echo "Current IRIS integration demonstrates how the forensics pipeline creates cases in IRIS:"
echo ""

echo "📋 IRIS Case Creation Process:"
echo "1. Jenkins pipeline authenticates with IRIS"
echo "2. Creates a new incident case via IRIS API"
echo "3. Links forensics evidence to the case"
echo "4. Updates case status throughout investigation"
echo "5. Logs all activities to ELK stack"

echo ""
echo "🔗 IRIS API Integration Points:"
echo "  - POST /login - Authenticate and get session token"
echo "  - POST /manage/cases/add - Create new incident case"
echo "  - POST /case/{id}/evidence/add - Add evidence items"
echo "  - PUT /case/{id}/status - Update case status"
echo "  - POST /case/{id}/notes - Add investigation notes"

echo ""
echo "📊 Data Flow:"
echo "  Jenkins → IRIS (case creation)"
echo "  Jenkins → Elasticsearch (structured logging)"
echo "  Kibana ← Elasticsearch (visualization)"

echo ""
echo "🎯 Example IRIS Case Creation:"
cat << 'IRIS_EXAMPLE'

# Example API call to create IRIS case:
curl -k -X POST "${IRIS_URL}/manage/cases/add" \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: ${CSRF_TOKEN}" \
  -b cookies.txt \
  -d '{
    "case_name": "Cyber Attack Investigation",
    "case_description": "Automated forensics investigation for CASE-001",
    "case_customer": 1,
    "case_classification": 1,
    "custom_attributes": {
      "jenkins_build": "123",
      "case_id": "CASE-001",
      "investigator": "analyst"
    }
  }'

IRIS_EXAMPLE

echo ""
echo "🔍 To see IRIS case creation in action:"
echo "1. Access IRIS: https://34.123.164.154/"
echo "2. Login with: administrator / Secret123"
echo "3. Run the IRIS-Forensics-Pipeline in Jenkins"
echo "4. Check IRIS Cases dashboard for new entries"
echo "5. View ELK logs for the complete data flow"

echo ""
echo "💡 IRIS Benefits for Forensics:"
echo "  ✅ Centralized case management"
echo "  ✅ Evidence chain of custody"
echo "  ✅ Timeline and task tracking"
echo "  ✅ Collaborative investigation"
echo "  ✅ Compliance reporting"
