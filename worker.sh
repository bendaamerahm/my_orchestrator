#!/bin/bash

# List all <deployment-name>_<deployment-id>_<timestamp>.json container files located in /tmp/strivly/containers
# and create container using docker run ... command-line
# delete all containers that not listed in that location

CONTAINERS_DIR="/tmp/strivly/containers"
pattern="^.+_[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}_\d{10}\.json$"

while true; do
    files=("$CONTAINERS_DIR"/*)
    container_list=()
    echo "files"
    for filepath in "${files[@]}"; do
        file=$(basename "$filepath")
        echo "step 1 into for ${file}"
        #if [[ $file =~ $pattern ]]; then
            echo "step 2 into if"
            data=$(cat "$filepath")
            timestamp=$(jq -r '.timestamp' <<< "$data")
            name=$(jq -r '.name' <<< "$data")
            image=$(jq -r '.image' <<< "$data")

            exist=$(docker ps -aq --filter "name=$name$" --filter "label=timestamp=$timestamp")
            echo "step 2 show json ${data}"
            if [[ -z $exist ]]; then
                echo "step 3 not exist ${exist}"
                docker run -d --name "$name" --label "timestamp=$timestamp" "$image"
            else
                echo "step 3 exist ${exist}"
                docker restart "$exist"
            fi

            container_list+=("$name")
            echo "step 4 container_list ${container_list[*]}"
        #fi
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
