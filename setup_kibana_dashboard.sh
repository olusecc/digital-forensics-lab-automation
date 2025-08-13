#!/bin/bash

# Create Kibana Index Pattern and Dashboard for Forensics Data

KIBANA_URL="http://localhost:5601"

echo "Setting up Kibana for forensics data visualization..."

# Wait for Kibana to be ready
echo "Waiting for Kibana to be fully ready..."
while ! curl -s "$KIBANA_URL/api/status" > /dev/null; do
    sleep 5
    echo "Still waiting for Kibana..."
done

echo "✅ Kibana is ready!"

# Create index pattern for forensics-logs
echo "Creating index pattern for forensics data..."
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/forensics-logs" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "attributes": {
      "title": "forensics-logs*",
      "timeFieldName": "timestamp"
    }
  }'

echo ""
echo "Index pattern created!"

# Create a simple visualization for case status
echo "Creating forensics case dashboard..."
curl -X POST "$KIBANA_URL/api/saved_objects/visualization" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "attributes": {
      "title": "Forensics Cases by Status",
      "visState": "{\"title\":\"Forensics Cases by Status\",\"type\":\"pie\",\"aggs\":[{\"id\":\"1\",\"type\":\"count\",\"schema\":\"metric\",\"params\":{}},{\"id\":\"2\",\"type\":\"terms\",\"schema\":\"segment\",\"params\":{\"field\":\"status.keyword\",\"size\":10,\"order\":\"desc\",\"orderBy\":\"1\"}}]}",
      "uiStateJSON": "{}",
      "description": "",
      "version": 1,
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"index\":\"forensics-logs\",\"query\":{\"match_all\":{}}}"
      }
    }
  }'

echo ""
echo "Visualization created!"

# Create dashboard
echo "Creating forensics dashboard..."
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -d '{
    "attributes": {
      "title": "Digital Forensics Lab Dashboard",
      "description": "Overview of forensics cases and pipeline status",
      "panelsJSON": "[]",
      "version": 1
    }
  }'

echo ""
echo "🎯 KIBANA SETUP COMPLETE!"
echo "========================="
echo "📊 Access Kibana at: http://34.123.164.154:5601"
echo "🔍 Go to Discover to explore forensics-logs* data"
echo "📈 Go to Visualize to create charts and graphs"
echo "📋 Go to Dashboard to see the overview"
echo ""
echo "💡 TIP: In Kibana Discover, set the time range to 'Last 24 hours' to see your forensics data!"
