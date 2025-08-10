#!/bin/bash

# Fix SSH keys for all users on all VMs
# This script sets up both your personal SSH key and the cluster key

set -e

echo "Setting up SSH keys for all users on all VMs..."

# Your personal public key
PERSONAL_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4r9yDAcE6C3LBW40A6ixY6u2RmBHdjH2mtLYbCUU42 olusec@oadewusi"

# Get cluster public key
CLUSTER_KEY=$(terraform output -raw cluster_private_key | ssh-keygen -y -f /dev/stdin)

echo "Personal key: $PERSONAL_KEY"
echo "Cluster key: $CLUSTER_KEY"

# List of VMs and users
VMS="vm-formgt vm-fortools vm-formie"
USERS="formgt fortools formie"

for vm in $VMS; do
    echo "Configuring SSH keys on $vm..."
    
    for user in $USERS; do
        echo "  Setting up keys for user $user..."
        
        # Create authorized_keys with both personal and cluster keys
        gcloud compute ssh $vm --zone=us-central1-a --command="
            sudo mkdir -p /home/$user/.ssh
            sudo chmod 700 /home/$user/.ssh
            sudo chown $user:$user /home/$user/.ssh
            
            # Create authorized_keys with both keys
            echo '$PERSONAL_KEY' | sudo tee /home/$user/.ssh/authorized_keys > /dev/null
            echo '$CLUSTER_KEY' | sudo tee -a /home/$user/.ssh/authorized_keys > /dev/null
            
            sudo chown $user:$user /home/$user/.ssh/authorized_keys
            sudo chmod 600 /home/$user/.ssh/authorized_keys
            
            echo 'Keys configured for $user on $vm'
        " || echo "    Failed to configure keys for $user on $vm"
    done
    
    echo "  Completed $vm"
done

echo ""
echo "SSH key setup completed!"
echo ""
echo "You can now:"
echo "1. Connect from your laptop: ssh formgt-lab"
echo "2. Connect VM-to-VM: ssh fortools@fortools.lab.internal"
echo ""
echo "Testing connections..."

# Test connections
for alias in formgt-lab fortools-lab formie-lab; do
    if ssh -o ConnectTimeout=5 $alias "echo 'Connection to $alias successful'" 2>/dev/null; then
        echo "✅ $alias connection working"
    else
        echo "❌ $alias connection failed"
    fi
done
