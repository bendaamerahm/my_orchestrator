# Strivly orchestrator setup

1. Clone the project:
```
git clone https://github.com/bendaamerahm/my_orchestrator.git
```

2. Change to the project directory:
```
cd my_orchestrator
```

3. Create a directory named "strivly" in the /tmp directory and copy the project files into it:
```
cd /tmp && mkdir strivly
cd strivly && mkdir containers deployments
sudo cp -r <path_to_my_orchestrator>/* .
```

4. Make the necessary scripts executable:
```
chmod +x manager.sh
chmod +x cli.sh
chmod +x worker.sh
```

5. Copy the manager and worker service files to the appropriate systemd directory:
```
sudo cp ./manager.service /etc/systemd/system
sudo cp ./worker.service /etc/systemd/system
```

6. Enable and start the manager and worker services:
```
sudo systemctl enable manager
sudo systemctl enable worker
sudo systemctl start manager
sudo systemctl start worker
```

7. Create a deployment named "app" with an Nginx image and 3 replicas using the CLI script:
```
sudo ./cli.sh deployment:create --name app --image nginx --replicas 2
```