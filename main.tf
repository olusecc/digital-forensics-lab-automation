# -----------------------------
# Networking
# -----------------------------
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = true
}

# Cluster keypair (shared for lab-only VM-to-VM SSH)
resource "tls_private_key" "cluster" {
  algorithm = "ED25519"
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  # Auto-mode VPC internal ranges
  source_ranges = ["10.128.0.0/9"]
  target_tags   = ["vm-internal"]
}

# -----------------------------
# Common image / disk defaults
# -----------------------------
locals {
  ubuntu_image_family = "ubuntu-2204-lts"
  ubuntu_image_proj   = "ubuntu-os-cloud"
  disk_type           = "pd-balanced"

  # Your laptop key (ssh_public_key) + shared cluster public key for each user
  ssh_metadata_block = join("\n", [
    "${var.user_formgt}:${var.ssh_public_key}",
    "${var.user_formgt}:${trimspace(tls_private_key.cluster.public_key_openssh)}",
    "${var.user_fortools}:${var.ssh_public_key}",
    "${var.user_fortools}:${trimspace(tls_private_key.cluster.public_key_openssh)}",
    "${var.user_formie}:${var.ssh_public_key}",
    "${var.user_formie}:${trimspace(tls_private_key.cluster.public_key_openssh)}",
  ])

  # Startup script:
  # - ensures users exist
  # - installs cluster private key into each user's ~/.ssh/cluster_key
  # - preps known_hosts placeholders for internal names
  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -e  # Remove -u to avoid issues with unset variables
    
    # Enable logging for debugging
    exec > >(logger -t startup-script) 2>&1
    echo "Starting cluster setup script..."

    USERS="${var.user_formgt} ${var.user_fortools} ${var.user_formie}"
    echo "Users to configure: $USERS"

    # Wait for cloud-init to finish creating users
    echo "Waiting for cloud-init to complete..."
    while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
      sleep 2
    done
    echo "Cloud-init completed"

    # Ensure olusecc user exists and has sudo access
    if ! id olusecc >/dev/null 2>&1; then
      useradd -m -s /bin/bash olusecc
      usermod -aG sudo olusecc
      echo "olusecc ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/olusecc
    fi

    # Ensure users exist (in case guest agent hasn't created them yet)
    for U in $USERS; do
      echo "Checking user: $U"
      if ! id -u "$U" >/dev/null 2>&1; then
        echo "Creating user: $U"
        useradd -m -s /bin/bash "$U"
        # Add to both sudo groups for compatibility
        usermod -aG sudo "$U"
        usermod -aG google-sudoers "$U" 2>/dev/null || echo "google-sudoers group not found, skipping"
        # Ensure passwordless sudo access
        echo "$U ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$U"
        chmod 440 "/etc/sudoers.d/$U"
        echo "User $U created successfully with sudo access"
      else
        echo "User $U already exists"
        # Ensure existing users have sudo access
        usermod -aG sudo "$U" 2>/dev/null || echo "Failed to add $U to sudo group"
        usermod -aG google-sudoers "$U" 2>/dev/null || echo "google-sudoers group not found"
        echo "$U ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$U"
        chmod 440 "/etc/sudoers.d/$U"
        echo "Updated sudo access for existing user $U"
      fi
    done

    # Create cluster private key content (avoiding read -d issues)
    cat > /tmp/cluster_key <<'EOF'
${tls_private_key.cluster.private_key_openssh}
EOF
    
    echo "Created temporary cluster key file"
    chmod 600 /tmp/cluster_key

    for U in $USERS; do
      echo "Configuring SSH for user: $U"
      HOME_DIR="/home/$U"
      SSH_DIR="$HOME_DIR/.ssh"
      
      # Ensure home directory exists
      if [ ! -d "$HOME_DIR" ]; then
        echo "Creating home directory for $U"
        mkdir -p "$HOME_DIR"
        chown "$U:$U" "$HOME_DIR"
        chmod 755 "$HOME_DIR"
      fi
      
      # Create SSH directory
      echo "Creating SSH directory for $U"
      mkdir -p "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      chown "$U:$U" "$SSH_DIR"

      # Install cluster key
      echo "Installing cluster key for $U"
      cp /tmp/cluster_key "$SSH_DIR/cluster_key"
      chown "$U:$U" "$SSH_DIR/cluster_key"
      chmod 600 "$SSH_DIR/cluster_key"

      # Create SSH config for easier connections
      cat > "$SSH_DIR/config" <<SSHEOF
Host *.lab.internal
    User $U
    IdentityFile ~/.ssh/cluster_key
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts
SSHEOF
      chown "$U:$U" "$SSH_DIR/config"
      chmod 644 "$SSH_DIR/config"

      # Prime known_hosts
      echo "Setting up known_hosts for $U"
      KH="$SSH_DIR/known_hosts"
      touch "$KH"
      chown "$U:$U" "$KH"
      chmod 644 "$KH"

      for H in formgt.lab.internal fortools.lab.internal formie.lab.internal; do
        if ! grep -q "$H" "$KH" 2>/dev/null; then
          echo "# $H placeholder — will be learned on first connection" >> "$KH"
        fi
      done
      
      echo "Completed SSH setup for user: $U"
    done

    # Clean up temporary file
    rm -f /tmp/cluster_key
    echo "Cluster key setup completed successfully for users: $USERS"
  EOT
}

