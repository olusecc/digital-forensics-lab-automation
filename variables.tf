variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "vpc-ansible"
}

variable "ssh_public_key" {
  description = "Your full OpenSSH public key line"
  type        = string
}

variable "ssh_source_ranges" {
  description = "CIDRs allowed to SSH"
  type        = list(string)
  # Set to your /32 in terraform.tfvars; keep 0.0.0.0/0 only for testing
  default = ["0.0.0.0/0"]
}

variable "user_formgt" {
  type    = string
  default = "olusecc"  # Updated to match Ansible inventory user
}

variable "user_fortools" {
  type    = string
  default = "olusecc"  # Updated to match Ansible inventory user
}

variable "user_formie" {
  type    = string
  default = "olusecc"  # Updated to match Ansible inventory user
}
