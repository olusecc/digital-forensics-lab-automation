#!/usr/bin/env python3
import requests
import json
import time

def create_kibana_dashboards():
    """Create forensics-specific Kibana dashboards"""
    kibana_url = "http://192.168.1.12:5601"
    
    # Wait for Kibana to be fully ready
    print("Waiting for Kibana to be ready...")
    for i in range(30):
        try:
            response = requests.get(f"{kibana_url}/api/status")
            if response.status_code == 200:
                break
        except:
            pass
        time.sleep(10)
    
    headers = {
        'Content-Type': 'application/json',
        'kbn-xsrf': 'true'
    }
    
    # Create index patterns
    index_patterns = [
        {
            'id': 'forensics-*',
            'title': 'forensics-*',
            'timeFieldName': '@timestamp'
        }
    ]
    
    for pattern in index_patterns:
        url = f"{kibana_url}/api/saved_objects/index-pattern/{pattern['id']}"
        data = {
            'attributes': {
                'title': pattern['title'],
                'timeFieldName': pattern['timeFieldName']
            }
        }
        
        try:
            response = requests.post(url, headers=headers, json=data)
            print(f"Index pattern {pattern['id']}: {response.status_code}")
        except Exception as e:
            print(f"Error creating index pattern: {e}")
    
    # Create visualizations
    visualizations = [
        {
            'id': 'forensics-overview-pie',
            'title': 'Evidence Types Distribution',
            'type': 'pie',
            'kibanaSavedObjectMeta': {
                'searchSourceJSON': json.dumps({
                    'index': 'forensics-*',
                    'query': {'match_all': {}},
                    'aggs': {
                        '1': {
                            'terms': {
                                'field': 'type',
                                'size': 10
                            }
                        }
                    }
                })
            }
        },
        {
            'id': 'forensics-timeline',
            'title': 'Processing Timeline',
            'type': 'histogram',
            'kibanaSavedObjectMeta': {
                'searchSourceJSON': json.dumps({
                    'index': 'forensics-*',
                    'query': {'match_all': {}},
                    'aggs': {
                        '1': {
                            'date_histogram': {
                                'field': '@timestamp',
                                'interval': '1h',
                                'min_doc_count': 1
                            }
                        }
                    }
                })
            }
        },
        {
            'id': 'threat-scores-metric',
            'title': 'High Threat Score Items',
            'type': 'metric',
            'kibanaSavedObjectMeta': {
                'searchSourceJSON': json.dumps({
                    'index': 'forensics-*',
                    'query': {
                        'range': {
                            'threat_score': {'gte': 5}
                        }
                    }
                })
            }
        }
    ]
    
    for viz in visualizations:
        url = f"{kibana_url}/api/saved_objects/visualization/{viz['id']}"
        data = {
            'attributes': {
                'title': viz['title'],
                'visState': json.dumps({
                    'title': viz['title'],
                    'type': viz['type'],
                    'params': {}
                }),
                'kibanaSavedObjectMeta': viz['kibanaSavedObjectMeta']
            }
        }
        
        try:
            response = requests.post(url, headers=headers, json=data)
            print(f"Visualization {viz['id']}: {response.status_code}")
        except Exception as e:
            print(f"Error creating visualization: {e}")
    
    # Create main dashboard
    dashboard = {
        'id': 'forensics-main-dashboard',
        'title': 'Digital Forensics Lab - Main Dashboard',
        'panelsJSON': json.dumps([
            {
                'id': 'forensics-overview-pie',
                'type': 'visualization',
                'gridData': {'x': 0, 'y': 0, 'w': 24, 'h': 15}
            },
            {
                'id': 'forensics-timeline',
                'type': 'visualization', 
                'gridData': {'x': 24, 'y': 0, 'w': 24, 'h': 15}
            },
            {
                'id': 'threat-scores-metric',
                'type': 'visualization',
                'gridData': {'x': 0, 'y': 15, 'w': 48, 'h': 10}
            }
        ])
    }
    
    url = f"{kibana_url}/api/saved_objects/dashboard/{dashboard['id']}"
    data = {
        'attributes': {
            'title': dashboard['title'],
            'panelsJSON': dashboard['panelsJSON'],
            'timeRestore': False,
            'version': 1
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=data)
        print(f"Dashboard {dashboard['id']}: {response.status_code}")
        if response.status_code in [200, 201]:
            print(f"✅ Main dashboard created: {kibana_url}/app/dashboards#/view/{dashboard['id']}")
    except Exception as e:
        print(f"Error creating dashboard: {e}")

if __name__ == '__main__':
    create_kibana_dashboards()