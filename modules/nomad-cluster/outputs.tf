output "num_servers" {
  value = "${var.cluster_size}"
}

output "scale_set_name_servers" {
  value = "${var.cluster_name}"
}

output "load_balancer_ip_address_servers" {
  value = "${azurerm_public_ip.nomad_access.ip_address}"
}
