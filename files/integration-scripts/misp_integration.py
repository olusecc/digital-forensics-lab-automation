#!/usr/bin/env python3
import requests
import json
import sys
from datetime import datetime
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
# Import lab configuration
try:
    from lab_config import MISP_URL, MISP_SERVER
except ImportError:
    # Fallback to default if config not available
    MISP_URL = "http://10.128.0.19:80"
    MISP_SERVER = "10.128.0.19"

class MISPIntegration:
    def __init__(self, misp_url, api_key):
        self.misp_url = misp_url.rstrip('/')
        self.api_key = api_key
        self.headers = {
            'Authorization': api_key,
            'Accept': 'application/json',
            'Content-type': 'application/json'
        }
    
    def search_attributes(self, ioc_value, ioc_type='hash-sha256'):
        """Search for IOCs in MISP"""
        search_url = f"{self.misp_url}/attributes/restSearch"
        search_data = {
            'value': ioc_value,
            'type': ioc_type,
            'limit': 50,
            'page': 1
        }
        
        try:
            response = requests.post(search_url, 
                                   headers=self.headers,
                                   data=json.dumps(search_data),
                                   verify=False,
                                   timeout=30)
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"MISP search failed: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"Error searching MISP: {e}")
            return None
    
    def create_event(self, case_id, findings):
        """Create MISP event from forensic findings"""
        event_data = {
            'Event': {
                'info': f'Forensic Analysis - Case {case_id}',
                'threat_level_id': '2',  # Medium
                'analysis': '1',  # Ongoing
                'distribution': '1',  # This community only
                'published': False,
                'Attribute': []
            }
        }
        
        # Add attributes from findings
        for finding in findings:
            if 'file_hash' in finding and finding['file_hash']:
                event_data['Event']['Attribute'].append({
                    'category': 'Payload delivery',
                    'type': 'sha256',
                    'value': finding['file_hash'],
                    'comment': f"Found in case {case_id} - {finding.get('source', 'unknown')}"
                })
            
            if 'ip_address' in finding and finding['ip_address']:
                event_data['Event']['Attribute'].append({
                    'category': 'Network activity',
                    'type': 'ip-dst',
                    'value': finding['ip_address'],
                    'comment': f"Network connection from case {case_id}"
                })
            
            if 'url' in finding and finding['url']:
                event_data['Event']['Attribute'].append({
                    'category': 'Network activity',
                    'type': 'url',
                    'value': finding['url'],
                    'comment': f"URL from case {case_id}"
                })
        
        create_url = f"{self.misp_url}/events"
        try:
            response = requests.post(create_url,
                                   headers=self.headers,
                                   data=json.dumps(event_data),
                                   verify=False,
                                   timeout=30)
            
            if response.status_code in [200, 201]:
                return response.json()
            else:
                print(f"MISP event creation failed: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"Error creating MISP event: {e}")
            return None

def process_forensic_findings(findings_file, misp_url, api_key):
    """Process forensic findings and enrich with MISP data"""
    misp = MISPIntegration(misp_url, api_key)
    enriched_findings = []
    
    try:
        with open(findings_file, 'r') as f:
            for line in f:
                if line.strip():
                    finding = json.loads(line.strip())
                    
                    # Check for IOC matches
                    ioc_found = False
                    
                    if 'file_hash' in finding and finding['file_hash']:
                        result = misp.search_attributes(finding['file_hash'], 'sha256')
                        if result and result.get('response', {}).get('Attribute'):
                            finding['misp_match'] = True
                            finding['threat_intel'] = result['response']['Attribute']
                            finding['threat_score'] = 8  # High score for hash match
                            ioc_found = True
                    
                    if 'ip_address' in finding and finding['ip_address']:
                        result = misp.search_attributes(finding['ip_address'], 'ip-dst')
                        if result and result.get('response', {}).get('Attribute'):
                            finding['misp_match'] = True
                            finding['threat_intel'] = result['response']['Attribute']
                            finding['threat_score'] = finding.get('threat_score', 0) + 5
                            ioc_found = True
                    
                    if not ioc_found:
                        finding['misp_match'] = False
                        finding['threat_score'] = 1  # Low baseline score
                    
                    enriched_findings.append(finding)
                    
    except Exception as e:
        print(f"Error processing findings: {e}")
        return []
    
    return enriched_findings

def main():
    if len(sys.argv) != 4:
        print("Usage: misp_integration.py <misp_url> <api_key> <findings_file>")
        print("Example: misp_integration.py http://10.128.0.19 API_KEY /data/processed/findings.json")
        sys.exit(1)
    
    misp_url = sys.argv[1]
    api_key = sys.argv[2]
    findings_file = sys.argv[3]
    
    # Process and enrich findings
    enriched_findings = process_forensic_findings(findings_file, misp_url, api_key)
    
    # Output enriched findings
    for finding in enriched_findings:
        print(json.dumps(finding))
    
    # Create MISP event if high-value IOCs found
    high_value_findings = [f for f in enriched_findings if f.get('threat_score', 0) > 5]
    if high_value_findings:
        case_id = high_value_findings[0].get('case_id', 'UNKNOWN')
        misp = MISPIntegration(misp_url, api_key)
        event = misp.create_event(case_id, high_value_findings)
        if event:
            print(f"Created MISP event for case {case_id}")

if __name__ == '__main__':
    main()