#!/usr/bin/env python3
"""
Configuration Update Script for Digital Forensics Lab
Updates all IP addresses and configurations to match current infrastructure
"""

# Current Infrastructure IPs (based on inventory.yml)
INFRASTRUCTURE_CONFIG = {
    # VM Internal IPs (10.128.0.x network)
    'FORMGT_INTERNAL': '10.128.0.20',    # Jenkins server
    'FORTOOLS_INTERNAL': '10.128.0.18',   # Forensics tools server  
    'FORMIE_INTERNAL': '10.128.0.19',     # ELK/MISP/IRIS server
    
    # VM External IPs 
    'FORMGT_EXTERNAL': '34.136.254.74',   # Jenkins server external
    'FORTOOLS_EXTERNAL': '34.172.7.74',   # Forensics tools external
    'FORMIE_EXTERNAL': '34.123.164.154',  # ELK/MISP/IRIS external
    
    # Service Ports
    'JENKINS_PORT': '8080',
    'ELASTICSEARCH_PORT': '9200', 
    'KIBANA_PORT': '5601',
    'MISP_PORT': '80',
    'IRIS_PORT': '443',
    
    # Credentials and Keys
    'SSH_KEY': 'cluster_key',
    'SSH_USER': 'olusecc',
    
    # Paths
    'EVIDENCE_PATH': '/data/evidence',
    'PROCESSED_PATH': '/data/processed', 
    'CASES_PATH': '/data/cases'
}

def generate_integration_script_config():
    """Generate updated configuration for integration scripts"""
    config = f"""# Digital Forensics Lab - Updated Configuration
# Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

# Infrastructure IPs
JENKINS_HOST = "{INFRASTRUCTURE_CONFIG['FORMGT_INTERNAL']}"
FORENSICS_SERVER = "{INFRASTRUCTURE_CONFIG['FORTOOLS_INTERNAL']}"
ELK_SERVER = "{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"
MISP_SERVER = "{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"
IRIS_SERVER = "{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"

# External IPs (for external access)
JENKINS_EXTERNAL = "{INFRASTRUCTURE_CONFIG['FORMGT_EXTERNAL']}"
FORENSICS_EXTERNAL = "{INFRASTRUCTURE_CONFIG['FORTOOLS_EXTERNAL']}"
SERVICES_EXTERNAL = "{INFRASTRUCTURE_CONFIG['FORMIE_EXTERNAL']}"

# Service URLs
ELASTICSEARCH_URL = "http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['ELASTICSEARCH_PORT']}"
KIBANA_URL = "http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['KIBANA_PORT']}"
MISP_URL = "http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['MISP_PORT']}"
IRIS_URL = "https://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['IRIS_PORT']}"
JENKINS_URL = "http://{INFRASTRUCTURE_CONFIG['FORMGT_INTERNAL']}:{INFRASTRUCTURE_CONFIG['JENKINS_PORT']}"

# Authentication
SSH_KEY_PATH = "~/.ssh/{INFRASTRUCTURE_CONFIG['SSH_KEY']}"
SSH_USER = "{INFRASTRUCTURE_CONFIG['SSH_USER']}"

# Storage Paths
EVIDENCE_PATH = "{INFRASTRUCTURE_CONFIG['EVIDENCE_PATH']}"
PROCESSED_PATH = "{INFRASTRUCTURE_CONFIG['PROCESSED_PATH']}"
CASES_PATH = "{INFRASTRUCTURE_CONFIG['CASES_PATH']}"
"""
    return config

def generate_jenkins_integration_script():
    """Generate Jenkins integration helper script"""
    script = f"""#!/bin/bash
# Jenkins Integration Helper Script
# Digital Forensics Lab Automation

# Infrastructure Configuration
export JENKINS_HOST="{INFRASTRUCTURE_CONFIG['FORMGT_INTERNAL']}"
export FORENSICS_SERVER="{INFRASTRUCTURE_CONFIG['FORTOOLS_INTERNAL']}"
export ELK_SERVER="{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"
export MISP_SERVER="{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"
export IRIS_SERVER="{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}"

# Service URLs
export ELASTICSEARCH_URL="http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['ELASTICSEARCH_PORT']}"
export KIBANA_URL="http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['KIBANA_PORT']}"
export MISP_URL="http://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['MISP_PORT']}"
export IRIS_URL="https://{INFRASTRUCTURE_CONFIG['FORMIE_INTERNAL']}:{INFRASTRUCTURE_CONFIG['IRIS_PORT']}"

# SSH Configuration
export SSH_KEY_PATH="~/.ssh/{INFRASTRUCTURE_CONFIG['SSH_KEY']}"
export SSH_USER="{INFRASTRUCTURE_CONFIG['SSH_USER']}"

# Helper Functions
function ssh_forensics() {{
    ssh -i $SSH_KEY_PATH $SSH_USER@$FORENSICS_SERVER "$@"
}}

function ssh_services() {{
    ssh -i $SSH_KEY_PATH $SSH_USER@$ELK_SERVER "$@"
}}

function check_services() {{
    echo "Checking service availability..."
    curl -s "$ELASTICSEARCH_URL/_cluster/health" > /dev/null && echo "✅ Elasticsearch: OK" || echo "❌ Elasticsearch: FAIL"
    curl -s "$KIBANA_URL/api/status" > /dev/null && echo "✅ Kibana: OK" || echo "❌ Kibana: FAIL"
    curl -s -k "$IRIS_URL" > /dev/null && echo "✅ IRIS: OK" || echo "❌ IRIS: FAIL"
    curl -s "$MISP_URL" > /dev/null && echo "✅ MISP: OK" || echo "❌ MISP: FAIL"
}}

# Main execution
if [[ "${{BASH_SOURCE[0]}}" == "${{0}}" ]]; then
    echo "Digital Forensics Lab - Integration Helper"
    echo "=========================================="
    check_services
fi
"""
    return script

if __name__ == "__main__":
    import os
    from datetime import datetime
    
    print("🔧 Updating Digital Forensics Lab Configuration...")
    
    # Create config file
    config_content = generate_integration_script_config()
    with open('/tmp/lab_config.py', 'w') as f:
        f.write(config_content)
    print("✅ Generated lab_config.py")
    
    # Create integration helper script
    helper_script = generate_jenkins_integration_script()
    with open('/tmp/lab_integration_helper.sh', 'w') as f:
        f.write(helper_script)
    os.chmod('/tmp/lab_integration_helper.sh', 0o755)
    print("✅ Generated lab_integration_helper.sh")
    
    print("\n📋 Current Infrastructure:")
    for key, value in INFRASTRUCTURE_CONFIG.items():
        print(f"   {key}: {value}")
    
    print("\n🎯 Next Steps:")
    print("   1. Copy lab_config.py to your integration scripts directory")
    print("   2. Update integration scripts to import from lab_config")
    print("   3. Use lab_integration_helper.sh for Jenkins jobs")
    print("   4. Test connectivity with the check_services function")
