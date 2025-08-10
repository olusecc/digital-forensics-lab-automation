#!/usr/bin/env python3
import json
import sys
import os
import re
from datetime import datetime

def parse_process_list(proc_file, case_id, memory_hash):
    """Parse Volatility process list output"""
    results = []
    if os.path.exists(proc_file):
        try:
            with open(proc_file, 'r') as f:
                lines = f.readlines()
                for line in lines[2:]:  # Skip header lines
                    if line.strip():
                        # Parse process information
                        parts = line.strip().split()
                        if len(parts) >= 6:
                            result = {
                                '@timestamp': datetime.now().isoformat(),
                                'case_id': case_id,
                                'evidence_hash': memory_hash,
                                'type': 'volatility',
                                'source': 'process_list',
                                'process_name': parts[1] if len(parts) > 1 else '',
                                'pid': parts[2] if len(parts) > 2 else '',
                                'ppid': parts[3] if len(parts) > 3 else '',
                                'threads': parts[4] if len(parts) > 4 else '',
                                'handles': parts[5] if len(parts) > 5 else '',
                                'processed_time': datetime.now().isoformat()
                            }
                            results.append(result)
        except Exception as e:
            print(f"Error processing process list: {e}")
    return results

def parse_network_connections(net_file, case_id, memory_hash):
    """Parse Volatility network connections"""
    results = []
    if os.path.exists(net_file):
        try:
            with open(net_file, 'r') as f:
                lines = f.readlines()
                for line in lines[2:]:  # Skip headers
                    if line.strip():
                        parts = line.strip().split()
                        if len(parts) >= 4:
                            result = {
                                '@timestamp': datetime.now().isoformat(),
                                'case_id': case_id,
                                'evidence_hash': memory_hash,
                                'type': 'volatility',
                                'source': 'network_connections',
                                'protocol': parts[0] if len(parts) > 0 else '',
                                'local_addr': parts[1] if len(parts) > 1 else '',
                                'foreign_addr': parts[2] if len(parts) > 2 else '',
                                'state': parts[3] if len(parts) > 3 else '',
                                'processed_time': datetime.now().isoformat()
                            }
                            results.append(result)
        except Exception as e:
            print(f"Error processing network connections: {e}")
    return results

def main():
    if len(sys.argv) != 4:
        print("Usage: volatility_to_json.py <output_directory> <case_id> <memory_hash>")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    case_id = sys.argv[2]
    memory_hash = sys.argv[3]
    
    json_dir = '/data/processed/volatility'
    os.makedirs(json_dir, exist_ok=True)
    
    timestamp = int(datetime.now().timestamp())
    all_results = []
    
    # Process different volatility outputs
    files_to_process = {
        'processes.txt': parse_process_list,
        'network_connections.txt': parse_network_connections
    }
    
    for filename, parser_func in files_to_process.items():
        file_path = os.path.join(output_dir, filename)
        results = parser_func(file_path, case_id, memory_hash)
        all_results.extend(results)
    
    if all_results:
        output_file = os.path.join(json_dir, f'volatility_{case_id}_{timestamp}.json')
        with open(output_file, 'w') as f:
            for result in all_results:
                f.write(json.dumps(result) + '\n')
        print(f"Volatility data: {len(all_results)} entries written to {output_file}")
    else:
        print("No volatility data to process")

if __name__ == '__main__':
    main()