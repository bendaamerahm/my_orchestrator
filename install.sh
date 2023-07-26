#!/bin/bash

# check run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

rm -r /tmp/strivly
systemctl stop manager
systemctl stop worker
systemctl stop service
systemctl stop ingress
docker container prune --force
sudo docker image prune --force

# create directories
echo "Creating Working dir /tmp/strivly ..."
mkdir /tmp/strivly
mkdir /tmp/strivly/containers
mkdir /tmp/strivly/deployments
mkdir /tmp/strivly/services
mkdir /tmp/strivly/ingresses
mkdir /tmp/strivly/nginx
echo "Working dir /tmp/strivly and nested dirs created successfully"

# copy the project files into "strivly" dir
echo "Copy scripts under working dir"
cp -r ./* /tmp/strivly/

# go to strivly
cd /tmp/strivly || exit

# add executable rights to script files
echo "add executable rights to script files"
chmod +x manager.sh
chmod +x cli.sh
chmod +x worker.sh
chmod +x service.sh
chmod +x ingress.sh

# copy the services files into systemd dir
echo "copy the services files into systemd dir"
cp ./manager.service /etc/systemd/system
cp ./worker.service /etc/systemd/system
cp ./service.service /etc/systemd/system
cp ./ingress.service /etc/systemd/system

# enable and start services
echo "enable and start services"
systemctl enable manager
systemctl enable worker
systemctl enable service
systemctl enable ingress
systemctl start manager
systemctl start worker
systemctl start service
systemctl start ingress

# cli.sh as command
echo "add cli.sh as command"
cp cli.sh /usr/local/bin/cli

echo "Installed with success!"
echo "now you can use cli command to create deployments and services! happy orchestrating :)"