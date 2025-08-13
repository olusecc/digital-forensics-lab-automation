#!/usr/bin/env python3
"""
Digital Forensics Evidence Intake Portal
A Flask web application for submitting evidence and triggering automated processing
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from werkzeug.utils import secure_filename
import os
import hashlib
import datetime
import requests
import json
import uuid
from pathlib import Path

app = Flask(__name__)
app.secret_key = 'forensics-evidence-portal-2024'
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024 * 1024  # 50GB max file size

# Configuration
UPLOAD_FOLDER = '/var/lib/jenkins/forensics/evidence/intake'
EVIDENCE_STORAGE = '/var/lib/jenkins/forensics/evidence'
JENKINS_URL = 'http://localhost:8080'
JENKINS_USER = 'forensics_admin'
JENKINS_TOKEN = 'your-jenkins-api-token'
IRIS_API_URL = 'https://10.128.0.19:443/api'

# Ensure upload directory exists
Path(UPLOAD_FOLDER).mkdir(parents=True, exist_ok=True)
Path(EVIDENCE_STORAGE).mkdir(parents=True, exist_ok=True)

ALLOWED_EXTENSIONS = {
    'disk': {'img', 'dd', 'raw', 'vmdk', 'vdi', 'e01', 'ex01'},
    'memory': {'mem', 'dmp', 'raw', 'vmem', 'bin'},
    'mobile': {'ab', 'tar', 'zip', 'dd', 'bin'},
    'malware': {'exe', 'dll', 'bin', 'zip', 'rar', 'doc', 'pdf', 'js'}
}

def allowed_file(filename, evidence_type):
    return ('.' in filename and 
            filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS.get(evidence_type, set()))

def calculate_file_hash(filepath):
    """Calculate MD5, SHA1, and SHA256 hashes of a file"""
    hash_md5 = hashlib.md5()
    hash_sha1 = hashlib.sha1()
    hash_sha256 = hashlib.sha256()
    
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
            hash_sha1.update(chunk)
            hash_sha256.update(chunk)
    
    return {
        'md5': hash_md5.hexdigest(),
        'sha1': hash_sha1.hexdigest(),
        'sha256': hash_sha256.hexdigest()
    }

def trigger_jenkins_job(job_name, parameters):
    """Trigger a Jenkins job with parameters"""
    try:
        jenkins_job_url = f"{JENKINS_URL}/job/{job_name}/buildWithParameters"
        
        response = requests.post(
            jenkins_job_url,
            auth=(JENKINS_USER, JENKINS_TOKEN),
            data=parameters,
            timeout=30
        )
        
        if response.status_code in [200, 201]:
            return True, "Jenkins job triggered successfully"
        else:
            return False, f"Jenkins job trigger failed: {response.status_code}"
            
    except Exception as e:
        return False, f"Error triggering Jenkins job: {str(e)}"

def create_iris_case(case_data):
    """Create a new case in IRIS"""
    try:
        # This would integrate with IRIS API
        # For now, we'll simulate the API call
        return True, f"IRIS case {case_data['case_id']} created successfully"
    except Exception as e:
        return False, f"Error creating IRIS case: {str(e)}"

@app.route('/')
def index():
    """Main dashboard showing recent cases and system status"""
    return render_template('index.html')

@app.route('/submit-evidence')
def submit_evidence_form():
    """Evidence submission form"""
    return render_template('submit_evidence.html')

@app.route('/upload-evidence', methods=['POST'])
def upload_evidence():
    """Handle evidence file upload and processing initiation"""
    
    # Validate form data
    required_fields = ['case_id', 'evidence_type', 'investigator', 'description']
    for field in required_fields:
        if not request.form.get(field):
            flash(f'Error: {field} is required', 'error')
            return redirect(url_for('submit_evidence_form'))
    
    case_id = request.form['case_id']
    evidence_type = request.form['evidence_type']
    investigator = request.form['investigator']
    description = request.form['description']
    analysis_level = request.form.get('analysis_level', 'standard')
    urgent = request.form.get('urgent') == 'on'
    
    # Handle file upload
    if 'evidence_file' not in request.files:
        flash('Error: No file uploaded', 'error')
        return redirect(url_for('submit_evidence_form'))
    
    file = request.files['evidence_file']
    if file.filename == '':
        flash('Error: No file selected', 'error')
        return redirect(url_for('submit_evidence_form'))
    
    if not allowed_file(file.filename, evidence_type):
        flash(f'Error: File type not allowed for {evidence_type} evidence', 'error')
        return redirect(url_for('submit_evidence_form'))
    
    try:
        # Generate unique submission ID
        submission_id = str(uuid.uuid4())
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Create submission directory
        submission_dir = os.path.join(UPLOAD_FOLDER, f"{case_id}_{timestamp}_{submission_id}")
        os.makedirs(submission_dir, exist_ok=True)
        
        # Save uploaded file
        filename = secure_filename(file.filename)
        evidence_path = os.path.join(submission_dir, filename)
        file.save(evidence_path)
        
        # Calculate file hashes for integrity verification
        hashes = calculate_file_hash(evidence_path)
        
        # Create submission metadata
        metadata = {
            'submission_id': submission_id,
            'case_id': case_id,
            'evidence_type': evidence_type,
            'original_filename': file.filename,
            'stored_filename': filename,
            'evidence_path': evidence_path,
            'investigator': investigator,
            'description': description,
            'analysis_level': analysis_level,
            'urgent': urgent,
            'submission_time': datetime.datetime.now().isoformat(),
            'file_size': os.path.getsize(evidence_path),
            'hashes': hashes
        }
        
        # Save metadata
        metadata_path = os.path.join(submission_dir, 'metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        # Create IRIS case if it doesn't exist
        case_success, case_message = create_iris_case({
            'case_id': case_id,
            'investigator': investigator,
            'description': description
        })
        
        if not case_success:
            flash(f'Warning: {case_message}', 'warning')
        
        # Trigger appropriate Jenkins job based on evidence type
        job_mapping = {
            'disk': 'forensics-disk-analysis',
            'memory': 'forensics-memory-analysis',
            'mobile': 'forensics-mobile-analysis',
            'malware': 'forensics-malware-analysis'
        }
        
        job_name = job_mapping.get(evidence_type)
        if not job_name:
            flash(f'Error: Unknown evidence type: {evidence_type}', 'error')
            return redirect(url_for('submit_evidence_form'))
        
        # Jenkins job parameters
        jenkins_params = {
            'CASE_ID': case_id,
            'EVIDENCE_PATH': evidence_path,
            'INVESTIGATOR': investigator,
            'ANALYSIS_LEVEL': analysis_level,
            'URGENT': str(urgent).lower(),
            'SUBMISSION_ID': submission_id
        }
        
        # Trigger Jenkins job
        job_success, job_message = trigger_jenkins_job(job_name, jenkins_params)
        
        if job_success:
            flash(f'Evidence submitted successfully! Processing started for case {case_id}', 'success')
            return render_template('submission_success.html', 
                                   case_id=case_id, 
                                   submission_id=submission_id,
                                   evidence_type=evidence_type,
                                   hashes=hashes)
        else:
            flash(f'Evidence uploaded but processing failed to start: {job_message}', 'warning')
            return redirect(url_for('submit_evidence_form'))
            
    except Exception as e:
        flash(f'Error processing evidence submission: {str(e)}', 'error')
        return redirect(url_for('submit_evidence_form'))

@app.route('/case-status/<case_id>')
def case_status(case_id):
    """Show case processing status"""
    # TODO: Integrate with IRIS API to get real case status
    return render_template('case_status.html', case_id=case_id)

@app.route('/api/status')
def api_status():
    """API endpoint for system status"""
    try:
        # Check Jenkins connectivity
        jenkins_response = requests.get(f"{JENKINS_URL}/api/json", 
                                       auth=(JENKINS_USER, JENKINS_TOKEN),
                                       timeout=5)
        jenkins_status = jenkins_response.status_code == 200
    except:
        jenkins_status = False
    
    try:
        # Check IRIS connectivity
        iris_response = requests.get(f"{IRIS_API_URL}/ping", timeout=5, verify=False)
        iris_status = iris_response.status_code == 200
    except:
        iris_status = False
    
    return jsonify({
        'status': 'operational' if (jenkins_status and iris_status) else 'degraded',
        'jenkins': jenkins_status,
        'iris': iris_status,
        'timestamp': datetime.datetime.now().isoformat()
    })

@app.route('/api/submit', methods=['POST'])
def api_submit_evidence():
    """API endpoint for programmatic evidence submission"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['case_id', 'evidence_type', 'evidence_path', 'investigator']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Generate submission ID
        submission_id = str(uuid.uuid4())
        
        # Trigger Jenkins job
        job_mapping = {
            'disk': 'forensics-disk-analysis',
            'memory': 'forensics-memory-analysis', 
            'mobile': 'forensics-mobile-analysis',
            'malware': 'forensics-malware-analysis'
        }
        
        job_name = job_mapping.get(data['evidence_type'])
        if not job_name:
            return jsonify({'error': f'Invalid evidence type: {data["evidence_type"]}'}), 400
        
        jenkins_params = {
            'CASE_ID': data['case_id'],
            'EVIDENCE_PATH': data['evidence_path'],
            'INVESTIGATOR': data['investigator'],
            'ANALYSIS_LEVEL': data.get('analysis_level', 'standard'),
            'URGENT': str(data.get('urgent', False)).lower(),
            'SUBMISSION_ID': submission_id
        }
        
        job_success, job_message = trigger_jenkins_job(job_name, jenkins_params)
        
        if job_success:
            return jsonify({
                'success': True,
                'submission_id': submission_id,
                'message': 'Evidence processing started',
                'case_id': data['case_id']
            })
        else:
            return jsonify({'error': f'Failed to start processing: {job_message}'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
