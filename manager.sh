#!/bin/bash

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

        total_replicas=0
        for container_file in "$CONTAINERS_DIR"/*.json; do
            container_id_parent=$(jq -r '.parent' "$container_file")
            if [[ "$container_id_parent" == "$id_deployment" ]]; then
                ((total_replicas++))
            fi
        done

        if ((total_replicas < replicas)); then
            replicas_to_add=$((replicas - total_replicas))
            for ((i=0; i<replicas_to_add; i++)); do
                timestamp=$(date +%s)
                uuid=$(uuid)
                file_name="${id_deployment}_${uuid}_${timestamp}.json"
                file_path="$CONTAINERS_DIR/$file_name"
                content='{"parent": "'"$id_deployment"'", "id": "'"$uuid"'", "timestamp": "'"$timestamp"'", "name": "'"$name"'", "image": "'"$image"'"}'
                echo "$content" > "$file_path"
            done
        elif ((total_replicas > replicas)); then
            replicas_to_remove=$((total_replicas - replicas))
            excess=()
            for container_file in "$CONTAINERS_DIR"/*.json; do
                container_id_parent=$(jq -r '.parent' "$container_file")
                if [[ "$container_id_parent" == "$id_deployment" ]]; then
                    excess+=("$container_file")
                fi
                if (( ${#excess[@]} >= replicas_to_remove )); then
                    break
                fi
            done
            for path in "${excess[@]:0:$replicas_to_remove}"; do
                rm "$path"
            done
        fi
    done
    sleep 1
done
