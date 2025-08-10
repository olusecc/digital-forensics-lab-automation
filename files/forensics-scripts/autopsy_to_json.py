#!/usr/bin/env python3
import json
import csv
import sys
import os
from datetime import datetime

def process_timeline(timeline_file, case_id, file_hash):
    """Process Sleuth Kit timeline data"""
    results = []
    if os.path.exists(timeline_file):
        try:
            with open(timeline_file, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    if line.strip():
                        parts = line.strip().split(',')
                        if len(parts) >= 8:
                            result = {
                                '@timestamp': datetime.now().isoformat(),
                                'case_id': case_id,
                                'evidence_hash': file_hash,
                                'type': 'autopsy',
                                'source': 'timeline',
                                'timestamp': parts[0] if parts[0] != '0' else None,
                                'file_size': parts[1],
                                'activity_type': parts[2],
                                'permissions': parts[3],
                                'uid': parts[4],
                                'gid': parts[5],
                                'meta_address': parts[6],
                                'file_path': parts[7] if len(parts) > 7 else '',
                                'processed_time': datetime.now().isoformat(),
                                'line_number': line_num
                            }
                            results.append(result)
        except Exception as e:
            print(f"Error processing timeline: {e}")
    return results

def process_file_listing(listing_file, case_id, file_hash):
    """Process file listing data"""
    results = []
    if os.path.exists(listing_file):
        try:
            with open(listing_file, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    if line.strip():
                        result = {
                            '@timestamp': datetime.now().isoformat(),
                            'case_id': case_id,
                            'evidence_hash': file_hash,
                            'type': 'autopsy',
                            'source': 'file_listing',
                            'file_entry': line.strip(),
                            'processed_time': datetime.now().isoformat(),
                            'line_number': line_num
                        }
                        results.append(result)
        except Exception as e:
            print(f"Error processing file listing: {e}")
    return results

def main():
    if len(sys.argv) != 4:
        print("Usage: autopsy_to_json.py <output_directory> <case_id> <file_hash>")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    case_id = sys.argv[2]
    file_hash = sys.argv[3]
    
    json_dir = '/data/processed/autopsy'
    os.makedirs(json_dir, exist_ok=True)
    
    timestamp = int(datetime.now().timestamp())
    
    # Process timeline
    timeline_file = os.path.join(output_dir, 'timeline.csv')
    timeline_results = process_timeline(timeline_file, case_id, file_hash)
    
    if timeline_results:
        timeline_json = os.path.join(json_dir, f'timeline_{case_id}_{timestamp}.json')
        with open(timeline_json, 'w') as f:
            for result in timeline_results:
                f.write(json.dumps(result) + '\n')
        print(f"Timeline data: {len(timeline_results)} entries written to {timeline_json}")
    
    # Process file listing
    listing_file = os.path.join(output_dir, 'file_listing.txt')
    listing_results = process_file_listing(listing_file, case_id, file_hash)
    
    if listing_results:
        listing_json = os.path.join(json_dir, f'files_{case_id}_{timestamp}.json')
        with open(listing_json, 'w') as f:
            for result in listing_results:
                f.write(json.dumps(result) + '\n')
        print(f"File listing: {len(listing_results)} entries written to {listing_json}")

if __name__ == '__main__':
    main()