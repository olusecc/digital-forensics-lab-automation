#!/usr/bin/env python3
import json
import sys
import os
from datetime import datetime

def process_andriller_data(output_dir, case_id):
    """Process Andriller output directory"""
    results = []
    
    # Look for common Andriller output files
    andriller_files = ['contacts.csv', 'messages.csv', 'calls.csv', 'apps.txt']
    
    for filename in andriller_files:
        file_path = os.path.join(output_dir, filename)
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    result = {
                        '@timestamp': datetime.now().isoformat(),
                        'case_id': case_id,
                        'type': 'andriller',
                        'source': filename.replace('.csv', '').replace('.txt', ''),
                        'content': content[:1000],  # First 1000 chars
                        'file_size': len(content),
                        'processed_time': datetime.now().isoformat()
                    }
                    results.append(result)
            except Exception as e:
                print(f"Error processing {filename}: {e}")
    
    return results

def main():
    if len(sys.argv) != 3:
        print("Usage: andriller_to_json.py <output_directory> <case_id>")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    case_id = sys.argv[2]
    
    json_dir = '/data/processed/andriller'
    os.makedirs(json_dir, exist_ok=True)
    
    results = process_andriller_data(output_dir, case_id)
    
    if results:
        timestamp = int(datetime.now().timestamp())
        output_file = os.path.join(json_dir, f'andriller_{case_id}_{timestamp}.json')
        with open(output_file, 'w') as f:
            for result in results:
                f.write(json.dumps(result) + '\n')
        print(f"Andriller data: {len(results)} entries written to {output_file}")
    else:
        print("No andriller data to process")

if __name__ == '__main__':
    main()
