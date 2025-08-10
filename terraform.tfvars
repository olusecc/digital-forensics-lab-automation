project_id = "devsecopsupanzi"

# Optional: override defaults
# region = "us-central1"
# zone   = "us-central1-a"

ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII4r9yDAcE6C3LBW40A6ixY6u2RmBHdjH2mtLYbCUU42 olusec@oadewusi"

# Replace with YOUR current public IP in /32 form + VM IPs for inter-VM communication
ssh_source_ranges = [
  "41.186.112.90/32",      # Original allowed IP
  "34.136.254.74/32",      # vm-formgt
  "34.123.164.154/32",     # vm-formie  
  "34.173.123.123/32"      # vm-fortools
]