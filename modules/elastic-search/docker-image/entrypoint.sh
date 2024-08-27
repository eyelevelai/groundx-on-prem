#!/bin/bash

# Function to add a setting if it doesn't already exist
add_setting() {
  local setting="$1"
  local value="$2"
  local config_file="/usr/share/elasticsearch/config/elasticsearch.yml"

  # Check if the setting already exists
  if ! grep -q "^${setting}:" "$config_file"; then
    echo "${setting}: ${value}" >> "$config_file"
  fi
}

# Disable xpack security to allow HTTP traffic without requiring a password
add_setting "xpack.security.enabled" "false"
add_setting "xpack.security.http.ssl.enabled" "false"

# Enable HTTP access without SSL
add_setting "http.port" "9200"
add_setting "network.host" "0.0.0.0"

# Start Elasticsearch
exec /usr/local/bin/docker-entrypoint.sh "${@}"
