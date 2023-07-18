#!/bin/bash

set -euo pipefail

command=$1
API="http://localhost:8000"

if [[ -z "${1:-}" ]]; then
  echo "Error: Missing command."
  exit 1
fi

create_deployment() {
    local name="$1"
    local image="$2"
    local replicas="$3"

    # request the api server to create the deployment
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"image\":$image,\"replicas\":\"$replicas\"}" \
        "$API/deployments")
    
    # response
    echo "response: $response"
}

is_unique() {
    local name="$1"

    find /tmp/strivly/deployments -name 'config.json' -type f | while IFS= read -r filepath; do
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
