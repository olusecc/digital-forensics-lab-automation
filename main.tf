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

  # One startup script reused by all VMs (escape shell ${} with $$)
  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -eu

    USERS="${var.user_formgt} ${var.user_fortools} ${var.user_formie}"

    # Cluster private key (from Terraform)
    read -r -d '' PRIV_KEY <<'EOF'
${tls_private_key.cluster.private_key_openssh}
EOF

    for U in $${USERS}; do
      HOME_DIR="/home/$${U}"
      SSH_DIR="$${HOME_DIR}/.ssh"
      install -d -m 700 -o "$${U}" -g "$${U}" "$${SSH_DIR}"

      # Write cluster key
      umask 177
      echo "$${PRIV_KEY}" > "$${SSH_DIR}/cluster_key"
      chown "$${U}:$${U}" "$${SSH_DIR}/cluster_key"
      chmod 600 "$${SSH_DIR}/cluster_key"

      # Prime known_hosts (placeholders; real keys learned on first connect)
      KH="$${SSH_DIR}/known_hosts"
      touch "$${KH}"
      chown "$${U}:$${U}" "$${KH}"
      chmod 644 "$${KH}"

      for H in formgt.lab.internal fortools.lab.internal formie.lab.internal; do
        if ! ssh-keygen -F "$${H}" -f "$${KH}" >/dev/null 2>&1; then
          echo "# $${H} placeholder — will be learned on first connection" >> "$${KH}"
        fi
      done
    done

    logger -t startup-script "Cluster key installed at ~/.ssh/cluster_key for users: $${USERS}"
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
