# Nomad and Consul Azure Image

This folder shows an example of how to use the [install-nomad module](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad) from this Module and 
the [install-consul module](https://github.com/gruntwork-io/terraform-azurerm-consul/tree/master/modules/install-consul)
from the Consul Azure Module with [Packer](https://www.packer.io/) to create [Amazon Machine Images 
(Azure Images)](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer) that have Nomad and Consul installed on top of Ubuntu 16.04.

This Azure Image will have [Consul](https://www.consul.io/) and [Nomad](https://www.nomadproject.io/) installed and 
configured to automatically join a cluster during boot-up.

To see how to deploy this Azure Image, check out the [nomad-consul-colocated-cluster 
example](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-colocated-cluster). For more info on Nomad installation and configuration, check out 
the [install-nomad](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad) documentation.



## Quick start

To build the Nomad and Consul Azure Image:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your Azure credentials by setting the `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` and `ARM_TENANT_ID` environment variables
1. Update the `variables` section of the `nomad-consul.json` Packer template to configure the Azure location and Nomad version 
   you wish to use.
1. Run `packer build nomad.json`.

When the build finishes, it will output the IDs of the new Azure Images. To see how to deploy one of these Azure Images, check out the 
[nomad-consul-colocated-cluster example](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-colocated-cluster).




## Creating your own Packer template for production usage

When creating your own Packer template for production usage, you can copy the example in this folder more or less 
exactly, except for one change: we recommend replacing the `file` provisioner with a call to `git clone` in the `shell` 
provisioner. Instead of:

```json
{
  "provisioners": [{
    "type": "file",
    "source": "{{template_dir}}/../../../terraform-azurerm-nomad",
    "destination": "/tmp"
  },{
    "type": "shell",
    "inline": [
      "/tmp/terraform-azurerm-nomad/modules/install-nomad/install-nomad --version {{user `nomad_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

Your code should look more like this:

```json
{
  "provisioners": [{
    "type": "shell",
    "inline": [
      "git clone --branch <Module_VERSION> https://github.com/hashicorp/terraform-azurerm-nomad.git /tmp/terraform-azurerm-nomad",
      "/tmp/terraform-azurerm-nomad/modules/install-nomad/install-nomad --version {{user `nomad_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

You should replace `<Module_VERSION>` in the code above with the version of this Module that you want to use (see
the [Releases Page](../../releases) for all available versions). That's because for production usage, you should always
use a fixed, known version of this Module, downloaded from the official Git repo. On the other hand, when you're 
just experimenting with the Module, it's OK to use a local checkout of the Module, uploaded from your own 
computer.