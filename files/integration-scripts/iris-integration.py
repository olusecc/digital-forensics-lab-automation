#!/usr/bin/env python3
import requests
import json
import sys
from datetime import datetime

class IRISIntegration:
    def __init__(self, iris_url, username, password):
        self.iris_url = iris_url.rstrip('/')
        self.session = requests.Session()
        self.login(username, password)
    
    def login(self, username, password):
        """Login to IRIS and get session"""
        login_url = f"{self.iris_url}/login"
        login_data = {
            'email': username,
            'password': password
        }
        
        try:
            response = self.session.post(login_url, data=login_data)
            if response.status_code != 200:
                print(f"IRIS login failed: {response.status_code}")
            else:
                print("Successfully logged into IRIS")
        except Exception as e:
            print(f"Error logging into IRIS: {e}")
    
    def create_case(self, case_data):
        """Create a new case in IRIS"""
        url = f"{self.iris_url}/case/add"
        
        try:
            response = self.session.post(url, json=case_data)
            return response.json() if response.status_code in [200, 201] else None
        except Exception as e:
            print(f"Error creating IRIS case: {e}")
            return None
    
    def add_evidence(self, case_id, evidence_data):
        """Add evidence to an existing case"""
        url = f"{self.iris_url}/case/{case_id}/evidence/add"
        
        try:
            response = self.session.post(url, json=evidence_data)
            return response.json() if response.status_code in [200, 201] else None
        except Exception as e:
            print(f"Error adding evidence to IRIS: {e}")
            return None
    
    def create_timeline_entry(self, case_id, timeline_data):
        """Add timeline entry to case"""
        url = f"{self.iris_url}/case/{case_id}/timeline/add"
        
        try:
            response = self.session.post(url, json=timeline_data)
            return response.json() if response.status_code in [200, 201] else None
        except Exception as e:
            print(f"Error creating IRIS timeline entry: {e}")
            return None
    
    def update_case_status(self, case_id, status, notes):
        """Update case status and add notes"""
        url = f"{self.iris_url}/case/{case_id}/update"
        update_data = {
            'case_status': status,
            'case_description': notes,
            'modification_history': f"Updated by automation at {datetime.now().isoformat()}"
        }
        
        try:
            response = self.session.post(url, json=update_data)
            return response.json() if response.status_code == 200 else None
        except Exception as e:
            print(f"Error updating IRIS case: {e}")
            return None

def main():
    if len(sys.argv) < 5:
        print("Usage: iris_integration.py <iris_url> <username> <password> <action> [args...]")
        print("Actions:")
        print("  create_case <name> <description> <investigator>")
        print("  add_evidence <case_id> <evidence_name> <evidence_type> <evidence_path>")
        print("  update_status <case_id> <status> <notes>")
        sys.exit(1)
    
    iris_url = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]
    action = sys.argv[4]
    
    iris = IRISIntegration(iris_url, username, password)
    
    if action == 'create_case':
        if len(sys.argv) != 8:
            print("Usage: create_case <name> <description> <investigator>")
            sys.exit(1)
        
        case_data = {
            'case_name': sys.argv[5],
            'case_description': sys.argv[6],
            'case_customer': 1,  # Default customer
            'case_classification': 'internal',
            'case_owner': sys.argv[7],
            'case_opening_date': datetime.now().strftime('%Y-%m-%d'),
            'case_severity': 'medium'
        }
        
        result = iris.create_case(case_data)
        print(json.dumps(result) if result else "Case creation failed")
    
    elif action == 'add_evidence':
        if len(sys.argv) != 9:
            print("Usage: add_evidence <case_id> <evidence_name> <evidence_type> <evidence_path>")
            sys.exit(1)
        
        case_id = sys.argv[5]
        evidence_data = {
            'filename': sys.argv[6],
            'file_description': f"Evidence: {sys.argv[7]}",
            'file_path': sys.argv[8],
            'file_hash': '',  # Would be calculated
            'file_size': 0,   # Would be calculated
            'added_by': 'automation'
        }
        
        result = iris.add_evidence(case_id, evidence_data)
        print(json.dumps(result) if result else "Evidence addition failed")
    
    elif action == 'update_status':
        if len(sys.argv) != 8:
            print("Usage: update_status <case_id> <status> <notes>")
            sys.exit(1)
        
        case_id = sys.argv[5]
        status = sys.argv[6]
        notes = sys.argv[7]
        
        result = iris.update_case_status(case_id, status, notes)
        print(json.dumps(result) if result else "Status update failed")
    
    else:
        print(f"Unknown action: {action}")
        sys.exit(1)

if __name__ == '__main__':
    main()