To set up the orchestrator, follow the steps below:

1. Clone the project:
```
git clone <project-url>
```

2. Change to the project directory:
```
cd <project-directory>
```

3. Create a directory named "strivly" in the /tmp directory and copy the project files into it:
```
cd /tmp && mkdir strivly
sudo cp -r . /tmp/strivly
cd strivly && mkdir containers deployments
```

4. Copy the manager and worker service files to the appropriate systemd directory:
```
sudo cp ./manager.service /etc/systemd/system
sudo cp ./worker.service /etc/systemd/system
```

5. Enable and start the manager and worker services:
```
sudo systemctl enable manager
sudo systemctl enable worker
sudo systemctl start manager
sudo systemctl start worker
```

6. Make the necessary scripts executable:
```
chmod +x api.sh
chmod +x cli.sh
chmod +x worker.sh
```

7. Start the Vagrant virtual machine:
```
vagrant up
```

8. Create a deployment named "app" with an Nginx image and 3 replicas using the CLI script:
```
sudo ./cli.sh deployment:create --name app --image nginx --replicas 3
```

After completing these steps, you can organize the instructions as a readme.md script with the appropriate formatting and explanations.
