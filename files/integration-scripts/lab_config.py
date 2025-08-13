# Digital Forensics Lab - Updated Configuration
# Generated on: 2025-08-12 11:50:30

# Infrastructure IPs
JENKINS_HOST = "10.128.0.20"
FORENSICS_SERVER = "10.128.0.18"
ELK_SERVER = "10.128.0.19"
MISP_SERVER = "10.128.0.19"
IRIS_SERVER = "10.128.0.19"

# External IPs (for external access)
JENKINS_EXTERNAL = "34.136.254.74"
FORENSICS_EXTERNAL = "34.172.7.74"
SERVICES_EXTERNAL = "34.123.164.154"

# Service URLs
ELASTICSEARCH_URL = "http://10.128.0.19:9200"
KIBANA_URL = "http://10.128.0.19:5601"
MISP_URL = "http://10.128.0.19:8080"
IRIS_URL = "https://10.128.0.19:443"
JENKINS_URL = "http://10.128.0.20:8080"

# Authentication
SSH_KEY_PATH = "~/.ssh/cluster_key"
SSH_USER = "olusecc"

# Storage Paths
EVIDENCE_PATH = "/data/evidence"
PROCESSED_PATH = "/data/processed"
CASES_PATH = "/data/cases"
