#!/bin/bash
# Setup user accounts and final configuration

echo "🔐 Setting up user accounts and final configuration..."

# Jenkins user setup
echo "Configuring Jenkins users..."

# Create Jenkins users configuration
ansible management -i ../inventory.yml -m copy -b -a "
content='<?xml version=\"1.1\" encoding=\"UTF-8\"?>
<hudson.security.HudsonPrivateSecurityRealm_-Details>
  <users>
    <hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
      <username>admin</username>
      <password>{bcrypt}$2a$10$7apneHlDfHU4DdtNRmWLy.9N3W2IpF/F8dQ4OGFCXl7WW8F8H7zTe</password>
      <fullName>Lab Administrator</fullName>
      <emailAddress>admin@forensicslab.local</emailAddress>
    </hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
    <hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
      <username>investigator</username>
      <password>{bcrypt}$2a$10$7apneHlDfHU4DdtNRmWLy.9N3W2IpF/F8dQ4OGFCXl7WW8F8H7zTe</password>
      <fullName>Lead Investigator</fullName>
      <emailAddress>investigator@forensicslab.local</emailAddress>
    </hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
    <hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
      <username>analyst</username>
      <password>{bcrypt}$2a$10$7apneHlDfHU4DdtNRmWLy.9N3W2IpF/F8dQ4OGFCXl7WW8F8H7zTe</password>
      <fullName>Forensic Analyst</fullName>
      <emailAddress>analyst@forensicslab.local</emailAddress>
    </hudson.security.HudsonPrivateSecurityRealm_-Details_-User>
  </users>
</hudson.security.HudsonPrivateSecurityRealm_-Details>'
dest=/var/lib/jenkins/users/users.xml
owner=jenkins
group=jenkins
"

# Restart Jenkins to apply changes
ansible management -i ../inventory.yml -m systemd -a "name=jenkins state=restarted" -b

echo "✅ Jenkins users configured (Password: ForensicsLab2024!)"

# System maintenance scripts
echo "Creating maintenance scripts..."

# Elasticsearch maintenance
ansible data_services -i ../inventory.yml -m copy -b -a "
content='#!/bin/bash
# Elasticsearch maintenance script

echo \"Running Elasticsearch maintenance...\"

# Delete old indices (older than 90 days)
curl -X DELETE \"localhost:9200/forensics-*-$(date -d \"90 days ago\" +%Y.%m.%d)\"

# Force merge old indices for better performance
for index in \$(curl -s \"localhost:9200/_cat/indices/forensics-*\" | awk \"\\$3 ~ /^forensics-.*$(date -d \"7 days ago\" +%Y.%m)/ {print \\$3}\"); do
    curl -X POST \"localhost:9200/\$index/_forcemerge?max_num_segments=1\"
done

# Clean up snapshots older than 30 days
# (Add snapshot cleanup commands here when backup is configured)

echo \"Elasticsearch maintenance completed\"
'
dest=/opt/scripts/elasticsearch_maintenance.sh
mode=0755
"

# Log rotation setup
ansible all -i ../inventory.yml -m copy -b -a "
content='/var/log/forensics/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/opt/elk/elasticsearch/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}

/var/lib/jenkins/jobs/*/builds/*/log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
'
dest=/etc/logrotate.d/forensics-lab
"

# Create startup script
ansible all -i ../inventory.yml -m copy -b -a "
content='#!/bin/bash
# Forensics Lab startup script

echo \"Starting Digital Forensics Lab services...\"

# Start Docker services
systemctl start docker

# Start ELK stack
if [ -f /opt/elk/docker-compose.yml ]; then
    cd /opt/elk && docker-compose up -d
fi

# Start MISP
if [ -f /opt/misp/docker-compose.yml ]; then
    cd /opt/misp && docker-compose up -d
fi

# Start IRIS
if [ -f /opt/iris/docker-compose.yml ]; then
    cd /opt/iris && docker-compose up -d
fi

# Start Jenkins
systemctl start jenkins

# Start ElastAlert
systemctl start elastalert

# Start NFS (on forensics server)
if [ -f /etc/exports ]; then
    systemctl start nfs-kernel-server
    exportfs -ra
fi

echo \"All services started. Lab is ready for use.\"

# Display status
echo \"\"
echo \"Service Status:\"
docker ps --format \"table {{.Names}}\\t{{.Status}}\"
systemctl is-active jenkins || echo \"Jenkins: Not running\"
systemctl is-active elastalert || echo \"ElastAlert: Not running\"
'
dest=/opt/scripts/start_lab.sh
mode=0755
"

echo "✅ Maintenance and startup scripts created"

# Final system checks
echo "Performing final system checks..."

# Check disk space
echo "Disk space check:"
ansible all -i ../inventory.yml -m shell -a "df -h | grep -E '(Filesystem|/data|/$)'"

# Check memory usage
echo ""
echo "Memory usage check:"
ansible all -i ../inventory.yml -m shell -a "free -h"

# Check service status
echo ""
echo "Service status check:"
ansible data_services -i ../inventory.yml -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}'"

echo ""
echo "✅ Final configuration completed!"
echo ""
echo "🎉 DIGITAL FORENSICS LAB DEPLOYMENT COMPLETE!"
echo "=============================================="