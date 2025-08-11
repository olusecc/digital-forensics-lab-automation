#!/bin/bash

# Create forensics users on all VMs
# This script creates the formgt, fortools, and formie users

set -e

echo "Creating forensics users on all VMs..."

VMS="vm-formgt vm-fortools vm-formie"
USERS="formgt fortools formie"

for vm in $VMS; do
    echo "Creating users on $vm..."
    
    gcloud compute ssh $vm --zone=us-central1-a --command="
        # Create all forensics users
        for user in $USERS; do
            if ! id \$user >/dev/null 2>&1; then
                echo 'Creating user: '\$user
                sudo useradd -m -s /bin/bash \$user
                sudo usermod -aG sudo \$user
                sudo usermod -aG google-sudoers \$user 2>/dev/null || echo 'google-sudoers group not found'
                echo '\$user ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/\$user > /dev/null
                echo 'User '\$user' created successfully'
            else
                echo 'User '\$user' already exists'
            fi
        done
        
        echo 'User creation completed on $vm'
    " || echo "Failed to create users on $vm"
    
    echo "Completed user creation on $vm"
done

echo ""
echo "User creation completed on all VMs!"
echo ""
echo "Now running SSH key setup..."

# Now run the SSH key setup
./fix_ssh_keys.sh
