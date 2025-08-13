# Missing Forensic Tool Integrations

## 1. CAPE Sandbox (Malware Analysis)
- **Installation**: Not deployed yet
- **Integration**: No automated sample submission
- **Output Processing**: No Logstash parser for CAPE JSON
- **API Integration**: Missing Jenkins pipeline for malware analysis

## 2. Guymager (Disk Imaging)
- **Installation**: Missing from forensics tools playbook
- **Integration**: No automated disk imaging workflow
- **Evidence Chain**: No integration with IRIS case management

## 3. Advanced Sleuth Kit Integration
- **Timeline Generation**: No automated timeline creation
- **File System Analysis**: Basic processing only
- **Hash Databases**: No NSRL/known file filtering

## 4. Yara Rule Integration
- **Rule Management**: No centralized Yara rule repository
- **Scanning Integration**: No automated Yara scanning in pipelines
- **Custom Rules**: No interface for forensic analysts to add rules

## 5. Additional Missing Tools
- **Bulk Extractor**: Not integrated
- **RegRipper**: Windows registry analysis missing
- **Log2timeline/Plaso**: Advanced timeline analysis missing
- **Rekall**: Alternative memory analysis framework missing
