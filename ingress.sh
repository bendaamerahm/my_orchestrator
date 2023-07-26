#!/bin/bash

INGRESSES_DIR="/tmp/strivly/ingresses"
SERVICES_DIR="/tmp/strivly/services"
NGINX_DIR="/tmp/strivly/nginx"

while true; do
    find "$INGRESSES_DIR" -name 'config.json' -type f | while IFS= read -r filepath; do
        json=$(cat "$filepath")
        id=$(jq -r '.id' <<< "$json")
        name=$(jq -r '.name' <<< "$json")
        host=$(jq -r '.host' <<< "$json")
        backends=$(jq -r '.backends' <<< "$json")
        
        # add host
        if ! grep -q "$host" /etc/hosts; then
            echo "127.0.0.1       $host" | sudo tee -a /etc/hosts > /dev/null
        fi

        # prepare nginx configuration
        config="server {\n"
        config+="\tlisten 80;\n"
        config+="\tserver_name $host;\n"

        for backend in $(jq -c '.[]' <<< "$backends"); do
            # path and service
            backend_path=$(jq -r '.path' <<< "$backend")
            backend_service=$(jq -r '.service' <<< "$backend")
            echo "backend_service: $backend_service"

            service_id=""
            readarray -d '' service_files < <(find "$SERVICES_DIR" -name 'config.json' -print0)
            for service_file in "${service_files[@]}"; do
                service_json=$(cat "$service_file")
                service_name=$(jq -r '.name' <<< "$service_json")
                echo "service_json: $service_json"
                echo "service_name: $service_name"
                if [ "$service_name" == "$backend_service" ]; then
                    service_id=$(jq -r '.id' <<< "$service_json")
                    break
                fi
            done

            if [ -z "$service_id" ]; then
                echo "Service $backend_service not found. Skipping."
                continue
            fi

            if ! docker inspect "proxy_$service_id" > /dev/null 2>&1; then
                echo "Docker container proxy_$service_id not found. Skipping."
                continue
            fi

            service_ip=$(docker inspect "proxy_$service_id" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

            # add location  section in the nginx configuration
            config+="\tlocation $backend_path {\n"
            config+="\t\trewrite ${backend_path} /\$1;\n"
            config+="\t\tproxy_pass http://$service_ip;\n"
            config+="\t}\n"
        done

        config+="}"

        # create file with nginx conf in tmp
        echo -e "$config" > "/tmp/$id.conf"


        if ! docker ps --format '{{.Names}}' | grep -q "^$name\$"; then
            # if the container isn't running, try to start it
            if docker ps -a --format '{{.Names}}' | grep -q "^$name\$"; then
                docker start "$name"
            else
                # if the container doesn't exist at all, run a new one
                docker run -d --name "$name" -p 8081:80 -v "$NGINX_DIR":/etc/nginx/conf.d nginx
            fi
        fi

        if ! cmp -s "/tmp/$id.conf" "$NGINX_DIR/$id.conf"
        then
            mv "/tmp/$id.conf" "$NGINX_DIR/$id.conf"
            docker exec "$name" nginx -s reload
        else
            rm "/tmp/$id.conf"
        fi

    done

    sleep 5
done
