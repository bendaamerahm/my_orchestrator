#!/bin/bash

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

# api routes
if [[ "$REQUEST_METHOD" == "POST" && "$REQUEST_URI" == "/deployments" ]]; then
    read -r -d '' REQUEST_BODY
    name=$(jq -r '.name' <<< "$REQUEST_BODY")
    image=$(jq -r '.image' <<< "$REQUEST_BODY")
    replicas=$(jq -r '.replicas' <<< "$REQUEST_BODY")
    create_deployment "$name" "$image" "$replicas"
else
    echo "Invalid api endpoint."
    exit 1
fi
