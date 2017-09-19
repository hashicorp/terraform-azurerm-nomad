output "num_servers" {
  value = "${module.servers.cluster_size}"
}

output "scale_set_name_servers" {
  value = "${module.servers.scale_set_name}"
}

output "load_balancer_ip_address_servers" {
  value = "${module.servers.load_balancer_ip_address}"
}

output "load_balancer_ip_address_clients" {
  value = "${module.clients.load_balancer_ip_address_servers}"
}