#!/bin/bash

# List all <deployment-name>_<deployment-id>_<timestamp>.json container files located in /tmp/strivly/containers
# and create container using docker run ... command-line
# delete all containers that not listed in that location

CONTAINERS_DIR="/tmp/strivly/containers"
pattern="^.+_[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}_\d{10}\.json$"

while true; do
    files=("$CONTAINERS_DIR"/*)
    container_list=()

    for filepath in "${files[@]}"; do
        file=$(basename "$filepath")

        if [[ $file =~ $pattern ]]; then
            data=$(cat "$filepath")
            timestamp=$(jq -r '.timestamp' <<< "$data")
            name=$(jq -r '.name' <<< "$data")
            image=$(jq -r '.image' <<< "$data")

            exist=$(docker ps -aq --filter "name=$name$" --filter "label=timestamp=$timestamp")

            if [[ -z $exist ]]; then
                docker run -d --name "$name" --label "timestamp=$timestamp" "$image"
            else
                docker restart "$exist"
            fi

            container_list+=("$name")
        fi
    done

    all_containers=$(docker ps -aq --filter "label=timestamp" --format "{{.Names}}")
    for container in $all_containers; do
        container_found=false
        for existing_container in "${container_list[@]}"; do
            if [[ $container == "$existing_container" ]]; then
                container_found=true
                break
            fi
        done

        if [[ $container_found == false ]]; then
            docker stop "$container"
            docker rm "$container"
        fi
    done

    sleep 5
done
