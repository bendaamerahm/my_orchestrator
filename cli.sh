#!/bin/bash

set -euo pipefail

command=$1

if [[ -z "${1:-}" ]]; then
  echo "Error: Missing command."
  exit 1
fi

DEPLOYMENTS_DIR="/tmp/strivly/deployments"
SERVICES_DIR="/tmp/strivly/services"
INGRESSES_DIR="/tmp/strivly/ingresses"

create_deployment() {
    name="$1"
    image="$2"
    replicas="$3"
    label="$4"

    timestamp=$(date +%s)
    uuid=$(uuid)
    mkdir -p "$DEPLOYMENTS_DIR"/"${uuid}"
    json_content='{"timestamp": "'"$timestamp"'", "id": "'"$uuid"'","name": "'"$name"'","image": "'"$image"'","replicas": "'"$replicas"'","label": "'"$label"'"}'

    echo "$json_content" > "$DEPLOYMENTS_DIR"/"${uuid}"/config.json
    echo "Your deployment creation request with Name: $name and ID: $uuid has been acknowledged!"
}

scale_deployment() {
    name="$1"
    replicas="$2"

    find "$DEPLOYMENTS_DIR" -type f -name 'config.json' | while IFS= read -r filepath; do
        if jq --arg name "$name" '.name == $name' "$filepath" >/dev/null 2>&1; then
            jq --argjson replicas "$replicas" 'if has("replicas") then .replicas = $replicas else . + { "replicas": $replicas } end' "$filepath" > tmpfile && mv tmpfile "$filepath"
        fi
    done

    echo "Your deployment scaling request with Name: $name and Replicas: $replicas has been acknowledged!"
}

create_service() {
    name="$1"
    selector="$2"

    uuid=$(uuid)
    mkdir -p "$SERVICES_DIR"/"${uuid}"
    json_content='{"name": "'"$name"'", "id": "'"$uuid"'", "selector": "'"$selector"'"}'

    echo "$json_content" > "$SERVICES_DIR"/"${uuid}"/config.json
    echo "Your service creation request with Name: $name and ID: $uuid has been acknowledged!"
}

create_ingress() {
    name="$1"
    host="$2"
    backends="$3"

    uuid=$(uuid)
    mkdir -p "$INGRESSES_DIR"/"${uuid}"

    # prepare json of backends list
    IFS=','
    read -ra ADDR <<< "$backends"
    json_backends_list=""

    for i in "${ADDR[@]}"; do
        IFS='=' read -ra PATH_SERVICE <<< "$i"
        path=${PATH_SERVICE[0]}
        service=${PATH_SERVICE[1]}
        if [ -z "$json_backends_list" ]
        then
            json_backends_list="{\"path\": \"${path}\", \"service\": \"${service}\"}"
        else
            json_backends_list="$json_backends_list, {\"path\": \"${path}\", \"service\": \"${service}\"}"
        fi
    done

    #json content of ingress config
    json_content="{
    \"name\": \"$name\",
    \"id\": \"$uuid\",
    \"host\": \"$host\",
    \"backends\": [$json_backends_list]
    }"

    echo "$json_content" > "$INGRESSES_DIR"/"${uuid}"/config.json
    echo "Your engress creation request with Name: $name and ID: $uuid has been acknowledged!"
}

check_uniqueness() {
    local name="$1"
    local dir="$2"
    local resource_type="$3"

    if find "$dir" -name 'config.json' -type f -exec jq -e --arg name "$name" '.name == $name' {} \; | grep -q true; then
        echo "$name $resource_type is not unique: try another name!"
        exit 1
    fi
}

is_deployment_exist() {
    local name="$1"

    if find "$DEPLOYMENTS_DIR" -name 'config.json' -type f -exec jq -e --arg name "$name" '.name == $name' {} \; | grep -q true; then
        return 0
    else
        echo "$name $resource_type is not unique: try another name!"
        exit 1
    fi
}

is_unique_deployment() {
    local name="$1"
    check_uniqueness "$name" "$DEPLOYMENTS_DIR" "deployment"
}

is_unique_service() {
    local name="$1"
    check_uniqueness "$name" "$SERVICES_DIR" "service"
}

is_unique_ingress() {
    local name="$1"
    check_uniqueness "$name" "$INGRESSES_DIR" "ingress"
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

is_valid_host() {
    local host="$1"
    local domain_pattern='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'

    if [[ "$host" =~ $domain_pattern ]]; then
        echo "host '$host' is a valid domain."
        return 0 
    else
        echo "host '$host' is not a valid domain."
        return 1 
    fi
}

validate_and_check_services() {
    local pattern="$1"
    local valid_pattern='^(/[^=]+=[^,/]+(,/[^=]+=[^,/]+)*)$'

    if ! [[ "$pattern" =~ $valid_pattern ]]; then
        echo "invalid pattern: $pattern"
        return 1
    fi

    IFS=',' read -ra services <<< "${pattern//\//,}"

    for service in "${services[@]}"; do
        IFS='=' read -r -a parts <<< "$service"
        local path_name="${parts[0]}"
        local service_name="${parts[1]}"

        local service_file="$SERVICES_DIR/${path_name#\/}.json"

        if [ ! -f "$service_file" ] || ! jq -e --arg name "$service_name" '.name == $name' "$service_file" > /dev/null; then
            echo "service '$service_name' does not exist or is invalid :("
            return 1
        fi
    done

    echo "all services exist :)"
}

case "$command" in
    deployment:create)
        name=""
        image=""
        replicas=1
        label=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --name)
                    shift
                    name="$1"
                    is_unique_deployment "$name"
                    ;;
                --image)
                    shift
                    image="$1"
                    ;;
                --replicas)
                    shift
                    replicas="$1"
                    ;;
                --label)
                    shift
                    label="$1"
                    ;;
            esac
            shift
        done

        if [[ -z "$name" || -z "$image" || -z "$replicas" || -z "$label" ]]; then
            echo "Error: Missing required options for 'deployment:create' command."
            exit 1
        fi

        create_deployment "$name" "$image" "$replicas" "$label"
        ;;
    
    deployment:scale)
        name=""
        image=""
        replicas=1
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --name)
                    shift
                    name="$1"
                    is_deployment_exist "$name"
                    ;;
                --replicas)
                    shift
                    replicas="$1"
                    ;;
            esac
            shift
        done

        if [[ -z "$name" || -z "$replicas" ]]; then
            echo "Error: Missing required options for 'deployment:scale' command."
            exit 1
        fi

        scale_deployment "$name" "$replicas"
        ;;

    service:create)
        name=""
        selector=""
        
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --name)
                    shift
                    name="$1"
                    is_unique_service "$name"
                    ;;
                --selector)
                    shift
                    selector="$1"
                    is_valid_selector "$selector"
                    ;;
            esac
            shift
        done

        if [[ -z "$name" || -z "$selector" ]]; then
            echo "Error: Missing required options for 'service:create' command."
            exit 1
        fi

        create_service "$name" "$selector"
        ;;

    ingress:create)
        name=""
        host=""
        backends=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --name)
                    shift
                    name="$1"
                    is_unique_ingress "$name"
                    ;;
                --host)
                    shift
                    host="$1"
                    is_valid_host "$host"
                    ;;
                --backends)
                    shift
                    backends="$1"
                    ;;
            esac
            shift
        done

        if [[ -z "$name" || -z "$host" || -z "$backends" ]]; then
            echo "Error: Missing required options for 'ingress:create' command."
            exit 1
        fi

        create_ingress "$name" "$host" "$backends"
        ;;
    *)
        echo "Error: Unknown command: $command"
        exit 1
        ;;
esac
