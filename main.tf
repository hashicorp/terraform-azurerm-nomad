# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A NOMAD CLUSTER CO-LOCATED WITH A CONSUL CLUSTER IN AZURE
# These templates show an example of how to use the nomad-cluster module to deploy a Nomad cluster in Azure. This cluster
# has Consul colocated on the same nodes.
#
# We deploy two Scale Sets: one with a small number of Nomad and Consul server nodes and one with a
# larger number of Nomad and Consul client nodes. Note that these templates assume that the Azure Image you provide via
# the image_uri input variable is built from the examples/nomad-consul-image/nomad-consul.json Packer template.
# ---------------------------------------------------------------------------------------------------------------------

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id = "${var.client_id}"
  client_secret = "${var.secret_access_key}"
  tenant_id = "${var.tenant_id}"
}

terraform {
  required_version = ">= 0.10.0"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE NECESSARY NETWORK RESOURCES FOR THE EXAMPLE
# ---------------------------------------------------------------------------------------------------------------------
resource "azurerm_virtual_network" "nomad" {
  name = "nomadvn"
  address_space = ["${var.address_space}"]
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
}

resource "azurerm_subnet" "nomad" {
  name = "nomadsubnet"
  resource_group_name = "${var.resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.nomad.name}"
  address_prefix = "${var.subnet_address}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE SERVER NODES
# Note that we use the consul-cluster module to deploy both the Nomad and Consul nodes on the same servers
# ---------------------------------------------------------------------------------------------------------------------

module "servers" {
  source = "git::git@github.com:hashicorp/terraform-azurerm-consul//modules/consul-cluster?ref=v0.0.3"

  cluster_name = "${var.cluster_name}-server"
  cluster_size = "${var.num_servers}"
  key_data = "${var.key_data}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  #allowed_ssh_cidr_blocks = "${var.allowed_ssh_cidr_blocks}"

  resource_group_name = "${var.resource_group_name}"
  storage_account_name = "${var.storage_account_name}"

  location = "${var.location}"
  custom_data = "${data.template_file.custom_data_server.rendered}"
  instance_size = "${var.instance_size}"
  image_id = "${var.image_uri}"
  subnet_id = "${azurerm_subnet.nomad.id}"

  # When set to true, a load balancer will be created to allow SSH to the instances as described in the 'Connect to VMs by using NAT rules'
  # section of https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-overview
  #
  # For testing and development purposes, set this to true. For production, this should be set to false.
  associate_public_ip_address_load_balancer = true
  allowed_inbound_cidr_blocks = []
}

resource "azurerm_lb_probe" "nomad_probe" {
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id = "${element(module.servers.load_balancer_id, 0)}"
  name                = "nomad-running-probe"
  port                = "4646"
}

resource "azurerm_lb_rule" "nomad_api_port" {
  resource_group_name = "${var.resource_group_name}"
  name = "nomad-api"
  loadbalancer_id = "${element(module.servers.load_balancer_id, 0)}"
  protocol = "Tcp"
  frontend_port = "4646"
  backend_port = "4646"
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id = "${element(module.servers.backend_pool_id, 0)}"
  probe_id = "${azurerm_lb_probe.nomad_probe.id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE CUSTOM DATA SCRIPT THAT WILL RUN ON EACH SERVER NODE WHEN IT'S BOOTING
# This script will configure and start Consul and Nomad
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "custom_data_server" {
  template = "${file("${path.module}/custom-data-server.sh")}"

  vars {
    num_servers       = "${var.num_servers}"
    scale_set_name = "${var.cluster_name}-server"
    subscription_id = "${var.subscription_id}"
    tenant_id = "${var.tenant_id}"
    client_id = "${var.client_id}"
    secret_access_key = "${var.secret_access_key}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CLIENT NODES
# ---------------------------------------------------------------------------------------------------------------------

module "clients" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-azurerm-nomad.git//modules/nomad-cluster?ref=v0.0.1"
  source = "./modules/nomad-cluster"

  cluster_name = "${var.cluster_name}-clients"
  cluster_size = "${var.num_servers}"
  key_data = "${var.key_data}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  #allowed_ssh_cidr_blocks = "${var.allowed_ssh_cidr_blocks}"

  resource_group_name = "${var.resource_group_name}"
  storage_account_name = "${var.storage_account_name}"

  location = "${var.location}"
  custom_data = "${data.template_file.custom_data_client.rendered}"
  instance_size = "${var.instance_size}"
  image_id = "${var.image_uri}"
  subnet_id = "${azurerm_subnet.nomad.id}"

  # When set to true, a load balancer will be created to allow SSH to the instances as described in the 'Connect to VMs by using NAT rules'
  # section of https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-overview
  #
  # For testing and development purposes, set this to true. For production, this should be set to false.
  associate_public_ip_address_load_balancer = true
  allowed_inbound_cidr_blocks = []
}


# ---------------------------------------------------------------------------------------------------------------------
# THE CUSTOM DATA SCRIPT THAT WILL RUN ON EACH CLIENT NODE WHEN IT'S BOOTING
# This script will configure and start Consul and Nomad
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "custom_data_client" {
  template = "${file("${path.module}/custom-data-client.sh")}"

  vars {
    scale_set_name = "${var.cluster_name}-clients"
    subscription_id = "${var.subscription_id}"
    tenant_id = "${var.tenant_id}"
    client_id = "${var.client_id}"
    secret_access_key = "${var.secret_access_key}"
  }
}
