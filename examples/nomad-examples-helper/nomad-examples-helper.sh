#!/bin/bash
# A script that is meant to be used with the Nomad cluster examples to:
#
# 1. Wait for the Nomad server cluster to come up.
# 2. Print out the IP address of the Nomad load balancer and server mapped ports.
# 3. Print out some example commands you can run against your Nomad servers.

set -e

readonly SCRIPT_NAME="$(basename "$0")"

readonly MAX_RETRIES=30
readonly SLEEP_BETWEEN_RETRIES_SEC=10

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_is_installed {
  local readonly name="$1"

  if [[ ! $(command -v ${name}) ]]; then
    log_error "The binary '$name' is required by this script but is not installed or in the system's PATH."
    exit 1
  fi
}

function get_required_terraform_output {
  local readonly output_name="$1"
  local output_value

  output_value=$(terraform output -no-color "$output_name")

  if [[ -z "$output_value" ]]; then
    log_error "Unable to find a value for Terraform output $output_name"
    exit 1
  fi

  echo "$output_value"
}

#
# Usage: join SEPARATOR ARRAY
#
# Joins the elements of ARRAY with the SEPARATOR character between them.
#
# Examples:
#
# join ", " ("A" "B" "C")
#   Returns: "A, B, C"
#
function join {
  local readonly separator="$1"
  shift
  local readonly values=("$@")

  printf "%s$separator" "${values[@]}" | sed "s/$separator$//"
}

function wait_for_all_nomad_servers_to_register {
  local readonly server_ip="$(get_required_terraform_output "load_balancer_ip_address_servers")"

  local expected_num_servers
  expected_num_servers=$(get_required_terraform_output "num_servers")

  log_info "Waiting for $expected_num_servers Nomad servers to register in the cluster"

  for (( i=1; i<="$MAX_RETRIES"; i++ )); do
    log_info "Running 'nomad members' command against server at IP address $server_ip"
    # Intentionally use local and readonly here so that this script doesn't exit if the nomad members or grep commands
    # exit with an error.
    local readonly members=$(nomad server-members -address=http://$server_ip:4646)
    local readonly server_members=$(echo "$members" | grep "4648")
    local readonly num_servers=$(echo "$server_members" | wc -l | tr -d ' ')

    if [[ "$num_servers" -eq "$expected_num_servers" ]]; then
      log_info "All $expected_num_servers Nomad servers have registered in the cluster!"
      return
    else
      log_info "$num_servers out of $expected_num_servers Nomad servers have registered in the cluster."
      log_info "Sleeping for $SLEEP_BETWEEN_RETRIES_SEC seconds and will check again."
      sleep "$SLEEP_BETWEEN_RETRIES_SEC"
    fi
  done

  log_error "Did not find $expected_num_servers Nomad servers registered after $MAX_RETRIES retries."
  exit 1
}

function print_instructions {
  local readonly server_ip=$(get_required_terraform_output "load_balancer_ip_address_servers")
  local readonly num_servers=$(get_required_terraform_output "num_servers")

  local instructions=()
  instructions+=("\nYour Nomad servers are running behind the following load balancer IP address: $server_ip\n")
  instructions+=("Some commands for you to try:\n")

  instructions+=("    nomad server-members -address=http://$server_ip:4646")
  instructions+=("    nomad node-status -address=http://$server_ip:4646")
  instructions+=("    nomad run -address=http://$server_ip:4646 $SCRIPT_DIR/example.nomad")
  
    let counter=counter+1

  local instructions_str
  instructions_str=$(join "\n" "${instructions[@]}")

  echo -e "$instructions_str"
}

function run {
  assert_is_installed "az"
  assert_is_installed "jq"
  assert_is_installed "terraform"
  assert_is_installed "nomad"

  wait_for_all_nomad_servers_to_register
  print_instructions
}

run