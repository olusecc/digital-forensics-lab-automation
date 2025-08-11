#!/bin/bash

# Digital Forensics Lab Health Check
# Verifies VM status, connectivity, and user configuration

set -e

echo "🔍 Digital Forensics Lab Health Check"
echo "===================================="
echo ""

# Function to print status with emoji
print_status() {
    if [ "$2" = "OK" ]; then
        echo "✅ $1"
    elif [ "$2" = "WARN" ]; then
        echo "⚠️  $1"
    else
        echo "❌ $1"
    fi
}

# Check VM status
echo "📊 VM Status Check:"
VMS_RUNNING=$(gcloud compute instances list --filter='name~vm-.*' --format='value(status)' | grep -c "RUNNING" || echo "0")
TOTAL_VMS=$(gcloud compute instances list --filter='name~vm-.*' --format='value(name)' | wc -l)

if [ "$VMS_RUNNING" = "$TOTAL_VMS" ] && [ "$TOTAL_VMS" = "3" ]; then
    print_status "All VMs running ($VMS_RUNNING/$TOTAL_VMS)" "OK"
else
    print_status "VMs not all running ($VMS_RUNNING/$TOTAL_VMS)" "FAIL"
fi

# Check current IPs
echo ""
echo "🌐 Current VM IP Addresses:"
terraform output vm_ips

echo ""
echo "🔑 SSH Connectivity Test:"

# Test SSH connections
CONNECTED=0
for alias in formgt-lab fortools-lab formie-lab; do
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes $alias "echo 'OK'" 2>/dev/null | grep -q "OK"; then
        print_status "$alias connection" "OK"
        CONNECTED=$((CONNECTED + 1))
    else
        print_status "$alias connection" "FAIL"
    fi
done

# Check user existence on VMs
echo ""
echo "👥 User Configuration Check:"
for vm in vm-formgt vm-fortools vm-formie; do
    echo "  Checking users on $vm:"
    USERS_EXIST=$(gcloud compute ssh $vm --zone=us-central1-a --command="id formgt && id fortools && id formie && id olusecc" 2>/dev/null | grep -c "uid=" || echo "0")
    if [ "$USERS_EXIST" = "4" ]; then
        print_status "  All users exist on $vm" "OK"
    else
        print_status "  Missing users on $vm ($USERS_EXIST/4)" "FAIL"
    fi
done

# Check DNS resolution
echo ""
echo "🌍 DNS Resolution Check:"
DNS_OK=0
for vm in vm-formgt vm-fortools vm-formie; do
    DNS_WORKING=$(gcloud compute ssh $vm --zone=us-central1-a --command="nslookup formgt.lab.internal && nslookup fortools.lab.internal && nslookup formie.lab.internal" 2>/dev/null | grep -c "Address:" || echo "0")
    if [ "$DNS_WORKING" -ge "3" ]; then
        print_status "DNS resolution on $vm" "OK"
        DNS_OK=$((DNS_OK + 1))
    else
        print_status "DNS resolution on $vm" "FAIL"
    fi
done

# Overall health summary
echo ""
echo "📋 Health Summary:"
echo "=================="

if [ "$VMS_RUNNING" = "3" ] && [ "$CONNECTED" = "3" ] && [ "$DNS_OK" = "3" ]; then
    print_status "Lab Status: HEALTHY - All systems operational" "OK"
    echo ""
    echo "🎯 Lab is ready for digital forensics work!"
    echo ""
    echo "Quick Start Commands:"
    echo "  ssh formgt-lab     # Management/Jenkins VM"
    echo "  ssh fortools-lab   # Analysis tools VM"
    echo "  ssh formie-lab     # Evidence/ELK/MISP VM"
    echo ""
    echo "VS Code Remote SSH: Use aliases formgt-lab, fortools-lab, formie-lab"
    
elif [ "$VMS_RUNNING" = "3" ] && [ "$CONNECTED" -lt "3" ]; then
    print_status "Lab Status: PARTIAL - VMs running but SSH issues" "WARN"
    echo ""
    echo "🔧 Suggested fixes:"
    echo "  ./update_config.sh   # Update IPs and configs"
    echo "  ./create_users.sh    # Ensure users exist"
    echo "  ./fix_ssh_keys.sh    # Fix SSH key configuration"
    
else
    print_status "Lab Status: UNHEALTHY - Infrastructure issues" "FAIL"
    echo ""
    echo "🚨 Critical issues detected:"
    echo "  • Check VM status: gcloud compute instances list"
    echo "  • Restart VMs if needed: terraform apply"
    echo "  • Run health check again: ./health_check.sh"
fi

echo ""
echo "📅 Health check completed at $(date)"
