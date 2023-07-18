# Strivly orchestrator setup
    
clone project 

cd to project

cd /tmp && mkdir strivly
sudo cp . /tmp/strivly
cd strivly && mkdir containers deployments

sudo cp ./manager.service /etc/systemd/system
sudo cp ./worker.service /etc/systemd/system

sudo systemctl enable manager
sudo systemctl enable worker
sudo systemctl start manager
sudo systemctl start worker

chmod +x api.sh
chmod +x cli.sh
chmod +x worker.sh

vagrant up

sudo ./cli.sh deployment:create --name app --image nginx --replicas 3