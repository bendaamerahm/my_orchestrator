#!/bin/bash
DEPLOYMENTS_DIR="/tmp/strivly/deployments/"
SERVICES_DIR="/tmp/strivly/services/"

create_deployment() {
    name="$1"
    image="$2"
    replicas="$3"
    label="$4"

    timestamp=$(date +%s)
    uuid=$(uuid)
    mkdir -p "$DEPLOYMENTS_DIR""${uuid}"
    json_content='{"timestamp": "'"$timestamp"'", "id": "'"$uuid"'","name": "'"$name"'","image": "'"$image"'","replicas": "'"$replicas"'","label": "'"$label"'"}'

    echo "$json_content" > "$DEPLOYMENTS_DIR""${uuid}"/config.json
    echo "Your deployment creation request with Name: $name and ID: $uuid has been acknowledged!"
}

create_service() {
    name="$1"
    selector="$2"

    uuid=$(uuid)
    mkdir -p "$SERVICES_DIR""${uuid}"
    json_content='{"name": "'"$name"'", "id": "'"$uuid"'", "selector": "'"$selector"'"}'

    echo "$json_content" > "$SERVICES_DIR""${uuid}"/config.json
    echo "Your service creation request with Name: $name and ID: $uuid has been acknowledged!"
}

create_haproxy_config() {
    local proxy_container_name="$1"
    local config_file="haproxy.cfg"
    local container_ip_list=("${@:2}")

    # create haproxy.cfg (basic config found online)
    cat <<EOL > "$config_file"
global
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http_front
    bind *:80
    default_backend http_back

backend http_back
EOL

    # append backend ip list
    for ip in "${container_ip_list[@]}"; do
        echo "    server app_server_${ip//./_} $ip:80 check" >> "$config_file"
    done
    
    docker run -d --name "$proxy_container_name" -p 80:80 -v "$(pwd)/$config_file:/usr/local/etc/haproxy/haproxy.cfg:ro" haproxy

    # load config
    docker exec "$proxy_container_name" bash -c "mkdir -p /usr/local/etc/haproxy/ && cp $config_file /usr/local/etc/haproxy/ && haproxy -f /usr/local/etc/haproxy/$config_file -p /var/run/haproxy.pid -sf \$(cat /var/run/haproxy.pid)"
}