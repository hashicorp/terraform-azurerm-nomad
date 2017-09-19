#!/bin/bash
# This script is meant to be run in the User Data of each Azure Instance while it's booting. The script uses the
# run-nomad and run-consul scripts to configure and start Consul and Nomad in server mode. Note that this script
# assumes it's running in an Azure Image built from the Packer template in examples/nomad-consul-image/nomad-consul.json.

set -e

# Send the log output from this script to custom-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-custom-data-output/
exec > >(tee /var/log/custom-data.log|logger -t custom-data -s 2>/dev/console) 2>&1

# These variables are passed in via Terraform template interplation
/opt/consul/bin/run-consul --server --scale-set-name "${scale_set_name}" --subscription-id "${subscription_id}" --tenant-id "${tenant_id}" --client-id "${client_id}" --secret-access-key "${secret_access_key}"
/opt/nomad/bin/run-nomad --server --num-servers "${num_servers}"