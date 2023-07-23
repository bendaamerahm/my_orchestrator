#!/bin/bash

set -euo pipefail

command=$1

if [[ -z "${1:-}" ]]; then
  echo "Error: Missing command."
  exit 1
fi

DEPLOYMENTS_DIR="/tmp/strivly/deployments/"
SERVICES_DIR="/tmp/strivly/services/"

create_deployment() {
    name="$1"
    image="$2"
    replicas="$3"
    label="$4"

    timestamp=$(date +%s)
    uuid=$(uuid)
    mkdir -p "$DEPLOYMENTS_DIR""${uuid}"
    json_content='{"timestamp": "'"$timestamp"'", "id": "'"$uuid"'","name": "'"$name"'","image": "'"$image"'","replicas": "'"$replicas"'","label": "'"$label"'"}'

    echo "$json_content" > "$DEPLOYMENTS_DIR""${uuid}"/config.json
    echo "Your deployment creation request with Name: $name and ID: $uuid has been acknowledged!"
}

create_service() {
    name="$1"
    selector="$2"

    uuid=$(uuid)
    mkdir -p "$SERVICES_DIR""${uuid}"
    json_content='{"name": "'"$name"'", "id": "'"$uuid"'", "selector": "'"$selector"'"}'

    echo "$json_content" > "$SERVICES_DIR""${uuid}"/config.json
    echo "Your service creation request with Name: $name and ID: $uuid has been acknowledged!"
}

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

case "$command" in
    deployment:create)
        name=""
        image=""
        replicas=1
        image=""
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
    *)
        echo "Error: Unknown command: $command"
        exit 1
        ;;
esac
