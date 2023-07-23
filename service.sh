#!/bin/bash

SERVICES_DIR="/tmp/strivly/services"

# TODO
# /tmp/strivly/services
# {"id", "name", "selector"}
# Retrieve all containers ip with the same label as service selector
# docker ps --filter label=role=intranet --format json | jq .
# docker inspect --format "{{.ID }} {{ .Name }} {{ .NetworkSettings.Networks.bridge.IPAddress }}" $1 | sed 's/\///'):$(docker port "$1" | grep -o "0.0.0.0:.*" | cut -f2 -d:)

# update haproxy lb (service) backends section with corresponding retrieved containers ips
# reload haproxy config
# access to our application via haproxy lb (service) ip and test if the traffic is loaded between all containers replicas

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

is_haproxy_config_updated() {
    local config_file="haproxy.cfg"
    local container_ip_list=("$@")

    if [[ ! -f "$config_file" ]]; then
        return 1  # does not exist
    fi

    # check backend conf
    local existing
    existing=$(awk '/^backend http_back$/,/^backend/{print}' "$config_file")

    local new=""
    for ip in "${container_ip_list[@]}"; do
        new+="    server app_server_${ip//./_} $ip:80 check\n"
    done

    if [[ "$existing" == "$new" ]]; then
        return 0  # same backend 
    else
        return 1  # need update
    fi
}

while true; do
    find "$SERVICES_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json=$(cat "$filepath")
        id=$(jq -r '.id' <<< "$json")
        selector=$(jq -r '.selector' <<< "$json")

        container_id_array=$(sudo docker ps -q --filter "label=$selector")
        ip_array=()
        for container_id in $container_id_array; do
            ip=$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_id")
            ip_array+=("$ip")
            echo "container id: $container_id => ip: ${ip}"
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
        done

        if docker ps -q -f name="proxy_$id"; then
            echo "haproxy container with id proxy_$id already exists."
        else
            echo "creating haproxy container..."
            create_haproxy_config "proxy_$id" "${ip_array[@]}"
            echo "haproxy container with id proxy_$id created!"
        fi

        if is_haproxy_config_updated "${ip_array[@]}"; then
            echo "haproxy.cfg is already created and updated."
        else
            echo "creating and updating haproxy.cfg..."
            create_haproxy_config "proxy_$id" "${ip_array[@]}"
        fi

        haproxy_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "proxy_$id")
        echo "haproxy_ip: $haproxy_ip"
        num_req=4

        echo "test traffic load between all container replicas using haproxy ip: $haproxy_ip"
        for ((i = 1; i <= num_req; i++)); do
            response=$(curl -s "http://$haproxy_ip:80")
            echo "Request $i: $response"
            sleep 2
        done
    done
    sleep 3

done

