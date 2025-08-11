#!/bin/bash

# Clean SSH config for VS Code compatibility
# Removes duplicates and creates clean configuration

set -e

echo "🧹 Cleaning SSH configuration for VS Code compatibility..."

# Backup existing config
cp ~/.ssh/config ~/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backed up existing SSH config"

# Get current VM IPs from Terraform
echo "🔍 Getting current VM IP addresses..."
VM_IPS_JSON=$(terraform output -json vm_ips)
FORMGT_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_formgt')
FORTOOLS_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_fortools') 
FORMIE_IP=$(echo "$VM_IPS_JSON" | jq -r '.vm_formie')

echo "Current VM IPs:"
echo "  formgt:   $FORMGT_IP"
echo "  fortools: $FORTOOLS_IP"
echo "  formie:   $FORMIE_IP"

# Create clean SSH config
cat > ~/.ssh/config << EOF
# Digital Forensics Lab - Clean SSH Configuration for VS Code
# Generated on $(date)

# Lab VM Aliases - Primary method for VS Code Remote SSH
Host formgt-lab
    HostName $FORMGT_IP
    User formgt
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

Host fortools-lab
    HostName $FORTOOLS_IP
    User fortools
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

Host formie-lab
    HostName $FORMIE_IP
    User formie
    IdentityFile ~/.ssh/gcp_olusec
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

# Global SSH settings for better VS Code compatibility
Host *
    AddKeysToAgent yes
    ForwardAgent no
    PasswordAuthentication no
    PubkeyAuthentication yes
    PreferredAuthentications publickey
    TCPKeepAlive yes
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 10m

EOF

echo "✅ Created clean SSH configuration"

# Verify SSH key exists
if [ ! -f ~/.ssh/gcp_olusec ]; then
    echo "❌ SSH key ~/.ssh/gcp_olusec not found!"
    echo "Available SSH keys:"
    ls -la ~/.ssh/*.pem ~/.ssh/*_rsa ~/.ssh/*ed25519* 2>/dev/null || echo "No SSH keys found"
    exit 1
fi

# Set proper permissions
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh
chmod 600 ~/.ssh/gcp_olusec

echo "✅ Set proper SSH permissions"

# Clear SSH control sockets (can interfere with VS Code)
rm -f ~/.ssh/control-* 2>/dev/null || true
echo "✅ Cleared SSH control sockets"

# Test connections
echo ""
echo "🧪 Testing SSH connections..."
for alias in formgt-lab fortools-lab formie-lab; do
    if timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=10 $alias "echo 'VS Code test: $alias connection successful'" 2>/dev/null; then
        echo "✅ $alias connection working"
    else
        echo "❌ $alias connection failed"
    fi
done

echo ""
echo "🎯 SSH configuration cleaned for VS Code compatibility!"
echo ""
echo "📋 Next steps for VS Code Remote SSH:"
echo "1. Open VS Code"
echo "2. Install 'Remote - SSH' extension if not already installed"
echo "3. Press Ctrl+Shift+P (or Cmd+Shift+P on Mac)"
echo "4. Type 'Remote-SSH: Connect to Host'"
echo "5. Select one of these hosts:"
echo "   - formgt-lab"
echo "   - fortools-lab" 
echo "   - formie-lab"
echo ""
echo "If VS Code still doesn't connect, check the Output panel:"
echo "View → Output → Select 'Remote-SSH' from dropdown"
