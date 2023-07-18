#!/bin/bash

set -euo pipefail

# List all deployment config.json files
# and generate multiple JSON files in this format <deployment-name>_<deployment-id>_<timestamp>.json for each container
# based on the `replicas` number, JSON files are located in /tmp/strivly/containers directory
# in this format
#{
#    "parent": "<deployment-uuid>",
#   "id": "<uuid>",
#    "timestamp": "<timestamp>",
#    "name": "<deployment-name>_<deployment-id>_<timestamp>",
#    "image": "<image>"
#}
# Override (Refresh) each time all JSON files in /tmp/strivly/containers to deal with orphelin/missing/excess containers
# in order to match the desired state (deployment objects)

DEPLOYMENTS_DIR="/tmp/strivly/deployments"
CONTAINERS_DIR="/tmp/strivly/containers"

while true; do
    find "$DEPLOYMENTS_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json=$(cat "$filepath")
        id_deployment=$(jq -r '.id' <<< "$json")
        name=$(jq -r '.name' <<< "$json")
        image=$(jq -r '.image' <<< "$json")
        replicas=$(jq -r '.replicas' <<< "$json")

        declare -A total_replicas
        for path in "${CONTAINERS_DIR[@]}"; do
            deployment_uuid=$(jq -r '.parent' "$path")
            total_replicas[$deployment_uuid]=$(( ${total_replicas[$deployment_uuid]} + 1 ))
        done
        
        for deployment_uuid in "${!total_replicas[@]}"; do
            actual_replicas=${total_replicas[$deployment_uuid]}

            if (( actual_replicas < replicas )); then
                replicas_to_add=$(( replicas - actual_replicas ))
                for (( i=0; i<replicas_to_add; i++ )); do
                    timestamp=$(date +%s)
                    uuid=$(uuid)
                    file_name="${deployment_uuid}_${uuid}_${timestamp}.json"
                    file_path="$CONTAINERS_DIR/$file_name"
                    content='{"parent": "'"$id_deployment"'", "id": "'"$uuid"'", "timestamp": "'"$timestamp"'", "name": "'"$name"'","image": "'"$image"'"}'
                    echo "$content" > "$file_path"
                done

            elif (( actual_replicas > replicas )); then
                replicas_to_remove=$(( actual_replicas - replicas ))
                excess=()
                configs=$(find "$DEPLOYMENTS_DIR" -name "config.json")
                for config in "${configs[@]}"; do
                    file_deployment_uuid=$(jq -r '.parent' "$config")
                    if [[ $file_deployment_uuid == "$deployment_uuid" ]]; then
                        excess+=("$config")
                    fi
                done
                excess=("${excess[@]:0:$replicas_to_remove}")
                for path in "${excess[@]}"; do
                    rm "$path"
                done
            fi

        done
    done
    sleep 1
done
