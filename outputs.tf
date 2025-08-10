output "vm_ips" {
  description = "External IPs"
  value = {
    vm_formgt   = google_compute_instance.vm1.network_interface[0].access_config[0].nat_ip
    vm_fortools = google_compute_instance.vm2.network_interface[0].access_config[0].nat_ip
    vm_formie   = google_compute_instance.vm3.network_interface[0].access_config[0].nat_ip
  }
}

output "ssh_commands" {
  description = "Ready-to-run SSH commands"
  value = {
    vm_formgt   = "ssh -i ~/.ssh/gcp_tf -o IdentitiesOnly=yes formgt@${google_compute_instance.vm1.network_interface[0].access_config[0].nat_ip}"
    vm_fortools = "ssh -i ~/.ssh/gcp_tf -o IdentitiesOnly=yes fortools@${google_compute_instance.vm2.network_interface[0].access_config[0].nat_ip}"
    vm_formie   = "ssh -i ~/.ssh/gcp_tf -o IdentitiesOnly=yes formie@${google_compute_instance.vm3.network_interface[0].access_config[0].nat_ip}"
  }
}

output "cluster_private_key" {
  description = "Private key for VM-to-VM SSH (save as ~/.ssh/cluster_key)"
  value       = tls_private_key.cluster.private_key_openssh
  sensitive   = true
}

output "internal_ssh_commands" {
  description = "SSH commands for VM-to-VM communication using internal hostnames"
  value = {
    from_formgt_to_fortools = "ssh -i ~/.ssh/cluster_key fortools@fortools.lab.internal"
    from_formgt_to_formie   = "ssh -i ~/.ssh/cluster_key formie@formie.lab.internal"
    from_fortools_to_formgt = "ssh -i ~/.ssh/cluster_key formgt@formgt.lab.internal"
    from_fortools_to_formie = "ssh -i ~/.ssh/cluster_key formie@formie.lab.internal"
    from_formie_to_formgt   = "ssh -i ~/.ssh/cluster_key formgt@formgt.lab.internal"
    from_formie_to_fortools = "ssh -i ~/.ssh/cluster_key fortools@fortools.lab.internal"
  }
}

output "setup_verification" {
  description = "Commands to verify the cluster setup is working"
  value = {
    check_dns_resolution = "nslookup formgt.lab.internal && nslookup fortools.lab.internal && nslookup formie.lab.internal"
    test_cluster_key     = "ls -la ~/.ssh/cluster_key"
    test_ssh_config      = "cat ~/.ssh/config"
  }
}
