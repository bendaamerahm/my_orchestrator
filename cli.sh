#!/bin/bash

set -euo pipefail

command=$1

if [[ -z "${1:-}" ]]; then
  echo "Error: Missing command."
  exit 1
fi

DEPLOYMENTS_DIR="/tmp/strivly/deployments/"

create_deployment() {
    name="$1"
    image="$2"
    replicas="$3"

    timestamp=$(date +%s)
    uuid=$(uuid)
    mkdir -p "$DEPLOYMENTS_DIR""${uuid}"
    json_content='{"timestamp": "'"$timestamp"'", "id": "'"$uuid"'","name": "'"$name"'","image": "'"$image"'","replicas": "'"$replicas"'"}'

    echo "$json_content" > "$DEPLOYMENTS_DIR""${uuid}"/config.json
    echo "Your deployment creation request with Name: $name and ID: $uuid has been acknowledged!"
}

is_unique() {
    local name="$1"

    find "$DEPLOYMENTS_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json_content=$(cat "$filepath")

        if [[ "$(echo "$json_content" | jq -r '.name')" == "$name" ]]; then
            echo "$name is not unique: try another name!"
            exit 1
        fi
    done
}

case "$command" in
    deployment:create)
        name=""
        image=""
        replicas=1

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --name)
                    shift
                    name="$1"
                    is_unique "$name"
                    ;;
                --image)
                    shift
                    image="$1"
                    ;;
                --replicas)
                    shift
                    replicas="$1"
                    ;;
            esac
            shift
        done

        if [[ -z "$name" || -z "$image" || -z "$replicas" ]]; then
            echo "Error: Missing required options for 'deployment:create' command."
            exit 1
        fi

        create_deployment "$name" "$image" "$replicas"
        ;;
    *)
        echo "Error: Unknown command: $command"
        exit 1
        ;;
esac