# -----------------------------
# VM 1: formgt (60GB, 2 vCPU, 4GB) => e2-medium
# -----------------------------
resource "google_compute_instance" "vm1" {
  name         = "vm-formgt"
  machine_type = "e2-medium" # 2 vCPU, 4 GB

  tags = ["ssh", "vm-internal"]

  boot_disk {
    initialize_params {
      image = "${local.ubuntu_image_proj}/${local.ubuntu_image_family}"
      size  = 60
      type  = local.disk_type
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {} # ephemeral external IP
  }

  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = local.ssh_metadata_block
  }

  metadata_startup_script = local.startup_script
}

# -----------------------------
# VM 2: fortools (80GB, 2 vCPU, 4GB) => e2-medium
# -----------------------------
resource "google_compute_instance" "vm2" {
  name         = "vm-fortools"
  machine_type = "e2-medium"

  tags = ["ssh", "vm-internal"]

  boot_disk {
    initialize_params {
      image = "${local.ubuntu_image_proj}/${local.ubuntu_image_family}"
      size  = 80
      type  = local.disk_type
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {}
  }

  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = local.ssh_metadata_block
  }

  metadata_startup_script = local.startup_script
}

# -----------------------------
# VM 3: formie (100GB, 4 vCPU, 8GB) => e2-custom-4-8192
# -----------------------------
resource "google_compute_instance" "vm3" {
  name         = "vm-formie"
  machine_type = "e2-custom-4-8192" # 4 vCPU, 8 GB

  tags = ["ssh", "vm-internal"]

  boot_disk {
    initialize_params {
      image = "${local.ubuntu_image_proj}/${local.ubuntu_image_family}"
      size  = 100
      type  = local.disk_type
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {}
  }

  metadata = {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = local.ssh_metadata_block
  }

  metadata_startup_script = local.startup_script
}

# -----------------------------
# Enable required APIs
# -----------------------------
resource "google_project_service" "dns" {
  service = "dns.googleapis.com"

  disable_dependent_services = true
}

# -----------------------------
# Private Cloud DNS zone + records
# -----------------------------
resource "google_dns_managed_zone" "lab_internal" {
  name        = "lab-internal-zone"
  dns_name    = "lab.internal."
  description = "Private zone for lab VMs"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.self_link
    }
  }

  depends_on = [google_project_service.dns]
}

resource "google_dns_record_set" "a_formgt" {
  name         = "formgt.lab.internal."
  managed_zone = google_dns_managed_zone.lab_internal.name
  type         = "A"
  ttl          = 30
  rrdatas      = [google_compute_instance.vm1.network_interface[0].network_ip]
}

resource "google_dns_record_set" "a_fortools" {
  name         = "fortools.lab.internal."
  managed_zone = google_dns_managed_zone.lab_internal.name
  type         = "A"
  ttl          = 30
  rrdatas      = [google_compute_instance.vm2.network_interface[0].network_ip]
}

resource "google_dns_record_set" "a_formie" {
  name         = "formie.lab.internal."
  managed_zone = google_dns_managed_zone.lab_internal.name
  type         = "A"
  ttl          = 30
  rrdatas      = [google_compute_instance.vm3.network_interface[0].network_ip]
}
