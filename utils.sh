#!/bin/bash

DEPLOYMENTS_DIR="/tmp/strivly/deployments/"
SERVICES_DIR="/tmp/strivly/services/"

is_unique_deployment() {
    local name="$1"

    find "$DEPLOYMENTS_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json_content=$(cat "$filepath")

        if [[ "$(echo "$json_content" | jq -r '.name')" == "$name" ]]; then
            echo "$name is not unique: try another name!"
            exit 1
        fi
    done
}

is_unique_service() {
    local name="$1"

    find "$SERVICES_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json_content=$(cat "$filepath")

        if [[ "$(echo "$json_content" | jq -r '.name')" == "$name" ]]; then
            echo "$name service is not unique: try another name!"
            exit 1
        fi
    done
}

is_valid_selector() {
    local selector="$1"
    local pattern="^[^=]+=.*$"

    if [[ $selector =~ $pattern ]]; then
        echo "Valid selector: $selector"
    else
        echo "Selector not valid: $selector"
        exit 1
    fi
}

is_haproxy_config_updated() {
    local config_file="haproxy.cfg"
    local container_ip_list=("$@")

    if [[ ! -f "$config_file" ]]; then
        return 1  # does not exist
    fi

    # check backend conf
    local existing
    existing=$(awk '/^backend http_back$/,/^backend/{print}' "$config_file")

    local new=""
    for ip in "${container_ip_list[@]}"; do
        new+="    server app_server_${ip//./_} $ip:80 check\n"
    done

    if [[ "$existing" == "$new" ]]; then
        return 0  # same backend 
    else
        return 1  # need update
    fi
}