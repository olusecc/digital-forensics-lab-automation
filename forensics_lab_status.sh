#!/bin/bash

echo "=== Digital Forensics Lab Status Check ==="
echo ""

# Check fortools (VM-1: CAPE Sandbox, Sleuth Kit, Volatility3, Andriller, Guymager)
echo "=== FORTOOLS SERVER STATUS ==="
echo "Checking CAPE Sandbox installation..."
if [ -d "/opt/CAPEv2" ]; then
    echo "✓ CAPE Sandbox: Installed at /opt/CAPEv2"
    if [ -x "/opt/CAPEv2/run_cape.sh" ]; then
        echo "✓ CAPE Run Script: Available and executable"
    else
        echo "✗ CAPE Run Script: Missing or not executable"
    fi
    if systemctl is-enabled cape.service >/dev/null 2>&1; then
        echo "✓ CAPE Service: Configured"
        if systemctl is-active cape.service >/dev/null 2>&1; then
            echo "✓ CAPE Service: Running"
        else
            echo "! CAPE Service: Stopped (normal for testing)"
        fi
    else
        echo "✗ CAPE Service: Not configured"
    fi
else
    echo "✗ CAPE Sandbox: Not installed"
fi

echo ""
echo "Checking Sleuth Kit installation..."
if command -v fls >/dev/null 2>&1; then
    echo "✓ Sleuth Kit: $(fls -V 2>&1 | head -1)"
else
    echo "✗ Sleuth Kit: Not installed or not in PATH"
fi

echo ""
echo "Checking Volatility3 installation..."
if command -v vol >/dev/null 2>&1; then
    echo "✓ Volatility3: $(vol --version 2>&1 | head -1)"
else
    echo "✗ Volatility3: Not installed or not in PATH"
fi

echo ""
echo "Checking Andriller installation..."
if command -v andriller >/dev/null 2>&1; then
    echo "✓ Andriller: $(andriller --version 2>&1 | head -1)"
else
    echo "✗ Andriller: Not installed or not in PATH"
fi

echo ""
echo "Checking Guymager installation..."
if command -v guymager >/dev/null 2>&1; then
    echo "✓ Guymager: Available"
else
    echo "✗ Guymager: Not installed or not in PATH"
fi

echo ""
echo "=== STORAGE AND NETWORK ==="
echo "Checking NFS shared storage..."
if mount | grep -q "nfs"; then
    echo "✓ NFS Mounts:"
    mount | grep nfs | while read line; do
        echo "  $line"
    done
else
    echo "! NFS: No NFS mounts found"
fi

echo ""
echo "Checking network connectivity..."
ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "✓ Internet: Connected" || echo "✗ Internet: Not connected"

echo ""
echo "=== SYSTEM RESOURCES ==="
echo "Memory Usage:"
free -h | grep -E "Mem:|Swap:"

echo ""
echo "Disk Usage:"
df -h | grep -E "/$|/opt|/var"

echo ""
echo "=== PROCESS STATUS ==="
echo "CAPE-related processes:"
ps aux | grep -E "(cape|cuckoo)" | grep -v grep || echo "No CAPE processes running"

echo ""
echo "=== LOG CHECK ==="
echo "Recent CAPE logs (if any):"
if [ -f "/opt/CAPEv2/log/cuckoo.log" ]; then
    tail -5 /opt/CAPEv2/log/cuckoo.log 2>/dev/null || echo "No recent CAPE logs"
else
    echo "CAPE log file not found"
fi

echo ""
echo "=== CONCLUSION ==="
echo "Forensics lab status check completed."
echo "Note: This is fortools server (CAPE Sandbox + core forensics tools)"
echo "For complete lab status, run this script on formie (ELK+MISP) and formgt (Jenkins) servers."
