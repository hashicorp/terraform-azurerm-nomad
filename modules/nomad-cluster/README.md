# Nomad Cluster

This folder contains a [Terraform](https://www.terraform.io/) module that can be used to deploy a 
[Nomad](https://www.nomadproject.io/) cluster in [Azure](https://azure.microsoft.com/) on top of an Scale Set. This 
module is designed to deploy an [Azure Managed Image](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer) 
that had Nomad installed via the [install-nomad](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad) module in this Module.

Note that this module assumes you have a separate [Consul](https://www.consul.io/) cluster already running. If you want
to run Consul and Nomad in the same cluster, instead of using this module, see the [Deploy Nomad and Consul in the same 
cluster documentation](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/README.md#deploy-nomad-and-consul-in-the-same-cluster).



## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "nomad_cluster" {
  # TODO: update this to the final URL
  # Use version v0.0.1 of the nomad-cluster module
  source = "github.com/hashicorp/terraform-azurerm-nomad//modules/nomad-cluster?ref=v0.0.1"

  # Specify the ID of the Nomad Azure Image. You should build this using the scripts in the install-nomad module.
  ami_id = "ami-abcd1234"
  
  # Configure and start Nomad during boot. It will automatically connect to the Consul cluster specified in its 
  # configuration and form a cluster with other Nomad nodes connected to that Consul cluster. 
  user_data = <<-EOF
              #!/bin/bash
              /opt/nomad/bin/run-nomad --server --num-servers 3
              EOF
  
  # ... See vars.tf for the other parameters you must define for the nomad-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the nomad-cluster module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `ami_id`: Use this parameter to specify the ID of a Nomad [Amazon Machine Image 
  (Azure Image)](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/build-image-with-packer) to deploy on each server in the cluster. You
  should install Nomad in this Azure Image using the scripts in the [install-nomad](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad) module.
  
* `user_data`: Use this parameter to specify a [User 
  Data](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/classic/inject-custom-data) script that each
  server will run during boot. This is where you can use the [run-nomad script](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/run-nomad) to configure and 
  run Nomad. The `run-nomad` script is one of the scripts installed by the [install-nomad](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad) 
  module. 

You can find the other parameters in [vars.tf](vars.tf).

Check out the [nomad-consul-separate-cluster example](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-separate-cluster example) for working
sample code. Note that if you want to run Nomad and Consul on the same cluster, see the [nomad-consul-colocated-cluster 
example](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-colocated-cluster example) instead.





## How do you connect to the Nomad cluster?

### Using the Node agent from your own computer

If you want to connect to the cluster from your own computer, [install 
Nomad](https://www.nomadproject.io/docs/install/index.html) and execute commands with the `-address` parameter set to
the IP address of one of the servers in your Nomad cluster. Note that this only works if the Nomad cluster is running 
in public subnets and/or your default VPC (as in both [examples](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples)), which is OK for testing and 
experimentation, but NOT recommended for production usage.

To use the HTTP API, you first need to get the public IP address of one of the Nomad Instances. If you deployed the
[nomad-consul-colocated-cluster](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-colocated-cluster) or
[nomad-consul-separate-cluster](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-separate-cluster) example, the 
[nomad-examples-helper.sh script](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-examples-helper/nomad-examples-helper.sh) will do the tag lookup for 
you automatically (note, you must have the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest), 
[jq](https://stedolan.github.io/jq/), and the [Nomad agent](https://www.nomadproject.io/) installed locally):

```
> ../nomad-examples-helper/nomad-examples-helper.sh 

Your Nomad servers are running at the following IP addresses:

34.204.85.139
52.23.167.204
54.236.16.38
```

Copy and paste one of these IPs and use it with the `-address` argument for any [Nomad 
command](https://www.nomadproject.io/docs/commands/index.html). For example, to see the status of all the Nomad
servers:

```
> nomad server-members -address=http://<INSTANCE_IP_ADDR>:4646

ip-172-31-23-140.global  172.31.23.140  4648  alive   true    2         0.5.4  dc1         global
ip-172-31-23-141.global  172.31.23.141  4648  alive   true    2         0.5.4  dc1         global
ip-172-31-23-142.global  172.31.23.142  4648  alive   true    2         0.5.4  dc1         global
```

To see the status of all the Nomad agents:

```
> nomad node-status -address=http://<INSTANCE_IP_ADDR>:4646

ID        DC          Name                 Class   Drain  Status
ec2796cd  us-east-1e  i-0059e5cafb8103834  <none>  false  ready
ec2f799e  us-east-1d  i-0a5552c3c375e9ea0  <none>  false  ready
ec226624  us-east-1b  i-0d647981f5407ae32  <none>  false  ready
ec2d4635  us-east-1a  i-0c43dcc509e3d8bdf  <none>  false  ready
ec232ea5  us-east-1d  i-0eff2e6e5989f51c1  <none>  false  ready
ec2d4bd6  us-east-1c  i-01523bf946d98003e  <none>  false  ready
```

And to submit a job called `example.nomad`:
 
```
> nomad run -address=http://<INSTANCE_IP_ADDR>:4646 example.nomad

==> Monitoring evaluation "0d159869"
    Evaluation triggered by job "example"
    Allocation "5cbf23a1" created: node "1e1aa1e0", group "example"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "0d159869" finished with status "complete"
```



### Using the Nomad agent on another Azure Instance

For production usage, your Azure Instances should be running the [Nomad 
agent](https://www.nomadproject.io/docs/agent/index.html). The agent nodes should discover the Nomad server nodes
automatically using Consul. Check out the [Service Discovery 
documentation](https://www.nomadproject.io/docs/service-discovery/index.html) for details.




## What's included in this module?

This module creates the following architecture:

![Nomad architecture](https://raw.githubusercontent.com/hashicorp/terraform-azurerm-nomad/master/_docs/architecture.png)

This architecture consists of the following resources:

* [Scale Set](#scale-set)
* [Security Group](#security-group)
* [IAM Role and Permissions](#iam-role-and-permissions)


### Scale Set

This module runs Nomad on top of an Scale Set. Each of the Azure
Instances should be running an Azure Image that has had Nomad installed via the [install-nomad](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/install-nomad)
module. You pass in the URI of the Azure Image to run using the `ami_id` input parameter.


### Security Group

Each Azure Instance in the Scale Set has a Security Group that allows:
 
* All outbound requests
* All the inbound ports specified in the [Nomad 
  documentation](https://www.nomadproject.io/docs/agent/configuration/index.html#ports)

The Security Group ID is exported as an output variable if you need to add additional rules. 

Check out the [Security section](#security) for more details. 



## How do you roll out updates?

If you want to deploy a new version of Nomad across the cluster, the best way to do that is to:

1. Build a new Azure Image.
1. Set the `image_id` parameter to the ID of the new Azure Image.
1. Run `terraform apply`.

This updates the Launch Configuration of the Scale Set, so any new Instances in the Scale Set will have your new Azure Image, but it does
NOT actually deploy those new instances. 

1. Issue an API call to one of the old Instances in the Scale Set to have it leave gracefully. E.g.:

    ```
    nomad server-force-leave -address=<OLD_INSTANCE_IP>:4646
    ```
    
1. Once the instance has left the cluster, ssh to the instance and terminate it:
 
    ```
    init 0
    ```

1. After a minute or two, the Scale Set should automatically launch a new Instance, with the new Azure Image, to replace the old one.

1. Wait for the new Instance to boot and join the cluster.

1. Repeat these steps for each of the other old Instances in the Scale Set.
   
We will add a script in the future to automate this process (PRs are welcome!).





## What happens if a node crashes?

There are two ways a Nomad node may go down:
 
1. The Nomad process may crash. In that case, `supervisor` should restart it automatically.
1. The Azure Instance running Nomad dies. In that case, the Scale Set should launch a replacement automatically. 
   Note that in this case, since the Nomad agent did not exit gracefully, and the replacement will have a different ID,
   you may have to manually clean out the old nodes using the [server-force-leave
   command](https://www.nomadproject.io/docs/commands/server-force-leave.html). We may add a script to do this 
   automatically in the future. For more info, see the [Nomad Outage 
   documentation](https://www.nomadproject.io/guides/outage.html).





## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Dedicated instances](#dedicated-instances)
1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)


### Encryption in transit

Nomad can encrypt all of its network traffic. For instructions on enabling network encryption, have a look at the
[How do you handle encryption documentation](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/modules/run-nomad#how-do-you-handle-encryption).


### Encryption at rest

The Azure Instances in the cluster store all their data on the root EBS Volume. To enable encryption for the data at
rest, you must enable encryption in your Nomad Azure Image. If you're creating the Azure Image using Packer (e.g. as shown in
the [nomad-consul-ami example](https://github.com/hashicorp/terraform-azurerm-nomad/tree/master/examples/nomad-consul-ami)), you need to set the [encrypt_boot 
parameter](https://www.packer.io/docs/builders/amazon-ebs.html#encrypt_boot) to `true`.  


### Dedicated instances

If you wish to use dedicated instances, you can set the `tenancy` parameter to `"dedicated"` in this module. 


### Security groups

This module attaches a security group to each Azure Instance that allows inbound requests as follows:

* **Nomad**: For all the [ports used by Nomad](https://www.nomadproject.io/docs/agent/configuration/index.html#ports), 
  you can use the `allowed_inbound_cidr_blocks` parameter to control the list of 
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access.  

* **SSH**: For the SSH port (default: 22), you can use the `allowed_ssh_cidr_blocks` parameter to control the list of   
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access. 
  
Note that all the ports mentioned above are configurable via the `xxx_port` variables (e.g. `http_port`). See
[vars.tf](vars.tf) for the full list.  
  