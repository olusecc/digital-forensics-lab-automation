#!/bin/bash
# Test IRIS Case Creation

IRIS_URL="https://localhost"
IRIS_USER="administrator"
IRIS_PASS="Secret123"

echo "🏛️ Testing IRIS Case Creation..."

# Get CSRF token
echo "Getting CSRF token..."
CSRF_TOKEN=$(curl -k -s "${IRIS_URL}/login" | grep csrf_token | grep -o 'value="[^"]*"' | cut -d'"' -f2)
echo "CSRF Token: $CSRF_TOKEN"

if [ -z "$CSRF_TOKEN" ]; then
    echo "❌ Failed to get CSRF token"
    exit 1
fi

# Login and get session cookie
echo "Logging into IRIS..."
LOGIN_RESPONSE=$(curl -k -s -c /tmp/iris_cookies.txt -b /tmp/iris_cookies.txt \
    -X POST "${IRIS_URL}/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${IRIS_USER}&password=${IRIS_PASS}&csrf_token=${CSRF_TOKEN}")

echo "Login response length: $(echo "$LOGIN_RESPONSE" | wc -c)"

# Check if login was successful by getting the dashboard
DASHBOARD_CHECK=$(curl -k -s -b /tmp/iris_cookies.txt "${IRIS_URL}/dashboard" | grep -o "Dashboard" | head -1)

if [ "$DASHBOARD_CHECK" = "Dashboard" ]; then
    echo "✅ Successfully logged into IRIS"
    
    # Get a fresh CSRF token for case creation
    NEW_CSRF=$(curl -k -s -b /tmp/iris_cookies.txt "${IRIS_URL}/manage/cases" | grep csrf_token | grep -o 'value="[^"]*"' | cut -d'"' -f2 | head -1)
    echo "Case creation CSRF: $NEW_CSRF"
    
    # Create a test case
    echo "Creating test forensics case in IRIS..."
    CASE_RESPONSE=$(curl -k -s -b /tmp/iris_cookies.txt \
        -X POST "${IRIS_URL}/manage/cases/add" \
        -H "Content-Type: application/json" \
        -H "X-CSRF-Token: ${NEW_CSRF}" \
        -d '{
            "case_name": "Jenkins Forensics Test Case",
            "case_description": "Automated test case created from Jenkins pipeline",
            "case_customer": 1,
            "case_classification": 1,
            "custom_attributes": {
                "source": "jenkins_pipeline",
                "test_case": true,
                "created_at": "'$(date)'"
            }
        }')
    
    echo "Case creation response:"
    echo "$CASE_RESPONSE"
    
    if echo "$CASE_RESPONSE" | grep -q "case_id"; then
        echo "✅ Successfully created IRIS case!"
        CASE_ID=$(echo "$CASE_RESPONSE" | grep -o '"case_id":[0-9]*' | cut -d':' -f2)
        echo "New case ID: $CASE_ID"
    else
        echo "❌ Failed to create IRIS case"
        echo "Response: $CASE_RESPONSE"
    fi
    
else
    echo "❌ Failed to login to IRIS"
    echo "Dashboard check result: '$DASHBOARD_CHECK'"
fi

# Clean up
rm -f /tmp/iris_cookies.txt

echo "🏛️ IRIS integration test completed!"
