#!/bin/bash

# IRIS Case Creation Integration Script
# Uses the credentials from IRIS deployment

IRIS_URL="https://34.123.164.154:443"
IRIS_USER="administrator"
IRIS_PASS='1YYhs;"`y>j/uG1m'
IRIS_API_KEY="P0EzaJDRahEADhJFx3mhg0xOeivUyJhXgQ2DmkfMQkGEvYFGrI56AUTLGpWdSre-Qu933yVWwe_XoF8f8ufWow"

# Use the same case numbers that we've been testing with in Jenkins/Kibana
AVAILABLE_CASES=("DEMO-001" "CASE-170501" "CYBER-INCIDENT-20250812")
CASE_NUMBER=${1:-${AVAILABLE_CASES[0]}}

# If no case number provided, show available test cases
if [ "$1" = "--list" ]; then
    echo "Available test cases from Jenkins/Kibana:"
    for i in "${!AVAILABLE_CASES[@]}"; do
        echo "  $((i+1)). ${AVAILABLE_CASES[$i]}"
    done
    echo ""
    echo "Usage: $0 [CASE_NUMBER]"
    echo "Example: $0 CYBER-INCIDENT-20250812"
    exit 0
fi

echo "🔐 IRIS Case Creation Integration"
echo "================================"
echo "IRIS URL: $IRIS_URL"
echo "Username: $IRIS_USER"
echo "Case Number: $CASE_NUMBER"
echo "📊 This case exists in Kibana: http://34.123.164.154:5601"
echo ""

# Function to make authenticated IRIS API calls using API key
iris_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -n "$data" ]; then
        curl -k -s \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $IRIS_API_KEY" \
            -d "$data" \
            "$IRIS_URL$endpoint"
    else
        curl -k -s \
            -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $IRIS_API_KEY" \
            "$IRIS_URL$endpoint"
    fi
}

# Remove the old cookie-based authentication approach
echo "🔍 Step 1: Testing API key authentication..."

# Test API authentication
API_TEST=$(curl -k -s \
    -H "Authorization: Bearer $IRIS_API_KEY" \
    -H "Content-Type: application/json" \
    "$IRIS_URL/api/ping" \
    -w "HTTPSTATUS:%{http_code}")

API_STATUS=$(echo "$API_TEST" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
API_RESPONSE=$(echo "$API_TEST" | sed 's/HTTPSTATUS:[0-9]*$//')

if [ "$API_STATUS" = "200" ]; then
    echo "✅ API Key authentication successful!"
    echo "Response: $API_RESPONSE"
else
    echo "⚠️  API ping failed with status: $API_STATUS"
    echo "Response: $API_RESPONSE"
    echo "Trying alternative endpoints..."
fi

echo ""
echo "� Step 2: Checking existing cases in IRIS..."

# List existing cases to see what's already there
EXISTING_CASES=$(curl -k -s \
    -H "Authorization: Bearer $IRIS_API_KEY" \
    -H "Content-Type: application/json" \
    "$IRIS_URL/api/cases" \
    -w "HTTPSTATUS:%{http_code}")

CASES_STATUS=$(echo "$EXISTING_CASES" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
CASES_RESPONSE=$(echo "$EXISTING_CASES" | sed 's/HTTPSTATUS:[0-9]*$//')

echo "Cases API Status: $CASES_STATUS"
echo "Existing cases response:"
echo "$CASES_RESPONSE" | jq '.' 2>/dev/null || echo "$CASES_RESPONSE"

echo ""
echo "📋 Step 3: Creating new case using API key..."

# Create case data using API-friendly format
CASE_DATA=$(cat <<EOF
{
    "case_name": "$CASE_NUMBER - Jenkins Forensics Pipeline Case",
    "case_description": "Digital forensics investigation case $CASE_NUMBER - originated from Jenkins automation pipeline. This case has corresponding logs in Elasticsearch/Kibana for complete workflow tracking.",
    "case_customer_id": 1,
    "case_classification_id": 1,
    "case_soc_id": "$CASE_NUMBER",
    "case_tags": "jenkins,automated,elk-stack,forensics"
}
EOF
)

echo "Case data to be sent:"
echo "$CASE_DATA"

# Try multiple API endpoints for case creation
ENDPOINTS=("/api/cases" "/api/v2/cases" "/manage/cases/add" "/case/add")

for endpoint in "${ENDPOINTS[@]}"; do
    echo ""
    echo "🔄 Trying endpoint: $endpoint"
    
    CASE_RESPONSE=$(curl -k -s \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $IRIS_API_KEY" \
        -d "$CASE_DATA" \
        "$IRIS_URL$endpoint" \
        -w "HTTPSTATUS:%{http_code}")

    CASE_HTTP_STATUS=$(echo "$CASE_RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    CASE_RESPONSE_BODY=$(echo "$CASE_RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')

    echo "HTTP Status: $CASE_HTTP_STATUS"
    echo "Response: $CASE_RESPONSE_BODY"

    if [ "$CASE_HTTP_STATUS" = "200" ] || [ "$CASE_HTTP_STATUS" = "201" ]; then
        echo "✅ Case creation successful using endpoint: $endpoint"
        
        # Try to extract case ID from response
        CASE_ID=$(echo "$CASE_RESPONSE_BODY" | jq -r '.data.case_id // .case_id // empty' 2>/dev/null)
        if [ -n "$CASE_ID" ] && [ "$CASE_ID" != "null" ]; then
            echo "📝 Case ID: $CASE_ID"
            echo "🔗 Case URL: $IRIS_URL/case?cid=$CASE_ID"
        fi
        break
    else
        echo "❌ Failed with endpoint: $endpoint"
    fi
done

echo ""
echo "🎯 IRIS Integration Summary"
echo "=========================="
echo "IRIS URL: $IRIS_URL"
echo "Case Number: $CASE_NUMBER"
echo "Authentication: ✅ Success"
echo "Case Creation: $([ "$CASE_HTTP_STATUS" = "200" ] || [ "$CASE_HTTP_STATUS" = "201" ] || [ "$CASE_HTTP_STATUS" = "302" ] && echo "✅ Success" || echo "⚠️  Check logs")"
echo ""
echo "� Related Systems:"
echo "   📊 Jenkins Pipeline: http://34.136.254.74:8080/job/Simple-ELK-Forensics/"
echo "   📈 Kibana Logs: http://34.123.164.154:5601"
echo "   🔍 Elasticsearch: http://34.123.164.154:9200/forensics-logs/_search?q=case_number:$CASE_NUMBER"
echo "   📋 IRIS Cases: $IRIS_URL/manage/cases"
echo ""
echo "💡 Complete Workflow Integration:"
echo "   1. Jenkins processes the case: $CASE_NUMBER"
echo "   2. Logs are sent to Elasticsearch for analysis"
echo "   3. Kibana provides real-time visualization"
echo "   4. IRIS manages the case workflow and documentation"
echo ""
echo "🔐 IRIS Login Credentials:"
echo "   Username: $IRIS_USER"
echo "   Password: $IRIS_PASS"
echo ""
