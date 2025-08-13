#!/usr/bin/env python3
"""
Digital Forensics Lab - Connectivity Test Script
Tests connectivity to all services with updated IP configurations
"""

import requests
import subprocess
import json
from datetime import datetime
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Import lab configuration
try:
    from lab_config import *
except ImportError:
    print("⚠️  lab_config.py not found, using fallback configuration")
    # Fallback configuration
    ELASTICSEARCH_URL = "http://10.128.0.19:9200"
    KIBANA_URL = "http://10.128.0.19:5601"
    MISP_URL = "http://10.128.0.19:8080"
    IRIS_URL = "https://10.128.0.19:443"
    JENKINS_URL = "http://10.128.0.20:8080"
    FORENSICS_SERVER = "10.128.0.18"
    ELK_SERVER = "10.128.0.19"

def test_service(name, url, timeout=10):
    """Test if a service is accessible"""
    try:
        if url.startswith('https://'):
            response = requests.get(url, timeout=timeout, verify=False)
        else:
            response = requests.get(url, timeout=timeout)
        
        if response.status_code in [200, 302, 401, 403]:  # 401/403 might be auth required
            return True, response.status_code
        else:
            return False, response.status_code
    except requests.exceptions.RequestException as e:
        return False, str(e)

def test_ssh_connectivity(server, user="olusecc", key="~/.ssh/cluster_key"):
    """Test SSH connectivity"""
    try:
        cmd = f"ssh -i {key} -o ConnectTimeout=10 -o StrictHostKeyChecking=no {user}@{server} 'echo SSH_OK'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
        return result.returncode == 0, result.stdout.strip()
    except subprocess.TimeoutExpired:
        return False, "SSH timeout"
    except Exception as e:
        return False, str(e)

def main():
    print("🧪 Digital Forensics Lab - Connectivity Test")
    print("=" * 50)
    print(f"Test run: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Service connectivity tests
    services = [
        ("Elasticsearch", ELASTICSEARCH_URL),
        ("Kibana", KIBANA_URL), 
        ("MISP", MISP_URL),
        ("IRIS", IRIS_URL),
        ("Jenkins", JENKINS_URL)
    ]
    
    print("🌐 Testing Service Connectivity:")
    print("-" * 30)
    for name, url in services:
        success, status = test_service(name, url)
        status_icon = "✅" if success else "❌"
        print(f"{status_icon} {name:12} {url:30} Status: {status}")
    
    print()
    
    # SSH connectivity tests
    print("🔑 Testing SSH Connectivity:")
    print("-" * 30)
    ssh_servers = [
        ("Forensics Server", FORENSICS_SERVER),
        ("ELK/Services Server", ELK_SERVER),
    ]
    
    for name, server in ssh_servers:
        success, result = test_ssh_connectivity(server)
        status_icon = "✅" if success else "❌"
        print(f"{status_icon} {name:18} {server:15} Result: {result}")
    
    print()
    
    # Elasticsearch cluster health
    print("🏥 Elasticsearch Cluster Health:")
    print("-" * 30)
    try:
        es_health = requests.get(f"{ELASTICSEARCH_URL}/_cluster/health", timeout=10)
        if es_health.status_code == 200:
            health_data = es_health.json()
            print(f"✅ Cluster Status: {health_data.get('status', 'unknown')}")
            print(f"   Nodes: {health_data.get('number_of_nodes', 'unknown')}")
            print(f"   Data Nodes: {health_data.get('number_of_data_nodes', 'unknown')}")
        else:
            print(f"❌ Cannot get cluster health: {es_health.status_code}")
    except Exception as e:
        print(f"❌ Elasticsearch health check failed: {e}")
    
    print()
    print("🎯 Infrastructure Summary:")
    print("-" * 30)
    print(f"   Management (Jenkins): {JENKINS_URL}")
    print(f"   Forensics Tools: ssh://olusecc@{FORENSICS_SERVER}")
    print(f"   Data Services: {ELK_SERVER} (ELK/MISP/IRIS)")
    print(f"   Storage: NFS on {ELK_SERVER}")
    
    print()
    print("📝 Next Steps if Issues Found:")
    print("   1. Check firewall rules: sudo ufw status")
    print("   2. Verify services are running: systemctl status <service>")
    print("   3. Check SSH key permissions: ls -la ~/.ssh/cluster_key")
    print("   4. Test manual SSH: ssh -i ~/.ssh/cluster_key olusecc@<ip>")

if __name__ == "__main__":
    main()
