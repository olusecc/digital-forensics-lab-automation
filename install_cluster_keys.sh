#!/bin/bash

# Manual cluster key installation script
# Run this if the startup script fails to install cluster keys

set -e

echo "Installing cluster keys manually on all VMs..."

# Get the cluster private key
terraform output -raw cluster_private_key > /tmp/cluster_key
chmod 600 /tmp/cluster_key

# List of VMs and users
VMS="vm-formgt vm-fortools vm-formie"
USERS="formgt fortools formie"

for vm in $VMS; do
    echo "Installing cluster key on $vm..."
    
    for user in $USERS; do
        echo "  Installing for user $user..."
        
        # Create SSH directory
        gcloud compute ssh $vm --zone=us-central1-a --command="sudo mkdir -p /home/$user/.ssh && sudo chmod 700 /home/$user/.ssh && sudo chown $user:$user /home/$user/.ssh" || echo "    SSH directory setup failed for $user on $vm"
        
        # Copy cluster key
        gcloud compute scp /tmp/cluster_key $vm:/tmp/cluster_key_$user --zone=us-central1-a || echo "    Failed to copy key for $user to $vm"
        
        # Move and set permissions
        gcloud compute ssh $vm --zone=us-central1-a --command="sudo mv /tmp/cluster_key_$user /home/$user/.ssh/cluster_key && sudo chmod 600 /home/$user/.ssh/cluster_key && sudo chown $user:$user /home/$user/.ssh/cluster_key" || echo "    Failed to install key for $user on $vm"
        
        # Create SSH config
        gcloud compute ssh $vm --zone=us-central1-a --command="sudo tee /home/$user/.ssh/config > /dev/null <<EOF
Host *.lab.internal
    User $user
    IdentityFile ~/.ssh/cluster_key
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
EOF
sudo chown $user:$user /home/$user/.ssh/config
sudo chmod 644 /home/$user/.ssh/config" || echo "    Failed to create SSH config for $user on $vm"
    done
    
    echo "  Completed $vm"
done

# Clean up
rm -f /tmp/cluster_key

echo "Cluster key installation completed!"
echo ""
echo "You can now test VM-to-VM SSH with:"
echo "  ssh formgt@34.69.233.83  # (replace with actual IP)"
echo "  Then from inside the VM:"
echo "  ssh fortools@fortools.lab.internal"
echo ""
echo "Or use: terraform output internal_ssh_commands"
