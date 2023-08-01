#!/bin/bash

# List all deployment config.json files
# and generate multiple JSON files in this format <deployment-name>_<deployment-id>_<timestamp>.json for each container
# based on the `replicas` number, JSON files are located in /tmp/strivly/containers directory
# in this format
# {
#    "parent": "<deployment-uuid>",
#   "id": "<uuid>",
#    "timestamp": "<timestamp>",
#    "name": "<deployment-name>_<deployment-id>_<timestamp>",
#    "image": "<image>"
# ²}
# Override (Refresh) each time all JSON files in /tmp/strivly/containers to deal with orphelin/missing/excess containers
# in order to match the desired state (deployment objects)

DEPLOYMENTS_DIR="/tmp/strivly/deployments"
PODS_DIR="/tmp/strivly/pods"

while true; do
    find "$DEPLOYMENTS_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json=$(cat "$filepath")
        id_deployment=$(jq -r '.id' <<< "$json")
        name=$(jq -r '.name' <<< "$json")
        containers=$(jq -r '.containers' <<< "$json")
        replicas=$(jq -r '.replicas' <<< "$json")
        label=$(jq -r '.label' <<< "$json")
        echo "replicas in: $replicas"
        total_replicas=0
        for pod in "$PODS_DIR"/*.json; do
            pod_id_parent=$(jq -r '.parent' "$pod")
            if [[ "$pod_id_parent" == "$id_deployment" ]]; then
                ((total_replicas++))
            fi
        done
        echo "total_replicas: $total_replicas"

         if ((total_replicas < replicas)); then
            echo "yes <"
            replicas_to_add=$((replicas - total_replicas))
            for ((i=0; i<replicas_to_add; i++)); do
                timestamp=$(date +%s)
                uuid=$(uuidgen)
                file_name="${name}_${id_deployment}_${timestamp}.json"
                file_path="$PODS_DIR/$file_name"
                cat <<EOF >"$file_path"
                    {
                        "parent": "$id_deployment",
                        "id": "$uuid",
                        "timestamp": "$timestamp",
                        "name": "$name",
                        "label": "$label",
                        "containers": $containers
                    }
EOF
            done
        elif ((total_replicas > replicas)); then
            echo "yes >"
            replicas_to_remove=$((total_replicas - replicas))
            excess=()
            for pod_file in "$PODS_DIR"/*.json; do
                pod_id_parent=$(jq -r '.parent' "$pod_file")
                if [[ "$pod_id_parent" == "$id_deployment" ]]; then
                    excess+=("$pod_file")
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
