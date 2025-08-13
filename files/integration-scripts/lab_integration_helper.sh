#!/bin/bash
# Jenkins Integration Helper Script
# Digital Forensics Lab Automation

# Infrastructure Configuration
export JENKINS_HOST="10.128.0.20"
export FORENSICS_SERVER="10.128.0.18"
export ELK_SERVER="10.128.0.19"
export MISP_SERVER="10.128.0.19"
export IRIS_SERVER="10.128.0.19"

# Service URLs
export ELASTICSEARCH_URL="http://10.128.0.19:9200"
export KIBANA_URL="http://10.128.0.19:5601"
export MISP_URL="http://10.128.0.19:80"
export IRIS_URL="https://10.128.0.19:443"

# SSH Configuration
export SSH_KEY_PATH="~/.ssh/cluster_key"
export SSH_USER="olusecc"

# Helper Functions
function ssh_forensics() {
    ssh -i $SSH_KEY_PATH $SSH_USER@$FORENSICS_SERVER "$@"
}

function ssh_services() {
    ssh -i $SSH_KEY_PATH $SSH_USER@$ELK_SERVER "$@"
}

function check_services() {
    echo "Checking service availability..."
    curl -s "$ELASTICSEARCH_URL/_cluster/health" > /dev/null && echo "✅ Elasticsearch: OK" || echo "❌ Elasticsearch: FAIL"
    curl -s "$KIBANA_URL/api/status" > /dev/null && echo "✅ Kibana: OK" || echo "❌ Kibana: FAIL"
    curl -s -k "$IRIS_URL" > /dev/null && echo "✅ IRIS: OK" || echo "❌ IRIS: FAIL"
    curl -s "$MISP_URL" > /dev/null && echo "✅ MISP: OK" || echo "❌ MISP: FAIL"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Digital Forensics Lab - Integration Helper"
    echo "=========================================="
    check_services
fi
