// IRIS API Integration Functions for Jenkins
// Provides seamless integration with DFIR-IRIS case management system

def checkCase(String caseId) {
    script {
        def response = httpRequest(
            url: "${env.IRIS_API_URL}/case/${caseId}",
            httpMode: 'GET',
            authentication: 'iris-api-key',
            validResponseCodes: '200,404'
        )
        return response.status == 200
    }
}

def createCase(String caseId, String investigator, String description = '') {
    script {
        def caseData = [
            case_name: "Forensic Investigation ${caseId}",
            case_description: description ?: "Automated forensic analysis case",
            case_customer: 1, // Default customer ID
            case_classification: 2, // Internal classification
            case_user: investigator,
            case_tags: ["automated", "jenkins", "forensics"]
        ]
        
        def response = httpRequest(
            url: "${env.IRIS_API_URL}/case/add",
            httpMode: 'POST',
            authentication: 'iris-api-key',
            contentType: 'APPLICATION_JSON',
            requestBody: groovy.json.JsonBuilder(caseData).toString()
        )
        
        if (response.status == 200) {
            echo "✅ Created IRIS case: ${caseId}"
            return readJSON(text: response.content)
        } else {
            error("Failed to create IRIS case: ${response.status}")
        }
    }
}

def addEvidence(String caseId, String evidenceType, String evidencePath, Map metadata = [:]) {
    script {
        def evidenceData = [
            filename: evidencePath.split('/').last(),
            file_original_name: evidencePath.split('/').last(),
            file_description: "Evidence file: ${evidenceType}",
            file_tags: [evidenceType, "automated"],
            case_id: caseId
        ] + metadata
        
        def response = httpRequest(
            url: "${env.IRIS_API_URL}/case/evidences/add",
            httpMode: 'POST',
            authentication: 'iris-api-key',
            contentType: 'APPLICATION_JSON',
            requestBody: groovy.json.JsonBuilder(evidenceData).toString()
        )
        
        if (response.status == 200) {
            echo "✅ Added evidence to IRIS case ${caseId}"
            return readJSON(text: response.content)
        } else {
            error("Failed to add evidence to IRIS: ${response.status}")
        }
    }
}

def updateFindings(String caseId, List findings) {
    script {
        findings.each { finding ->
            def noteData = [
                note_title: "Automated Finding: ${finding.type}",
                note_content: finding.description,
                note_tags: ["automated", "ioc", finding.type],
                case_id: caseId
            ]
            
            httpRequest(
                url: "${env.IRIS_API_URL}/case/notes/add",
                httpMode: 'POST',
                authentication: 'iris-api-key',
                contentType: 'APPLICATION_JSON',
                requestBody: groovy.json.JsonBuilder(noteData).toString()
            )
        }
        echo "✅ Updated IRIS case ${caseId} with ${findings.size()} findings"
    }
}

def addTimeline(String caseId, List timelineEvents) {
    script {
        timelineEvents.each { event ->
            def timelineData = [
                event_title: event.title,
                event_content: event.description,
                event_date: event.timestamp,
                event_tags: event.tags ?: ["automated"],
                case_id: caseId
            ]
            
            httpRequest(
                url: "${env.IRIS_API_URL}/case/timeline/events/add",
                httpMode: 'POST',
                authentication: 'iris-api-key',
                contentType: 'APPLICATION_JSON',
                requestBody: groovy.json.JsonBuilder(timelineData).toString()
            )
        }
        echo "✅ Added ${timelineEvents.size()} timeline events to IRIS case ${caseId}"
    }
}

def attachReport(String caseId, String reportPath) {
    script {
        // Read report file and encode
        def reportContent = readFile(reportPath)
        def encodedContent = reportContent.bytes.encodeBase64().toString()
        
        def reportData = [
            filename: reportPath.split('/').last(),
            file_content: encodedContent,
            file_description: "Automated forensic analysis report",
            file_tags: ["report", "automated", "forensics"],
            case_id: caseId
        ]
        
        def response = httpRequest(
            url: "${env.IRIS_API_URL}/case/evidences/add",
            httpMode: 'POST',
            authentication: 'iris-api-key',
            contentType: 'APPLICATION_JSON',
            requestBody: groovy.json.JsonBuilder(reportData).toString()
        )
        
        if (response.status == 200) {
            echo "✅ Attached report to IRIS case ${caseId}"
        } else {
            error("Failed to attach report to IRIS: ${response.status}")
        }
    }
}

def updateCaseStatus(String caseId, String status) {
    script {
        def statusMap = [
            'evidence_received': 1,
            'evidence_processed': 2,
            'analysis_complete': 3,
            'report_generated': 4,
            'processing_failed': 99
        ]
        
        def statusData = [
            case_status_id: statusMap[status] ?: 1,
            case_id: caseId
        ]
        
        httpRequest(
            url: "${env.IRIS_API_URL}/case/update",
            httpMode: 'POST',
            authentication: 'iris-api-key',
            contentType: 'APPLICATION_JSON',
            requestBody: groovy.json.JsonBuilder(statusData).toString()
        )
        
        echo "✅ Updated IRIS case ${caseId} status to: ${status}"
    }
}

def addIOCs(String caseId, List iocs) {
    script {
        iocs.each { ioc ->
            def iocData = [
                ioc_value: ioc.value,
                ioc_type_id: getIOCTypeId(ioc.type),
                ioc_description: ioc.description ?: "Automatically extracted IOC",
                ioc_tags: ["automated", "extracted"],
                case_id: caseId
            ]
            
            httpRequest(
                url: "${env.IRIS_API_URL}/case/ioc/add",
                httpMode: 'POST',
                authentication: 'iris-api-key',
                contentType: 'APPLICATION_JSON',
                requestBody: groovy.json.JsonBuilder(iocData).toString()
            )
        }
        echo "✅ Added ${iocs.size()} IOCs to IRIS case ${caseId}"
    }
}

def getIOCTypeId(String iocType) {
    def typeMap = [
        'ip': 1,
        'domain': 2,
        'url': 3,
        'file_hash': 4,
        'email': 5,
        'filename': 6,
        'registry_key': 7,
        'process': 8
    ]
    return typeMap[iocType] ?: 4 // Default to file_hash
}
