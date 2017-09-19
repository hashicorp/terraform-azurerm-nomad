terraform {
  required_version = ">= 0.10.0"
}

#---------------------------------------------------------------------------------------------------------------------
# CREATE A LOAD BALANCER FOR TEST ACCESS (SHOULD BE DISABLED FOR PROD)
#---------------------------------------------------------------------------------------------------------------------
resource "azurerm_public_ip" "nomad_access" {
  count = "${var.associate_public_ip_address_load_balancer ? 1 : 0}"
  name = "${var.cluster_name}_access"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
  domain_name_label = "${var.cluster_name}"
}

resource "azurerm_lb" "nomad_access" {
  count = "${var.associate_public_ip_address_load_balancer ? 1 : 0}"
  name = "${var.cluster_name}_access"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  frontend_ip_configuration {
    name = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.nomad_access.id}"
  }
}

resource "azurerm_lb_nat_pool" "nomad_lbnatpool_ssh" {
  count = "${var.associate_public_ip_address_load_balancer ? 1 : 0}"
  resource_group_name = "${var.resource_group_name}"
  name = "ssh"
  loadbalancer_id = "${azurerm_lb.nomad_access.id}"
  protocol = "Tcp"
  frontend_port_start = 2200
  frontend_port_end = 2299
  backend_port = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_backend_address_pool" "nomad_bepool" {
  count = "${var.associate_public_ip_address_load_balancer ? 1 : 0}"
  resource_group_name = "${var.resource_group_name}"
  loadbalancer_id = "${azurerm_lb.nomad_access.id}"
  name = "BackEndAddressPool"
}

#---------------------------------------------------------------------------------------------------------------------
# CREATE A VIRTUAL MACHINE SCALE SET TO RUN NOMAD (WITHOUT LOAD BALANCER)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_virtual_machine_scale_set" "nomad" {
  count = "${var.associate_public_ip_address_load_balancer ? 0 : 1}"
  name = "${var.cluster_name}"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  upgrade_policy_mode = "Manual"

  sku {
    name = "${var.instance_size}"
    tier = "${var.instance_tier}"
    capacity = "${var.cluster_size}"
  }

  os_profile {
    computer_name_prefix = "${var.computer_name_prefix}"
    admin_username = "${var.admin_user_name}"

    #This password is unimportant as it is disabled below in the os_profile_linux_config
    admin_password = "Passwword1234"
    custom_data = "${var.custom_data}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/${var.admin_user_name}/.ssh/authorized_keys"
      key_data = "${var.key_data}"
    }
  }

  network_profile {
    name = "nomadNetworkProfile"
    primary = true

    ip_configuration {
      name = "nomadIPConfiguration"
      subnet_id = "${var.subnet_id}"
    }
  }

  storage_profile_image_reference {
    id = "${var.image_id}"
  }

  storage_profile_os_disk {
    name = ""
    caching = "ReadWrite"
    create_option = "FromImage"
    os_type = "Linux"
    managed_disk_type = "Standard_LRS"
  }

  tags {
    scaleSetName = "${var.cluster_name}"
  }
}

#---------------------------------------------------------------------------------------------------------------------
# CREATE A VIRTUAL MACHINE SCALE SET TO RUN NOMAD (WITH LOAD BALANCER)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_virtual_machine_scale_set" "nomad_with_load_balancer" {
  count = "${var.associate_public_ip_address_load_balancer ? 1 : 0}"
  name = "${var.cluster_name}"
  location = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  upgrade_policy_mode = "Manual"

  sku {
    name = "${var.instance_size}"
    tier = "${var.instance_tier}"
    capacity = "${var.cluster_size}"
  }

  os_profile {
    computer_name_prefix = "${var.computer_name_prefix}"
    admin_username = "${var.admin_user_name}"

    #This password is unimportant as it is disabled below in the os_profile_linux_config
    admin_password = "Passwword1234"
    custom_data = "${var.custom_data}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/${var.admin_user_name}/.ssh/authorized_keys"
      key_data = "${var.key_data}"
    }
  }

  network_profile {
    name = "nomadNetworkProfile"
    primary = true

    ip_configuration {
      name = "nomadIPConfiguration"
      subnet_id = "${var.subnet_id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.nomad_bepool.id}"]
      load_balancer_inbound_nat_rules_ids = ["${element(azurerm_lb_nat_pool.nomad_lbnatpool_ssh.*.id, count.index)}"]
    }
  }

  storage_profile_image_reference {
    id = "${var.image_id}"
  }

  storage_profile_os_disk {
    name = ""
    caching = "ReadWrite"
    create_option = "FromImage"
    os_type = "Linux"
    managed_disk_type = "Standard_LRS"
  }

  tags {
    scaleSetName = "${var.cluster_name}"
  }
}
