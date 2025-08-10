#!/bin/bash

# Script to add SSH config entries for easy VS Code connection

echo "Setting up SSH config for VS Code connection..."

# Get current VM IPs from terraform
FORMGT_IP=$(terraform output -json vm_ips | jq -r '.vm_formgt')
FORTOOLS_IP=$(terraform output -json vm_ips | jq -r '.vm_fortools')
FORMIE_IP=$(terraform output -json vm_ips | jq -r '.vm_formie')

# Backup existing SSH config if it exists
if [ -f ~/.ssh/config ]; then
    cp ~/.ssh/config ~/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)
    echo "Backed up existing SSH config"
fi

# Create or append to SSH config
cat >> ~/.ssh/config << EOF

# Digital Forensics Lab VMs - Auto-generated $(date)
Host formgt-lab
    HostName $FORMGT_IP
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts

Host fortools-lab
    HostName $FORTOOLS_IP
    User fortools
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts

Host formie-lab
    HostName $FORMIE_IP
    User formie
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts

# Alternative entries with IPs (in case hostnames change)
Host formgt-vm
    HostName $FORMGT_IP
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no

Host fortools-vm
    HostName $FORTOOLS_IP
    User fortools
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no

Host formie-vm
    HostName $FORMIE_IP
    User formie
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no

EOF

echo "SSH config updated successfully!"
echo ""
echo "You can now connect using:"
echo "  ssh formgt-lab     # Connect to formgt VM"
echo "  ssh fortools-lab   # Connect to fortools VM"
echo "  ssh formie-lab     # Connect to formie VM"
echo ""
echo "Or in VS Code Remote SSH extension, use:"
echo "  formgt-lab"
echo "  fortools-lab"
echo "  formie-lab"
echo ""
echo "Current VM IPs:"
echo "  formgt:   $FORMGT_IP"
echo "  fortools: $FORTOOLS_IP"
echo "  formie:   $FORMIE_IP"
