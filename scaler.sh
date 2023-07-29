#!/bin/bash

MEMORY_LIMIT_CONTAINER=100000000 #100M 
DESIRED_MEMORY=0.6 # 0.6 for 60%
DEPLOYMENTS_DIR="/tmp/strivly/deployments"

scale_deployment() {
    name="$1"
    replicas="$2"

    find "$DEPLOYMENTS_DIR" -type f -name 'config.json' | while IFS= read -r filepath; do
        if jq --arg name "$name" '.name == $name' "$filepath" >/dev/null 2>&1; then
            jq --argjson replicas "$replicas" 'if has("replicas") then .replicas = $replicas else . + { "replicas": $replicas } end' "$filepath" > tmpfile && mv tmpfile "$filepath"
        fi
    done
}

while true; do
    find "$DEPLOYMENTS_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json=$(cat "$filepath")
        name=$(jq -r '.name' <<< "$json")
        replicas=$(jq -r '.replicas' <<< "$json")
        label=$(jq -r '.label' <<< "$json")
        id=$(jq -r '.id' <<< "$json")

        # deployment memory limit
        memory_limit_deployment=$((MEMORY_LIMIT_CONTAINER * replicas))

        # list container by label
        container_id_list=$(docker ps -q --filter "label=$label")
        echo "container_id_list=$container_id_list"

        total_memory_usage=0
        for id in $container_id_list; do
            stats_memory_container=$(docker stats --no-stream --format "{{.MemUsage}}" "$id")
            echo "stats_memory_container=$stats_memory_container"
            memory_usage_text=${stats_memory_container%%/*}
            echo "memory_usage_text=$memory_usage_text"
            memory_usage_converted=$(echo "$memory_usage_text" | awk '{printf "%.0f\n", $1 * 1048576}')
            echo "usage_memory_container=$memory_usage_converted"
            total_memory_usage=$(echo "$total_memory_usage + $memory_usage_converted" | bc)
            echo "total_memory=$total_memory_usage"
        done

        # memory usage % of the limit
        memory_usage=$(echo "$total_memory_usage / $memory_limit_deployment" | bc -l)
        
        for (( i=0; i<"$replicas"; i++ )); do
            echo "memory_usage=$memory_usage, DESIRED_MEMORY=$DESIRED_MEMORY"
            # memory usage > desired memory usage  =>  scale up
            result=$(echo "$memory_usage > $DESIRED_MEMORY" | bc)
            echo "result=$result"
            if [ "$result" -eq 1 ]; then
                # desired nb replicas (Kubernetes formula)
                desired_replicas=$(echo "scale=0; ($replicas * $memory_usage / $DESIRED_MEMORY)+0.5/1" | bc)
                # update nb replicas in the deployment config
                scale_deployment "$name" "$desired_replicas"
            fi
        done
    done
    sleep 10
done
