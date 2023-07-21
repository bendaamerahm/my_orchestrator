#!/bin/bash

# check run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# clone
git clone https://github.com/bendaamerahm/my_orchestrator.git

# create directories
mkdir /tmp/strivly
mkdir /tmp/strivly/containers
mkdir /tmp/strivly/deployments
mkdir /tmp/strivly/services

# copy the project files into "strivly" dir
cp -r my_orchestrator/* /tmp/strivly/

# go to strivly
cd /tmp/strivly

# add executable rights to script files
chmod +x manager.sh
chmod +x cli.sh
chmod +x worker.sh

# copy the services files into systemd dir
cp ./manager.service /etc/systemd/system
cp ./worker.service /etc/systemd/system

# enable and start services
systemctl enable manager
systemctl enable worker
systemctl start manager
systemctl start worker

# cli.sh as command
cp cli.sh /usr/local/bin/cli
