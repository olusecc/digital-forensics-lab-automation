#!/bin/bash
# Test ELK stack with sample data

echo "Creating test data for ELK stack..."

# Create sample forensics data
ansible forensics -i inventory.yml -m shell -a '
echo "{\"@timestamp\":\"$(date -Iseconds)\",\"case_id\":\"TEST-001\",\"type\":\"autopsy\",\"file_path\":\"/evidence/test.txt\",\"file_hash\":\"abc123\",\"investigator\":\"test_user\"}" > /data/processed/autopsy/test_data.json
echo "{\"@timestamp\":\"$(date -Iseconds)\",\"case_id\":\"TEST-001\",\"type\":\"volatility\",\"process_name\":\"notepad.exe\",\"pid\":\"1234\",\"investigator\":\"test_user\"}" > /data/processed/volatility/test_data.json
'

# Wait for Logstash to process
echo "Waiting 30 seconds for Logstash to process data..."
sleep 30

# Check if data was indexed
echo "Checking if data was indexed in Elasticsearch..."
ansible data_services -i inventory.yml -m uri -a "url=http://localhost:9200/forensics-*/_search?q=case_id:TEST-001 method=GET"