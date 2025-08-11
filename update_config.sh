#!/bin/bash

# Auto-update infrastructure configuration after VM restarts
# This script updates SSH configs and firewall rules when VM IPs change

set -e

echo "🔄 Checking VM IPs and updating configurations..."

# Get current VM IPs from Terraform
echo "Getting current VM IP addresses..."
VM_IPS_JSON=$(terraform output -json vm_ips)
FORMGT_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_formgt')
FORTOOLS_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_fortools') 
FORMIE_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_formie')

echo "Current VM IPs:"
echo "  formgt:   $FORMGT_IP"
echo "  fortools: $FORTOOLS_IP"
echo "  formie:   $FORMIE_IP"

# Update terraform.tfvars with current VM IPs
echo "📝 Updating terraform.tfvars with current VM IPs..."

# Create new tfvars content with current IPs
cat > terraform.tfvars << EOF
project_id = "devsecopsupanzi"

# Optional: override defaults
# region = "us-central1"
# zone   = "us-central1-a"

ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4r9yDAcE6C3LBW40A6ixY6u2RmBHdjH2mtLYbCUU42 olusec@oadewusi"

# Replace with YOUR current public IP in /32 form + VM IPs for inter-VM communication
ssh_source_ranges = [
  "41.186.112.90/32",      # Original allowed IP
  "41.216.98.178/32",      # Additional allowed IP
  "$FORMGT_IP/32",         # vm-formgt
  "$FORMIE_IP/32",         # vm-formie  
  "$FORTOOLS_IP/32"        # vm-fortools
]
EOF
echo "✅ Updated terraform.tfvars with current VM IPs"

# Update SSH config
echo "🔑 Updating SSH configuration..."
./setup_ssh_config.sh

# Clear old host keys
echo "🧹 Clearing old SSH host keys..."
ssh-keygen -f ~/.ssh/known_hosts -R "$FORMGT_IP" 2>/dev/null || true
ssh-keygen -f ~/.ssh/known_hosts -R "$FORTOOLS_IP" 2>/dev/null || true  
ssh-keygen -f ~/.ssh/known_hosts -R "$FORMIE_IP" 2>/dev/null || true

# Apply updated firewall rules
echo "🔥 Updating firewall rules with new VM IPs..."
if terraform plan -target=google_compute_firewall.allow_ssh | grep -q "will be updated"; then
    terraform apply -target=google_compute_firewall.allow_ssh -auto-approve
    echo "✅ Firewall rules updated"
else
    echo "ℹ️  Firewall rules already up to date"
fi

# Test connections
echo "🧪 Testing SSH connections..."
for alias in formgt-lab fortools-lab formie-lab; do
    if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new $alias "echo 'Connection to $alias successful'" 2>/dev/null; then
        echo "✅ $alias connection working"
    else
        echo "❌ $alias connection failed - may need manual SSH key setup"
    fi
done

echo ""
echo "🎯 Configuration update completed!"
echo ""
echo "If connections are still failing, run:"
echo "  ./create_users.sh    # Ensure users exist with proper permissions"
echo "  ./fix_ssh_keys.sh    # Reconfigure SSH keys"
echo ""
echo "Current connection commands:"
echo "  ssh formgt-lab       # $FORMGT_IP"
echo "  ssh fortools-lab     # $FORTOOLS_IP"  
echo "  ssh formie-lab       # $FORMIE_IP"
