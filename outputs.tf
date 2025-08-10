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
