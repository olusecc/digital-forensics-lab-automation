// Jenkins Pipeline Library for Digital Forensics Automation
// This library provides reusable functions for forensic evidence processing

def call(Map config) {
    pipeline {
        agent any
        
        parameters {
            string(name: 'CASE_ID', defaultValue: '', description: 'IRIS Case ID')
            string(name: 'EVIDENCE_TYPE', defaultValue: 'disk', description: 'Type of evidence: disk, memory, mobile, malware')
            string(name: 'EVIDENCE_PATH', defaultValue: '', description: 'Path to evidence file')
            string(name: 'INVESTIGATOR', defaultValue: '', description: 'Lead investigator name')
            booleanParam(name: 'URGENT', defaultValue: false, description: 'Mark as urgent/priority case')
            choice(name: 'ANALYSIS_LEVEL', choices: ['basic', 'standard', 'comprehensive'], description: 'Analysis depth')
        }
        
        environment {
            FORENSICS_WORKSPACE = "/var/lib/jenkins/forensics"
            IRIS_API_URL = "https://10.128.0.19:443/api"
            MISP_API_URL = "http://10.128.0.19:8080"
            ELK_URL = "http://10.128.0.19:9200"
            EVIDENCE_STORAGE = "/var/lib/jenkins/forensics/evidence"
            REPORT_OUTPUT = "/var/lib/jenkins/forensics/reports"
        }
        
        stages {
            stage('Initialization') {
                steps {
                    script {
                        // Initialize case in IRIS if not exists
                        def caseExists = irisCheckCase(params.CASE_ID)
                        if (!caseExists && params.CASE_ID) {
                            irisCreateCase(params.CASE_ID, params.INVESTIGATOR)
                        }
                        
                        // Create evidence tracking
                        forensicsInitEvidence(params.CASE_ID, params.EVIDENCE_TYPE, params.EVIDENCE_PATH)
                        
                        // Send notification
                        forensicsNotify("🔍 Started processing ${params.EVIDENCE_TYPE} evidence for case ${params.CASE_ID}")
                    }
                }
            }
            
            stage('Evidence Validation') {
                steps {
                    script {
                        // Validate evidence integrity
                        forensicsValidateEvidence(params.EVIDENCE_PATH)
                        
                        // Generate evidence metadata
                        forensicsGenerateMetadata(params.EVIDENCE_PATH, params.CASE_ID)
                        
                        // Log to ELK
                        elkLogEvent('evidence_validation', [
                            case_id: params.CASE_ID,
                            evidence_type: params.EVIDENCE_TYPE,
                            evidence_path: params.EVIDENCE_PATH,
                            investigator: params.INVESTIGATOR,
                            timestamp: new Date().format('yyyy-MM-dd HH:mm:ss')
                        ])
                    }
                }
            }
            
            stage('Evidence Processing') {
                parallel {
                    stage('Primary Analysis') {
                        steps {
                            script {
                                switch(params.EVIDENCE_TYPE) {
                                    case 'disk':
                                        forensicsProcessDiskImage(params.EVIDENCE_PATH, params.CASE_ID, params.ANALYSIS_LEVEL)
                                        break
                                    case 'memory':
                                        forensicsProcessMemoryDump(params.EVIDENCE_PATH, params.CASE_ID, params.ANALYSIS_LEVEL)
                                        break
                                    case 'mobile':
                                        forensicsProcessMobileData(params.EVIDENCE_PATH, params.CASE_ID, params.ANALYSIS_LEVEL)
                                        break
                                    case 'malware':
                                        forensicsProcessMalwareSample(params.EVIDENCE_PATH, params.CASE_ID, params.ANALYSIS_LEVEL)
                                        break
                                    default:
                                        error("Unsupported evidence type: ${params.EVIDENCE_TYPE}")
                                }
                            }
                        }
                    }
                    
                    stage('IOC Correlation') {
                        steps {
                            script {
                                // Extract and correlate IOCs with MISP
                                def iocs = forensicsExtractIOCs(params.EVIDENCE_PATH, params.EVIDENCE_TYPE)
                                def correlations = mispCorrelateIOCs(iocs)
                                
                                // Update IRIS with findings
                                if (correlations.size() > 0) {
                                    irisUpdateFindings(params.CASE_ID, correlations)
                                    forensicsNotify("⚠️ IOC matches found in case ${params.CASE_ID}: ${correlations.size()} indicators")
                                }
                            }
                        }
                    }
                }
            }
            
            stage('Report Generation') {
                steps {
                    script {
                        // Generate comprehensive forensic report
                        def reportPath = forensicsGenerateReport(params.CASE_ID, params.EVIDENCE_TYPE)
                        
                        // Update IRIS with report
                        irisAttachReport(params.CASE_ID, reportPath)
                        
                        // Archive report
                        archiveArtifacts artifacts: "reports/${params.CASE_ID}/*", fingerprint: true
                    }
                }
            }
        }
        
        post {
            success {
                script {
                    forensicsNotify("✅ Successfully completed processing ${params.EVIDENCE_TYPE} evidence for case ${params.CASE_ID}")
                    irisUpdateCaseStatus(params.CASE_ID, 'evidence_processed')
                }
            }
            failure {
                script {
                    forensicsNotify("❌ Failed to process ${params.EVIDENCE_TYPE} evidence for case ${params.CASE_ID}")
                    irisUpdateCaseStatus(params.CASE_ID, 'processing_failed')
                }
            }
            always {
                script {
                    // Clean up temporary files
                    forensicsCleanup(params.CASE_ID, params.EVIDENCE_TYPE)
                    
                    // Log completion to ELK
                    elkLogEvent('evidence_processing_complete', [
                        case_id: params.CASE_ID,
                        evidence_type: params.EVIDENCE_TYPE,
                        status: currentBuild.result ?: 'SUCCESS',
                        duration: currentBuild.durationString,
                        timestamp: new Date().format('yyyy-MM-dd HH:mm:ss')
                    ])
                }
            }
        }
    }
}
