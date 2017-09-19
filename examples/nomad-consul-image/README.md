# Nomad and Consul Azure Image

This folder shows an example of how to use the [install-nomad module](https://github.com/hashicorp/terraform-azurerm-vault/tree/master/modules/install-nomad) from this Blueprint and 
the [install-consul module](https://github.com/gruntwork-io/consul-aws-blueprint/tree/master/modules/install-consul)
from the Consul AWS Blueprint with [Packer](https://www.packer.io/) to create [Amazon Machine Images 
(Azure Images)](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer) that have Nomad and Consul installed on top of:
 
1. Ubuntu 16.04
1. Amazon Linux

These Azure Images will have [Consul](https://www.consul.io/) and [Nomad](https://www.nomadproject.io/) installed and 
configured to automatically join a cluster during boot-up.

To see how to deploy this Azure Image, check out the [nomad-consul-colocated-cluster 
example](https://github.com/hashicorp/terraform-azurerm-vault/tree/master/examples/nomad-consul-colocated-cluster). For more info on Nomad installation and configuration, check out 
the [install-nomad](https://github.com/hashicorp/terraform-azurerm-vault/tree/master/modules/install-nomad) documentation.



## Quick start

To build the Nomad and Consul Azure Image:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `nomad-consul.json` Packer template to configure the AWS region and Nomad version 
   you wish to use.
1. Run `packer build nomad.json`.

When the build finishes, it will output the IDs of the new Azure Images. To see how to deploy one of these Azure Images, check out the 
[nomad-consul-colocated-cluster example](https://github.com/hashicorp/terraform-azurerm-vault/tree/master/examples/nomad-consul-colocated-cluster).




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
      "git clone --branch <BLUEPRINT_VERSION> https://github.com/hashicorp/terraform-azurerm-nomad.git /tmp/terraform-azurerm-nomad",
      "/tmp/terraform-azurerm-nomad/modules/install-nomad/install-nomad --version {{user `nomad_version`}}"
    ],
    "pause_before": "30s"
  }]
}
```

You should replace `<BLUEPRINT_VERSION>` in the code above with the version of this blueprint that you want to use (see
the [Releases Page](../../releases) for all available versions). That's because for production usage, you should always
use a fixed, known version of this Blueprint, downloaded from the official Git repo. On the other hand, when you're 
just experimenting with the Blueprint, it's OK to use a local checkout of the Blueprint, uploaded from your own 
computer.