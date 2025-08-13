#!/usr/bin/env python3
import json
import sys
import os
from datetime import datetime
import requests

def generate_case_summary(case_id, evidence_type, investigator, output_dir):
    """Generate case summary report"""
    
    # Query Elasticsearch for case data
    elasticsearch_url = "http://192.168.1.12:9200"
    
    try:
        # Search for all data related to this case
        search_url = f"{elasticsearch_url}/forensics-*/_search"
        query = {
            "query": {
                "term": {
                    "case_id": case_id
                }
            },
            "size": 1000,
            "aggs": {
                "evidence_types": {
                    "terms": {
                        "field": "type"
                    }
                },
                "sources": {
                    "terms": {
                        "field": "source"
                    }
                }
            }
        }
        
        response = requests.post(search_url, json=query)
        data = response.json() if response.status_code == 200 else {}
        
        # Generate HTML report
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Forensics Case Report - {case_id}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; }}
        .header {{ background: #2c3e50; color: white; padding: 20px; }}
        .section {{ margin: 20px 0; }}
        .evidence-item {{ background: #f8f9fa; padding: 10px; margin: 10px 0; border-left: 4px solid #007bff; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Digital Forensics Case Report</h1>
        <p>Case ID: {case_id} | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    </div>
    
    <div class="section">
        <h2>Case Information</h2>
        <table>
            <tr><th>Case ID</th><td>{case_id}</td></tr>
            <tr><th>Primary Investigator</th><td>{investigator}</td></tr>
            <tr><th>Evidence Type</th><td>{evidence_type}</td></tr>
            <tr><th>Processing Date</th><td>{datetime.now().strftime('%Y-%m-%d')}</td></tr>
            <tr><th>Total Evidence Items</th><td>{data.get('hits', {}).get('total', {}).get('value', 0)}</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Analysis Summary</h2>
        <div class="evidence-item">
            <h3>Evidence Sources Processed:</h3>
            <ul>
"""
        
        # Add aggregation results
        if 'aggregations' in data:
            for bucket in data['aggregations'].get('sources', {}).get('buckets', []):
                html_content += f"<li>{bucket['key']}: {bucket['doc_count']} items</li>"
        
        html_content += """
            </ul>
        </div>
    </div>
    
    <div class="section">
        <h2>Key Findings</h2>
        <div class="evidence-item">
"""
        
        # Add key findings from evidence
        hits = data.get('hits', {}).get('hits', [])
        key_findings = []
        
        for hit in hits[:10]:  # Top 10 findings
            source_data = hit.get('_source', {})
            if source_data.get('file_path'):
                key_findings.append(f"File: {source_data['file_path']}")
            elif source_data.get('process_name'):
                key_findings.append(f"Process: {source_data['process_name']}")
            elif source_data.get('yara_matches'):
                key_findings.append("⚠️ YARA rule matches detected")
        
        for finding in key_findings[:5]:
            html_content += f"<p>• {finding}</p>"
        
        html_content += """
        </div>
    </div>
    
    <div class="section">
        <h2>Technical Details</h2>
        <p>This automated analysis was performed using the Digital Forensics Lab pipeline.</p>
        <p>For detailed results, please review:</p>
        <ul>
            <li>Kibana Dashboard: http://192.168.1.12:5601</li>
            <li>Raw analysis files in case directory</li>
            <li>Elasticsearch indices: forensics-*</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Next Steps</h2>
        <ol>
            <li>Review detailed findings in Kibana dashboards</li>
            <li>Investigate any flagged items or IOC matches</li>
            <li>Document additional manual analysis</li>
            <li>Prepare final case report</li>
        </ol>
    </div>
</body>
</html>
"""
        
        # Write report
        os.makedirs(output_dir, exist_ok=True)
        report_file = os.path.join(output_dir, f"case_report_{case_id}.html")
        
        with open(report_file, 'w') as f:
            f.write(html_content)
        
        # Also create JSON summary
        summary = {
            'case_id': case_id,
            'investigator': investigator,
            'evidence_type': evidence_type,
            'generated_at': datetime.now().isoformat(),
            'total_items': data.get('hits', {}).get('total', {}).get('value', 0),
            'elasticsearch_data': data
        }
        
        json_file = os.path.join(output_dir, f"case_summary_{case_id}.json")
        with open(json_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"Report generated: {report_file}")
        print(f"Summary data: {json_file}")
        
    except Exception as e:
        print(f"Error generating report: {e}")
        # Create minimal report even if ES query fails
        simple_report = f"""
# Forensics Case Report - {case_id}

**Case ID:** {case_id}
**Investigator:** {investigator}
**Evidence Type:** {evidence_type}
**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Status
Evidence processing completed. Manual review of results required.

## Error
Could not connect to Elasticsearch for detailed analysis: {e}

Please check:
- Elasticsearch service status
- Network connectivity
- Case data in /data/cases/{case_id}/
"""
        
        report_file = os.path.join(output_dir, f"case_report_{case_id}.txt")
        with open(report_file, 'w') as f:
            f.write(simple_report)
        
        print(f"Basic report generated: {report_file}")

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print("Usage: generate_case_report.py <case_id> <evidence_type> <investigator> <output_dir>")
        sys.exit(1)
    
    case_id = sys.argv[1]
    evidence_type = sys.argv[2]
    investigator = sys.argv[3]
    output_dir = sys.argv[4]
    
    generate_case_summary(case_id, evidence_type, investigator, output_dir)