#!/bin/bash

# List all <deployment-name>_<deployment-id>_<timestamp>.json container files located in /tmp/strivly/containers
# and create container using docker run ... command-line
# delete all containers that not listed in that location

CONTAINERS_DIR="/tmp/strivly/containers"
pattern="^.+_[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}_\d{10}\.json$"

while true; do
    files=("$CONTAINERS_DIR"/*)
    container_list=()
    current_label=""
    echo "files"
    for filepath in "${files[@]}"; do
        file=$(basename "$filepath")
        echo "step 1 into for ${file}"
        #if [[ $file =~ $pattern ]]; then
            echo "step 2 into if"
            data=$(cat "$filepath")
            parent=$(jq -r '.parent' <<< "$data")
            id=$(jq -r '.id' <<< "$data")
            label=$(jq -r '.label' <<< "$data")
            image=$(jq -r '.image' <<< "$data")
            echo "parent ${parent}"
            echo "label: ${label}"
            exist=$(docker ps -aq --filter "name=$id" --filter "label=$label")
            echo "step 2 show json ${data}"
            if [[ -z $exist ]]; then
                echo "step 3 not exist ${exist}"
                docker run -d --name "$id" --label "$label" "$image"
            else
                echo "step 3 exist ${exist}"
                #docker restart "$exist"
            fi

            docker exec -i "$id" sh -c "cat <<EOF > /usr/share/nginx/html/index.html
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Strivly</title>
                </head>
                <body>
                    <h1>Welcome to Strivly Container $id</h1>
                    <h3>About Us</h3>
                    <p>At Strivly, we are a dedicated team of Kubernetes experts with a passion for delivering exceptional container orchestration solutions. Our mission is to empower businesses of all sizes to embrace the power of Kubernetes, streamlining their operations, and accelerating their digital transformation journey.

                        With years of hands-on experience, we have developed a deep understanding of the complexities and nuances of Kubernetes. This expertise enables us to design, implement, and manage Kubernetes solutions that meet the unique needs of each client, driving efficiency and scalability in their applications and infrastructure.
                    </p>
                    <h4>deployment parent: $parent</h4>
                </body>
                </html>
                "
            current_label="$label"
            container_list+=("$id")
            echo "step 4 container_list ${container_list[*]}"
        #fi
    done

    all_containers=$(docker ps -aq --filter "label=$current_label" --format "{{.Names}}")
    for container in $all_containers; do
        container_found=false
        for existing_container in "${container_list[@]}"; do
            if [[ $container == "$existing_container" ]]; then
                container_found=true
                break
            fi
        done

        if [[ $container_found == true ]]; then
            docker stop "$container"
            docker rm "$container"
        fi
    done

    sleep 5
done