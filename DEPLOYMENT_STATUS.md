# Digital Forensics Lab Deployment Status

## Current Service Status

### ✅ ACTIVE SERVICES

#### ELK Stack (Fully Operational)
- **Elasticsearch**: Port 9200, 9300
- **Kibana**: Port 5601
- **Logstash**: Port 5044, 5000, 9600
- **Status**: All services running and healthy

#### IRIS (Fully Operational)
- **NGINX**: Port 443 (HTTPS)
- **Database**: PostgreSQL (internal)
- **Worker**: Background processing
- **RabbitMQ**: Message queue (internal)
- **Status**: All containers running and healthy

### ⏸️ DISABLED SERVICES

#### MISP (Temporarily Stopped - Port Conflict)
- **Reason**: Port 443 conflict with IRIS
- **Configuration**: Ready for HTTP-only deployment on port 8080
- **Status**: Containers stopped, ready for redeployment
- **Next Steps**: Can be restarted with HTTP-only access

## Port Allocation

### In Use
- **443**: IRIS (HTTPS)
- **5601**: Kibana
- **9200**: Elasticsearch
- **9300**: Elasticsearch cluster
- **5044**: Logstash beats input
- **5000**: Logstash TCP input
- **9600**: Logstash monitoring

### Available for MISP
- **8080**: MISP HTTP (configured, not active)
- **8443**: MISP HTTPS (commented out due to conflict)

## Recommendations

### Port Conflict Resolution
1. **Keep IRIS on port 443** (primary case management system)
2. **Use MISP on port 8080** (HTTP-only for now)
3. **Future option**: Use different external IPs or load balancer for proper HTTPS separation

### Deployment Order
1. Deploy ELK stack first (no conflicts)
2. Deploy IRIS second (primary application)
3. Deploy MISP last with HTTP configuration

### Security Considerations
- IRIS has proper HTTPS with self-signed certificates
- MISP currently configured for HTTP only
- Consider proper SSL certificates for production use

## Updated Playbook Features

### IRIS Playbook Safety Improvements ✅
- **Selective Docker cleanup**: Only removes IRIS-specific containers
- **No system-wide Docker pruning**: Preserves other applications
- **Targeted removal**: Uses specific container names and image patterns
- **Safe for multi-application environments**

### MISP Playbook Configuration ✅
- **Official documentation patterns**: Uses .env file approach
- **Proper environment variables**: Includes all required variables like CRON_USER_ID
- **Docker volume management**: Uses named volumes instead of bind mounts
- **MISP modules included**: Enhanced functionality with modules container

## Access Information

### IRIS
- **URL**: https://10.128.0.19:443 (or external IP)
- **Username**: administrator
- **Password**: Check container logs for generated password
- **Status**: Ready for forensics case management

### ELK Stack
- **Kibana**: http://10.128.0.19:5601
- **Elasticsearch**: http://10.128.0.19:9200
- **Status**: Ready for log analysis and monitoring

### MISP (When Reactivated)
- **URL**: http://10.128.0.19:8080
- **Username**: admin@forensicslab.local
- **Password**: ForensicsAdmin2024!
- **Status**: Ready for redeployment without port conflicts

## Next Steps
1. Test IRIS functionality thoroughly
2. Verify ELK stack data ingestion
3. Plan MISP redeployment strategy (separate server or different ports)
4. Consider implementing reverse proxy for proper SSL termination
