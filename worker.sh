#!/bin/bash

# List all <deployment-name>_<deployment-id>_<timestamp>.json container files located in /tmp/strivly/containers
# and create container using docker run ... command-line
# delete all containers that not listed in that location

PODS_DIR="/tmp/strivly/pods"
pattern="^.+_[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}_\d{10}\.json$"

while true; do
    files=("$PODS_DIR"/*)
    container_list=()
    current_label=""
    echo "files"
    for filepath in "${files[@]}"; do
        file=$(basename "$filepath")
        echo "step 1 into for ${file}"
        #if [[ $file =~ $pattern ]]; then
            echo "step 2 into if"
            data=$(cat "$filepath")
            label=$(jq -r '.label' <<< "$data")
            parent=$(jq -r '.parent' <<< "$data")
            containers=$(jq -r '.containers' <<< "$data")
            echo "label: $label"
            echo "containers: $containers"

            # pause container for current deployment
            pause_container="pause_$parent"
            echo "pause_container: $pause_container"
            exist_pause_container=$(docker ps -a --filter "name=$pause_container" --format "{{.Names}}")
            if [[ -z $exist_pause_container ]]; then
                docker run -d --name "$pause_container" --label "$label" --network "none" registry.k8s.io/pause:3.6
            fi

            for container in $(jq -c '.[]' <<< "$containers"); do
                # name and image
                container_name=$(jq -r '.name' <<< "$container")
                container_image=$(jq -r '.image' <<< "$container")
                echo "name: $container_name, image: $container_image"
                exist=$(docker ps -a --filter "label=$label" --filter "name=$container_name" --format "{{.Names}}")
                echo "exist $exist"
                if [[ -z $exist ]]; then
                    echo "not exist"
                    ghost_image="ghost"
                    if [[ "$container_image" == "$ghost_image" ]]; then
                        docker run -d --name "$container_name" -e "NODE_ENV=development" --label "$label" --network "container:$pause_container" --memory "500m" --memory-swap="500m" "$container_image"
                    else
                        docker run -d --name "$container_name" --label "$label" --network "container:$pause_container" --memory "20m" --memory-swap="20m" "$container_image"
                    fi
                fi
                current_label="$label"
                container_list+=("$container_name")
            done
        #fi
    done

    all_containers=$(docker ps --filter "label=$current_label" --format "{{.Names}}")
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