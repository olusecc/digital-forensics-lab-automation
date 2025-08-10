# Digital Forensics Lab Automation

This Terraform configuration creates a complete digital forensics lab environment on Google Cloud Platform with three VMs that can communicate with each other using internal hostnames.

## Infrastructure

- **3 Virtual Machines**:
  - `vm-formgt`: 60GB disk, 2 vCPU, 4GB RAM (e2-medium)
  - `vm-fortools`: 80GB disk, 2 vCPU, 4GB RAM (e2-medium)
  - `vm-formie`: 100GB disk, 4 vCPU, 8GB RAM (e2-custom-4-8192)

- **Networking**:
  - Private VPC network (`vpc-ansible`)
  - Internal DNS zone (`lab.internal`)
  - Firewall rules for SSH and internal communication

- **Users**: Each VM has three users:
  - `formgt`
  - `fortools` 
  - `formie`

## Setup

1. **Prerequisites**:
   ```bash
   # Install required tools
   sudo apt update
   sudo apt install terraform google-cloud-sdk

   # Authenticate with Google Cloud
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Configure variables**:
   Edit `terraform.tfvars` with your project details:
   ```hcl
   project_id = "your-gcp-project-id"
   ssh_public_key = "your-ssh-public-key"
   ssh_source_ranges = ["your.ip.address/32"]
   ```

3. **Deploy the infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```

## VM-to-VM Communication

The infrastructure includes automatic setup for seamless VM-to-VM SSH communication:

### Automatic Setup Features

- **Cluster SSH Keys**: Each VM has a shared private key (`~/.ssh/cluster_key`) for inter-VM communication
- **DNS Resolution**: VMs can reach each other using hostnames:
  - `formgt.lab.internal`
  - `fortools.lab.internal`
  - `formie.lab.internal`
- **SSH Configuration**: Pre-configured SSH settings for easy connections

### Usage Examples

1. **Connect to a VM from your laptop**:
   ```bash
   # Get connection commands
   terraform output ssh_commands
   
   # Connect (example)
   ssh -i ~/.ssh/gcp_olusec formgt@<external-ip>
   ```

2. **VM-to-VM SSH (from inside any VM)**:
   ```bash
   # These commands work from any VM to any other VM
   ssh fortools@fortools.lab.internal
   ssh formie@formie.lab.internal
   ssh formgt@formgt.lab.internal
   ```

3. **Verify the setup**:
   ```bash
   # Check cluster key exists
   ls -la ~/.ssh/cluster_key
   
   # Test DNS resolution
   nslookup formgt.lab.internal
   nslookup fortools.lab.internal
   nslookup formie.lab.internal
   
   # View SSH config
   cat ~/.ssh/config
   ```

## Troubleshooting

### If cluster keys are missing:

1. **Check startup script logs**:
   ```bash
   sudo journalctl -u google-startup-scripts.service
   ```

2. **Manual installation**:
   ```bash
   # Run the manual installation script
   ./install_cluster_keys.sh
   ```

3. **Verify setup**:
   ```bash
   terraform output setup_verification
   ```

### Common Issues

- **SSH Key Authentication**: Ensure your SSH public key is correctly set in `terraform.tfvars`
- **Firewall**: Verify your IP address is in `ssh_source_ranges`
- **DNS**: If hostnames don't resolve, wait a few minutes for DNS propagation

## Useful Commands

```bash
# View all output information
terraform output

# Get cluster private key (for manual installation)
terraform output -raw cluster_private_key

# View VM-to-VM SSH commands
terraform output internal_ssh_commands

# Check VM status
gcloud compute instances list

# Connect via gcloud (alternative method)
gcloud compute ssh vm-formgt --zone=us-central1-a
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy -auto-approve
```

## Files

- `main.tf`: Main infrastructure configuration
- `variables.tf`: Variable definitions
- `outputs.tf`: Output values
- `providers.tf`: Provider configuration
- `terraform.tfvars`: Your specific configuration values
- `install_cluster_keys.sh`: Manual cluster key installation script
- `README.md`: This documentation

## Security Notes

- SSH access is restricted to IPs in `ssh_source_ranges`
- Cluster keys are for lab-internal use only
- Project SSH keys are blocked on VMs
- Each user has isolated SSH configurations
